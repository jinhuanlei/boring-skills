# Setup mode

Read this when the user asks to set up learnings, or when a capture finds that `~/.learnings/` does not exist.

## Steps

1. **Create the global store.** Write `~/.learnings/global.md` with the skeleton from "Storage format" in `SKILL.md`, using the title `# Learnings: Global`.

2. **Ask which agents to wire up.** Do not assume. The user may pick several:

   ```
   Which agent(s) should I wire up for auto-recall?

     1. Claude Code  → SessionStart hook in ~/.claude/settings.json
     2. Codex        → SessionStart hook in $CODEX_HOME/hooks.json (default ~/.codex)
     3. opencode     → plugin symlink in ~/.config/opencode/plugins/
     4. Other        → managed text block; give the path to its global AGENTS.md or rules file
   ```

3. **Prepare each selected agent.** Read the existing file first. Merge into it, and leave every other setting and hook untouched.

   Each store gets its own hook. Both hosts limit each hook's output separately, so two hooks give each store the full 10,000 instead of sharing it. If the file already has a `SessionStart` entry whose command contains `auto-learnings/scripts/recall.sh`, replace that entry with the one below. Adding a second one would load the learnings twice.

   **Claude Code.** Add this entry to the `hooks.SessionStart` array in `~/.claude/settings.json`. It reaches the main session only, not subagents. The limit is 10,000 characters per hook, counted in UTF-16 units (an emoji counts as 2), and has no setting.

   ```json
   {
     "matcher": "startup|resume|clear|compact",
     "hooks": [
       { "type": "command", "command": "/bin/sh ~/.claude/skills/auto-learnings/scripts/recall.sh --scope global" },
       { "type": "command", "command": "/bin/sh ~/.claude/skills/auto-learnings/scripts/recall.sh --scope project" }
     ]
   }
   ```

   **Codex.** Add this entry to the `hooks.SessionStart` array in `$CODEX_HOME/hooks.json`. Replace `<HOME>` with the expanded home directory, because Codex may not run a login shell.

   ```json
   {
     "matcher": "startup|resume|clear|compact",
     "hooks": [
       { "type": "command", "command": "/bin/sh <HOME>/.claude/skills/auto-learnings/scripts/recall.sh --scope global SessionStart", "timeout": 5 },
       { "type": "command", "command": "/bin/sh <HOME>/.claude/skills/auto-learnings/scripts/recall.sh --scope project SessionStart", "timeout": 5 }
     ]
   }
   ```

   If identical entries exist, leave them byte-for-byte unchanged: Codex ties hook trust to a hash of the definition, so any change to a command needs trusting again. Tell the user to run `/hooks` in Codex and trust the new hooks. If they never fire, check that `config.toml` does not disable the `hooks` feature.

   Codex limits each hook to about 2,500 tokens by default, which it estimates as bytes divided by 4. That is 10,000 bytes: about 10,000 characters of English, but only about 3,300 characters of Chinese, Japanese or Korean. A handler's `additionalContextLimit` field raises it. Don't set it by default: the size warnings should keep the output under the default, and Codex advises against `0`.

   **opencode.** Link the plugin. opencode loads this directory on its own, so `opencode.jsonc` needs no edit. Ask the user to restart opencode afterward.

   ```sh
   mkdir -p ~/.config/opencode/plugins
   ln -s ~/.claude/skills/auto-learnings/scripts/opencode-plugin.js ~/.config/opencode/plugins/auto-learnings.js
   ```

   **Other agents.** Insert the global managed block (below) into the agent's config file. Place it with judgment, for example after an existing "Memory" or "Context" section. Do not append it blindly to the end: the file has its own structure.

4. **Plan every write, then confirm once.** Work out everything steps 5–7 will touch: hook entries, plugin links, managed blocks, `@` imports to remove, the reverse pointer, and legacy cleanup. Show a diff per file (the full file if it is new) and an explicit list of anything you will delete. One confirmation covers all of it.

   **Older `@` imports.** Before the hook existed, some instruction files imported the stores directly. Search the user's instruction files (`~/.claude/CLAUDE.md`, `~/.claude/rules/`, and in the current repo `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, `AGENTS.local.md`) for `@` imports of `.learnings/` files, such as `@.learnings/project.md` or `@~/.learnings/global.md`. With the hook installed, each import loads the same store a second time. List the ones you find and offer to remove them. Mention the tradeoff: an import also reaches most subagents (not Explore, Plan, or web-fetch), while the hook reaches only the main session. A project file importing a file outside the project, such as `@~/.learnings/global.md`, also needs a one-time approval per project. If the user wants subagents to see the learnings, keep the import and skip that agent's hook instead.

5. **Write.** Check that every edited JSON file still parses. For each agent that now has a hook or plugin, remove its old managed blocks (only the text between the markers) so learnings don't load twice. Keep a block in any file that an agent without a hook still reads. For example, opencode can read `~/.claude/CLAUDE.md` and a project `AGENTS.md`, so check who relies on a file before removing a block from it.

6. **Claude Code only: reverse pointer.** If Claude Code was selected, create `~/.claude/rules/auto-learnings.md` (loaded every session) with exactly:

   ```markdown
   Before writing a memory file, invoke the `auto-learnings` skill to route scope.
   ```

   It catches the other direction: Claude Code deciding to save a memory on its own. Skip if the file exists.

7. **Legacy cleanup.** An earlier version of this skill created `~/.claude/memory/`, which Claude Code never reads. If it exists, log each `*.md` in it except `MEMORY.md` to the global store with `log-learning.sh --scope global` (skip anything already there), then delete the files and the directory. Both actions must be in the step 4 preview. Skip silently if the directory doesn't exist.

8. **Optional: check that the hook fires (Claude Code).** Offer this, and run it only on a yes, because it starts a short session that uses the user's account:

   ```sh
   claude -p "Is a section titled 'Persistent Learnings (auto-memory)' in your context? Reply YES or NO."
   ```

   Run it in a folder where a store exists. Don't add `--bare`: it skips hooks. YES means the hook is wired and runs. It doesn't show whether the output fits under the limit, because the title survives truncation. For that, run `sh ~/.claude/skills/auto-learnings/scripts/check-size.sh`. For Codex, remind the user to trust the new hooks with `/hooks` instead.

## Project recall wiring (agents without a hook)

Read this from capture Step 6: the agent has no recall hook, and a project capture just created `./.learnings/project.md`. If the file existed before, skip: the repo was already offered wiring.

Project learnings load only if some config tells the agent to read `./.learnings/project.md`. Offer to wire it into a local, gitignored config file, which affects no one else:

> "Logged your first project learning here. Want me to add a recall note to this repo's local agent config (personal, gitignored, not committed) so these learnings load automatically each session? yes / no
> (Prefer to share them with teammates? I can add it to the committed `AGENTS.md` instead.)"

- **yes**: add the project managed block (below) to the local config file your agent actually reads. Check its docs: not every agent reads `AGENTS.local.md`. Create the file if missing. Show the diff, then write on confirm. If the user asked for the committed file, use `./AGENTS.md` and warn that it is version-controlled.
- **no**: skip silently. `project.md` now exists, so this won't fire again for this repo.

## Managed blocks

Global block:

```markdown
<!-- BEGIN learnings-skill (managed) -->
## Persistent Learnings (auto-memory)
At the start of each session, read these files if they exist and treat their
contents as persistent memory you must respect:
- `~/.learnings/global.md`: global learnings (preferences, cross-project corrections & insights)
- `./.learnings/project.md`: learnings specific to the current project

When you learn something worth remembering (a correction, a stated preference,
a durable project fact, or a hard-won debug insight), capture it with the
learnings skill.
<!-- END learnings-skill -->
```

Project block:

```markdown
<!-- BEGIN learnings-skill project recall (managed) -->
## Project Learnings (auto-memory)
At the start of each session, read `./.learnings/project.md` if it exists and
treat its contents as persistent memory you must respect for this project.
<!-- END learnings-skill project recall -->
```
