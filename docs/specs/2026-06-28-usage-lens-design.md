# usage-lens Design Spec
*2026-06-28*

## Overview

A skill that tracks and analyzes Claude Code skill invocations (and future: MCP tool calls) to surface usage patterns and recommendations. Initial release covers tracking and analysis; automatic enable/disable is a future improvement.

---

## Phase 0: Probe (do this first)

Before building the hooks, we don't actually know (a) what fields the `PostToolCall` hook payload contains, (b) which file Claude Code reads tool-level hooks from (`settings.json` vs `hooks.json`), (c) whether session ID is available to hook scripts, or (d) how hook failures (non-zero exit) affect tool calls.

A temporary probe script answers all four:
1. Wire a probe as the `PostToolCall` handler in `settings.json`.
2. Dump everything it receives (stdin + env) to `~/.claude/usage-lens-probe.json`.
3. Invoke any skill once to trigger it.
4. Read the dump, confirm field names and the hook mechanism, then remove the probe.

All field-access decisions below are provisional until the probe confirms them.

---

## Architecture

Three moving parts wired via Claude Code's hook system:

```
User prompt
    │
    ▼
[UserPromptSubmit hook]      →  writes prompt to /tmp/claude-usage-lens-<session_id>.txt
    │
    ▼  (Claude invokes Skill tool)
[PostToolCall hook]          →  if tool == "Skill": read config + last prompt → append to JSONL
    │
    ▼
~/.claude/usage-lens.jsonl   (one line per invocation)
    │
    ▼  (user types /usage-lens)
[usage-lens skill]           →  calls analyze.py --json → formats report + recommendations
```

### File layout

```
boring-skills/skills/usage-lens/
├── SKILL.md
└── scripts/
    ├── analyze.py           # analysis; emits JSON; also callable standalone
    ├── post_tool_hook.py    # PostToolCall handler
    ├── prompt_hook.py       # UserPromptSubmit handler
    ├── setup.py             # patches settings.json, creates default config
    └── cleanup.py           # trims log + stale temp files
```

External:
- `~/.config/usage-lens/config.json` — user config (optional; defaults used if missing)
- `~/.claude/usage-lens.jsonl` — event log (path overridable in config)
- `~/.claude/usage-lens-errors.log` — silent error log from hooks
- `/tmp/claude-usage-lens-<session_id>.txt` — per-session prompt handoff

---

## Data Schema

### JSONL record

One JSON object per line. Fields present depend on verbosity level.

```json
{
  "ts": 1782691691492,
  "type": "skill",
  "name": "brainstorming",
  "session_id": "abc123",
  "project": "/Users/jinhuanlei/Documents/code/boring-skills",
  "trigger": "explicit"
}
```

| Field | Always present | Description |
|---|---|---|
| `ts` | yes | Unix timestamp (ms) |
| `type` | yes | Event type: `"skill"` today, `"mcp"` when extended |
| `name` | yes | Skill name or MCP tool name |
| `session_id` | standard + verbose | Claude Code session ID |
| `project` | standard + verbose | CWD of the session |
| `trigger` | standard + verbose | `"explicit"`, `"auto"`, or `"unknown"` |
| `prompt` | verbose only | The user message that triggered the invocation |

**Trigger detection:** `prompt_hook.py` writes the raw user prompt to `/tmp/claude-usage-lens-<session_id>.txt` on every `UserPromptSubmit`. `post_tool_hook.py` reads its session's file and checks if it starts with `/<name>` — yes → `"explicit"`, otherwise → `"auto"`. If session ID is unavailable to the hook, log `"trigger": "unknown"` rather than guessing.

**Concurrent writes:** `post_tool_hook.py` uses `fcntl.flock` when appending to the JSONL so simultaneous sessions can't interleave partial lines.

### Config file (`~/.config/usage-lens/config.json`)

The config file is **optional**. If it is missing or malformed, hooks and scripts fall back to the defaults below silently (no crash, no prompt).

```json
{
  "verbosity": "standard",
  "log_path": "~/.claude/usage-lens.jsonl",
  "inactive_threshold_days": 30,
  "trend_window_days": 30,
  "cleanup_keep_days": 90
}
```

| Key | Default | Description |
|---|---|---|
| `verbosity` | `"standard"` | `"minimal"` \| `"standard"` \| `"verbose"` |
| `log_path` | `~/.claude/usage-lens.jsonl` | Where to write the event log (`~` expanded) |
| `inactive_threshold_days` | `30` | Days without use before "inactive" flag; also the grace period after install before a skill is eligible for the flag |
| `trend_window_days` | `30` | Size of each window for trend comparison (recent vs prior) |
| `cleanup_keep_days` | `90` | Records/temp files older than this are removed by cleanup |

`post_tool_hook.py` reads config on every fire (sub-ms local read; no caching to avoid a session-start dependency). Reads are wrapped in error handling — missing/bad config never breaks logging.

---

## Hooks

Two entries added to `~/.claude/settings.json` (path confirmed by the probe; if Claude Code uses `hooks.json` for tool-level hooks instead, setup targets that file) by `setup.py`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python ~/.claude/skills/usage-lens/scripts/prompt_hook.py"
          }
        ]
      }
    ],
    "PostToolCall": [
      {
        "matcher": "Skill",
        "hooks": [
          {
            "type": "command",
            "command": "python ~/.claude/skills/usage-lens/scripts/post_tool_hook.py"
          }
        ]
      }
    ]
  }
}
```

Hook commands reference the **symlink path** (`~/.claude/skills/usage-lens/scripts/...`) so they stay valid regardless of where the repo lives.

**Setup is a surgical merge, not an overwrite:** `setup.py` reads the existing JSON, merges in only the two new hook entries, and writes back — existing keys (env, permissions, other hooks) are preserved. No backup needed.

**Setup is idempotent:** if the entries already exist, print "already configured" and exit without duplicating.

**Hook resilience:** every hook body is wrapped in `try/except Exception`, logs failures to `~/.claude/usage-lens-errors.log`, and always `sys.exit(0)`. A telemetry script must never block the tool it observes.

No manual configuration required — `/usage-lens setup` does all of the above and creates the default config file.

---

## Analysis Script

`analyze.py` is the single analysis entry point. It emits **JSON only** — the skill formats the human-friendly report from that JSON. No Claude-specific output mode in the script.

```bash
python analyze.py --json              # full analysis as JSON (default consumer: the skill)
python analyze.py --type skill        # filter by event type
python analyze.py --days 30           # limit window to last N days
python analyze.py --all               # read entire log (no date filter)
```

It reads the whole JSONL file and filters by date in memory (invocations are low-frequency; revisit only if measurably slow).

### Installed-skill sources

To flag never-used skills, `analyze.py` cross-references three sources:
1. **`~/.agents/.skill-lock.json`** — canonical installed list with `installedAt` per skill
2. **`~/.claude/skills/`** — filesystem fallback for skills missing from the lock file
3. **`~/.claude/usage-lens.jsonl`** — invocation history

Skill identity is the **directory name** (matches what's logged); `SKILL.md` frontmatter is not parsed.

### JSON output schema (consumed by the skill)

```json
{
  "period_days": 30,
  "total_events": 127,
  "skills": [
    {
      "name": "brainstorming",
      "count": 24,
      "last_ts": 1782691691492,
      "installed_at": "2026-04-01T12:00:00Z",
      "trend": "up"
    }
  ],
  "recommendations": [
    {"name": "gmail-spam-cleanup", "reason": "inactive", "detail": "not used in 45 days"}
  ]
}
```

`recommendations` is computed by `analyze.py` (the skill only displays). `trend` is one of `"up"` / `"down"` / `"flat"`.

### Trend calculation

Fixed comparison, independent of `--days`: compare the last `trend_window_days` against the `trend_window_days` before that (e.g. recent 30 days vs the prior 30). Classification uses a percentage change with a minimum-volume floor so low counts (1→2) don't register as a trend; below the floor → `"flat"`.

### Inactive / recommendation rules

- A skill is flagged **inactive** if it has zero invocations within `inactive_threshold_days` **and** was installed more than `inactive_threshold_days` ago (grace period — newly installed skills aren't flagged).
- Recommendations are informational only in v1.

### Report format (rendered by the skill from the JSON)

```
Usage Lens — last 30 days (127 events)

Skills
  brainstorming     ████████  24   last: 2h ago    ↑ trending
  auto-learnings    ██████    18   last: 1d ago
  tdd               ██        5    last: 8d ago
  gmail-spam-cleanup          0    last: 45d ago   ⚠ inactive

Recommendations
  • gmail-spam-cleanup — not used in 45 days, consider disabling
  • tdd — usage declining (was 12/mo, now 5/mo)
```

Plain ASCII bars (no ANSI/color) so output renders cleanly both in-conversation and standalone.

---

## Skill (`/usage-lens`)

Modes:

- **`/usage-lens`** — run `analyze.py --json`, format and present the report in-conversation. If hooks aren't configured yet (checked via `settings.json`), prompt the user to run setup first.
- **`/usage-lens setup`** — one-time setup via `setup.py`: merge hook entries, create default config, confirm log path. Idempotent.
- **`/usage-lens cleanup`** — via `cleanup.py`: trim `usage-lens.jsonl` to the last `cleanup_keep_days`, and remove stale `/tmp/claude-usage-lens-*.txt` files older than `cleanup_keep_days`.

---

## Extensibility

Adding MCP tool tracking later requires:
1. A new `PostToolCall` hook matcher for MCP tool names
2. The hook script emits `"type": "mcp"` with `"name": "gmail__send_email"` (or similar)
3. `analyze.py` already handles multiple types via `--type` filter — no changes needed

The JSONL schema and analysis script are type-agnostic by design.

---

## Out of Scope (v1)

- Automatic skill enable/disable
- Cross-user aggregation
- Web dashboard
- Backfilling from `history.jsonl`
