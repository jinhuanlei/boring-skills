#!/usr/bin/env sh
# log-learning.sh: mechanical append to a learnings store.
# All judgment (what to capture, scope, dedup, confirmation) is the agent's job.
# This script only: resolve file, create skeleton if missing, build entry, insert newest-last,
# then report the store's size against the hook output limit.

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

SCOPE="" SECTION="" AGENT="" TEXT="" WHY=""
WIDTH=100       # wrap column; continuation lines are indented 2 spaces
LONG_ENTRY=400  # characters of text + why before suggesting a separate file

while [ $# -gt 0 ]; do
  case "$1" in
    --scope)   SCOPE="$2";   shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    --agent)   AGENT="$2";   shift 2 ;;
    --text)    TEXT="$2";    shift 2 ;;
    --why)     WHY="$2";     shift 2 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

[ -z "$SCOPE" ]   && { printf 'Missing required argument: --scope\n' >&2;   exit 1; }
[ -z "$SECTION" ] && { printf 'Missing required argument: --section\n' >&2; exit 1; }
[ -z "$AGENT" ]   && { printf 'Missing required argument: --agent\n' >&2;   exit 1; }
[ -z "$TEXT" ]    && { printf 'Missing required argument: --text\n' >&2;    exit 1; }

# Resolve target file. The project store sits at the git root (or the nearest folder that has one),
# the same place recall.sh reads, so writing from a subfolder doesn't create a store nobody loads.
case "$SCOPE" in
  global)  TARGET="$HOME/.learnings/global.md"; SCOPE_LABEL="Global" ;;
  project)
    PROJ="$(project_dir "${CLAUDE_PROJECT_DIR:-$PWD}")"
    TARGET="$PROJ/.learnings/project.md"; SCOPE_LABEL="Project" ;;
  *) printf 'Unknown --scope: %s (expected: global|project)\n' "$SCOPE" >&2; exit 1 ;;
esac

case "$SECTION" in
  corrections) HEADER="## Corrections" ;;
  preferences) HEADER="## Preferences" ;;
  facts)       HEADER="## Project Facts" ;;
  insights)    HEADER="## Debug Insights" ;;
  *) printf 'Unknown --section: %s (expected: corrections|preferences|facts|insights)\n' "$SECTION" >&2; exit 1 ;;
esac

TARGET_DIR="$(dirname "$TARGET")"
if [ ! -d "$TARGET_DIR" ]; then
  mkdir -p "$TARGET_DIR" || { printf 'Cannot create directory: %s\n' "$TARGET_DIR" >&2; exit 1; }
fi

CREATED=""
if [ ! -f "$TARGET" ]; then
  printf '# Learnings: %s\n<!-- learnings-skill schema: v2 | - [YYYY-MM-DD] (agent) text, optional "  Why:" line. Edits OK. -->\n\n## Corrections\n\n## Preferences\n\n## Project Facts\n\n## Debug Insights\n' \
    "$SCOPE_LABEL" > "$TARGET" \
    || { printf 'Cannot write skeleton to: %s\n' "$TARGET" >&2; exit 1; }
  CREATED=1
fi

if ! grep -qxF "$HEADER" "$TARGET"; then
  printf 'Section header "%s" not found in %s: file may be malformed.\n' "$HEADER" "$TARGET" >&2
  exit 1
fi

# Collapse newlines, tabs, and runs of whitespace to single spaces.
flat() { printf '%s' "$1" | tr '\n\r\t' '   ' | tr -s ' ' | sed 's/^ //;s/ $//'; }
# Word-wrap at spaces only, so a multibyte character is never split. Width is measured in bytes
# by some awks, which only makes CJK lines wrap a little early.
wrap() { printf '%s\n' "$1" | awk -v w="$2" '{
  n = split($0, a, " "); line = ""
  for (i = 1; i <= n; i++) {
    if (line == "") line = a[i]
    else if (length(line) + 1 + length(a[i]) <= w) line = line " " a[i]
    else { print line; line = a[i] }
  }
  if (line != "") print line
}'; }

FLAT_TEXT="$(flat "$TEXT")"
FLAT_WHY="$(flat "$WHY")"
DATE="$(date +%F)"  # from the system clock, never the model

# First line holds WIDTH-2 so that every line, indented or not, fits in WIDTH.
ENTRY="$(wrap "- [$DATE] ($AGENT) $FLAT_TEXT" $((WIDTH - 2)) | sed '2,$s/^/  /')"
[ -n "$FLAT_WHY" ] && ENTRY="$ENTRY
$(wrap "Why: $FLAT_WHY" $((WIDTH - 2)) | sed 's/^/  /')"

# Insert newest-last in the section, with a blank line between entries. Blank lines inside the
# section are held back until more content shows they are not trailing. The entry is passed
# through the environment: awk -v would rewrite backslashes and reject newlines.
AL_ENTRY="$ENTRY" awk -v header="$HEADER" '
BEGIN { entry = ENVIRON["AL_ENTRY"]; in_s = 0; done = 0; blanks = 0; content = 0 }
$0 == header && !done { in_s = 1; content = 0; blanks = 0; print; next }
in_s && /^## / {
  if (content) print ""
  print entry; done = 1; in_s = 0
  print ""; print; next
}
in_s && /^[ \t]*$/ { blanks++; next }
in_s {
  for (i = 0; i < blanks; i++) print ""
  blanks = 0; content = 1; print; next
}
{ print }
END { if (in_s && !done) { if (content) print ""; print entry } }
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

[ -n "$CREATED" ] && printf 'Created %s\n' "$TARGET"
printf 'Logged to %s:\n%s\n' "$TARGET" "$(printf '%s\n' "$ENTRY" | sed 's/^/  /')"

# Advisory notes: the entry is already written, so these never change the exit code.
LEN_TMP="$(mktemp 2>/dev/null)" && {
  printf '%s %s' "$FLAT_TEXT" "$FLAT_WHY" > "$LEN_TMP"
  n="$(size_utf16 "$LEN_TMP")"; rm -f "$LEN_TMP"
  [ "$n" -gt "$LONG_ENTRY" ] && printf 'Note: this entry is %s characters. Above about %s, consider moving the detail to a separate file and keeping a one-line pointer here.\n' "$n" "$LONG_ENTRY"
}
if [ "$SCOPE" = project ]; then
  CLAUDE_PROJECT_DIR="$PROJ" /bin/sh "$HERE/check-size.sh" --scope project --warn-only
else
  /bin/sh "$HERE/check-size.sh" --scope global --warn-only
fi
exit 0
