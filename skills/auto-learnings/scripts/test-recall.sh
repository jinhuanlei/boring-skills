#!/bin/sh
# Self-check for recall.sh. Needs jq. Usage: sh test-recall.sh
set -eu
SCRIPT="$(cd "$(dirname "$0")" && pwd)/recall.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home/.learnings" "$T/proj/.learnings" "$T/empty"

run() { HOME="$T/home" CLAUDE_PROJECT_DIR="$1" /bin/sh "$SCRIPT" ${2:-}; }
fail() { echo "FAIL: $1" >&2; exit 1; }

# No stores: silent in text mode, empty object in JSON mode.
[ -z "$(run "$T/empty")" ] || fail "expected no output without stores"
[ "$(run "$T/empty" SessionStart)" = "{}" ] || fail "expected {} without stores"

printf 'GLOBAL-MARK "quoted" back\\slash `tick`\ttab 中文内容 \\n literal\r\n' > "$T/home/.learnings/global.md"
printf 'PROJECT-MARK $HOME %%s {"a":1}' > "$T/proj/.learnings/project.md"

plain="$(run "$T/proj")"
case "$plain" in *"read these files"*"capture it"*GLOBAL-MARK*PROJECT-MARK*) ;; *) fail "plain output missing content or order" ;; esac

json="$(run "$T/proj" SessionStart)"
[ "$(printf '%s' "$json" | jq -r .hookSpecificOutput.hookEventName)" = "SessionStart" ] || fail "bad event name"
[ "$(printf '%s' "$json" | jq -r .hookSpecificOutput.additionalContext)" = "$plain" ] || fail "JSON text differs from plain text"

# Falls back to the working directory when CLAUDE_PROJECT_DIR is unset.
cwd_out="$(cd "$T/proj" && env -u CLAUDE_PROJECT_DIR HOME="$T/home" /bin/sh "$SCRIPT")"
case "$cwd_out" in *PROJECT-MARK*) ;; *) fail "PWD fallback" ;; esac

echo "ok"
