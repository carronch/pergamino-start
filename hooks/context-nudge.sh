#!/usr/bin/env bash
# Hook: on UserPromptSubmit, measure the conversation's context size. Above a threshold,
# ask the agent to find a natural break and to suggest a manual /compact to the author.
#
# Why: automatic compaction drops detail at a random moment. A compaction the author starts at a
# natural break, with a one-line focus, keeps more of what matters.
# Advisory only: it never blocks, never compacts, and fails open (any error: no output, exit 0).
# Claude Code's own auto-compaction stays as the safety net near the window's limit.
#
# Context size = the last main-thread assistant message's input + cache-creation + cache-read
# tokens, read from the session transcript. First nudge at CONTEXT_NUDGE_AT (default 500000),
# then again every CONTEXT_NUDGE_STEP tokens above the last nudge (default 150000). When the
# context falls below the threshold or below the last nudge (a /compact), the count starts over,
# so the next climb past the threshold nudges again.
# State: one file per session in CONTEXT_NUDGE_STATE_DIR (default ~/.claude/state/context-nudge).
# Works under macOS's bash 3.2. Tests: hooks/context-nudge.test.sh.
set -u

input=$(cat 2>/dev/null) || exit 0
tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null) || exit 0
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
[ -n "$tp" ] && [ -f "$tp" ] || exit 0

at=${CONTEXT_NUDGE_AT:-500000}
step=${CONTEXT_NUDGE_STEP:-150000}
case "$at" in ''|*[!0-9]*) exit 0 ;; esac
case "$step" in ''|*[!0-9]*) step=150000 ;; esac
[ "$step" -ge 1 ] || step=150000

# The last main-thread usage line; subagent (sidechain) lines are skipped. 3,000 lines leave
# room for long runs of sidechain lines after the last main-thread reply.
tokens=$(tail -n 3000 "$tp" 2>/dev/null \
  | jq -r 'select(.type == "assistant" and ((.isSidechain // false) | not))
           | .message.usage // empty
           | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))' 2>/dev/null \
  | tail -n 1)
case "$tokens" in ''|*[!0-9]*) exit 0 ;; esac

home=${HOME:-}
dir=${CONTEXT_NUDGE_STATE_DIR:-}
if [ -z "$dir" ]; then [ -n "$home" ] || exit 0; dir="$home/.claude/state/context-nudge"; fi
key=${sid:-$(basename "$tp" .jsonl)}
key=$(printf '%s' "$key" | tr -cd 'A-Za-z0-9._-')
[ -n "$key" ] || exit 0
state="$dir/$key"
last=$(cat "$state" 2>/dev/null || true)
case "$last" in ''|*[!0-9]*) last=0 ;; esac

# Below the threshold, or below the last nudge (a /compact happened): start over.
if [ "$tokens" -lt "$at" ]; then
  [ "$last" -eq 0 ] || rm -f "$state" 2>/dev/null
  exit 0
fi
if [ "$last" -gt 0 ] && [ "$tokens" -lt "$last" ]; then last=0; fi

# The first nudge at the threshold; after that, one more each time the context grows by a step.
if [ "$last" -eq 0 ]; then due=$at; else due=$((last + step)); fi
[ "$tokens" -ge "$due" ] || exit 0

k=$((tokens / 1000))
msg="Context check: this conversation is at about ${k}k tokens (the nudge starts at $((at / 1000))k). The author compacts by hand at a natural break, never automatically. At the next natural break (when the current step is done, not in the middle of a task), first save the session's state where your rules say (for work in the LLM brain: the timeline of the active card in wiki/workblocks/; in a repository: tasks/todo.md). Then tell the author in one short line that this is a good moment to run /compact, and suggest the one-line focus to pass to it. Do not stop the current task for this, and do not repeat it in later replies."
out=$(jq -n --arg c "$msg" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $c}}' 2>/dev/null) || exit 0
[ -n "$out" ] || exit 0

# Record the nudge only once the message exists, so a failure never silences a step.
mkdir -p "$dir" 2>/dev/null && printf '%s\n' "$tokens" > "$state" 2>/dev/null
printf '%s\n' "$out"
exit 0
