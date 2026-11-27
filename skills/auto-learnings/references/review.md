# Review mode

Read this when the user asks to review their learnings. Review is maintenance: it edits existing entries and never adds new ones. A new learning that comes up during review goes through capture Step 4 in `SKILL.md`.

## Steps

1. **Measure.** From the project folder, run:

   ```sh
   sh ~/.claude/skills/auto-learnings/scripts/check-size.sh
   ```

   It prints each store's recall output size, header included: characters for Claude Code, bytes for Codex. Both hosts allow 10,000 per hook, then show only a short preview. Chinese, Japanese and Korean text uses about 3 bytes per character, so Codex reaches its limit at roughly 3,300 of those characters. Lead the report with any `Warning:` or `Note:` line.

2. **Fact-check.** Each entry was true when written; code moves on. For every entry that names a file, path, function, flag, command, config key, or ticket, check that it still exists and still behaves as the entry says. Use search, file reads, and `--help`, not memory. Give each entry one verdict:

   | Verdict | Meaning |
   |---------|---------|
   | correct | Checked, still true |
   | stale detail | The rule holds, but a detail is out of date (a moved path, a renamed flag) |
   | wrong | The rule no longer holds |
   | unchecked | Can't be checked from here (another repo, an external system) |

   Give the evidence for each verdict that is not `correct`: a `file:line`, a command and its output, or what you searched for and didn't find.

3. **Find duplicates and conflicts.** Compare entries within each store, across the two stores, and against the always-loaded instruction files in your context (`CLAUDE.md`, `AGENTS.md`, their local variants, user-level rules). A rule that already lives in an instruction file loads twice every session.

4. **Suggest moves.** For each store near or over the limit, or with entries in the wrong place, suggest:
   - **Project to global:** an entry that is true outside this repo.
   - **To an on-demand file:** a cluster of rules about one topic, or an entry over about 400 characters. Move the detail to a file the agent reads only when the topic comes up, for example one listed in a lazy-load table in `CLAUDE.md`. Keep a one-line pointer in the store.
   - **Delete:** a `wrong` entry with nothing worth keeping, or a duplicate.

   Global learnings load in every repo, so a large global store hurts everywhere. Each store gets its own hook, so a large global store doesn't use up project's space.

5. **Report, then confirm.** Show one table: entry (first few words), store, verdict, evidence, proposed action. Then ask how to apply the changes: all at once, or one at a time. Apply only what the user approves, with your file tools. An entry is its `- [` line plus the indented lines under it; keep the "Storage format" from `SKILL.md`.

6. **Record the check.** In each store you reviewed, add or update this line right after the schema comment, with today's date from the system clock:

   ```markdown
   <!-- last reviewed: YYYY-MM-DD -->
   ```

   If you are Claude Code, also apply deletions and moves to any matching native memory file, as in Delete.

## Format conversion

Files in the older v1 format (one line per entry) stay valid. Offer to convert them to v2 (wrapped lines, a `Why:` line, blank lines between entries) only if the user asks, or if they complain about readability. Don't invent a reason for an entry that has none: leave out the `Why:` line.
