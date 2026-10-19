#!/usr/bin/env bash
# Fail-closed wrapper for PreToolUse guard hooks.
#   run-guard.sh <guard-script>
#
# Claude Code treats a hook that cannot run, or that exits with a code other than 2, as a
# non-blocking error: the tool call goes through unguarded. A guard file that is missing, or that
# the operating system will not let the session read, would then switch the guard off without a
# sign. This wrapper runs the guard with bash (so a lost executable bit does not matter) and turns
# every result other than "allow" (0) and "block" (2) into a block:
#   0         the guard allows; its output (for example a JSON "ask" decision) passes through.
#   2         the guard blocks; its message on stderr goes back to the agent.
#   126, 127  the guard could not run (a missing file, no permission): block.
#   any other the guard failed: block.
# The wrapper itself must exist for this to work. Keep it in the kit's hooks/ folder, next to the
# guards, and wire each guard in .claude/settings.json as:
#   bash "$CLAUDE_PROJECT_DIR"/hooks/run-guard.sh "$CLAUDE_PROJECT_DIR"/hooks/<guard>.sh
# Tests: hooks/hooks.test.sh.
guard="${1:-}"
if [ -z "$guard" ]; then
  echo "run-guard: no guard script given. Blocking to fail closed." >&2
  exit 2
fi
bash "$guard"
rc=$?
case "$rc" in
  0|2) exit "$rc" ;;
  126|127)
    echo "Guard $(basename "$guard") could not run (exit $rc: a missing file, or the system blocks this session from reading the kit folder). Blocking to fail closed. Fix the file or its permissions, or ask the author." >&2
    exit 2 ;;
  *)
    echo "Guard $(basename "$guard") failed (exit $rc). Blocking to fail closed. Run the guard's test, or ask the author." >&2
    exit 2 ;;
esac
