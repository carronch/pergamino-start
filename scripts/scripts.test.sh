#!/usr/bin/env bash
# Test harness for scripts/rebuild-index.sh and scripts/promote-to-mainvault.sh. Runs only in
# temporary folders: HOME, the kit root and both brains point at made-up folders, so it never
# reads or writes the real brains.
#
# Usage: bash scripts/scripts.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REBUILD="${REBUILD:-$HERE/rebuild-index.sh}"
PROMOTE="${PROMOTE:-$HERE/promote-to-mainvault.sh}"
fails=0
check() { if [[ "$2" == 0 ]]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

tmp="$(mktemp -d)" && [ -d "$tmp" ] || { echo "mktemp failed" >&2; exit 1; }; trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" PERGAMINO_HOME="$tmp/kit"
L="$tmp/llm"; M="$tmp/main"
mkdir -p "$HOME" "$PERGAMINO_HOME" "$L/wiki/concepts" "$L/wiki/meetings" "$L/wiki/tools" "$M/beliefs" "$L/outputs/mainvault-pending"
page() { printf -- '---\n%s\n---\n%s\n' "$2" "${3:-}" > "$1"; }

# ---------- rebuild-index.sh ----------
page "$L/wiki/concepts/compounding.md" $'type: concept\ntitle: Compounding\nupdated: 2030-01-02' $'# Compounding\n\nSmall gains add up.'
page "$L/wiki/meetings/2030-01-01-kickoff.md" $'title: Kickoff' 'Notes from the kickoff.'
page "$L/wiki/tools/qmd.md" $'kind: tool\ntitle: qmd' 'Search for the brains. See [[wiki/concepts/compounding]].'
out=$(bash "$REBUILD" "$L" 2>&1); rc=$?
[[ $rc == 0 && -f "$L/wiki/_index.md" ]]; check "rebuild: argument 1 is the LLM brain; the index is written" $?
idx=$(cat "$L/wiki/_index.md" 2>/dev/null)
[[ "$idx" == *"Total pages: **3**"* && "$idx" == *"[[wiki/concepts/compounding.md|Compounding]] — Small gains add up. _(updated 2030-01-02)_"* ]]
check "rebuild: the index lists each page with its summary line and date" $?
[[ "$idx" == *"### Meetings (1)"* ]]; check "rebuild: a page in wiki/meetings/ without type: counts as a meeting" $?
[[ -f "$L/wiki/_graph.json" ]]; check "rebuild: the graph is rebuilt too" $?
rm -f "$L/wiki/_index.md"
PERGAMINO_LLM_BRAIN="$L" bash "$REBUILD" >/dev/null 2>&1; rc=$?
[[ $rc == 0 && -f "$L/wiki/_index.md" ]]; check "rebuild: with no argument, PERGAMINO_LLM_BRAIN is the brain" $?
out=$(env -u PERGAMINO_LLM_BRAIN bash "$REBUILD" 2>&1); rc=$?
[[ $rc != 0 && "$out" == *"no LLM brain given"* ]]; check "rebuild: no argument and no brain set: stops with a message" $?
out=$(bash "$REBUILD" "$tmp/nowhere" 2>&1); rc=$?
[[ $rc != 0 && "$out" == *"wiki directory not found"* ]]; check "rebuild: a folder with no wiki/: stops with a message" $?

# ---------- promote-to-mainvault.sh ----------
export PERGAMINO_LLM_BRAIN="$L" PERGAMINO_MAIN_BRAIN="$M"
T="$L/outputs/mainvault-pending"
printf '<!-- target: beliefs/compounding.md -->\n# Compounding\n\nI believe small gains add up.\n' > "$T/compounding.md"
printf '# No marker\n' > "$T/nomarker.md"
printf '<!-- target: ../escape.md -->\nx\n' > "$T/escape.md"
out=$(bash "$PROMOTE" </dev/null 2>&1); rc=$?
[[ $rc == 0 && "$out" == *"compounding.md"*"beliefs/compounding.md  (new)"* && "$out" == *"nomarker.md  (missing"* ]]
check "promote: with no argument, it lists the tray and each target" $?
out=$(printf 'n\n' | bash "$PROMOTE" compounding.md 2>&1); rc=$?
[[ $rc == 0 && "$out" == *aborted* && ! -e "$M/beliefs/compounding.md" && -e "$T/compounding.md" ]]
check "promote: an answer other than y writes nothing" $?
out=$(bash "$PROMOTE" compounding.md </dev/null 2>&1); rc=$?
[[ ! -e "$M/beliefs/compounding.md" ]]; check "promote: no answer at all (no terminal) writes nothing" $?
out=$(printf 'y\n' | bash "$PROMOTE" compounding.md 2>&1); rc=$?
[[ $rc == 0 && -f "$M/beliefs/compounding.md" && ! -e "$T/compounding.md" ]] && ! grep -q 'target:' "$M/beliefs/compounding.md" && grep -q 'compounding.md' "$T/_log.md"
check "promote: y copies the file without its marker, removes it from the tray, and logs it" $?
out=$(printf 'y\n' | bash "$PROMOTE" escape.md 2>&1); rc=$?
[[ $rc != 0 && "$out" == *"Target rejected"* && ! -e "$tmp/escape.md" ]]; check "promote: a target with .. is rejected" $?
out=$(printf 'y\n' | bash "$PROMOTE" ../../main/beliefs/x.md 2>&1); rc=$?
[[ $rc != 0 && "$out" == *"not a path"* ]]; check "promote: a source given as a path is rejected" $?
out=$(env -u PERGAMINO_MAIN_BRAIN bash "$PROMOTE" </dev/null 2>&1); rc=$?
[[ $rc != 0 && "$out" == *"PERGAMINO_MAIN_BRAIN"* ]]; check "promote: no Main brain set: stops with a message" $?

echo
if [[ $fails -eq 0 ]]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
exit $(( fails > 0 ? 1 : 0 ))
