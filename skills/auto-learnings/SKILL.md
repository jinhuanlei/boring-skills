---
name: auto-learnings
metadata:
  files:
    - SKILL.md
    - references/
    - scripts/
    - evals/
description: >
  Persistent cross-session memory for coding work: captures corrections, preferences, project facts, and debug insights to a markdown store (~/.learnings/ and ./.learnings/) so future sessions remember them. ALWAYS invoke this skill when the user manages their memory or learnings — "set up learnings", "show" or "list my learnings", "review my learnings", "forget X" or "remove that from learnings", and "migrate" / "import my notes or CLAUDE.md into learnings" must each trigger it. ALSO invoke it to capture knowledge mid-session: when the user corrects you ("no, use X not Y", "we use yarn not npm"), states a preference ("always use...", "I prefer...", "don't do..."), reveals a durable project fact (paths, conventions, where things live), or shares a hard-won debug insight — propose logging it, even if they never say the words "remember", "learning", or "memory". When unsure whether something is worth persisting across sessions, consult this skill. FINALLY, if you are about to record something in your own built-in memory store, invoke this skill first — it routes scope so the two stores don't drift apart.
---

# auto-learnings

Two stores: `~/.learnings/global.md` (everywhere) and `./.learnings/project.md` (this repo). A recall hook or managed block loads both at session start.

## When to act

- **Capture:** judge silently every turn. When a signal fires, capture in that same turn. Don't batch: anything not written when the session ends is lost.
- **Management** (list, review, delete, setup, migrate): only when the user asks.

## What counts as a learning

Capture only what would still be true and useful in a fresh session on a different task. These fail the test: a question (even one that challenges your work: answer it, don't log it), an instruction for the current task only, and a fact tied to the current task, PR, or rollout state ("treat flag X as on"). When unsure, skip.

| Kind | `--section` | Example signals |
|------|-------------|-----------------|
| Correction | `corrections` | "no, use X not Y"; reverting your code; "that's wrong, do Y" |
| Preference | `preferences` | "I prefer…"; "always/never…"; style or workflow asks |
| Project fact | `facts` | durable truths about this repo: paths, conventions, team gotchas |
| Debug insight | `insights` | a non-obvious root cause or fix worth not rediscovering |

## Capture flow

Do these steps in the turn the signal fires. Use `AskUserQuestion` for Step 2's non-git choice and Step 4, so the user gets a picker. The rare `skip / overwrite / append` and `yes / no` prompts can be plain text.

### Step 1 — Check setup

If `~/.learnings/` doesn't exist and this is the first capture in the session, ask: "Looks like auto-learnings isn't set up yet. Run setup now? (yes / no)". On yes, follow `references/setup.md`, then continue. On no, skip and don't ask again this session.

### Step 2 — Route scope

Use the first rule that matches:

1. Mentions a specific file path, repo convention, or project-specific tool → **project**
2. Personal style, cross-project workflow, or true regardless of codebase → **global**
3. Genuinely unclear → ask "Should this be project-specific or global?"

If the directory is **not a git repo** and the entry routes to project, ask with `AskUserQuestion` instead. Picking a location also confirms the save, so skip Step 4:

- **question:** `"Heads up — this isn't a git repo, so project learnings would just sit in a ./.learnings/ folder here. Where should this <text> go?"`
- **header:** `"Learning scope"`
- **options:** `Project` (save to `./.learnings/project.md` here), `Global` (save to `~/.learnings/global.md`), `Don't save` (drop it)

An **Other** answer is edit instructions, handled as in Step 4.

### Step 3 — Dedup

Check both files: a duplicate often sits in the other scope. They are usually in context already, but read any file you can't see; a missing file is not proof of no duplicates. Flag an entry that states the **same fact or rule** in different words. Lean toward flagging. (Claude Code's native memory dedups itself; don't cross-check it.)

On a likely duplicate or conflict, show both:

```
Possible duplicate detected:
  Existing: - [2026-06-15] (opencode) Use rg not grep in this repo
  Proposed: Use `rg` instead of `grep -r` everywhere in this project
Options: skip / overwrite / append
```

- **skip:** drop the proposed entry.
- **overwrite:** replace the existing line in place with your file tools.
- **append:** write the new entry right after the existing one with your file tools.

These two branches edit the file directly because position matters and the script can only append to the end of a section. Keep the format `- [YYYY-MM-DD] (agent) text`, with the date from the system clock.

### Step 4 — Confirm

Ask one `AskUserQuestion`:

- **question:** `"Capture learning? Scope: <scope> | Section: <section> | Text: <text>"`
- **header:** `"Save learning"`
- **options:** `Yes` (log this entry now), `No` (drop it silently)

The tool adds an **Other** free-text option on its own. Treat that answer as edit instructions: apply them, then ask again.

### Step 5 — Write

For a project entry, first note whether `./.learnings/project.md` exists; Step 6 needs it. Then run:

```sh
sh ~/.claude/skills/auto-learnings/scripts/log-learning.sh \
  --scope   <global|project> \
  --section <corrections|preferences|facts|insights> \
  --agent   <tag> \
  --text    "<one-line content>"
```

`--agent` records who wrote the entry:

| Agent | `--agent` |
|-------|-----------|
| Claude Code | `claude-code` |
| opencode | `opencode` |
| Codex | `codex` |
| Other | short lowercase name, e.g. `cursor` |

If the script exits non-zero, report its message and stop. Don't hand-write the entry instead: the script guarantees the format, so a failure means something is wrong.

### Step 5b — Native memory (Claude Code, project scope only)

If you are Claude Code and the entry is project-scoped, also save it with your normal memory mechanism, following your system prompt's rules. Global entries stay in `~/.learnings/global.md` only: Claude Code's memory store is per project, so there is no global target. Other agents skip this step.

### Step 6 — Project recall wiring

Only for agents without a recall hook, and only when this capture just created `./.learnings/project.md`: follow "Project recall wiring" in `references/setup.md`. Claude Code, Codex, and opencode with the hook installed skip this.

## Management commands

**List** ("show my learnings"): print both files, grouped by section, saying which file each section is from.

**Review** ("review my learnings"): flag stale, contradictory, or duplicate entries. Propose specific edits and confirm before changing anything.

**Delete** ("forget X", "remove X from learnings"):

1. Find the entry and show the exact line, e.g. `Found: - [2026-06-15] (opencode) ...`
2. Ask "Delete this entry? yes / no".
3. On yes, remove the line with your file tools (the script only writes).
4. If you are Claude Code and the entry was project-scoped, delete the matching native memory file and its `MEMORY.md` pointer too. Writing to both stores but deleting from one makes them drift.

**Setup** ("set up learnings"): follow `references/setup.md`.

**Migrate** ("migrate learnings", "import my notes / CLAUDE.md"): follow `references/migrate.md`.

## Storage format

```markdown
# Learnings — <Global|Project>
<!-- learnings-skill schema: v1 | Entries: - [YYYY-MM-DD] (agent) text. Manual edits OK. -->

## Corrections
- [YYYY-MM-DD] (agent) one-line text

## Preferences

## Project Facts

## Debug Insights
```
