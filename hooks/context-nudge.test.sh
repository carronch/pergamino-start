#!/usr/bin/env bash
# Test harness for hooks/context-nudge.sh (UserPromptSubmit: suggest a manual /compact above
# a context threshold). Runs only in temporary folders. HOOK_SHELL=/bin/bash runs it under
# macOS's bash 3.2.
#
# Usage: bash hooks/context-nudge.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="${HOOK:-$HERE/context-nudge.sh}"
fails=0
check() { if [[ "$2" == 0 ]]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }
run() { if [[ -n "${HOOK_SHELL:-}" ]]; then "$HOOK_SHELL" "$@"; else "$@"; fi; }

tmp="$(mktemp -d)" && [ -d "$tmp" ] || { echo "mktemp failed" >&2; exit 1; }; trap 'rm -rf "$tmp"' EXIT
export CONTEXT_NUDGE_STATE_DIR="$tmp/state"
T="$tmp/session.jsonl"

turn() {  # turn <main-thread context tokens>: append one user line and one assistant line
  printf '{"type":"user","message":{"role":"user","content":"hi"}}\n' >> "$T"
  printf '{"type":"assistant","isSidechain":false,"message":{"usage":{"input_tokens":2,"cache_creation_input_tokens":1000,"cache_read_input_tokens":%s,"output_tokens":50}}}\n' "$(($1 - 1002))" >> "$T"
}
side() {  # side <tokens>: a sidechain (subagent) assistant line, which must be ignored
  printf '{"type":"assistant","isSidechain":true,"message":{"usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":%s}}}\n' "$1" >> "$T"
}
fire() {  # fire [session] [transcript]: run the hook; additional context in $out, exit code in $rc
  printf '{"session_id":"%s","transcript_path":"%s","hook_event_name":"UserPromptSubmit","prompt":"x"}' "${1:-s1}" "${2:-$T}" \
    | run "$HOOK" > "$tmp/out.json"
  rc=$?
  out="$(jq -r '.hookSpecificOutput.additionalContext // empty' "$tmp/out.json" 2>/dev/null)"
}

: > "$T"; turn 120000; fire
[[ -z "$out" ]]; check "120k: no nudge" $?
turn 520000; fire
[[ "$out" == *"about 520k tokens"* && "$out" == *"/compact"* ]]; check "520k: first nudge, names the size and /compact" $?
turn 530000; fire
[[ -z "$out" ]]; check "530k: no repeat before the next step" $?
turn 669000; fire
[[ -z "$out" ]]; check "669k: still below 520k + 150k" $?
turn 680000; fire
[[ "$out" == *"about 680k tokens"* ]]; check "680k: second nudge, one step later" $?
fire s2
[[ "$out" == *"about 680k tokens"* ]]; check "another session id: its own first nudge" $?

: > "$T"; turn 100000; side 900000; fire s3
[[ -z "$out" ]]; check "a subagent's large context does not count" $?
: > "$T"; turn 600000; side 100; fire s4
[[ "$out" == *"about 600k tokens"* ]]; check "a later sidechain line does not hide the main thread's size" $?

fire s5 "$tmp/missing.jsonl"
[[ -z "$out" && "$rc" == 0 ]]; check "missing transcript: silent, exit 0" $?
out="$(printf 'not json' | run "$HOOK")"; rc=$?
[[ -z "$out" && "$rc" == 0 ]]; check "garbage input: silent, exit 0" $?
printf '{"type":"assistant","message":{"usage":"broken"}}\n' > "$tmp/bad.jsonl"; fire s6 "$tmp/bad.jsonl"
[[ -z "$out" && "$rc" == 0 ]]; check "malformed usage: silent, exit 0" $?

: > "$T"; turn 300000; CONTEXT_NUDGE_AT=250000 fire s7
[[ "$out" == *"about 300k tokens"* && "$out" == *"starts at 250k"* ]]; check "CONTEXT_NUDGE_AT lowers the threshold" $?
CONTEXT_NUDGE_AT=abc fire s8
[[ -z "$out" && "$rc" == 0 ]]; check "a non-numeric threshold: silent, exit 0" $?

: > "$T"; turn 700000; fire "../../evil"
ls "$tmp" | grep -q evil; [[ $? != 0 && -f "$CONTEXT_NUDGE_STATE_DIR/....evil" ]]; check "a session id cannot leave the state folder" $?

# After a /compact the context falls; the next climb past the threshold must nudge again.
: > "$T"; turn 520000; fire c1
[[ "$out" == *"about 520k tokens"* ]]; check "compact path: first nudge at 520k" $?
turn 90000; fire c1
[[ -z "$out" && ! -f "$CONTEXT_NUDGE_STATE_DIR/c1" ]]; check "compact path: below the threshold, silent, count reset" $?
turn 510000; fire c1
[[ "$out" == *"about 510k tokens"* ]]; check "compact path: climbing past 500k again nudges again" $?
: > "$T"; turn 600000; fire c2; turn 550000; fire c2
[[ "$out" == *"about 550k tokens"* ]]; check "a drop below the last nudge (still above 500k) starts over" $?

# Many subagent lines after the last main-thread reply must not hide its size.
: > "$T"; turn 600000; for i in $(seq 1 500); do side 1000; done; fire c3
[[ "$out" == *"about 600k tokens"* ]]; check "500 sidechain lines after the main reply: still found" $?

: > "$T"; turn 600000
out="$(printf '{"session_id":"h1","transcript_path":"%s"}' "$T" | env -u HOME -u CONTEXT_NUDGE_STATE_DIR "${HOOK_SHELL:-bash}" "$HOOK" 2>&1)"; rc=$?
[[ -z "$out" && "$rc" == 0 ]]; check "HOME unset and no state folder set: silent, exit 0" $?
: > "$T"; turn 600000; CONTEXT_NUDGE_STEP=0 fire z1; CONTEXT_NUDGE_STEP=0 fire z1
[[ -z "$out" ]]; check "CONTEXT_NUDGE_STEP=0 falls back to the default step (no nudge on every prompt)" $?

echo; if [[ $fails == 0 ]]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
exit $(( fails > 0 ))
