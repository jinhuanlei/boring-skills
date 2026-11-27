#!/bin/sh
# recall.sh — print the learnings stores so an agent hook can inject them.
# Usage: recall.sh                 plain text (Claude Code SessionStart, OpenCode plugin)
#        recall.sh SessionStart    hook JSON (Codex)
# Always exits 0: a failure here must never block a session from starting.

EVENT="$1"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

emit() {
  set --
  for f in "$HOME/.learnings/global.md" "$PROJECT_DIR/.learnings/project.md"; do
    [ -f "$f" ] && [ -r "$f" ] && set -- "$@" "$f"
  done
  [ "$#" -gt 0 ] || return 0
  printf '## Persistent Learnings (auto-memory)\nTreat these entries as persistent memory you must respect.\n'
  # Hosts truncate large hook output to a short preview, so the file list comes first.
  printf 'If this block is truncated, read these files in full before continuing:\n'
  printf -- '- %s\n' "$@"
  printf 'When you learn something worth remembering — a correction, a stated preference, a durable project fact, or a hard-won debug insight — capture it with the auto-learnings skill.\n'
  for f in "$@"; do
    printf '\n### From %s\n\n' "$f"
    cat "$f"
    printf '\n'
  done
}

if [ -z "$EVENT" ]; then
  emit
  exit 0
fi

# JSON-escape in byte mode: drop other control characters, then escape \ " TAB CR and join lines.
TAB="$(printf '\t')"
CR="$(printf '\r')"
BODY="$(emit | LC_ALL=C tr -d '\000-\010\013\014\016-\037' \
  | LC_ALL=C sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$TAB/\\\\t/g" -e "s/$CR/\\\\r/g" \
  | LC_ALL=C awk '{ printf "%s\\n", $0 }')"

if [ -z "$BODY" ]; then
  printf '{}\n'
else
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$EVENT" "$BODY"
fi
exit 0
