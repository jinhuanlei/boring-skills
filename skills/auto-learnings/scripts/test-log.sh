#!/bin/sh
# Self-check for log-learning.sh. Usage: sh test-log.sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
LOG="$HERE/log-learning.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home" "$T/repo/sub" "$T/plain"
git -C "$T/repo" init -q
fail() { echo "FAIL: $1" >&2; exit 1; }
log() { (cd "$1" && shift && env -u CLAUDE_PROJECT_DIR HOME="$T/home" sh "$LOG" --agent t "$@"); }
P="$T/repo/.learnings/project.md"

# Skeleton: v2 schema comment, no em-dash in the title, created at the git root from a subfolder.
out="$(log "$T/repo/sub" --scope project --section facts --text 'first fact')"
case "$out" in *"Created $(cd "$T/repo" && pwd -P)/.learnings/project.md"*) ;; *) fail "expected Created line, got: $out" ;; esac
[ -f "$P" ] || fail "project store not at git root"
[ ! -e "$T/repo/sub/.learnings" ] || fail "store created in subfolder"
[ "$(head -n 1 "$P")" = "# Learnings: Project" ] || fail "title"
grep -q 'schema: v2' "$P" || fail "schema v2 comment"
! grep -q '—' "$P" || fail "em-dash in skeleton"
out="$(log "$T/repo/sub" --scope project --section facts --text 'second fact')"
case "$out" in *Created*) fail "Created printed for an existing store" ;; esac

# Why line, wrapping at 100 columns with 2-space continuation, blank line between entries.
long="Do not wrap the X precondition with the feature-flag precondition when the flag guards only one of the checks."
log "$T/repo" --scope project --section facts --text "$long" --why 'the wrapper skips the whole delegate when the flag is off, so every check in X would turn off, not only the gated one.' > /dev/null
awk 'length($0) > 100 { bad = 1 } END { exit bad }' "$P" || fail "line over 100 columns"
grep -q '^  Why: the wrapper' "$P" || fail "Why line not on its own indented line"
grep -q '^  [a-z]' "$P" || fail "no indented continuation line"
sec="$(sed -n '/^## Project Facts$/,/^## /p' "$P")"
[ "$(printf '%s\n' "$sec" | grep -c '^- \[')" = 3 ] || fail "expected 3 entries in section"
[ "$(printf '%s\n' "$sec" | grep -c '^$')" = 3 ] || fail "expected blank lines between entries and before next section"
grep -qx '## Debug Insights' "$P" || fail "next section lost"
tail -n 1 "$P" | grep -qx '## Debug Insights' || fail "entry inserted after the wrong section"

# Text is kept as written: backslashes, literal \n, quotes, CJK; real newlines are flattened.
TXT='back\slash \n literal "q" 中文内容
next line'
log "$T/repo" --scope project --section insights --text "$TXT" > /dev/null
grep -qF 'back\slash \n literal "q" 中文内容 next line' "$P" || fail "text altered: $(tail -n 1 "$P")"
iconv -f UTF-8 -t UTF-8 < "$P" > "$T/utf8.out" || fail "file is not valid UTF-8"
# Long CJK words wrap only at spaces, so no character is split.
log "$T/repo" --scope project --section insights --text "$(python3 -I -c 'print(" ".join(["中文内容测试"] * 30))')" > /dev/null
iconv -f UTF-8 -t UTF-8 < "$P" > "$T/utf8.out" || fail "CJK wrap broke UTF-8"

# Not a git repo: the store goes in the working directory.
log "$T/plain" --scope project --section facts --text 'plain' > /dev/null
[ -f "$T/plain/.learnings/project.md" ] || fail "non-git store location"

# Global scope.
log "$T/plain" --scope global --section preferences --text 'pref' > /dev/null
grep -q '(t) pref' "$T/home/.learnings/global.md" || fail "global write"
[ "$(head -n 1 "$T/home/.learnings/global.md")" = "# Learnings: Global" ] || fail "global title"

# Notes: long entry, near and over the limit. The entry is still written and the exit code is 0.
out="$(log "$T/plain" --scope global --section facts --text "$(python3 -I -c 'print("word " * 100)')")"
case "$out" in *"Note: this entry is"*) ;; *) fail "missing long-entry note" ;; esac
python3 -I -c 'print("- [2026-01-01] (t) " + "y" * 8200)' >> "$T/plain/.learnings/project.md"
out="$(log "$T/plain" --scope project --section facts --text 'near')"
case "$out" in *"Note: project learnings"*) ;; *) fail "missing near-limit note: $out" ;; esac
python3 -I -c 'print("- [2026-01-01] (t) " + "y" * 2000)' >> "$T/plain/.learnings/project.md"
out="$(log "$T/plain" --scope project --section facts --text 'over')"
case "$out" in *"Warning: project learnings"*"Claude Code and Codex"*) ;; *) fail "missing over-limit warning: $out" ;; esac

# Errors.
if log "$T/plain" --scope project --section bogus --text x 2>/dev/null; then fail "bad section accepted"; fi
if log "$T/plain" --scope project --section facts 2>/dev/null; then fail "missing text accepted"; fi

echo "ok"
