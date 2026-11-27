# lib.sh: helpers shared by recall.sh, log-learning.sh and check-size.sh. Source it; do not run it.

# Hook output limit, the same number on both hosts. Claude Code counts UTF-16 units, Codex counts bytes.
AL_LIMIT=10000
AL_NEAR=8000

# project_dir <start>: the folder whose .learnings/project.md is the project store.
# Nearest folder from <start> up to the git root that already has one, else the git root, else <start>.
project_dir() {
  _start="$(cd "$1" 2>/dev/null && pwd -P)" || { printf '%s\n' "$1"; return 0; }
  _root="$(git -C "$_start" rev-parse --show-toplevel 2>/dev/null)" || _root=""
  if [ -z "$_root" ]; then printf '%s\n' "$_start"; return 0; fi
  _root="$(cd "$_root" && pwd -P)"
  _d="$_start"
  while :; do
    [ -f "$_d/.learnings/project.md" ] && { printf '%s\n' "$_d"; return 0; }
    [ "$_d" = "$_root" ] || [ "$_d" = "/" ] && break
    _d="$(dirname "$_d")"
  done
  printf '%s\n' "$_root"
}

# Sizes of a file, independent of the inherited locale.
size_bytes() { wc -c < "$1" | tr -d ' '; }
# UTF-16 units, as Claude Code counts. Falls back to bytes (never smaller) if iconv can't convert.
# Converts into a temp file: macOS iconv fails when writing large CJK output to /dev/null.
size_utf16() {
  _t="$(mktemp 2>/dev/null)" || { size_bytes "$1"; return 0; }
  if iconv -f UTF-8 -t UTF-16LE < "$1" > "$_t" 2>/dev/null; then
    echo $(( $(size_bytes "$_t") / 2 ))
  else
    size_bytes "$1"
  fi
  rm -f "$_t"
}
