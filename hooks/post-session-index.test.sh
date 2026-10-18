#!/usr/bin/env bash
# Test harness for hooks/post-session-index.sh, the Stop hook that rebuilds the indexes of the LLM
# brain only when a page or folder changed since its last run, in a background job under a lock.
# Runs only in temporary folders, under a made-up HOME, kit root and LLM brain whose
# rebuild-index.sh and qmd only leave marker files, so it never reads the real brains or touches
# the real indexes. Each check waits for
# the job to end (the lock folder goes) before it looks. HOOK_SHELL=/bin/bash runs the hook under
# macOS's bash 3.2.
#
# Usage: bash hooks/post-session-index.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="${HOOK:-$HERE/post-session-index.sh}"
SH="${HOOK_SHELL:-$(command -v bash)}"
fails=0
check() { if [[ "$2" == 0 ]]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

tmp="$(mktemp -d)" && [ -d "$tmp" ] || { echo "mktemp failed" >&2; exit 1; }; trap 'rm -rf "$tmp"' EXIT
H="$tmp/home"; V="$H/LLMBrain"; KIT="$tmp/kit"; STAMP="$H/.cache/pergamino/post-session-index.stamp"
LOCK="$H/.cache/pergamino/post-session-index.lock"; REBUILD="$KIT/scripts/rebuild-index.sh"
touch -t 202601010000 "$tmp/stamp-before"   # the stamp's time in fresh()
fresh() {  # fresh [rebuild exit] [rebuild seconds]: a vault older than the stamp; stand-ins for rebuild-index.sh and qmd
  rm -rf "$H" "$KIT"
  mkdir -p "$V/wiki" "$V/scripts" "$V/.obsidian" "$V/memory" "${REBUILD%/*}" "$H/.bun/bin" "${STAMP%/*}"
  echo page > "$V/wiki/a.md"; echo x > "$V/scripts/tool.sh"
  echo '- [a](a.md)' > "$V/memory/MEMORY.md"
  printf '#!/bin/sh\necho "$1" >> "%s/rebuilt"\nsleep %s\nexit %s\n' "$H" "${2:-0}" "${1:-0}" > "$REBUILD"
  printf '#!/bin/sh\necho "$*" >> "%s/qmd-ran"\n' "$H" > "$H/.bun/bin/qmd"
  chmod +x "$REBUILD" "$H/.bun/bin/qmd"
  find "$V" -exec touch -t 202501010000 {} +
  touch -t 202601010000 "$STAMP"
}
run() { env -i HOME="$H" PATH=/usr/bin:/bin PERGAMINO_HOME="$KIT" PERGAMINO_LLM_BRAIN="$V" "$SH" "$HOOK" </dev/null; rc=$?; }   # one Stop: the hook alone
settle() {  # waits, at most 15 s, until no rebuild holds the lock
  local i=0; while [[ -d "$LOCK" && $i -lt 150 ]]; do sleep 0.1; i=$((i + 1)); done
}
hook() {  # one Stop and the rebuild it starts; "rebuild" or "skip" in $got, exit code in $rc
  run; settle
  got=skip; [[ -e "$H/rebuilt" ]] && got=rebuild
}
rebuilds() { if [[ -e "$H/rebuilt" ]]; then wc -l < "$H/rebuilt" | tr -d ' '; else echo 0; fi; }
seconds() { /usr/bin/perl -MTime::HiRes=time -e 'printf "%.3f", time'; }
expect() { [[ "$got" == "$1" && $rc == 0 ]]; }

fresh; hook; expect skip; check "nothing changed: no rebuild" $?
fresh; echo more >> "$V/wiki/a.md"; hook; expect rebuild; check "a page edited: rebuild" $?
fresh; echo p > "$V/wiki/b.md"; hook; expect rebuild; check "a new page: rebuild" $?
fresh; mkdir "$V/wiki/sub"; hook; expect rebuild; check "a new folder: rebuild" $?
fresh; echo y > "$V/scripts/other.sh"; hook; expect rebuild; check "a new file in a folder of the brain: rebuild (its folder changed)" $?
fresh; echo z > "$V/.obsidian/w.json"; hook; expect skip; check "a change inside .obsidian: no rebuild" $?

# memory/: an agent's memory notes, which are not pages.
fresh; echo m > "$V/memory/feedback-new.md"; hook; expect skip
check "a new memory in memory/: no rebuild (a memory is not a page)" $?
fresh; echo '- [b](b.md)' >> "$V/memory/MEMORY.md"; hook; expect skip
check "the memory index edited in place: no rebuild" $?
fresh; echo m > "$V/memory/feedback-new.md"; echo p > "$V/wiki/f.md"; hook; expect rebuild
check "a new memory and a new page: rebuild" $?

fresh; echo p > "$V/wiki/d.md"; hook; [[ "$STAMP" -nt "$tmp/stamp-before" ]]; check "a rebuild that succeeds moves the stamp" $?
fresh 1; echo p > "$V/wiki/e.md"; hook; [[ ! "$STAMP" -nt "$tmp/stamp-before" && $rc == 0 ]]
check "a failed rebuild leaves the stamp, so the next reply retries; the hook still exits 0" $?

# In the background: on a slow computer the reply would wait for the whole rebuild, close to the hook's 30 s limit.
fresh 0 3; echo more >> "$V/wiki/a.md"; t0=$(seconds); out=$(env -i HOME="$H" PATH=/usr/bin:/bin PERGAMINO_HOME="$KIT" PERGAMINO_LLM_BRAIN="$V" "$SH" "$HOOK" </dev/null 2>&1); rc=$?
t1=$(seconds); settle
awk -v a="$t0" -v b="$t1" 'BEGIN { exit !(b - a < 1) }' && [[ $rc == 0 && -z "$out" && $(rebuilds) == 1 && "$STAMP" -nt "$tmp/stamp-before" ]]
check "with a 3-second rebuild the hook returns in under a second, silent; the rebuild then runs and moves the stamp" $?
fresh 0 2; echo more >> "$V/wiki/a.md"; run & sleep 0.5; run; wait; settle; [[ $(rebuilds) == 1 && ! -d "$LOCK" ]]
check "a second run while the first one's rebuild holds the lock starts no second rebuild; the lock goes at the end" $?
fresh; mkdir -p "$LOCK"; echo more >> "$V/wiki/a.md"; run; sleep 0.3; [[ $(rebuilds) == 0 && $rc == 0 ]]; r=$?; rmdir "$LOCK"
check "a lock held by a running rebuild: this reply starts none" $r
fresh; mkdir -p "$LOCK"; touch -t 202501010000 "$LOCK"; echo more >> "$V/wiki/a.md"; hook; expect rebuild && [[ ! -d "$LOCK" ]]
check "a lock untouched for more than 10 minutes (its rebuild died) is taken over" $?
fresh 0 2; echo more >> "$V/wiki/a.md"; run; sleep 0.5; echo p > "$V/wiki/during.md"; settle
[[ $(rebuilds) == 2 && "$STAMP" -nt "$V/wiki/during.md" ]]
check "a page written while the rebuild runs gets a second pass before the stamp moves" $?
fresh; cat > "$REBUILD" <<EOF
#!/bin/sh
# Stand-in that writes the index and the graph as the real ones do: a temporary file renamed into wiki/.
echo x >> "$H/rebuilt"
echo index > "$V/wiki/._index.tmp.md.tmp"; mv "$V/wiki/._index.tmp.md.tmp" "$V/wiki/_index.md"
echo '{}' > "$V/wiki/_graph.json.tmp"; mv "$V/wiki/_graph.json.tmp" "$V/wiki/_graph.json"
EOF
echo more >> "$V/wiki/a.md"; hook; hook; [[ $(rebuilds) == 1 ]]
check "the rebuild's own index and graph, renamed into wiki/, start neither a second pass nor the next reply's rebuild" $?
fresh; echo more >> "$V/wiki/a.md"; hook; [[ "$(cat "$H/qmd-ran")" == update ]]
check "qmd runs as \`qmd update\`, which updates every collection" $?
fresh; echo more >> "$V/wiki/a.md"; hook; [[ "$(head -n 1 "$H/rebuilt")" == "$V" ]]
check "rebuild-index.sh gets the LLM brain as its argument" $?
fresh; echo more >> "$V/wiki/a.md"; env -i HOME="$H" PATH=/usr/bin:/bin PERGAMINO_HOME="$KIT" "$SH" "$HOOK" </dev/null; rc=$?; settle
[[ $rc == 0 && ! -e "$H/rebuilt" ]]; check "no LLM brain set: nothing runs, exit 0" $?

echo
if [[ $fails -eq 0 ]]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
exit $(( fails > 0 ? 1 : 0 ))
