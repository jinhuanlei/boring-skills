#!/bin/sh
# check-size.sh: report how close each learnings store's recall output is to the hook output limit.
# Usage: check-size.sh [--scope global|project] [--warn-only]
# Measures the real recall.sh output (header included) for the current project, both ways:
# UTF-16 units for Claude Code, bytes for Codex. Both hosts allow 10,000.

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

SCOPES="global project" WARN_ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --scope) SCOPES="$2"; shift 2 ;;
    --warn-only) WARN_ONLY=1; shift ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

TMP="$(mktemp)" || exit 1
trap 'rm -f "$TMP"' EXIT

# report <label>: classify the recall output in $TMP.
report() {
  [ -s "$TMP" ] || { [ -n "$WARN_ONLY" ] || printf '%s learnings: none\n' "$1"; return 0; }
  c="$(size_utf16 "$TMP")" b="$(size_bytes "$TMP")"
  over=""
  [ "$c" -gt "$AL_LIMIT" ] && over="Claude Code"
  verb="shows"
  [ "$b" -gt "$AL_LIMIT" ] && { [ -n "$over" ] && verb="show"; over="${over:+$over and }Codex"; }
  sizes="$c characters for Claude Code, $b bytes for Codex"
  if [ -n "$over" ]; then
    printf 'Warning: %s learnings are %s. Over %s, %s %s only a short preview. Run "review my learnings" to move or prune entries.\n' "$1" "$sizes" "$AL_LIMIT" "$over" "$verb"
  elif [ "$c" -ge "$AL_NEAR" ] || [ "$b" -ge "$AL_NEAR" ]; then
    printf 'Note: %s learnings are %s, near the %s limit. Run "review my learnings" to move or prune entries.\n' "$1" "$sizes" "$AL_LIMIT"
  elif [ -z "$WARN_ONLY" ]; then
    printf '%s learnings: %s (limit %s each).\n' "$1" "$sizes" "$AL_LIMIT"
  fi
}

for s in $SCOPES; do
  AUTO_LEARNINGS_NO_SIZE_WARNING=1 /bin/sh "$HERE/recall.sh" --scope "$s" > "$TMP"
  report "$s"
done

# An older setup runs one hook for both stores, so they share one limit. Measure that output too.
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ] && grep -q 'auto-learnings/scripts/recall.sh' "$SETTINGS" && ! grep -q 'recall.sh --scope' "$SETTINGS"; then
  AUTO_LEARNINGS_NO_SIZE_WARNING=1 /bin/sh "$HERE/recall.sh" > "$TMP"
  report "combined (single Claude Code hook; run \"set up learnings\" to split it)"
fi
exit 0
