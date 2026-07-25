---
name: skill-cleaner
description: >
  Audit installed agent skills for health problems and duplicates, then safely remove
  named skills after checking what depends on them. Invoke when the user wants to clean
  up, uninstall, or remove skills, asks which skills are duplicates or redundant, asks
  whether removing a skill will break anything, or wants a health check of their skill
  set (dangling references, broken handoffs, orphans).
---

Audit first, delete only after explicit approval. Never delete during discovery.

## Hard rules

- **Read-only until approved.** Discovery and analysis never mutate anything.
- **Never edit a skill's files unless the user explicitly agrees to that specific local
  edit.** Installed skills are usually managed by an upstream repo and get overwritten on
  update; a local patch is silent data loss. Propose the edit, name the file, and say it
  will be lost on the next upstream update — then wait. Silence, a vague "sounds good" to
  the surrounding analysis, or approval of a *different* action is not agreement. Without
  that explicit yes, recommend the edit or recommend removal instead.
- **Removal goes through the CLI only** — `npx skills remove`. No `rm -rf`, no hand-editing
  lock files. If the CLI fails, stop and report; recovery needs separate approval.
- **Never infer a dependency from a name.** Shared source repo, shared prefix, or similar
  naming is not evidence. Only a textual reference or declared metadata counts.
- **Approval must follow the report.** Intent stated before the audit ("clean up my skills")
  is not approval of the specific list the audit produces.

## Mode A — Health & duplicate scan

Run when the user asks what's redundant, what's broken, or wants a general audit.

### 1. Inventory

```sh
npx skills list -g          # global
npx skills list             # project (from project root)
```

Read `~/.agents/.skill-lock.json` if present for source/scope metadata. Note the skill
roots the CLI reports — there is usually more than one (`~/.agents/skills`,
`~/.claude/skills`, plugin marketplaces). Scan all of them; skills discovered by the agent
but absent from CLI output are still live and still collide.

### 2. Health findings

Read each skill's `SKILL.md` (not just frontmatter — handoffs live in the body).

| Finding | How to detect |
|---|---|
| **Dangling handoff** | Skill instructs "invoke X" / "run /X" / "the next step is X" where X is not installed. Its workflow dead-ends. |
| **Dangling setup dep** | Skill requires a file or setup skill that isn't present (`docs/agents/issue-tracker.md`, `/setup-foo`). Runs half-broken. |
| **Orphan** | Nothing references it and its trigger overlaps a more developed sibling — it may never fire. |
| **Stale instruction ref** | `CLAUDE.md` / `AGENTS.md` / hooks name a skill that is no longer installed. Report it; do not silently edit those files. |
| **Broken symlink** | Skill dir is a symlink to a missing target. Identify the owning CLI install before recommending anything. |

### 3. Duplicate detection

Compare by **capability**, not name. Two skills are duplicates when their descriptions and
trigger phrases would both plausibly fire on the same user request. Read both bodies in
full before judging — a shared topic is not a duplicate if the depth or output differs
(a quick lookup vs a deep synthesis are complements, not rivals).

For each duplicate pair, recommend a keeper on evidence:

- **Integration** — does it cross-reference other installed skills, or dangle?
- **Depth** — modes, references, sub-agents, verification gates vs a single linear flow.
- **Working state** — a skill whose handoff points at something uninstalled loses.
- **Unique salvage** — name what the loser has that the keeper lacks. If the loser owns
  real tooling (scripts, servers, templates) the keeper has no equivalent of, that is a
  reason to keep both, not a footnote. Say so plainly and let the user decide.

Do not port the loser's content into the keeper's files on your own initiative — see the
hard rule on editing. Extraction into a *new* skill is always fine; patching an existing
one needs the user's explicit yes to that edit first.

Output: findings grouped by severity, each with the file evidence. Then a recommendation
per pair. Stop there — a scan does not roll into deletion without the user asking.

## Mode B — Named-target removal

Run when the user names skills to remove.

### 1. Resolve targets

Normalize each name against the inventory from Mode A step 1. Record scope (global /
project / both) and source. If a target isn't installed, say which scopes were checked and
do not fabricate a command. If the same name exists in both scopes, ask which one.

### 2. Reference analysis

For each target, gather evidence in both directions:

- **Inbound** (who needs the target): grep every installed skill body, `CLAUDE.md`,
  `AGENTS.md`, `.claude/rules/`, hooks, and settings for the target name and its `/name`
  form. Check both scopes — a project skill can depend on a global one and vice versa.
- **Outbound** (what the target needs): references from the target to other skills. These
  become orphan candidates only if every dependent is also being removed.

Weigh the wording. "must use X" / "invoke X" / "run /X" is a required reference.
"may use X" / "if available" is optional. Dynamic or generated invocation is **uncertain** —
uncertain resolves to keep.

Also state **capability loss**: what the user simply won't be able to do anymore. This is
not dependency breakage and must be labeled separately, but it's often the thing the user
actually cares about.

### 3. Classify

| Class | Meaning |
|---|---|
| Safe to remove | No inbound reference, no active workflow use. Only capability is lost. |
| Unsafe alone | A retained skill or instruction requires it. |
| Safe as a group | Safe only if the listed dependents go in the same batch. |
| Uncertain | Evidence incomplete, dynamic, or contradictory → recommend keeping, say what couldn't be proven. |
| Keep | Explicitly requested, or transitively required. |

### 4. Report, then wait

Present: targets table (skill / source / scope / class / one-line reason), dependency
impact (inbound, outbound, cross-scope, capability loss, uncertainties + the files that
caused them), and the proposed action — exact keep list, exact delete list per scope, exact
commands. Then ask for approval or amendment.

### 5. Remove

After explicit approval, re-check the installed list (the plan may be stale), then one bulk
command per scope:

```sh
npx skills remove <names> -g -y     # global
npx skills remove <names> -y        # project
```

If one scope fails, stop. Report partial completion; don't attempt destructive recovery.

### 6. Verify

Re-run the list commands, confirm removed entries are gone from lock files, confirm
retained dependencies survive, and re-grep for references to what was removed. Report any
stale reference in `CLAUDE.md` / `AGENTS.md` / hooks as a follow-up — offer to fix them,
but only edit after the user says yes to that edit.

## Error handling

- CLI syntax uncertain → run `npx skills --help` first. Never guess destructive syntax.
- Malformed lock file → fall back to CLI inventory, mark source conclusions lower confidence.
- Permission failure → report the exact path and command, stop.
- Dependency conflict found right before deletion → return to the report, get fresh approval.

## Non-goals

Wholesale cleanup of everything unused without named targets. Proving runtime dependencies
that leave no textual trace. Editing agent instructions or skill files. Removing source
repos, caches, or non-skill plugins.
