# auto-learnings

A cross-agent skill that automatically captures durable knowledge during coding sessions and persists it to a plain-markdown store so future sessions remember.

Works with opencode, Rovo Dev, Cursor, Claude Code, and any agent that reads `AGENTS.md` or `CLAUDE.md`.

---

## How it works

The skill has two modes:

- **Passive capture** — runs silently every turn. When you correct the agent, state a preference, reveal a project fact, or share a debug insight, it proposes logging it before writing anything.
- **Explicit commands** — triggered by specific phrases for setup, recall, and management.

---

## Quick start

**First time:** say `set up learnings` — the agent will create the store and wire recall into your agent config.

**After that:** just work normally. The skill watches every turn and asks before it saves anything.

---

## Activation modes

### 1. Passive capture (always on)

No trigger needed. The agent judges every turn.

| Signal | What gets captured |
|--------|--------------------|
| You correct the agent ("no, use yarn not npm") | Correction |
| You state a preference ("always use const") | Preference |
| You reveal a project fact ("auth tokens live in Vault") | Project Fact |
| You share a hard-won debug insight | Debug Insight |

When a signal fires, the agent shows a confirmation block before writing:

```
Capture learning?
  Scope:   project
  Section: Corrections
  Text:    Use yarn, not npm — project switched 6 months ago, yarn.lock is the source of truth.
[yes / no / edit]
```

`edit` lets you rephrase before confirming.

---

### 2. Setup

```
set up learnings
```

Run once on each machine. The agent will:
1. Create `~/.learnings/global.md` with the four-section skeleton
2. Ask which agent(s) to configure — choose any combination:
   - **opencode** → `~/.config/opencode/AGENTS.md`
   - **Claude Code** → `~/.claude/CLAUDE.md`
   - **Cursor / Rovo Dev / Other** → you provide the path
3. Show the exact diff for each config file
4. Write everything on a single confirmation

> **Note:** Claude Code reads `CLAUDE.md`, not `AGENTS.md`. The same managed block is written to both — only the target file differs.

---

### 3. List

```
show me my learnings
show my learnings
list learnings
```

Reads both `~/.learnings/global.md` and `./.learnings/project.md` and prints them organized by section, noting which file each comes from.

---

### 4. Review

```
review my learnings
```

Reads the learnings files and flags entries that are stale, contradictory, or duplicated. Proposes edits — nothing changes without your confirmation.

---

### 5. Delete

```
forget that thing about rg
forget X
remove X from learnings
```

Finds the matching entry, shows you the exact line, then removes it on confirmation.

---

### 6. Migrate

```
migrate learnings
import my CLAUDE.md into learnings
import my notes into learnings from /path/to/file
```

Imports pre-existing knowledge from another source (CLAUDE.md, another agent's memory file, your own notes, or a `self-improvement` skill's `LEARNINGS.md`). 

Flow:
1. You provide the source path
2. Agent extracts individual knowledge items and classifies them
3. Ambiguous items go into an **Unclassified** bucket — you assign each one before anything is written
4. Full preview → single confirmation → writes all entries tagged `(migrated)`

---

## Storage

```
~/.learnings/
└── global.md          # Preferences and cross-project knowledge

<project>/
└── .learnings/
    └── project.md     # Project-specific conventions, facts, insights
```

Both files use the same format:

```markdown
## Corrections
- [2026-06-20] (claude-code) Use yarn not npm; project switched 6 months ago.

## Preferences
- [2026-06-20] (opencode) Always use const unless reassignment is needed.

## Project Facts
- [2026-06-20] (rovo-dev) Auth tokens live in Vault at secret/app/api, not in .env.

## Debug Insights
- [2026-06-20] (opencode) aiohttp swallows exceptions in background tasks — must await response explicitly.
```

Entries are plain text and fully editable by hand.

---

## Recall

After setup, the managed block in `AGENTS.md` instructs the agent to read both learnings files at the start of every session. No extra commands needed — learnings are automatically in context.

---

## Install

The skill lives at `~/.claude/skills/auto-learnings/` (symlinked from this repo).

To install on a new machine, copy or symlink this directory to `~/.claude/skills/auto-learnings/`.
