#!/usr/bin/env sh
# log-learning.sh — mechanical append to learnings store.
# All judgment (what to capture, scope, dedup, confirmation) is the AI's job.
# This script only handles: resolve file → create skeleton if missing → build entry → insert newest-last.

SCOPE="" SECTION="" AGENT="" TEXT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --scope)   SCOPE="$2";   shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    --agent)   AGENT="$2";   shift 2 ;;
    --text)    TEXT="$2";    shift 2 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

[ -z "$SCOPE" ]   && { printf 'Missing required argument: --scope\n' >&2;   exit 1; }
[ -z "$SECTION" ] && { printf 'Missing required argument: --section\n' >&2; exit 1; }
[ -z "$AGENT" ]   && { printf 'Missing required argument: --agent\n' >&2;   exit 1; }
[ -z "$TEXT" ]    && { printf 'Missing required argument: --text\n' >&2;    exit 1; }

# Resolve target file and scope label for skeleton
case "$SCOPE" in
  global)  TARGET="$HOME/.learnings/global.md"; SCOPE_LABEL="Global" ;;
  project)
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
      printf 'Not a git repository — project learnings require a git-initialized project.\nThis looks like a casual session; use --scope global for cross-project knowledge, or skip logging entirely.\n' >&2
      exit 1
    fi
    TARGET="./.learnings/project.md"; SCOPE_LABEL="Project" ;;
  *) printf 'Unknown --scope: %s (expected: global|project)\n' "$SCOPE" >&2; exit 1 ;;
esac

# Map --section flag to markdown header
case "$SECTION" in
  corrections) HEADER="## Corrections" ;;
  preferences) HEADER="## Preferences" ;;
  facts)       HEADER="## Project Facts" ;;
  insights)    HEADER="## Debug Insights" ;;
  *) printf 'Unknown --section: %s (expected: corrections|preferences|facts|insights)\n' "$SECTION" >&2; exit 1 ;;
esac

# Create directory and file (with four-section skeleton) if missing
TARGET_DIR="$(dirname "$TARGET")"
if [ ! -d "$TARGET_DIR" ]; then
  mkdir -p "$TARGET_DIR" || { printf 'Cannot create directory: %s\n' "$TARGET_DIR" >&2; exit 1; }
fi

if [ ! -f "$TARGET" ]; then
  printf '# Learnings — %s\n<!-- learnings-skill schema: v1 | Entries: - [YYYY-MM-DD] (agent) text. Manual edits OK. -->\n\n## Corrections\n\n## Preferences\n\n## Project Facts\n\n## Debug Insights\n' \
    "$SCOPE_LABEL" > "$TARGET" \
    || { printf 'Cannot write skeleton to: %s\n' "$TARGET" >&2; exit 1; }
fi

# Verify the section header is present (guard against a manually broken file)
if ! grep -qF "$HEADER" "$TARGET"; then
  printf 'Section header "%s" not found in %s — file may be malformed.\n' "$HEADER" "$TARGET" >&2
  exit 1
fi

# Flatten --text: collapse newlines, tabs, and runs of whitespace to single spaces
FLAT_TEXT="$(printf '%s' "$TEXT" | tr '\n\r\t' '   ' | tr -s ' ' | sed 's/^ //;s/ $//')"

# Build the dated entry (date from system clock, never the model)
DATE="$(date +%F)"
ENTRY="- [$DATE] ($AGENT) $FLAT_TEXT"

# Insert entry newest-last in its section.
# Strategy: stream through the file; when inside the target section, buffer blank lines
# so they don't appear before the new entry. When the next ## header is reached (or EOF),
# flush the entry, then add a single blank line separator before the next section.
awk -v header="$HEADER" -v entry="$ENTRY" '
BEGIN { in_section=0; inserted=0; blanks=0 }
{
  # Entering our target section
  if ($0 == header) {
    in_section=1; print; blanks=0; next
  }
  # Entering the next section while inside ours
  if (in_section && /^## /) {
    if (!inserted) { print entry; inserted=1 }
    blanks=0; in_section=0
    print ""; print; next
  }
  # Buffer blank lines within the section (they are trailing until proven otherwise)
  if (in_section && /^$/) { blanks++; next }
  # Non-blank content in the section: flush any held blanks, then print the line
  if (in_section && blanks > 0) {
    for (i=0; i<blanks; i++) print ""
    blanks=0
  }
  print
}
END {
  # Last section in the file: append entry at EOF
  if (in_section && !inserted) { print entry }
}
' "$TARGET" > "${TARGET}.tmp"

AWK_STATUS=$?
if [ "$AWK_STATUS" -ne 0 ]; then
  rm -f "${TARGET}.tmp"
  printf 'awk failed (exit %d) writing to %s\n' "$AWK_STATUS" "$TARGET" >&2
  exit 1
fi

mv "${TARGET}.tmp" "$TARGET" || {
  rm -f "${TARGET}.tmp"
  printf 'Cannot replace %s with updated file\n' "$TARGET" >&2
  exit 1
}

printf 'Logged to %s:\n  %s\n' "$TARGET" "$ENTRY"
