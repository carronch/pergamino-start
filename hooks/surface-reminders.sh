#!/usr/bin/env bash
# SessionStart hook: list the due reminders of the LLM brain.
# Lists the reminders whose `due:` date (YYYY-MM-DD in frontmatter) is today or earlier, one line
# each: due date · title · path relative to the LLM brain. A reminder keeps firing every session
# until you delete its file (= dismiss).
#
# Reminders live in <LLM brain>/reminders/*.md. The LLM brain path comes from hooks/lib/paths.sh
# (the environment, else pergamino.local.env).
#
# Reminder file shape:
#   ---
#   due: 2030-05-29
#   title: Short label
#   ---
#   Body. Not shown at session start: the session reads the file before it acts on it.
#
# The title is the frontmatter's `title:`, or else the first body line (heading marks removed);
# control characters are removed (a tab becomes a space), and it is cut at 120 characters.
# A reminder whose `due:` line is missing or empty falls back to the date its file name starts
# with (YYYY-MM-DD-...) and is flagged; with no date at all, or a due: that isn't YYYY-MM-DD, it is
# flagged and skipped, so no reminder sits unseen. Only regular files are read (no symlinks,
# FIFOs), and only from a real folder: a reminders folder that is a link is flagged, not read, even
# when the link stays inside the brain (a link to the cards would put every dated note in front of
# the session). A file without frontmatter is flagged, and nothing from it is shown; file names
# are reduced to [A-Za-z0-9._-].
#
# Silent when: no LLM brain set, no reminders folder, no due reminders, no malformed reminders.
# Tests: hooks/surface-reminders.test.sh.

set -u
[ -t 0 ] || cat >/dev/null 2>&1 || true   # the hook input is not needed
. "$(dirname "$0")/lib/paths.sh"
BRAIN="${PERGAMINO_LLM_BRAIN:-}"
[ -n "$BRAIN" ] || exit 0
ROOT=$(cd "$BRAIN" 2>/dev/null && pwd -P) || exit 0

TODAY=$(date +%Y-%m-%d)
OUT=""
add() { OUT="${OUT}$1
"; }

# cut_title TEXT: at most 120 characters, cut on a character boundary (a UTF-8 locale in a subshell;
# the rest of the hook keeps the caller's locale).
cut_title() (
  LC_ALL=en_US.UTF-8
  t=$1
  if [ "${#t}" -gt 120 ]; then t="${t:0:119}…"; fi
  printf '%s' "$t"
)

# scan REL: one line per due or malformed reminder in <LLM brain>/REL.
scan() {
  local rel="$1" dir="$BRAIN/$1" f name shown due note fm title
  [ -d "$dir" ] || return 0
  if [ ! -r "$dir" ] || [ ! -x "$dir" ]; then
    add "$rel cannot be opened (permissions), so it was not read: let this user read it (chmod u+rx)."
    return 0
  fi
  if [ "$(cd "$dir" 2>/dev/null && pwd -P)" != "$ROOT/$rel" ]; then
    add "$rel is a link (or sits under one), so it was not read: make it a real folder."
    return 0
  fi
  for f in "$dir"/*.md; do
    { [ -f "$f" ] && [ ! -L "$f" ]; } || continue
    name=$(printf '%s' "$(basename "$f")" | LC_ALL=C tr -c 'A-Za-z0-9._-' '_')
    shown="$rel/$name"
    if [ ! -r "$f" ]; then
      add "$shown cannot be read (permissions), so it was not checked: let this user read it (chmod u+r)."
      continue
    fi
    due=$(grep -m1 '^due:' "$f" | sed 's/^due:[[:space:]]*//' | tr -d '"'"'"' ')
    note=""
    if [ -z "$due" ]; then
      due=$(basename "$f" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
      if [ -z "$due" ]; then
        add "$shown has no usable due: line and no date in its name, so it never fires: add a due: line"
        continue
      fi
      note=" (no usable due: line; date taken from the file name: add a due: line)"
    fi
    case "$due" in
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*) due=${due:0:10} ;;
      *) add "$shown has a due: line that is not YYYY-MM-DD, so it won't fire until that line is fixed"
         continue ;;
    esac
    # String compare works for ISO dates. Fire when due <= today.
    if [[ "$due" > "$TODAY" ]]; then continue; fi
    # "+<title>" when the first non-blank line opens a frontmatter block, "-" when it does not. The
    # title is the frontmatter's title:, or else the first non-blank body line. awk runs under
    # LC_ALL=C, like the tr calls: under a UTF-8 locale macOS awk stops on a byte that is not UTF-8
    # ("towc: multibyte conversion failure"), and the file looked like it had no frontmatter.
    fm=$(LC_ALL=C awk '
      state == 0 { if (NF == 0) next; if ($0 == "---") { state = 1; next }; nofm = 1; exit }
      state == 1 { if ($0 == "---") { state = 2; next }
                   if (title == "" && sub(/^title:[[:space:]]*/, "")) title = $0
                   next }
      NF { body = $0; sub(/^#+[[:space:]]+/, "", body); exit }
      END { if (nofm || state == 0) print "-"; else print "+" (title != "" ? title : body) }
    ' "$f" | LC_ALL=C tr '\t' ' ' | LC_ALL=C tr -d '\000-\037\177')
    case "$fm" in
      +*)
        title=${fm#+}
        title="${title#"${title%%[![:space:]]*}"}"; title="${title%"${title##*[![:space:]]}"}"
        case "$title" in
          \"*\") title=${title#\"}; title=${title%\"} ;;
          \'*\') title=${title#\'}; title=${title%\'} ;;
        esac
        [ -n "$title" ] || title="(no title)"
        title=$(cut_title "$title") ;;
      *) title="(no frontmatter, so the content is not shown: give the file a frontmatter block with a due: line)" ;;
    esac
    add "$due · $title · $shown$note"
  done
}

scan reminders

[ -z "$OUT" ] && exit 0

CTX="=== Due reminders (in the LLM brain) ===
${OUT}Read a reminder's file before you act on it. To dismiss one, delete its file."

jq -n --arg c "$CTX" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $c
  }
}'
exit 0
