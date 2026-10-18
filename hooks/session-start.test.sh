#!/usr/bin/env bash
# Test harness for hooks/lib/paths.sh and three SessionStart hooks: session-context.sh (paths,
# AGENTS.local.md, lessons.md), recent-workblocks.sh and stale-projects.sh. Runs only in
# temporary folders: HOME, the kit root and both brains point at made-up folders, so it never
# reads the real brains or the real pergamino.local.env. HOOK_SHELL=/bin/bash runs the hooks
# under macOS's bash 3.2.
#
# Usage: bash hooks/session-start.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PATHS="$HERE/lib/paths.sh"
CTX="${CTX:-$HERE/session-context.sh}"
RECENT="${RECENT:-$HERE/recent-workblocks.sh}"
STALE="${STALE:-$HERE/stale-projects.sh}"
SH="${HOOK_SHELL:-bash}"
fails=0
check() { if [[ "$2" == 0 ]]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

tmp="$(mktemp -d)" && [ -d "$tmp" ] || { echo "mktemp failed" >&2; exit 1; }; trap 'rm -rf "$tmp"' EXIT
K="$tmp/kit"; L="$tmp/llm"; M="$tmp/main"; H="$tmp/home"
mkdir -p "$K" "$L/wiki/workblocks" "$M" "$H"
# runs <script> with only the variables given after it, HOME set to the made-up home
hook() { local s="$1"; shift; printf '{}' | env -i HOME="$H" PATH=/usr/bin:/bin "$@" "$SH" "$s" 2>/dev/null; }
ctx_of() { jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }

# ---------- lib/paths.sh ----------
out=$(env -i HOME="$H" PATH=/usr/bin:/bin PERGAMINO_HOME="$K" PERGAMINO_LLM_BRAIN="$L/" PERGAMINO_MAIN_BRAIN="$M" "$SH" "$PATHS")
[[ "$out" == *"PERGAMINO_LLM_BRAIN=$L"$'\n'* || "$out" == *"PERGAMINO_LLM_BRAIN=$L" ]] && [[ "$out" != *"$L/"* ]]
check "paths: the environment wins, and a trailing slash goes" $?
cat > "$K/pergamino.local.env" <<'EOF'
# a comment
export PERGAMINO_MAIN_BRAIN="~/Main Brain"
PERGAMINO_LLM_BRAIN='$HOME/LLM'
PERGAMINO_HOME=/somewhere/else
OTHER=$(touch /tmp/should-not-run)
EOF
out=$(env -i HOME="$H" PATH=/usr/bin:/bin PERGAMINO_HOME="$K" "$SH" -c '. "$1"; printf "%s|%s|%s" "$PERGAMINO_HOME" "$PERGAMINO_MAIN_BRAIN" "$PERGAMINO_LLM_BRAIN"' _ "$PATHS")
[[ "$out" == "$K|$H/Main Brain|$H/LLM" ]]; check "paths: the file fills both brains, quotes off, ~ and \$HOME expanded, its PERGAMINO_HOME ignored (got $out)" $?
out=$(env -i HOME="$H" PATH=/usr/bin:/bin PERGAMINO_HOME="$K" PERGAMINO_LLM_BRAIN=/env/llm "$SH" -c '. "$1"; printf "%s|%s" "$PERGAMINO_MAIN_BRAIN" "$PERGAMINO_LLM_BRAIN"' _ "$PATHS")
[[ "$out" == "$H/Main Brain|/env/llm" ]]; check "paths: per key, the environment wins over the file" $?
printf 'PERGAMINO_LLM_BRAIN=$(echo pwned > %s/ran)\n' "$tmp" > "$K/pergamino.local.env"
env -i HOME="$H" PATH=/usr/bin:/bin PERGAMINO_HOME="$K" "$SH" "$PATHS" >/dev/null
[[ ! -e "$tmp/ran" ]]; check "paths: nothing in the file runs" $?
printf 'PERGAMINO_LLM_BRAIN=/crlf/llm\r\n' > "$K/pergamino.local.env"
out=$(env -i HOME="$H" PATH=/usr/bin:/bin PERGAMINO_HOME="$K" "$SH" -c '. "$1"; printf "%s" "$PERGAMINO_LLM_BRAIN"' _ "$PATHS")
[[ "$out" == /crlf/llm ]]; check "paths: a Windows line ending is removed" $?
rm -f "$K/pergamino.local.env"
# Both brains set, so the kit's own pergamino.local.env (if any) is never read.
out=$(env -i HOME="$H" PATH=/usr/bin:/bin PERGAMINO_LLM_BRAIN="$L" PERGAMINO_MAIN_BRAIN="$M" "$SH" -c '. "$1"; printf "%s" "$PERGAMINO_HOME"' _ "$PATHS")
[[ "$out" == "$(cd "$HERE/.." && pwd -P)" ]]; check "paths: with no PERGAMINO_HOME, the kit root is the folder above hooks/" $?
out=$(env -i HOME="$H" PATH=/usr/bin:/bin PERGAMINO_HOME="$K" "$SH" -c 'set -eu; . "$1"; echo "still here:$PERGAMINO_LLM_BRAIN."' _ "$PATHS")
[[ "$out" == "still here:." ]]; check "paths: no file and no variables: empty values, and the caller keeps running under set -eu" $?

# ---------- session-context.sh ----------
out=$(hook "$CTX" PERGAMINO_HOME="$K" PERGAMINO_LLM_BRAIN="$L" PERGAMINO_MAIN_BRAIN="$M")
[[ "$out" == *"=== Pergamino paths ==="* && "$out" == *"PERGAMINO_LLM_BRAIN=$L"* && "$out" != *"Your rules"* && "$out" != *"Lessons"* && "$out" != *Warning* ]]
check "context: paths only when AGENTS.local.md and lessons.md are absent" $?
printf '# My rules\n- Write in Spanish.\n' > "$K/AGENTS.local.md"
printf -- '- 2030-01-01 · **Cite.** Always cite.\n' > "$L/lessons.md"
out=$(hook "$CTX" PERGAMINO_HOME="$K" PERGAMINO_LLM_BRAIN="$L" PERGAMINO_MAIN_BRAIN="$M")
rules_at=$(printf '%s\n' "$out" | grep -nxF '=== Your rules (AGENTS.local.md) ===' | cut -d: -f1)
lessons_at=$(printf '%s\n' "$out" | grep -nxF '=== Lessons (lessons.md) ===' | cut -d: -f1)
[[ -n "$rules_at" && -n "$lessons_at" && $rules_at -lt $lessons_at && "$out" == *"Write in Spanish."* && "$out" == *"Always cite."* ]]
check "context: AGENTS.local.md, then lessons.md, each under its header" $?
out=$(hook "$CTX" PERGAMINO_HOME="$K" PERGAMINO_MAIN_BRAIN="$M")
[[ "$out" == *"PERGAMINO_LLM_BRAIN=(not set)"* && "$out" == *"Warning: PERGAMINO_LLM_BRAIN is not set"* && "$out" == *"Write in Spanish."* && "$out" != *"Always cite."* ]]
check "context: no LLM brain: a warning, the author's rules still shown" $?
out=$(hook "$CTX" PERGAMINO_HOME="$K" PERGAMINO_LLM_BRAIN="$tmp/missing" PERGAMINO_MAIN_BRAIN="$M")
[[ "$out" == *"Warning: PERGAMINO_LLM_BRAIN points at $tmp/missing, which is not a folder"* ]]; check "context: a brain path that is not a folder is flagged" $?
head -c 30000 /dev/zero | tr '\0' 'x' > "$K/AGENTS.local.md"
out=$(hook "$CTX" PERGAMINO_HOME="$K" PERGAMINO_LLM_BRAIN="$L" PERGAMINO_MAIN_BRAIN="$M")
[[ "$out" == *"[cut at 20000 of 30000 bytes"* ]]; check "context: a long file is cut, with a note" $?
: > "$tmp/env-file"
hook "$CTX" PERGAMINO_HOME="$K" PERGAMINO_LLM_BRAIN="$L/with space" PERGAMINO_MAIN_BRAIN="$M" CLAUDE_ENV_FILE="$tmp/env-file" >/dev/null
got=$(env -i "$SH" -c '. "$1"; printf "%s" "$PERGAMINO_LLM_BRAIN"' _ "$tmp/env-file")
[[ "$got" == "$L/with space" ]]; check "context: CLAUDE_ENV_FILE gets export lines that a shell reads back exactly" $?
hook "$CTX" PERGAMINO_HOME="$K" PERGAMINO_LLM_BRAIN="$L" CLAUDE_ENV_FILE="$tmp/no/such/dir/env" >/dev/null; rc=$?
[[ $rc == 0 ]]; check "context: an env file that cannot be written: still exit 0" $?

# ---------- recent-workblocks.sh ----------
W="$L/wiki/workblocks"
for i in 1 2 3 4 5 6; do printf -- '---\ntitle: c%s\n---\n' "$i" > "$W/2030-01-0$i-c$i.md"; touch -t "20300101000$i" "$W/2030-01-0$i-c$i.md"; done
printf 'x\n' > "$W/README.md"
printf 'x\n' > "$W/$(printf 'evil\nINJECTED').md"
out=$(hook "$RECENT" PERGAMINO_HOME="$K" PERGAMINO_LLM_BRAIN="$L" | ctx_of)
[[ $(printf '%s\n' "$out" | grep -c '^  - ') == 5 && "$out" == *"2030-01-06-c6.md"* && "$out" != *"2030-01-01-c1.md"* && "$out" != *README* && "$out" != *INJECTED* ]]
check "recent: the five newest cards; README and a name with a line break are left out" $?
out=$(hook "$RECENT" PERGAMINO_HOME="$K")
[[ -z "$out" ]]; check "recent: silent with no LLM brain set" $?

# ---------- stale-projects.sh ----------
rm -f "$W"/*.md
old=$(date -v-20d +%F 2>/dev/null || date -d '20 days ago' +%F)
new=$(date -v-1d +%F 2>/dev/null || date -d '1 day ago' +%F)
printf -- '---\ntitle: Old project\ntags: [rollup]\nupdated: %s\n---\n- %s: [source: test] x\n' "$old" "$old" > "$W/2020-01-01-old.md"
printf -- '---\ntitle: Busy project\ntags: [rollup]\nupdated: %s\n---\n' "$old" > "$W/2020-01-02-busy.md"
printf -- '---\ntitle: Busy child\n---\nParent: [[2020-01-02-busy]]\n- %s: [source: test] y\n' "$new" > "$W/2020-01-03-child.md"
printf -- '- see [[wiki/workblocks/2020-01-03-child]]\n' >> "$W/2020-01-02-busy.md"
printf -- '---\ntitle: Not a rollup\nupdated: %s\n---\n' "$old" > "$W/2020-01-04-plain.md"
out=$(hook "$STALE" PERGAMINO_HOME="$K" PERGAMINO_LLM_BRAIN="$L" | ctx_of)
[[ "$out" == *"Old project — last movement $old"* && "$out" != *"Busy project"* && "$out" != *"Not a rollup"* ]]
check "stale: a quiet rollup is named; one whose linked card moved, and a card that is not a rollup, are not" $?
out=$(hook "$STALE" PERGAMINO_HOME="$K" PERGAMINO_LLM_BRAIN="$L" STALE_DAYS=30 | ctx_of)
[[ -z "$out" ]]; check "stale: STALE_DAYS raises the threshold" $?

echo
if [[ $fails -eq 0 ]]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
exit $(( fails > 0 ? 1 : 0 ))
