#!/bin/bash
# Stop hook: workblock-status-guard.
# If this session changed any <LLM brain>/wiki/workblocks/*.md card (not archive/) and the card has no timeline
# entry dated from the day of that change through today, block the stop ONCE and ask the agent to
# update the card's status frontmatter + timeline before ending. Deterministic backstop for the
# house rule "the session that advances a card updates its status and timeline".
# Cards come from the transcript's Edit/Write/MultiEdit calls and from the list
# wiki-lint.sh keeps for this session: cards changed through the shell, and by
# subagents, whose calls are not in this transcript.
# The day of a change is its local date: the transcript line's timestamp (UTC), or the date
# wiki-lint.sh wrote on the list line. So a session that runs past midnight is not blocked again
# on cards it changed the evening before.
# Fails open: any parse problem → exit 0. Never loops: stop_hook_active → exit 0.
# Tests: hooks/workblock-status-guard.test.sh.

set -uo pipefail

STATE="$HOME/.cache/pergamino/wiki-lint"   # wiki-lint.sh's stamps, per-session card lists and named lines

input=$(cat)
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null | tr -cd 'A-Za-z0-9_-')

[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0
[ "$active" = "true" ] && exit 0

# Stamps and lists that nothing touched for more than 7 days: their sessions have ended.
find "$STATE" -type f -mtime +7 -delete 2>/dev/null

today=$(date +%F)
list="" named=""
[ -n "$sid" ] && { list="$STATE/$sid.cards"; named="$STATE/$sid.named"; }

# The transcript's Edit/Write/MultiEdit calls, one line each: the local date of the call, a tab, the
# file. The date comes from the call line's timestamp (UTC). A line without a usable one takes the
# newest timestamp before it in the transcript, on any line; with none before it the date stays
# empty, which counts as today below. Each line is read on its own: one that doesn't fit is skipped,
# not fatal.
calls=$(jq -rn '
  foreach inputs as $line ({newest: "", own: ""};
    (try ($line.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 | strflocaltime("%Y-%m-%d")) catch "") as $d |
    {newest: (if $d > .newest then $d else .newest end), own: $d};
    (if .own != "" then .own else .newest end) as $day |
    try ($line | objects | select(.type == "assistant") | .message.content[]? | objects |
      select(.type == "tool_use") | select(.name == "Edit" or .name == "Write" or .name == "MultiEdit") |
      (.input.file_path? // empty) | strings | "\($day)\t\(.)") catch empty)' "$transcript" 2>/dev/null)

# The cards to name, one line each: the file, a tab, the day its entry needs. Cards only:
# wiki/workblocks/*.md, the files the kanban reads; archive/ holds old entries copied verbatim.
# A card counts from the latest change that still counts:
# - a transcript call, or a list line from an Edit or Write: until the card has the entry;
# - a list line from the shell (or an old line, the path only, dated today): once. A shell
#   command also lists a card that another session or a sync program changed while it ran, so
#   naming such a card at every reply would block each one, and an agent might add an entry to a
#   card this session never changed. Its call id goes on the session's named lines, so the next
#   stop skips that line; a later shell call is a new line.
# The guard never rewrites the list: a background subagent may be appending to it. A day after
# today (a clock that went back) counts as today.
due=$(printf '%s\n' "$calls" | awk -F'\t' -v today="$today" -v list="$list" -v named="$named" '
  function card(p) { return p ~ /\/wiki\/workblocks\/[^\/]+$/ && p !~ /README/ }
  function day(d) { return (d ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ && d <= today) ? d : today }
  function need(p, d) { if (card(p) && (!(p in want) || d > want[p])) want[p] = d }
  BEGIN {
    if (named != "") { while ((getline line < named) > 0) { split(line, f, "\t"); done[f[1] "\t" f[2]] = 1 }; close(named) }
    if (list != "") {
      while ((getline line < list) > 0) {
        split(line, f, "\t")   # file, how (shell or edit), local date, call id
        if (f[2] == "edit") { need(f[1], day(f[3])); continue }
        key = f[1] "\t" f[4]
        if (!card(f[1]) || key in done) continue
        need(f[1], day(f[3])); shell[key] = f[1]
      }
      close(list)
    }
  }
  { need($2, day($1)) }
  END {
    for (p in want) {
      if ((r = (getline line < p)) < 0) continue   # the card is gone
      found = 0
      while (r > 0 && !found) {
        d = substr(line, 3, 10)
        if (line ~ /^- [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]:/ && d >= want[p] && d <= today) found = 1
        r = (getline line < p)
      }
      close(p)
      if (found) continue
      print p "\t" want[p]
      if (named != "") for (k in shell) if (shell[k] == p) print k >> named
    }
  }' 2>/dev/null)

[ -n "$due" ] || exit 0
missing=$(printf '%s\n' "$due" | sort | awk -F'\t' '{ printf " %s (changed %s)", $1, $2 }')

jq -n --arg m "$missing" --arg d "$today" '{
  decision: "block",
  reason: ("workblock-status-guard: this session changed workblock card(s) without a timeline entry dated on or after the day of the change:" + $m + ". Before stopping: (1) if the card'\''s real state changed, update its `status:` / `status_note:` frontmatter — the kanban lane reads it; (2) add a `- " + $d + ": [source:...]` timeline entry (one line is enough for small edits; an entry dated the day of the change also counts). Then stop. If this session did not change one of them, say so and stop: a shell command also lists a card that another session or a sync program changed while the command ran, and such a card is named only once.")
}'
exit 0
