# usage-lens

Tracks which Claude Code skills you actually invoke, then surfaces usage patterns and inactive-skill recommendations. Runs silently via hooks — no manual logging needed.

---

## How it works

Two hooks record every skill invocation:

```
User prompt
    │
    ▼
[UserPromptSubmit hook]  →  writes prompt to /tmp/claude-usage-lens-<session>.txt
    │
    ▼  (Claude invokes a skill)
[PostToolUse hook]       →  reads config + prompt file → appends to ~/.claude/usage-lens.jsonl
    │
    ▼  (you type /usage-lens)
[usage-lens skill]       →  runs analyze.py → formats report
```

`trigger` in each log record is `"explicit"` when your prompt started with `/<skill-name>`, `"auto"` when the agent invoked it on its own.

---

## Commands

### `/usage-lens` — show report

Runs analysis and formats a report:

```
Usage Lens — last 30d  (42 events)

Skills
  brainstorming         ████████    24   last: 2h ago    ↑ trending
  auto-learnings        ██████      18   last: 1d ago
  tdd                   ██           5   last: 8d ago    ↓ declining
  gmail-spam-cleanup                 0   last: 45d ago   ⚠ inactive

Recommendations
  • gmail-spam-cleanup — not used in 45d, consider disabling
  • tdd — usage declining (was 12/mo, now 5/mo)
```

Plain ASCII, renders cleanly in-conversation and standalone.

---

### `/usage-lens setup` — first-time setup

Run once. Merges hook entries into `~/.claude/settings.json` and creates a default config at `~/.config/usage-lens/config.json`. Idempotent — safe to re-run.

Hooks take effect immediately (no restart needed).

---

### `/usage-lens cleanup` — trim old data

Removes log records and stale `/tmp` session files older than `cleanup_keep_days` (default: 90 days). It does not remove or disable any skill; use [`skill-healthcheck`](../../skills/skill-healthcheck/SKILL.md) for that.

---

## Config

Optional. Defaults apply if the file is missing or malformed.

**`~/.config/usage-lens/config.json`:**

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
|-----|---------|-------------|
| `verbosity` | `"standard"` | `"minimal"` / `"standard"` / `"verbose"` — controls which fields are logged |
| `log_path` | `~/.claude/usage-lens.jsonl` | Where events are written |
| `inactive_threshold_days` | `30` | Days without use before "inactive" flag; also the grace period for newly installed skills |
| `trend_window_days` | `30` | Window size for trend comparison (recent 30d vs prior 30d) |
| `cleanup_keep_days` | `90` | Records older than this are removed by cleanup |

---

## Log format

One JSON line per skill invocation:

```json
{"ts": 1782691691492, "type": "skill", "name": "brainstorming", "session_id": "abc123", "project": "/Users/you/code/myapp", "trigger": "explicit"}
```

`ts` is Unix milliseconds. `type` is `"skill"` today — `"mcp"` when MCP tool tracking is added later.

---

## Scripts

All under `skills/usage-lens/scripts/`:

| Script | Purpose |
|--------|---------|
| `prompt_hook.py` | `UserPromptSubmit` handler — writes prompt to `/tmp` |
| `post_tool_hook.py` | `PostToolUse` handler — appends to JSONL |
| `analyze.py` | Reads JSONL + skill-lock, emits JSON consumed by the skill |
| `setup.py` | Merges hooks into `settings.json`, creates default config |
| `cleanup.py` | Trims JSONL and stale `/tmp` files |

`analyze.py` is also callable standalone:

```sh
python ~/.claude/skills/usage-lens/scripts/analyze.py --json
python ~/.claude/skills/usage-lens/scripts/analyze.py --days 7
python ~/.claude/skills/usage-lens/scripts/analyze.py --all
```

---

## Install

```sh
ln -s /path/to/boring-skills/skills/usage-lens ~/.claude/skills/usage-lens
```

Then run `/usage-lens setup` to wire the hooks.

---

## Design spec

Full design rationale: [`docs/specs/2026-06-28-usage-lens-design.md`](../specs/2026-06-28-usage-lens-design.md)
