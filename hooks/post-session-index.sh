#!/bin/bash
# Stop hook: keep the derived indexes of the LLM brain fresh after every reply.
# Deterministic, silent, never blocks: always exits 0.
# 1) <LLM brain>/wiki/_index.md and wiki/_graph.json (scripts/rebuild-index.sh)
# 2) qmd's keyword (BM25) index, so "search before you claim" sees this session's pages. `qmd update`
#    re-indexes every collection (main and llm). Vector embeddings are not made here (the model load is
#    slow): run `qmd embed` by hand or on a schedule (docs/search-setup.md).
#
# Stop fires after every reply, not once per session. So both steps are skipped when nothing
# changed since the last run: no page (*.md) and no folder (a page added, renamed or deleted)
# newer than the stamp. Dot-folders (.obsidian, .claude) don't count, and neither does memory/
# (an agent's memory notes are not pages).
#
# The steps run in the background: on a slow computer a rebuild can take more than 20 seconds, and
# every reply that changed a page would wait for it. The hook only runs the change test, takes the
# lock and starts a job detached from the session (no shared output, SIGHUP ignored), then returns.
# - One job at a time: the lock is a folder (mkdir). A reply that finds it held starts nothing: the
#   running job sees the changes. A lock untouched for 10 minutes was left by a job that died (a pass
#   takes under a minute, and each pass touches it): the next reply that finds a change takes it over.
#   If two replies take over the same stale lock at once, two jobs run once side by side: harmless.
# - The stamp moves only after both steps succeeded, so a failed pass is retried at the next reply
#   that finds a change, and its time is the end of the pass, so the pass's own writes never count as
#   a change. A page written while a pass ran is newer than the pass's start: the job runs another
#   pass (three at most; after the third the stamp stays, and the next reply starts again). The pass's
#   own files (wiki/_index.md and wiki/_graph.json, renamed into wiki/, which moves the folder's time)
#   don't count there. Still not seen: a page deleted at the top of wiki/ during a pass (only the
#   folder's time shows it, and the pass moves that too).
# Tests: hooks/post-session-index.test.sh.

[ -t 0 ] || cat >/dev/null 2>&1 || true   # the hook input is not needed
. "$(dirname "$0")/lib/paths.sh"
[ -n "${PERGAMINO_LLM_BRAIN:-}" ] && [ -d "$PERGAMINO_LLM_BRAIN/wiki" ] || exit 0
VAULT="$PERGAMINO_LLM_BRAIN"
STAMP="$HOME/.cache/pergamino/post-session-index.stamp"
LOCK="$HOME/.cache/pergamino/post-session-index.lock"
REBUILD="$PERGAMINO_HOME/scripts/rebuild-index.sh"

# changed_since <file> [find tests]: prints the first page or folder newer than <file>, if any.
changed_since() {
  local ref="$1"; shift
  find "$VAULT" -path '*/.*' -prune -o -path "$VAULT/memory" -prune \
    -o "$@" \( -name '*.md' -o -type d \) -newer "$ref" -print -quit 2>/dev/null
}

if [ -f "$STAMP" ] && [ -z "$(changed_since "$STAMP")" ]; then
  exit 0
fi

steps() {  # the index, then qmd's keyword index; fails when either step failed
  local ok=0 qmd="$HOME/.bun/bin/qmd"
  bash "$REBUILD" "$VAULT" >/dev/null 2>&1 || ok=1
  [ -x "$qmd" ] || qmd="$(command -v qmd 2>/dev/null || true)"
  if [ -n "$qmd" ]; then
    "$qmd" update >/dev/null 2>&1 || ok=1
  fi
  return $ok
}

job() {
  local pass
  for pass in 1 2 3; do
    touch "$LOCK"                 # this pass starts now (and the lock is alive)
    steps || return 0             # the stamp stays: the next reply that finds a change retries
    touch "$STAMP.next"           # the end of this pass: the stamp's time if nothing changed during it
    if [ -z "$(changed_since "$LOCK" ! -path "$VAULT/wiki" ! -path "$VAULT/wiki/_index.md")" ]; then
      mv -f "$STAMP.next" "$STAMP"
      return 0
    fi
  done
  rm -f "$STAMP.next"
}

mkdir -p "${STAMP%/*}" 2>/dev/null
if ! mkdir "$LOCK" 2>/dev/null; then
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ] || exit 0   # a job is running
  rm -rf "$LOCK"
  mkdir "$LOCK" 2>/dev/null || exit 0
fi
( trap '' HUP; trap 'rm -rf "$LOCK"' EXIT; job ) </dev/null >/dev/null 2>&1 &
exit 0
