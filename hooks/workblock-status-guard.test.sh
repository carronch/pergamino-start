#!/usr/bin/env bash
# Test harness for hooks/workblock-status-guard.sh, the Stop hook that blocks a stop once when the
# session changed a workblock card without a timeline entry dated from the day of the change (its local date)
# through today. It finds the cards in the transcript's
# Edit and Write calls and in the list that hooks/wiki-lint.sh keeps for each session (shell writes, and
# subagents, whose calls are not in the main transcript), so the suite runs both hooks. Runs only in a temporary
# folder, under a made-up HOME, kit root and LLM brain, so it never reads the real brains. HOOK_SHELL=/bin/bash
# runs the hooks under macOS's bash 3.2.
#
# Usage: bash hooks/workblock-status-guard.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GUARD="${GUARD:-$HERE/workblock-status-guard.sh}"
LINT="${LINT:-$HERE/wiki-lint.sh}"
SH="${HOOK_SHELL:-$(command -v bash)}"
fails=0
check() { if [[ "$2" == 0 ]]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

# One fixed time zone, 6 hours behind UTC, for the suite and both hooks: 22:00 yesterday here is 04:00 today in UTC,
# so a check of the day of a change tells the local date from the UTC one.
export TZ=CST6
tmp="$(mktemp -d)" && [ -d "$tmp" ] || { echo "mktemp failed" >&2; exit 1; }; trap 'rm -rf "$tmp"' EXIT
H="$tmp/home"; B="$H/LLMBrain"; KIT="$tmp/kit"; C="$B/wiki/workblocks"; T="$tmp/transcript.jsonl"; S="$H/.cache/pergamino/wiki-lint"
mkdir -p "$KIT"
# macOS date first, then GNU date.
ago() { date -v-"$1"d +%F 2>/dev/null || date -d "$1 days ago" +%F; }              # ago <days>: a local date
at_utc() {  # at_utc <days ago> <hour>: that local time, as a UTC transcript timestamp
  local s
  s=$(date -j -v-"$1"d -v"$2"H -v0M -v0S +%s 2>/dev/null) || s=$(date -d "$(ago "$1") $2:00:00" +%s)
  date -u -r "$s" +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u -d "@$s" +%Y-%m-%dT%H:%M:%S.000Z
}
today=$(date +%F); yesterday=$(ago 1); daybefore=$(ago 2); n=0
now=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)   # a transcript timestamp
late=$(at_utc 1 22)                      # 22:00 yesterday, in UTC
early=$(at_utc 2 10)                     # 10:00 the day before
mkdir -p "$tmp/bin"   # a date that says it is yesterday, for a wiki-lint run "before midnight"
printf '#!/bin/sh\n[ "$*" = "+%%F" ] && { echo %s; exit 0; }\nexec /bin/date "$@"\n' "$yesterday" > "$tmp/bin/date"
chmod +x "$tmp/bin/date"
fresh() {  # a vault with cards a, b and README (timeline entries from 2025 only), no state, an empty transcript
  local c; rm -rf "$H"; mkdir -p "$C"; : > "$T"
  for c in a b README; do printf -- '---\ntitle: %s\n---\n## Timeline\n- 2025-01-01: [source: test] x\n' "$c" > "$C/$c.md"; done
}
edited() {  # edited <card> [timestamp | none]: an Edit of the card in the main transcript (default: now; the file is not changed)
  jq -cn --arg p "$C/$1.md" --arg ts "${2:-$now}" \
    '{type: "assistant", timestamp: $ts, message: {content: [{type: "tool_use", name: "Edit", input: {file_path: $p}}]}}
     | if $ts == "none" then del(.timestamp) else . end' >> "$T"
}
said() {  # said <timestamp>: a transcript line that is not a tool call (a prompt), at that time
  jq -cn --arg ts "$1" '{type: "user", timestamp: $ts, message: {role: "user", content: "x"}}' >> "$T"
}
lint() {  # lint <event> <tool> <call id> <session> [file_path]: one wiki-lint.sh run (PATH from $LINT_PATH)
  jq -cn --arg e "$1" --arg t "$2" --arg u "$3" --arg s "$4" --arg p "${5:-}" \
    '{hook_event_name: $e, tool_name: $t, tool_use_id: $u, session_id: $s, tool_input: {file_path: $p}}' |
    env -i HOME="$H" PATH="${LINT_PATH:-/usr/bin:/bin}" TZ="$TZ" PERGAMINO_HOME="$KIT" PERGAMINO_LLM_BRAIN="$B" "$SH" "$LINT" >/dev/null 2>&1
}
shell() {  # shell <card> <line> [session]: a Bash call in that session (default s1) appends <line> to the card
  n=$((n + 1)); lint PreToolUse Bash "c$n" "${3:-s1}"; echo "$2" >> "$C/$1.md"; lint PostToolUse Bash "c$n" "${3:-s1}"
}
stop() {  # stop [stop_hook_active]: the guard at the end of a reply in session s1; output in $out, exit code in $rc
  out=$(jq -cn --arg t "$T" --argjson a "${1:-false}" \
    '{hook_event_name: "Stop", session_id: "s1", transcript_path: $t, stop_hook_active: $a}' |
    env -i HOME="$H" PATH=/usr/bin:/bin TZ="$TZ" "$SH" "$GUARD" 2>/dev/null)
  rc=$?
}
blocks() { [[ $rc == 0 && $(jq -r .decision <<<"$out" 2>/dev/null) == block && $out == *"$C/$1.md"* ]]; }   # blocks <card>
silent() { [[ $rc == 0 && -z "$out" ]]; }

fresh; edited a; stop; blocks a; check "a card edited with Edit, no entry dated today: blocks" $?
fresh; edited a; echo "- $today: [source: test] y" >> "$C/a.md"; stop; silent
check "a card edited with Edit and given an entry dated today: silent" $?
fresh; edited a; stop true; silent; check "stop_hook_active: never blocks a second time" $?
fresh; stop; silent; check "no card changed: silent" $?

fresh; shell a "more"; stop; blocks a; check "a card changed through the shell, no entry dated today: blocks" $?
fresh; shell a "- $today: [source: test] y"; stop; silent; check "a card the shell gave an entry dated today: silent" $?
fresh; shell a "more" s2; stop; silent; check "another session's shell change: silent" $?
# A card on the shell list leaves it once it is named, so a card that a sync program or another session changed
# during a shell command blocks one reply, not every reply for the rest of the session.
fresh; shell a "more"; stop; blocks a && { stop; silent; }; check "a card from the shell list is named once; the next reply is silent" $?
fresh; shell a "more"; stop; stop; shell a "again"; stop; blocks a; check "a card the shell changes again is named again" $?
fresh; edited a; stop; stop; blocks a; check "a card the session edited with Edit stays named until it has an entry" $?
fresh; lint PostToolUse Edit c0 s1 "$C/b.md"; stop; blocks b
check "a card a subagent edited (its calls are not in the main transcript): blocks" $?
fresh; shell README "more"; stop; silent; check "the workblocks README is not a card: silent" $?
fresh; mkdir -p "$C/archive"; cp "$C/a.md" "$C/archive/a-2025.md"; shell archive/a-2025 "more"
lint PostToolUse Write c0 s1 "$C/archive/a-2025.md"; edited archive/a-2025; stop; silent
check "an archive file (workblocks/archive/, off the kanban) is not a card: silent" $?
fresh; shell a "more"; rm "$C/a.md"; stop; silent; check "a card deleted since: silent" $?
fresh; edited a; shell a "more"; shell b "more"; stop; blocks a && blocks b && [[ $(grep -oF "$C/a.md" <<<"$out" | wc -l) -eq 1 ]]
check "a card in both the transcript and the list is named once" $?

# The day of each card's own last change, not today: cards edited before midnight are not blocked again after it.
fresh; edited a "$late"; echo "- $yesterday: [source: test] y" >> "$C/a.md"; stop; silent
check "a card edited at 22:00 yesterday (04:00 today in UTC) with an entry dated yesterday: silent" $?
fresh; edited a "$late"; stop; blocks a && [[ $out == *"$yesterday"* ]]
check "a card edited yesterday without an entry: blocks, and gives the day of the edit" $?
fresh; edited a "$late"; edited a; echo "- $yesterday: [source: test] y" >> "$C/a.md"; stop; blocks a
check "a card edited yesterday and again today, with an entry dated yesterday only: blocks" $?
fresh; n=$((n + 1)); lint PreToolUse Bash "c$n" s1; echo more >> "$C/a.md"; LINT_PATH="$tmp/bin:/usr/bin:/bin" lint PostToolUse Bash "c$n" s1
echo "- $yesterday: [source: test] y" >> "$C/a.md"; stop; silent
check "a card changed through the shell yesterday (wiki-lint keeps the day) with an entry dated yesterday: silent" $?
fresh; edited a; echo "- 2099-01-01: [source: test] planned" >> "$C/a.md"; stop; blocks a
check "an entry dated after today does not count" $?
# A call line without a usable timestamp takes the day of the newest timestamp before it in the transcript (lines
# that are not calls count too), and today only when there is none.
fresh; said "$late"; edited a none; said "$now"; echo "- $yesterday: [source: test] y" >> "$C/a.md"; stop; silent
check "an Edit line without a timestamp, after a line at 22:00 yesterday and before one today: yesterday's entry is enough" $?
fresh; edited a none; said "$late"; echo "- $yesterday: [source: test] y" >> "$C/a.md"; stop; blocks a
check "an Edit line without a timestamp and no timestamp before it: today, whatever comes after it" $?
fresh; said "$early"; said "$late"; edited a none; echo "- $daybefore: [source: test] y" >> "$C/a.md"; stop; blocks a
check "an Edit line without a timestamp takes the newest day before it (yesterday), not an older one" $?
fresh; mkdir -p "$S"; echo "$C/a.md" > "$S/s1.cards"; stop; blocks a && { stop; silent; }
check "a list from before the date field (a path per line): its card is named once, as before" $?

# The guard must not rewrite the list (with grep -v and mv, a line that a background subagent appended between the
# read and the mv was lost); and a card that only a subagent changed with Edit or Write stays named until it has an entry.
fresh; shell a "more"; shell b "more"; list="$S/s1.cards"; lines=$(cat "$list"); inode=$(ls -i "$list" | awk '{ print $1 }')
stop; blocks a && [[ $(ls -i "$list" | awk '{ print $1 }') == "$inode" && "$(cat "$list")" == "$lines" ]]
check "a stop never rewrites the session's list (same file, every line kept), so no subagent's line is lost" $?
fresh; lint PostToolUse Write c0 s1 "$C/b.md"; stop; blocks b && { stop; blocks b; } && { echo "- $today: [source: test] y" >> "$C/b.md"; stop; silent; }
check "a card a subagent changed with Edit or Write stays named until it has an entry" $?

fresh; mkdir -p "$S"; echo "$C/a.md" > "$S/old.cards"; touch -t 202501010000 "$S/old.cards"; echo "$C/b.md" > "$S/new.cards"
stop; [[ ! -e "$S/old.cards" && -e "$S/new.cards" ]]; check "state untouched for more than 7 days is deleted; newer state stays" $?
fresh; out=$(printf 'not json' | env -i HOME="$H" PATH=/usr/bin:/bin "$SH" "$GUARD" 2>/dev/null); rc=$?; silent
check "input that is not JSON: silent, exit 0" $?

echo
if [[ $fails -eq 0 ]]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
exit $(( fails > 0 ? 1 : 0 ))
