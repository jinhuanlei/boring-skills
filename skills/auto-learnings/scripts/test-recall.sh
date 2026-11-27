#!/bin/sh
# Self-check for recall.sh and check-size.sh. Needs jq. Usage: sh test-recall.sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/recall.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home/.learnings" "$T/proj/.learnings" "$T/empty" "$T/nohome"

run() { HOME="$T/home" CLAUDE_PROJECT_DIR="$1" /bin/sh "$SCRIPT" ${2:-}; }
fail() { echo "FAIL: $1" >&2; exit 1; }
has() { case "$1" in *"$2"*) ;; *) fail "$3" ;; esac; }
hasnt() { case "$1" in *"$2"*) fail "$3" ;; esac; }

# No stores: silent in text mode, empty object in JSON mode.
[ -z "$(HOME="$T/nohome" CLAUDE_PROJECT_DIR="$T/empty" /bin/sh "$SCRIPT")" ] || fail "expected no output without stores"
[ "$(HOME="$T/nohome" CLAUDE_PROJECT_DIR="$T/empty" /bin/sh "$SCRIPT" SessionStart)" = "{}" ] || fail "expected {} without stores"

printf 'GLOBAL-MARK "quoted" back\\slash `tick`\ttab 中文内容 \\n literal\r\n' > "$T/home/.learnings/global.md"
printf 'PROJECT-MARK $HOME %%s {"a":1}' > "$T/proj/.learnings/project.md"

# No arguments: both stores, header first, global before project.
plain="$(run "$T/proj")"
case "$plain" in *"read these files"*"capture it"*GLOBAL-MARK*PROJECT-MARK*) ;; *) fail "plain output missing content or order" ;; esac

json="$(run "$T/proj" SessionStart)"
[ "$(printf '%s' "$json" | jq -r .hookSpecificOutput.hookEventName)" = "SessionStart" ] || fail "bad event name"
[ "$(printf '%s' "$json" | jq -r .hookSpecificOutput.additionalContext)" = "$plain" ] || fail "JSON text differs from plain text"

# Scopes: one store each; the shared header and capture reminder appear once across the pair.
g="$(run "$T/proj" "--scope global")"; p="$(run "$T/proj" "--scope project")"
has "$g" GLOBAL-MARK "global scope missing global"; hasnt "$g" PROJECT-MARK "global scope leaked project"
has "$p" PROJECT-MARK "project scope missing project"; hasnt "$p" GLOBAL-MARK "project scope leaked global"
has "$g" "capture it" "global output lacks the reminder"; hasnt "$p" "capture it" "reminder loaded twice"
has "$p" "read these files" "project output lacks the read-in-full line"
p_alone="$(HOME="$T/nohome" CLAUDE_PROJECT_DIR="$T/proj" /bin/sh "$SCRIPT" --scope project)"
has "$p_alone" "capture it" "project output must carry the header when there is no global store"
pj="$(run "$T/proj" "--scope project SessionStart")"
[ "$(printf '%s' "$pj" | jq -r .hookSpecificOutput.additionalContext)" = "$p" ] || fail "scoped JSON differs from scoped text"

# Falls back to the working directory when CLAUDE_PROJECT_DIR is unset.
cwd_out="$(cd "$T/proj" && env -u CLAUDE_PROJECT_DIR HOME="$T/home" /bin/sh "$SCRIPT")"
has "$cwd_out" PROJECT-MARK "PWD fallback"

# Project folder: a subfolder start finds the store at the git root, or the nearest one.
mkdir -p "$T/repo/a/b"; git -C "$T/repo" init -q
mkdir -p "$T/repo/.learnings"; printf 'ROOT-MARK' > "$T/repo/.learnings/project.md"
has "$(run "$T/repo/a/b" "--scope project")" ROOT-MARK "subfolder start missed the git-root store"
mkdir -p "$T/repo/a/.learnings"; printf 'NEAR-MARK' > "$T/repo/a/.learnings/project.md"
has "$(run "$T/repo/a/b" "--scope project")" NEAR-MARK "nearest store should win"

# Size warning. Each fixture makes the project-scope output exactly the given size, with no global store.
# fill <unit-char> <count>: print the character count times.
fill() { python3 -I -c 'import sys; sys.stdout.write(sys.argv[1] * int(sys.argv[2]))' "$1" "$2"; }
S="$T/size"; mkdir -p "$S/.learnings"
: > "$S/.learnings/project.md"
OVER="$(HOME="$T/nohome" CLAUDE_PROJECT_DIR="$S" AUTO_LEARNINGS_NO_SIZE_WARNING=1 /bin/sh "$SCRIPT" --scope project | wc -c | tr -d ' ')"

sized() {  # sized <char> <total output characters>
  fill "$1" $(($2 - OVER)) > "$S/.learnings/project.md"
}
check() {  # check <label> <plain: warn|ok> <codex: warn|ok> [locale]
  for mode in plain codex; do
    want="$2"; [ "$mode" = codex ] && want="$3"
    if [ "$mode" = plain ]; then out="$(HOME="$T/nohome" CLAUDE_PROJECT_DIR="$S" LC_ALL="${4:-C}" /bin/sh "$SCRIPT" --scope project)"
    else out="$(HOME="$T/nohome" CLAUDE_PROJECT_DIR="$S" LC_ALL="${4:-C}" /bin/sh "$SCRIPT" --scope project SessionStart | jq -r .hookSpecificOutput.additionalContext)"; fi
    first="$(printf '%s\n' "$out" | head -n 1)"
    case "$want:$first" in
      warn:Warning:*|ok:"## "*) ;;
      *) fail "$1 ($mode, LC_ALL=${4:-C}): expected $want, first line: $(printf '%.80s' "$first")" ;;
    esac
  done
}
sized x 10000;  check "English 10,000" ok ok
sized x 10001;  check "English 10,001" warn warn
sized 中 9900;  check "Chinese 9,900" ok warn; check "Chinese 9,900" ok warn en_US.UTF-8
sized 😀 6000;  check "Emoji 6,000" warn warn
[ "$(printf '%s\n' "$(HOME="$T/nohome" CLAUDE_PROJECT_DIR="$S" /bin/sh "$SCRIPT" --scope project)" | sed -n 4p)" = "If this block is truncated, read these files in full before continuing:" ] \
  || fail "read-in-full line must follow the warning closely"
out="$(HOME="$T/nohome" CLAUDE_PROJECT_DIR="$S" AUTO_LEARNINGS_NO_SIZE_WARNING=1 /bin/sh "$SCRIPT" --scope project)"
hasnt "$out" "Warning:" "AUTO_LEARNINGS_NO_SIZE_WARNING ignored"

# check-size.sh: names the host that is over, and stays quiet with --warn-only when small.
sized 中 9900
cs="$(cd "$S" && HOME="$T/nohome" /bin/sh "$HERE/check-size.sh" --scope project)"
has "$cs" "Warning: project" "check-size missed Codex overflow"; has "$cs" "Codex shows" "check-size should name Codex"
hasnt "$cs" "Claude Code and" "check-size wrongly named Claude Code"
sized x 8500
has "$(cd "$S" && HOME="$T/nohome" /bin/sh "$HERE/check-size.sh" --scope project)" "Note: project" "check-size missed near-limit note"
sized x 100
[ -z "$(cd "$S" && HOME="$T/nohome" /bin/sh "$HERE/check-size.sh" --scope project --warn-only)" ] || fail "--warn-only should be silent when small"

# Single old hook: both stores share one limit, so check-size also reports the combined output.
mkdir -p "$T/old/.claude" "$T/old/.learnings"
printf '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"/bin/sh ~/.claude/skills/auto-learnings/scripts/recall.sh"}]}]}}' > "$T/old/.claude/settings.json"
fill x 6000 > "$T/old/.learnings/global.md"
sized x 6000
cs="$(cd "$S" && HOME="$T/old" /bin/sh "$HERE/check-size.sh" --scope project --warn-only)"
has "$cs" "Warning: combined" "single-hook combined overflow not reported"
printf '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"/bin/sh ~/.claude/skills/auto-learnings/scripts/recall.sh --scope global"}]}]}}' > "$T/old/.claude/settings.json"
hasnt "$(cd "$S" && HOME="$T/old" /bin/sh "$HERE/check-size.sh" --warn-only)" "combined" "combined reported for split hooks"

echo "ok"
