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

Reads the learnings files and flags stale, contradictory, or duplicated entries. Proposes edits — nothing changes without your confirmation.

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

Imports pre-existing knowledge from another file. Agent extracts items, classifies them, puts ambiguous ones in **Unclassified** for you to assign — then writes everything on a single confirmation, tagged `(migrated)`.

---

## Passive capture

| Signal | What gets captured |
|--------|--------------------|
| You correct the agent ("no, use yarn not npm") | Correction |
| You state a preference ("always use const") | Preference |
| You reveal a project fact ("auth tokens live in Vault") | Project Fact |
| You share a hard-won debug insight | Debug Insight |

Before writing, the agent shows a confirmation block:

```
Capture learning?
  Scope:   project
  Section: Corrections
  Text:    Use yarn, not npm — project switched 6 months ago.
[yes / no / edit]
```

`edit` lets you rephrase before confirming.

---

## Storage

```
~/.learnings/
└── global.md          # Preferences and cross-project knowledge

<project>/
└── .learnings/
    └── project.md     # Project-specific conventions, facts, insights
```

Format:

```markdown
## Corrections
- [2026-06-20] (claude-code) Use yarn not npm; project switched 6 months ago.

## Preferences
- [2026-06-20] (opencode) Always use const unless reassignment is needed.

## Project Facts
- [2026-06-20] (claude-code) Auth tokens live in Vault at secret/app/api, not in .env.

## Debug Insights
- [2026-06-20] (opencode) aiohttp swallows exceptions in background tasks — must await response explicitly.
```

Plain text, fully editable by hand.

---

## Recall

Setup loads both learnings files into context automatically:

| Agent | Mechanism |
|-------|-----------|
| Claude Code | `SessionStart` hook running `scripts/recall.sh` (main session only, not subagents) |
| Codex | `SessionStart` hook running `scripts/recall.sh SessionStart`; trust it once with `/hooks` (not yet tested on a real Codex) |
| opencode | `scripts/opencode-plugin.js` plugin, linked into `~/.config/opencode/plugins/`; re-reads the files on every turn |
| Other | Managed text block in the agent's config file |

Claude Code truncates large hook output to a short preview (seen at about 35 KB). The injected text starts with the file paths so the agent can read them in full.

Check the script with `sh scripts/test-recall.sh` (needs `jq`).

---

## Install

```sh
ln -s /path/to/boring-skills/skills/auto-learnings ~/.claude/skills/auto-learnings
```
