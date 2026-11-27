# Migrate mode

Read this when the user asks to migrate learnings or import notes, a `CLAUDE.md`, or another file into learnings.

## Flow

1. **Find the source.** Use the path the user gives, or check common ones: `~/.claude/CLAUDE.md`, old-format `~/.learnings/*.md`, project notes.

2. **Extract items.** Pull individual knowledge items from the source. Skip anything between `<!-- BEGIN learnings-skill ... -->` and `<!-- END learnings-skill ... -->`, and skip the `~/.claude/rules/auto-learnings.md` reverse pointer. They are this skill's own wiring; importing them turns a recall instruction into a fake learning.

3. **Classify.** Give each item a section and a scope, using the routing rules in `SKILL.md`. Put items that don't fit cleanly into an **Unclassified** bucket.

4. **Dedup.** Skip items already in the learnings files.

5. **Preview and confirm.** Show every proposed entry grouped by destination. List unclassified items separately, and have the user assign each one before confirming:

   ```
   Ready to import:
     Global › Preferences (2): ...
     Project › Project Facts (3): ...

   Unclassified (2) — assign a section before I write:
     1. "Run db migrations before starting the dev server" → ?
     2. "Check #backend-alerts Slack for deploy failures" → ?
   ```

6. **Write.** Once everything is classified and confirmed, run `log-learning.sh` once per entry with `--agent migrated`. Entries come out as `- [YYYY-MM-DD] (migrated) <text>`.

## Schema upgrade

When the source is a learnings file in an older format:

1. Back up: `cp <file> <file>.bak`
2. Rewrite it to the format in "Storage format" in `SKILL.md`.
3. Show the diff.
4. Write on confirm.
