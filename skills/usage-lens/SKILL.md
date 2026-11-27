---
name: usage-lens
description: >
  Track and analyze Claude Code skill invocations to surface usage patterns and
  recommendations. Invoke when the user types /usage-lens (with optional subcommands:
  setup to install the tracking hooks, cleanup to trim old usage logs; cleanup does not
  remove skills). Shows which skills are being used, trending, or going stale.
---

## Modes

| Command | What it does |
|---------|--------------|
| `/usage-lens` | Shows the usage report. Changes nothing. |
| `/usage-lens setup` | Adds the tracking hooks to `~/.claude/settings.json` and creates a default config. |
| `/usage-lens cleanup` | Deletes old usage log records and old temp files. Does not remove or disable any skill. |

If the user wants to uninstall unused skills, that is the `skill-healthcheck` skill, not
`cleanup`.

### /usage-lens (default — show report)

1. Check that hooks are configured: read `~/.claude/settings.json` and look for a
   `PostToolUse` entry whose command contains `usage-lens`. If missing, tell the user
   to run `/usage-lens setup` first and stop.

2. Run analysis:
   ```
   python3 ~/.claude/skills/usage-lens/scripts/analyze.py --json
   ```
   Parse the JSON output.

3. Format and present the report (plain ASCII, no ANSI color):

```
Usage Lens — last {period_days}d  ({total_events} events)

Skills
  {name:<20} {bar:<10} {count:<5}  last: {relative_time}  {trend_indicator}
  ...

Recommendations
  • {name} — {detail}
  ...
```

**Formatting rules:**
- Bar: one `█` per invocation, max 10, scaled to the highest count
- Relative time: "Xh ago", "Xd ago", "never" (if last_ts is null)
- Trend indicator: `↑ trending` (up), `↓ declining` (down), nothing (flat)
- Sort: by count descending, then name alphabetically
- Skills with count 0 shown last with no bar
- If recommendations is empty, omit the Recommendations section

### /usage-lens setup

Run `python3 ~/.claude/skills/usage-lens/scripts/setup.py` and relay the output to the user.

After setup, remind the user that hooks take effect immediately (no restart needed —
the harness reads settings.json per prompt).

### /usage-lens cleanup

Removes log records and `/tmp/claude-usage-lens-*.txt` files older than
`cleanup_keep_days` (default 90). It runs without a confirmation prompt.

Run `python3 ~/.claude/skills/usage-lens/scripts/cleanup.py` and relay the output.

## Error handling

If `analyze.py` exits non-zero or produces no output, tell the user:
> "No usage data yet — invoke a few skills and try again."

If `~/.claude/usage-lens-errors.log` exists and is non-empty, mention it:
> "Hook errors logged to ~/.claude/usage-lens-errors.log — check if something is misconfigured."
