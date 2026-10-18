#!/bin/bash
# SessionStart hook: list the 5 most recently touched cards in <LLM brain>/wiki/workblocks/.
# Glob, not `ls`: a file name with a line break cannot inject extra lines into this trusted
# context; names with control characters are skipped; the order comes from one stat call for
# all cards (a stat per card is slow at a few hundred cards).
# Silent when no LLM brain is set or it has no cards. Tests: hooks/session-start.test.sh.

[ -t 0 ] || cat >/dev/null 2>&1 || true   # the hook input is not needed
. "$(dirname "$0")/lib/paths.sh"
[ -n "${PERGAMINO_LLM_BRAIN:-}" ] || exit 0
WB="$PERGAMINO_LLM_BRAIN/wiki/workblocks"
[ -d "$WB" ] || exit 0

names=()
for f in "$WB"/*.md; do
  [ -e "$f" ] || continue
  base="${f##*/}"
  [ "$base" = "README.md" ] && continue
  case "$base" in (*[[:cntrl:]]*) continue ;; esac
  names+=("$base")
done
[ ${#names[@]} -gt 0 ] || exit 0

# macOS stat first, then GNU stat.
recent=$(cd "$WB" && { stat -f '%m%t%N' -- "${names[@]}" 2>/dev/null || stat --printf '%Y\t%n\n' -- "${names[@]}" 2>/dev/null; } \
  | sort -rn | head -5 | cut -f2- | sed 's/^/  - /')
[ -n "$recent" ] || exit 0

jq -n --arg c "Recent cards (wiki/workblocks/ in the LLM brain):
$recent" '{
  hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: $c }
}'
exit 0
