#!/usr/bin/env bash
# SessionStart hook (every source: startup, resume, clear, compact): give the session its paths
# and the author's own rules.
#
# It prints, as plain text that Claude Code adds to the session's context:
#   1. "=== Pergamino paths ===": the three resolved paths (hooks/lib/paths.sh), and a warning
#      when a brain path is not set or is not a folder.
#   2. "=== Your rules (AGENTS.local.md) ===": $PERGAMINO_HOME/AGENTS.local.md, when it exists.
#      These are the author's personal rules. They win over the kit's AGENTS.md on preferences.
#   3. "=== Lessons (lessons.md) ===": <LLM brain>/lessons.md, when it exists.
# A missing file prints nothing. Each file is cut at MAX_BYTES (default 20000) with a note.
#
# When Claude Code gives the hook CLAUDE_ENV_FILE, the hook also appends export lines for the
# three paths to it, so the session's shell commands can use "$PERGAMINO_LLM_BRAIN" and the
# other two variables directly.
# Never blocks; always exits 0. Tests: hooks/session-start.test.sh.
set -u

[ -t 0 ] || cat >/dev/null 2>&1 || true   # the hook input is not needed
. "$(dirname "$0")/lib/paths.sh"
MAX_BYTES="${PERGAMINO_CONTEXT_MAX_BYTES:-20000}"
case "$MAX_BYTES" in ''|*[!0-9]*) MAX_BYTES=20000 ;; esac

show() {  # show <header> <file>: the file under its header, cut at MAX_BYTES
  local size
  [ -f "$2" ] && [ -r "$2" ] || return 0
  size=$(wc -c < "$2" 2>/dev/null | tr -d ' ') || size=0
  printf '\n%s\n' "$1"
  head -c "$MAX_BYTES" "$2"
  if [ "${size:-0}" -gt "$MAX_BYTES" ]; then
    printf '\n[cut at %s of %s bytes: read the rest of %s yourself]\n' "$MAX_BYTES" "$size" "$2"
  else
    printf '\n'
  fi
}

echo "=== Pergamino paths ==="
echo "PERGAMINO_HOME=$PERGAMINO_HOME"
echo "PERGAMINO_MAIN_BRAIN=${PERGAMINO_MAIN_BRAIN:-(not set)}"
echo "PERGAMINO_LLM_BRAIN=${PERGAMINO_LLM_BRAIN:-(not set)}"
for key in PERGAMINO_MAIN_BRAIN PERGAMINO_LLM_BRAIN; do
  eval "val=\${$key:-}"
  if [ -z "$val" ]; then
    echo "Warning: $key is not set. Run install.sh, or write it to $PERGAMINO_HOME/pergamino.local.env (see pergamino.local.env.example)."
  elif [ ! -d "$val" ]; then
    echo "Warning: $key points at $val, which is not a folder. Tell the author before you write anything."
  fi
done

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  ( printf 'export PERGAMINO_HOME=%q\nexport PERGAMINO_MAIN_BRAIN=%q\nexport PERGAMINO_LLM_BRAIN=%q\n' \
    "$PERGAMINO_HOME" "$PERGAMINO_MAIN_BRAIN" "$PERGAMINO_LLM_BRAIN" >> "$CLAUDE_ENV_FILE" ) 2>/dev/null || true
fi

show "=== Your rules (AGENTS.local.md) ===" "$PERGAMINO_HOME/AGENTS.local.md"
[ -n "${PERGAMINO_LLM_BRAIN:-}" ] && show "=== Lessons (lessons.md) ===" "$PERGAMINO_LLM_BRAIN/lessons.md"
exit 0
