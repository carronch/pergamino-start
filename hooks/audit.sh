#!/usr/bin/env bash
# PostToolUse(*) hook, optional (off by default): append one JSON line per tool call to ~/.claude/audit/YYYY-MM-DD.jsonl.
# Keeps a fixed list of metadata fields plus the tool input; every other field is
# dropped, so a host that renames its output field cannot leak output. Never the
# tool's output itself, only its size: output_chars = characters for a string
# output, length of the JSON text for any other value. Write content and Edit
# strings are stored as lengths. Every string is cut at 300 characters, and
# common secret formats (cloud keys, tokens, bearer headers, private keys,
# passwords in URLs) are redacted first. Files are owner-only (umask 077) and
# kept 30 days: pruned when a new day's file starts. Never blocks a tool call:
# on any failure the line is dropped and the hook still exits 0.
# Payloads from Claude Code (tool_response) and Cursor (tool_output) both handled.
# Tests: hooks/hooks.test.sh
set -uo pipefail
umask 077

dir="$HOME/.claude/audit"
mkdir -p "$dir" 2>/dev/null || exit 0
file="$dir/$(date -u +%Y-%m-%d).jsonl"
if [ ! -e "$file" ]; then
  find "$dir" -maxdepth 1 -name '*.jsonl' -type f -mtime +29 -delete 2>/dev/null
fi

prog=$(cat <<'JQ'
def redact:
  gsub("\\b(AKIA|ASIA)[A-Z0-9]{16}\\b"; "[redacted]")
  | gsub("(?<p>aws_secret_access_key[\"']?\\s*[:=]\\s*[\"']?)[A-Za-z0-9/+=]{40}"; "\(.p)[redacted]"; "i")
  | gsub("\\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}\\b"; "[redacted]")
  | gsub("\\bgithub_pat_[A-Za-z0-9_]{22,}"; "[redacted]")
  | gsub("\\b(sk|rk)_(live|test)_[A-Za-z0-9]{16,}"; "[redacted]")
  | gsub("\\bsk-[A-Za-z0-9_-]{20,}"; "[redacted]")
  | gsub("\\bxox[abprs]-[A-Za-z0-9-]{10,}"; "[redacted]")
  | gsub("(?<p>authorization[\"']?\\s*[:=]\\s*[\"']?((bearer|basic|token)\\s+)?)[A-Za-z0-9._~+/=-]{8,}"; "\(.p)[redacted]"; "i")
  | gsub("(?<p>\\bbearer\\s+)[A-Za-z0-9._~+/=-]{16,}"; "\(.p)[redacted]"; "i")
  | gsub("-----BEGIN [A-Z ]*PRIVATE KEY-----[\\s\\S]*?(-----END [A-Z ]*PRIVATE KEY-----|\\z)"; "[redacted private key]")
  | gsub("(?<p>://)[^/\\s:@]+:[^/\\s@]+@"; "\(.p)[redacted]@");
def cut:
  if type == "string" then
    length as $n
    | (.[0:2000] | redact) as $s
    | if $n > 300 then ($s | .[0:300]) + "…[+\($n - 300) chars]" else $s end
  else . end;
def lengths_only:
  if type == "object" then
    with_entries(
      if (.key | IN("content", "old_string", "new_string", "new_source")) and (.value | type) == "string"
      then .value = "[\(.value | length) chars]"
      else .value |= lengths_only end)
  elif type == "array" then map(lengths_only)
  else . end;
([.tool_response, .tool_output, .toolResult] | map(select(. != null)) | .[0]) as $out
| (.tool_input // .toolInput) as $in
| with_entries(select(.key | IN(
    "session_id", "transcript_path", "cwd", "hook_event_name", "tool_name",
    "tool_use_id", "permission_mode", "prompt_id", "duration_ms", "effort",
    "agent_type", "agent_id", "mcp_server", "conversation_id", "generation_id",
    "model", "cursor_version", "workspace_roots", "duration", "user_email")))
| . + {
    ts: $ts,
    tool_input: ($in | lengths_only),
    output_chars: (if $out == null then null
                   elif ($out | type) == "string" then ($out | length)
                   else ($out | tojson | length) end)
  }
| walk(cut)
JQ
)

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -c --arg ts "$ts" "$prog" >> "$file" 2>/dev/null || true
exit 0
