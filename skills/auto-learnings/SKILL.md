---
name: auto-learnings
metadata:
  files:
    - SKILL.md
    - references/
    - scripts/
    - evals/
description: >
  Persistent cross-session memory for coding work: saves corrections, preferences, project facts, and debug insights to markdown (~/.learnings/ and ./.learnings/). ALWAYS invoke when the user manages memory or learnings: "set up learnings", "show" or "list my learnings", "review my learnings", "forget X" or "remove that from learnings", "migrate" / "import my notes or CLAUDE.md into learnings". ALSO invoke to capture knowledge mid-session: the user corrects you ("no, use X not Y", "we use yarn not npm"), states a preference ("always use...", "I prefer...", "don't do..."), reveals a durable project fact (paths, conventions, where things live), or shares a hard-won debug insight. Propose logging it even if they never say "remember", "learning", or "memory". When unsure whether something is worth persisting, consult this skill. If you are about to record something in your own built-in memory store, invoke this skill first: it routes scope so the two stores don't drift apart.
---

# auto-learnings

Two stores: `~/.learnings/global.md` (everywhere) and `.learnings/project.md` in the project folder. The project folder is the git root, or the nearest folder below it that already has a `.learnings/project.md`. The scripts resolve it, so you can run them from any subfolder. A recall hook or managed block loads both stores at session start.

## When to act

- **Capture** (a new entry): judge silently every turn. When a signal fires, capture in that same turn. Don't batch: anything not written when the session ends is lost.
- **Maintenance** (list, review, edit, move, merge, delete, setup, migrate): only when the user asks.

Permission for maintenance never covers capture. If the user lets you reorganize or prune their learnings, every new entry still goes through Step 4, including one that would record that permission or a complaint. Never save a learning that grants you permission to do something: an entry like that approves itself.

## What counts as a learning

Capture only what would still be true and useful in a fresh session on a different task. These fail the test: a question (even one that challenges your work: answer it, don't log it), an instruction for the current task only, and a fact tied to the current task, PR, or rollout state ("treat flag X as on"). When unsure, skip.

| Kind | `--section` | Example signals |
|------|-------------|-----------------|
| Correction | `corrections` | "no, use X not Y"; reverting your code; "that's wrong, do Y" |
| Preference | `preferences` | "I prefer…"; "always/never…"; style or workflow asks |
| Project fact | `facts` | durable truths about this repo: paths, conventions, team gotchas |
| Debug insight | `insights` | a non-obvious root cause or fix worth not rediscovering |

## Entry shape

An entry is a rule plus its reason. A later agent with only the rule follows it blindly, or drops it when it looks odd. With the reason, it can apply the rule to cases the author never saw.

- `--text`: the rule. If it applies only in some cases, say when in the rule itself ("In migration files, …").
- `--why`: the reason. Leave it out only when the rule shows its own reason.

Take the reason from what the user said. Never invent one. If the user gave none and you can't tell, ask once, or save without it.

Keep text and reason together under about 400 characters. If an entry needs more (steps, code, several cases), put the detail in a separate file that loads on demand, and save a short entry pointing to it.

## Capture flow

Do these steps in the turn the signal fires. Use `AskUserQuestion` for Step 2's non-git choice and Step 4, so the user gets a picker. The rare `skip / overwrite / append` and `yes / no` prompts can be plain text.

### Step 1: Check setup

If `~/.learnings/` doesn't exist and this is the first capture in the session, ask: "Looks like auto-learnings isn't set up yet. Run setup now? (yes / no)". On yes, follow `references/setup.md`, then continue. On no, skip and don't ask again this session.

### Step 2: Route scope

Use the first rule that matches:

1. Mentions a specific file path, repo convention, or project-specific tool → **project**
2. Personal style, cross-project workflow, or true regardless of codebase → **global**
3. Genuinely unclear → ask "Should this be project-specific or global?"

If the directory is **not a git repo** and the entry routes to project, ask with `AskUserQuestion` instead. Picking a location also confirms the save, so skip Step 4:

- **question:** `"Heads up: this isn't a git repo, so project learnings would just sit in a .learnings/ folder here. Where should this <text> go?"`
- **header:** `"Learning scope"`
- **options:** `Project` (save to `.learnings/project.md` here), `Global` (save to `~/.learnings/global.md`), `Don't save` (drop it)

An **Other** answer is edit instructions, handled as in Step 4.

### Step 3: Dedup

Check both stores: a duplicate often sits in the other scope. Also check the always-loaded instruction files in your context: `CLAUDE.md`, `AGENTS.md`, their local variants, and user-level rules. A rule that is already there would load twice every session. The stores are usually in context already, but read any you can't see; a missing file is not proof of no duplicates. Flag an entry that states the **same fact or rule** in different words. Lean toward flagging. (Claude Code's native memory dedups itself; don't cross-check it.)

If the duplicate is in an instruction file, tell the user where it is and skip the capture.

If it is in a learnings store, show both:

```
Possible duplicate detected:
  Existing: - [2026-06-15] (opencode) Use rg not grep in this repo
  Proposed: Use `rg` instead of `grep -r` everywhere in this project
Options: skip / overwrite / append
```

- **skip:** drop the proposed entry.
- **overwrite:** replace the existing entry in place with your file tools.
- **append:** write the new entry right after the existing one with your file tools.

These two branches edit the file directly because position matters and the script can only append to the end of a section. An entry is its `- [` line plus the indented lines under it. Keep the format from "Storage format" below, with the date from the system clock.

### Step 4: Confirm

Before asking, check: would an agent on a different task understand why this rule exists? If not, add the reason the user gave, or ask for it (see "Entry shape").

Ask one `AskUserQuestion`:

- **question:** `"Capture learning? Scope: <scope> | Section: <section> | Text: <text> | Why: <why or none>"`
- **header:** `"Save learning"`
- **options:** `Yes` (log this entry now), `No` (drop it silently)

The tool adds an **Other** free-text option on its own. Treat that answer as edit instructions: apply them, then ask again.

### Step 5: Write

```sh
sh ~/.claude/skills/auto-learnings/scripts/log-learning.sh \
  --scope   <global|project> \
  --section <corrections|preferences|facts|insights> \
  --agent   <tag> \
  --text    "<the rule>" \
  --why     "<the reason>"   # optional
```

`--agent` records who wrote the entry:

| Agent | `--agent` |
|-------|-----------|
| Claude Code | `claude-code` |
| opencode | `opencode` |
| Codex | `codex` |
| Other | short lowercase name, e.g. `cursor` |

If the script exits non-zero, report its message and stop. Don't hand-write the entry instead: the script guarantees the format, so a failure means something is wrong.

Pass any `Note:` or `Warning:` line from the output to the user. A size note means the store's recall output is close to or over the hosts' 10,000 limit. Past it, a host shows only a short preview and later sessions miss most entries. Suggest "review my learnings".

### Step 5b: Native memory (Claude Code, project scope only)

Skip this step if `~/.claude/settings.json` has a `SessionStart` hook whose command contains `auto-learnings/scripts/recall.sh`. The hook already loads the project store every session, so a native copy would only drift.

Otherwise, if you are Claude Code and the entry is project-scoped, also save it with your normal memory mechanism, following your system prompt's rules. Global entries stay in `~/.learnings/global.md` only: Claude Code's memory store is per project, so there is no global target. Other agents skip this step.

### Step 6: Project recall wiring

Only for agents without a recall hook, and only when the Step 5 output started with `Created`, meaning this capture made a new project store: follow "Project recall wiring" in `references/setup.md`. Claude Code, Codex, and opencode with the hook installed skip this.

## Management commands

**List** ("show my learnings"): print both stores, grouped by section, saying which file each section is from.

**Review** ("review my learnings"): follow `references/review.md`.

**Delete** ("forget X", "remove X from learnings"):

1. Find the entry and show all of it (its `- [` line and the indented lines under it), e.g. `Found: - [2026-06-15] (opencode) ...`
2. Ask "Delete this entry? yes / no".
3. On yes, remove the whole entry with your file tools (the script only writes), plus one blank line next to it.
4. If you are Claude Code and the entry was project-scoped, look for a matching native memory file. Older captures made one even with the hook installed. Delete it and its `MEMORY.md` pointer too, so the stores don't drift.

**Setup** ("set up learnings"): follow `references/setup.md`.

**Migrate** ("migrate learnings", "import my notes / CLAUDE.md"): follow `references/migrate.md`.

## Storage format

```markdown
# Learnings: <Global|Project>
<!-- learnings-skill schema: v2 | - [YYYY-MM-DD] (agent) text, optional "  Why:" line. Edits OK. -->

## Corrections
- [YYYY-MM-DD] (agent) The rule, wrapped at 100 columns, with continuation lines
  indented 2 spaces.
  Why: the reason, on its own indented line.

- [YYYY-MM-DD] (agent) Next entry.

## Preferences

## Project Facts

## Debug Insights
```

An entry runs from its `- [` line to the next `- [` line, blank line, or `## ` heading. Files in the older v1 format (one line per entry, no blank lines, a `—` in the title) stay valid. New entries are written in v2. Convert old entries only when the user asks.
