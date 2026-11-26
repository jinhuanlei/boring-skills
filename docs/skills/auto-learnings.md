# auto-learnings

Cross-session memory for agent coding sessions. Captures corrections, preferences, project facts, and debug insights to a plain-text markdown store so future sessions remember them without re-explaining.

---

## How it works

Two modes:

- **Passive capture** — runs silently every turn. When you correct the agent, state a preference, reveal a project fact, or share a debug insight, it proposes logging it before writing anything.
- **Explicit commands** — setup, list, review, delete, migrate.

---

## Quick start

**First time:** say `set up learnings` — the agent creates the store and wires recall into your agent config.

**After that:** just work normally. The skill watches every turn and asks before saving anything.

---

## Commands

### Setup

```
set up learnings
```

Run once per machine. Creates `~/.learnings/global.md` and offers to add a recall block to your agent configs (opencode, Claude Code, Cursor, or a custom path).

> Claude Code reads `CLAUDE.md`, not `AGENTS.md`. The managed recall block is written to the right file for each agent.

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

After setup, the managed block in your agent config reads both learnings files at session start — no extra commands needed.

The first time a project learning is captured in a new repo, the agent offers to add a recall note to `.learnings/project.md` in that repo (gitignored — never committed). Optional.

---

## Install

```sh
ln -s /path/to/boring-skills/skills/auto-learnings ~/.claude/skills/auto-learnings
```
