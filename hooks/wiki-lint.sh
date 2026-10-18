#!/usr/bin/env bash
# PreToolUse(Bash), PostToolUse(Edit|Write|Bash) and PostToolUseFailure(Bash) hook: minimal
# frontmatter sanity check on each page of <LLM brain>/wiki/ that a tool call writes.
# Exit 2 on a failed check: the agent corrects the page. Anything else exits 0: the hook fails open.
#
# Which pages:
# - Edit|Write (PostToolUse): the page in tool_input.file_path.
# - Bash: a command does not say which pages it writes (cat >>, python3, sed -i), and its text is not
#   parsed. The PreToolUse run leaves a stamp for the call (session_id + tool_use_id). The run after
#   the call, PostToolUse or PostToolUseFailure (a heredoc can write a page before a later command
#   fails), lints each wiki page whose change time is newer than the stamp, then deletes the stamp.
#   Change time, not modification time: mv, cp -p and rsync -a keep a page's old modification time.
# - Each page it sees under wiki/workblocks/ goes on this session's list, which the Stop hook
#   workblock-status-guard.sh reads: the transcript that hook scans shows neither shell writes nor
#   the calls of subagents (their hooks get the parent's session_id). One line per card and call:
#   "<path>\t<shell or edit>\t<local date>\t<call id>".
# Limits: what a background command writes after its call returns is not seen, nor what an interrupted
# command (Escape: neither PostToolUse nor PostToolUseFailure runs) wrote; its stamp waits for the 7-day
# clean-up. A renamed folder keeps its pages' change times, so its pages are not seen. The stamp knows when,
# not who: a page that another session or a sync program changes while a command runs is linted (and
# listed) here too. workblock-status-guard.sh deletes stamps and lists left for more than 7 days.
# Tests: hooks/wiki-lint.test.sh, hooks/workblock-status-guard.test.sh.
set -uo pipefail

[[ -t 0 ]] && exit 0
input=$(cat)
. "$(dirname "$0")/lib/paths.sh"
[[ -n "${PERGAMINO_LLM_BRAIN:-}" ]] || exit 0
VAULT="$PERGAMINO_LLM_BRAIN"
WIKI="$VAULT/wiki"
WIKI_REAL=$(cd "$WIKI" 2>/dev/null && pwd -P) || WIKI_REAL="$WIKI"
STATE="$HOME/.cache/pergamino/wiki-lint"   # <session>.<call>.stamp and <session>.cards
# Check 4's memory slugs: a memory/ folder in the LLM brain when there is one, else Claude Code's
# memory folder for the kit root (~/.claude/projects/<the kit path, each / and . as ->/memory).
MEM_DIR="$VAULT/memory"
[[ -d "$MEM_DIR" ]] || MEM_DIR="$HOME/.claude/projects/$(printf '%s' "$PERGAMINO_HOME" | sed 's/[^A-Za-z0-9]/-/g')/memory"

slugs="" quoted="" alt="" read_slugs=""
read_memory_slugs() {  # once per run: the memory slugs, one per line, and the same lines as regex text
  local nl=$'\n'
  [[ -z "$read_slugs" ]] || return 0
  read_slugs=yes
  slugs=$(ls "$MEM_DIR" | sed 's/\.md$//' | grep -v '^MEMORY$')
  # Fixed text: a backslash before each character that an extended regex treats as special, so a slug
  # a.b matches [[a.b]] only, never [[aXb]].
  quoted=$(printf '%s\n' "$slugs" | sed 's/[][\.*^$+?(){}|]/\\&/g')
  alt=${quoted//$nl/|}
}
may_link_memory() {  # may_link_memory <page>: false only when no per-slug pattern of check 4 can match
  read_memory_slugs
  # One grep with every slug as an alternative matches exactly when one of the per-slug greps of
  # check 4 would. It saves those ~100 greps (~250 ms a page) on pages that link no memory slug.
  # The slugs are quoted, so any name can be an alternative.
  [[ -n "$alt" ]] || return 0
  grep -qE "\[\[(memory: *)?(${alt})(\|[^]]*)?\]\]" "$1"
  [[ $? -ne 1 ]]   # 0: a slug may be linked; 2 (an error): check the slugs one by one
}

lint_page() {  # lint_page <page>: the four checks; on the first one that fails, says why and returns 1
  local path="$1" first fm hits slug q name

  # Check 1: file starts with ---
  first=$(head -1 "$path")
  if [[ "$first" != "---" ]]; then
    echo "wiki-lint: $path is missing YAML frontmatter (first line should be ---). Add frontmatter with kind/title/created/updated." >&2
    return 1
  fi

  # Check 2: closing --- exists within first 80 lines
  # No pipes in checks 2 and 3: a `grep -q` or `head` that stops reading early kills the command
  # before it with SIGPIPE, and pipefail turns that 141 into a false alarm on pages whose first
  # 80 lines exceed the pipe buffer.
  if ! awk 'NR > 80 { exit } NR > 1 && /^---$/ { found = 1; exit } END { exit !found }' "$path"; then
    echo "wiki-lint: $path has an opening --- but no closing --- in the first 80 lines. Frontmatter is broken." >&2
    return 1
  fi

  # Check 3: frontmatter contains some required hint of structure
  fm=$(awk '/^---$/ { if (++c == 2) exit; next } c == 1 && ++n <= 40' "$path" 2>/dev/null)
  if ! grep -qE '^(kind|type|title):' <<<"$fm"; then
    echo "wiki-lint: $path frontmatter is missing kind/type or title. Add at minimum: kind, title, created, updated." >&2
    return 1
  fi

  # Check 4: no [[wikilinks]] to memory slugs: memory refs go as plain text `memory: <slug>`.
  # (Such links once made most of the broken links a lint found. Wikilinks are for wiki/ paths only.)
  if [[ -d "$MEM_DIR" ]] && grep -q '\[\[' "$path"; then
    # skip wiki/todo.md — lint findings legitimately quote broken patterns
    if [[ "$path" != *"/wiki/todo.md" ]] && may_link_memory "$path"; then
      hits=""
      # Each slug as one line (no word splitting, no file-name expansion), with its regex text alongside.
      while IFS= read -r slug <&3 && IFS= read -r q <&4; do
        [[ -n "$slug" ]] || continue
        # flag [[slug]] / [[memory: slug]] only when no wiki page shares the basename
        if grep -qE "\[\[(memory: *)?$q(\|[^]]*)?\]\]" "$path"; then
          name=${slug//\\/\\\\}; name=${name//\*/\\*}; name=${name//\?/\\?}; name=${name//\[/\\[}   # find -name: fixed text too
          if ! find "$WIKI" -name "$name.md" -print -quit 2>/dev/null | grep -q .; then
            hits="$hits $slug"
          fi
        fi
      done 3<<<"$slugs" 4<<<"$quoted"
      if [[ -n "$hits" ]]; then
        echo "wiki-lint: $path links memory slugs as [[wikilinks]]:$hits — memory refs must be plain text \`memory: <slug>\` (wikilinks are for wiki/ pages only; these break in Obsidian)." >&2
        return 1
      fi
    fi
  fi
  return 0
}

# Letters, digits, _ and - only, so an id cannot point outside the state folder.
IFS='|' read -r event tool sid call <<<"$(jq -r '[.hook_event_name, .tool_name, .session_id, .tool_use_id]
  | map(. // "" | tostring | gsub("[^A-Za-z0-9_-]"; "")) | join("|")' <<<"$input" 2>/dev/null)"

if [[ "$event" == PreToolUse ]]; then   # before a shell command: stamp it; never block the call
  if [[ "$tool" == Bash && -n "$sid" && -n "$call" ]]; then
    mkdir -p "$STATE" 2>/dev/null && touch "$STATE/$sid.$call.stamp" 2>/dev/null
  fi
  exit 0
fi

if [[ "$tool" == Bash ]]; then   # after a shell command: the pages that changed while it ran
  stamp="$STATE/$sid.$call.stamp"
  [[ -n "$sid" && -n "$call" && -f "$stamp" ]] || exit 0
  pages=$(find "$WIKI" -type f \( -name '*.md' -o -name '*.markdown' \) -cnewer "$stamp" 2>/dev/null)
  rm -f "$stamp"
else                             # after an Edit or Write: its page, when it is a wiki page
  pages=$(jq -r '.tool_input.file_path // ""' <<<"$input" 2>/dev/null)
  case "$pages" in
    "$WIKI/"*.md|"$WIKI/"*.markdown|"$WIKI_REAL/"*.md|"$WIKI_REAL/"*.markdown) ;;
    *) exit 0 ;;
  esac
fi

# This session's cards, for workblock-status-guard.sh. Listed before the checks, so a sweep that runs
# past the hook's timeout cannot lose them. Each line says how the card was seen (an Edit or Write is
# certainly this session's change, a subagent's too; a shell command also sees what another session or
# a sync program changed while it ran), the local date, which sets the day the card's entry needs, and the
# call, which tells one sighting from the next. The list is only ever appended to.
if [[ -n "$sid" ]] && cards=$(grep '/wiki/workblocks/' <<<"$pages"); then
  how=edit; [[ "$tool" == Bash ]] && how=shell
  day=$(date +%F)
  mkdir -p "$STATE" 2>/dev/null &&
    while IFS= read -r card; do printf '%s\t%s\t%s\t%s\n' "$card" "$how" "$day" "${call:--}"; done <<<"$cards" \
      >> "$STATE/$sid.cards" 2>/dev/null
fi

rc=0
while IFS= read -r page; do
  [[ -f "$page" && -r "$page" ]] || continue
  lint_page "$page" || rc=2
done <<<"$pages"
exit "$rc"
