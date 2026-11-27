# auto-learnings

Cross-session memory for agent coding sessions. Captures corrections, preferences, project facts, and debug insights to a plain-text markdown store so future sessions remember them without re-explaining.

---

## How it works

Two modes:

- **Passive capture** — runs silently every turn. When you correct the agent, state a preference, reveal a project fact, or share a debug insight, it proposes logging it before writing anything.
- **Explicit commands** — setup, list, review, delete, migrate.

---

## Quick start

**First time:** say `set up learnings` — the agent creates the store and wires recall into your agent.

**After that:** just work normally. The skill watches every turn and asks before saving anything.

---

## Commands

### Setup

```
set up learnings
```

Run once per machine. Creates `~/.learnings/global.md` and wires recall into the agents you pick (see [Recall](#recall)).

---

### List

```
show me my learnings
list learnings
```

Prints both `~/.learnings/global.md` and `./.learnings/project.md`, organized by section.

---

### Review

```
review my learnings
```

Reports each store's size against the hook limit, fact-checks every entry that names a file, function, flag, or command (correct, stale detail, wrong, or unchecked, with evidence), finds duplicates (including rules already in `CLAUDE.md` or `AGENTS.md`), and suggests moves. Nothing changes without your confirmation. Review only edits existing entries; it never adds new ones.

---

### Delete

```
forget that thing about rg
remove X from learnings
```

Finds the matching entry, shows the exact line, removes it on confirmation.

---

### Migrate

```
migrate learnings
import my CLAUDE.md into learnings
import my notes into learnings from /path/to/file
```

Imports pre-existing knowledge from another file. Agent extracts items, classifies them, puts ambiguous ones in **Unclassified** for you to assign, then writes everything on a single confirmation, tagged `(migrated)`.

---

## Passive capture

| Signal | What gets captured |
|--------|--------------------|
| You correct the agent ("no, use yarn not npm") | Correction |
| You state a preference ("always use const") | Preference |
| You reveal a project fact ("auth tokens live in Vault") | Project Fact |
| You share a hard-won debug insight | Debug Insight |

Each entry is a rule plus the reason you gave for it, so a later session knows when the rule applies. The agent never invents a reason.

Before writing, the agent asks with a picker:

```
Capture learning? Scope: project | Section: Corrections | Text: Use yarn, not npm. | Why: npm doesn't work with our lockfile.
  Yes / No / Other
```

Type into **Other** to change the entry before it is saved. Permission to reorganize or prune your learnings never lets the agent add new entries without this question.

---

## Storage

```
~/.learnings/
└── global.md          # Preferences and cross-project knowledge

<project>/              # the git root, from any subfolder
└── .learnings/
    └── project.md     # Project-specific conventions, facts, insights
```

Format (schema v2):

```markdown
## Corrections
- [2026-06-20] (claude-code) Use yarn, not npm.
  Why: npm doesn't work with our lockfile.

- [2026-06-20] (opencode) Always use const unless reassignment is needed.

## Project Facts
- [2026-06-20] (claude-code) Auth tokens live in Vault at secret/app/api, not in .env.

## Debug Insights
- [2026-06-20] (opencode) aiohttp swallows exceptions in background tasks, so await the
  response explicitly.
```

Lines wrap at 100 columns, with a blank line between entries. Older one-line (v1) entries stay valid. Plain text, fully editable by hand.

---

## Recall

Setup loads both learnings files into context automatically:

| Agent | Mechanism |
|-------|-----------|
| Claude Code | Two `SessionStart` hooks, `scripts/recall.sh --scope global` and `--scope project` (main session only, not subagents) |
| Codex | The same two hooks with `SessionStart` added; trust them once with `/hooks` (not yet tested on a real Codex) |
| opencode | `scripts/opencode-plugin.js` plugin, linked into `~/.config/opencode/plugins/`; re-reads the files on every turn |
| Other | Managed text block in the agent's config file |

### Size limit

Each hook's output has a limit of 10,000. Past it, the host saves the full text to a file and shows only a short preview, so the session misses most entries. Measured on Claude Code 2.1.332: 10,000 arrives in full, 10,001 becomes a 2,000-character preview.

| Host | Counts | 10,000 is about |
|------|--------|-----------------|
| Claude Code | UTF-16 units (an emoji counts as 2) | 10,000 characters of English or Chinese |
| Codex | bytes (tokens estimated as bytes ÷ 4) | 10,000 characters of English, 3,300 of Chinese |

One hook per store gives each store its own limit. The skill warns you before it matters:

- After each capture, `log-learning.sh` prints a note at 8,000 and a warning above 10,000, naming the host.
- At session start, an over-limit `recall.sh` output begins with a warning, followed by the file list, so both stay inside the preview.
- `sh scripts/check-size.sh` reports both stores at any time.

The scripts never cut entries themselves: choosing what to drop is up to you and the agent, through review.

### Tests

```sh
sh scripts/test-recall.sh   # recall.sh and check-size.sh, needs jq and python3
sh scripts/test-log.sh      # log-learning.sh, needs python3
```

---

## Install

```sh
ln -s /path/to/boring-skills/skills/auto-learnings ~/.claude/skills/auto-learnings
```
