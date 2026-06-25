---
name: auto-learnings
description: >
  Persistent cross-session memory for coding work: captures corrections, preferences, project facts, and debug insights to a markdown store (~/.learnings/ and ./.learnings/) so future sessions remember them. ALWAYS invoke this skill when the user manages their memory or learnings — "set up learnings", "show" or "list my learnings", "review my learnings", "forget X" or "remove that from learnings", and "migrate" / "import my notes or CLAUDE.md into learnings" must each trigger it. ALSO invoke it to capture knowledge mid-session: when the user corrects you ("no, use X not Y", "we use yarn not npm"), states a preference ("always use...", "I prefer...", "don't do..."), reveals a durable project fact (paths, conventions, where things live), or shares a hard-won debug insight — propose logging it, even if they never say the words "remember", "learning", or "memory". When unsure whether something is worth persisting across sessions, consult this skill.
---

## Activation

**Capture** — judge silently every turn. When a signal fires, act in that same turn. Don't wait or batch. Nothing is lost if you miss it here; something is lost if the session ends.

**Management commands** (list, review, delete, setup, migrate) — only when the user explicitly requests them.

## What counts as a learning

| Kind | `--section` flag | Example signals |
|------|-----------------|-----------------|
| Correction | `corrections` | "no, use X not Y"; reverting your code; "that's wrong" |
| Preference | `preferences` | "I prefer…"; "always/never…"; stylistic or workflow asks |
| Project fact | `facts` | durable truths about this repo: paths, conventions, team gotchas |
| Debug insight | `insights` | a non-obvious root cause or fix worth not rediscovering |

## Capture flow

Work through these steps in the same turn the signal fires.

### Step 1 — Check setup

If `~/.learnings/` does not exist and this is the first capture attempt in the session, pause:

> "Looks like auto-learnings isn't set up yet. Run setup now? (yes / no)"

If yes → run Setup Mode below, then continue capture. If no → skip for this turn and don't ask again this session.

### Step 2 — Route scope

Apply the first matching rule:

1. Learning references a specific file path, repo convention, or project-specific tool **and the current directory is a git repo** → **project** (`./.learnings/project.md`)
2. Personal style, cross-project workflow, or applies regardless of codebase → **global** (`~/.learnings/global.md`)
3. Current directory is **not a git repo** → treat as a casual chat session; skip project scope entirely and route to global if the learning is worth keeping, or drop it if it's context-specific to the conversation.
4. Genuinely uncertain → ask: "Should this be project-specific or global?"

### Step 3 — Dedup

The learnings files are in context (loaded by the AGENTS.md recall instruction). Before writing, check whether the proposed entry covers the **same fact or rule** as an existing one, even with different wording. Lean toward flagging rather than silently writing.

If a potential duplicate or conflict is found, show both side-by-side:

```
Possible duplicate detected:
  Existing: - [2026-06-15] (opencode) Use rg not grep in this repo
  Proposed: Use `rg` instead of `grep -r` everywhere in this project
Options: skip / overwrite / append
```

- **skip** — drop the proposed entry
- **overwrite** — delete the existing line with your file tools, then write the new entry via script
- **append** — write the new entry immediately after the existing one using your file tools directly (not the script), so they stay adjacent

### Step 4 — Confirm

Use the `AskUserQuestion` tool (not plain text) so the user gets a navigable option picker. Ask one question:

- **question:** `"Capture learning? Scope: <scope> | Section: <section> | Text: <text>"`
- **header:** `"Save learning"`
- **options:**
  - `{ label: "Yes", description: "Log this entry now." }`
  - `{ label: "No", description: "Drop it silently." }`
  - `{ label: "Edit", description: "Change the scope, section, or text before saving." }`

On **Yes** → proceed to step 5.
On **No** → drop silently.
On **Edit** → ask "What would you like to change?" → user replies → regenerate the full block → loop back to Step 4.

### Step 5 — Write

For a project-scoped entry, first note whether `./.learnings/project.md` already exists — Step 6 needs to know whether this capture is what created it. Then run:

```sh
sh ~/.claude/skills/auto-learnings/log-learning.sh \
  --scope   <global|project> \
  --section <corrections|preferences|facts|insights> \
  --agent   <your-tag> \
  --text    "<one-line content>"
```

If the script exits non-zero, report the error message to the user and stop. Do not write the entry directly as a fallback — the script exists to guarantee correct formatting.

### Step 6 — Offer project recall wiring (first project capture only)

This step fires **only** when the entry was project-scoped **and** `./.learnings/project.md` did not exist before Step 5 (i.e., this capture just created it). If the file already existed, skip — the repo was offered wiring before, so don't nag.

Project learnings are only read at session start if some config tells the agent to read `./.learnings/project.md`. Global setup already does this for you on this machine — but a teammate, or you on another machine, without global setup won't pick them up. Offer to wire recall into a **local, gitignored** config file, which is safe because it's never committed and doesn't affect the repo for anyone else:

> "Logged your first project learning here. Want me to add a recall note to this repo's `CLAUDE.local.md` (personal, gitignored — not committed) so these learnings load automatically each session, even without global setup? yes / no
> (Prefer to share them with teammates instead? I can add it to the committed `CLAUDE.md` / `AGENTS.md` — just say so.)"

- **yes** → append the managed block below to the local config for your agent: `./CLAUDE.local.md` for Claude Code, `./AGENTS.local.md` otherwise. Create the file if missing. Show the diff first, then write on confirm. If the user instead asked for the shared/committed file, target `./CLAUDE.md` or `./AGENTS.md` and warn that it will be version-controlled.
- **no** → skip silently. `project.md` now exists, so this step won't fire again for this repo.

Managed block (project recall — the project counterpart to the global block in Setup mode):

```markdown
<!-- BEGIN learnings-skill project recall (managed) -->
## Project Learnings (auto-memory)
At the start of each session, read `./.learnings/project.md` if it exists and
treat its contents as persistent memory you must respect for this project.
<!-- END learnings-skill project recall -->
```

## Your agent tag

| Agent | `--agent` tag |
|-------|--------------|
| Claude Code | `claude-code` |
| opencode | `opencode` |
| Rovo Dev | `rovo-dev` |
| Other | short lowercase identifier, e.g. `cursor`, `copilot` |

## Management commands

### List
**Trigger:** "show my learnings" / "list learnings"

Read `~/.learnings/global.md` and `./.learnings/project.md` (if it exists). Print both, grouped by section, noting which file each section comes from.

### Review
**Trigger:** "review my learnings"

Read the learnings files. Flag entries that are stale (likely no longer true), contradictory (two entries say opposite things), or duplicate (same fact recorded twice). Propose specific edits and confirm before making any change.

### Delete
**Trigger:** "forget X" / "delete this learning" / "remove X from learnings"

1. Find the matching entry in the learnings files
2. Show the exact line: `Found: - [2026-06-15] (opencode) ...`
3. Confirm: "Delete this entry? yes / no"
4. On yes, remove the line with your file tools. The script handles writes only — not deletions.

## Setup mode

**Triggers:**
- User says "set up learnings" (or equivalent phrasing)
- First capture attempt when `~/.learnings/` does not exist

**Steps:**

1. Create `~/.learnings/` and write `~/.learnings/global.md` with the four-section skeleton:

   ```markdown
   # Learnings — Global
   <!-- learnings-skill schema: v1 | Entries: - [YYYY-MM-DD] (agent) text. Manual edits OK. -->

   ## Corrections

   ## Preferences

   ## Project Facts

   ## Debug Insights
   ```

2. **Ask which agent(s) to configure** — do not assume. Present the options:

   ```
   Which agent(s) should I wire up for auto-recall?
   (I'll add a managed block to each agent's config file so it reads your learnings at session start.)

     1. opencode     → ~/.config/opencode/AGENTS.md
     2. Claude Code  → ~/.claude/CLAUDE.md
     3. Rovo Dev     → ~/.rovodev/AGENTS.md
     4. Cursor       → provide path (e.g. ~/.cursor/AGENTS.md)
     5. Other        → provide path to your global AGENTS.md or CLAUDE.md
   ```

   The user may select multiple. For agents not listed, ask for the path to their global config file. For each path provided, check whether the file exists.

3. For each selected agent, read its config file (or note it's missing). Decide where to insert the managed block using judgment — the most natural placement (e.g., after an existing "Memory" or "Context" section; a sensible early position otherwise). Do not blindly append.

4. Show the user the exact diff for each file — the full new file if creating from scratch, or the inserted block if adding to an existing one. Single confirmation covers all writes.

5. On confirm, write the block to each selected agent's config file. The block is the same for all agents:

   ```markdown
   <!-- BEGIN learnings-skill (managed) -->
   ## Persistent Learnings (auto-memory)
   At the start of each session, read these files if they exist and treat their
   contents as persistent memory you must respect:
   - `~/.learnings/global.md` — global learnings (preferences, cross-project corrections & insights)
   - `./.learnings/project.md` — learnings specific to the current project

   When you learn something worth remembering — a correction, a stated preference,
   a durable project fact, or a hard-won debug insight — capture it with the
   learnings skill.
   <!-- END learnings-skill -->
   ```

## Migrate mode

**Triggers:** "migrate learnings" / "import my notes into learnings" / "import CLAUDE.md"

**Flow:**

1. **Identify source** — the path the user provides, or auto-detect common ones: `~/.claude/CLAUDE.md`, old-format `~/.learnings/*.md`, project notes.

2. **Read & extract** — pull individual knowledge items from the source text.

3. **Classify & route** — assign each item to a section (corrections / preferences / facts / insights) and scope (global / project). Items that don't fit cleanly go into an **Unclassified** bucket.

4. **Dedup** — skip items already present in the loaded learnings.

5. **Preview & confirm** — show all proposed entries grouped by destination. List unclassified items separately and wait for the user to assign each one before confirming:

   ```
   Ready to import:
     Global › Preferences (2): ...
     Project › Project Facts (3): ...

   Unclassified (2) — assign a section before I write:
     1. "Run db migrations before starting the dev server" → ?
     2. "Check #backend-alerts Slack for deploy failures" → ?
   ```

6. **Write** — once all items are classified and the user confirms, call `log-learning.sh` per entry. Imported entries use agent tag `(migrated)`:
   `- [YYYY-MM-DD] (migrated) <text>`

**Schema upgrade** (when source is an old-format learnings file):
1. Back up: `cp <file> <file>.bak`
2. Rewrite to current schema
3. Show the diff
4. Write on confirm

## Storage format reference

```markdown
# Learnings — <Global|Project>
<!-- learnings-skill schema: v1 | Entries: - [YYYY-MM-DD] (agent) text. Manual edits OK. -->

## Corrections
- [YYYY-MM-DD] (agent) one-line text

## Preferences

## Project Facts

## Debug Insights
```

Files: `~/.learnings/global.md` (global) · `./.learnings/project.md` (project-specific)
