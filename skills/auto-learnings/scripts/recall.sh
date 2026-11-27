#!/bin/sh
# recall.sh: print the learnings stores so an agent hook can inject them.
# Usage: recall.sh [--scope global|project] [SessionStart]
#   no event       plain text (Claude Code SessionStart, OpenCode plugin)
#   SessionStart   hook JSON (Codex)
#   --scope        print one store only, so each gets its own hook output limit. Default: both.
# Set AUTO_LEARNINGS_NO_SIZE_WARNING=1 to skip the size warning (OpenCode has no hook limit).
# Always exits 0: a failure here must never block a session from starting.

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

EVENT="" SCOPE="both"
while [ $# -gt 0 ]; do
  case "$1" in
    --scope) SCOPE="$2"; shift 2 ;;
    *) EVENT="$1"; shift ;;
  esac
done

GLOBAL="$HOME/.learnings/global.md"
PROJECT="$(project_dir "${CLAUDE_PROJECT_DIR:-$PWD}")/.learnings/project.md"
readable() { [ -f "$1" ] && [ -r "$1" ]; }

emit() {
  set --
  case "$SCOPE" in
    global)  readable "$GLOBAL" && set -- "$GLOBAL" ;;
    project) readable "$PROJECT" && set -- "$PROJECT" ;;
    *)       readable "$GLOBAL" && set -- "$GLOBAL"; readable "$PROJECT" && set -- "$@" "$PROJECT" ;;
  esac
  [ "$#" -gt 0 ] || return 0
  # The shared header goes in one output only: global's, or project's when there is no global store.
  lead=1
  [ "$SCOPE" = project ] && readable "$GLOBAL" && lead=0
  if [ "$lead" = 1 ]; then
    printf '## Persistent Learnings (auto-memory)\nTreat these entries as persistent memory you must respect.\n'
  else
    printf '## Project Learnings (auto-memory)\nTreat these entries as persistent memory you must respect for this project.\n'
  fi
  # Hosts cut large hook output to a short preview, so the file list comes first.
  printf 'If this block is truncated, read these files in full before continuing:\n'
  printf -- '- %s\n' "$@"
  [ "$lead" = 1 ] && printf 'When you learn something worth remembering (a correction, a stated preference, a durable project fact, or a hard-won debug insight), capture it with the auto-learnings skill.\n'
  for f in "$@"; do
    printf '\n### From %s\n\n' "$f"
    cat "$f"
    printf '\n'
  done
}

# Build the output in a temp file so its exact size can be measured before printing.
TMP="$(mktemp 2>/dev/null)" || {
  # No temp file: print the learnings without the size check rather than drop them.
  if [ -z "$EVENT" ]; then emit; else printf '{}\n'; fi
  exit 0
}
trap 'rm -f "$TMP"' EXIT
emit > "$TMP"

WARN=""
if [ -s "$TMP" ] && [ -z "${AUTO_LEARNINGS_NO_SIZE_WARNING:-}" ]; then
  if [ -z "$EVENT" ]; then n="$(size_utf16 "$TMP")"; unit="characters"; host="Claude Code"
  else n="$(size_bytes "$TMP")"; unit="bytes"; host="Codex"; fi
  if [ "$n" -gt "$AL_LIMIT" ]; then
    WARN="Warning: these learnings are $n $unit, over the $AL_LIMIT limit, so $host shows only a short preview. Read the files below in full now, and tell the user to run \"review my learnings\" to move or prune entries."
  fi
fi
out() { [ -n "$WARN" ] && printf '%s\n' "$WARN"; cat "$TMP"; }

if [ -z "$EVENT" ]; then
  out
  exit 0
fi

if [ ! -s "$TMP" ]; then
  printf '{}\n'
  exit 0
fi

# JSON-escape in byte mode: drop other control characters, then escape \ " TAB CR and join lines.
TAB="$(printf '\t')"
CR="$(printf '\r')"
BODY="$(out | LC_ALL=C tr -d '\000-\010\013\014\016-\037' \
  | LC_ALL=C sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$TAB/\\\\t/g" -e "s/$CR/\\\\r/g" \
  | LC_ALL=C awk '{ printf "%s\\n", $0 }')"
printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$EVENT" "$BODY"
exit 0
