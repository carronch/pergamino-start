#!/usr/bin/env bash
# PreToolUse(Edit|Write) guard: block direct edits of lock files.
# Lock files change through the package manager only. Also reads the file paths out of Codex's
# apply_patch, which sends a patch instead of a file_path. Fails closed: an unexpected error, or a
# patch with no readable file path, exits 2 (block).
# Run it through run-guard.sh. Tests: hooks/hooks.test.sh.
set -euo pipefail
trap 'rc=$?; if [[ $rc -ne 0 && $rc -ne 2 ]]; then echo "block-lockfile-edits: internal error (exit $rc); blocking to fail closed." >&2; exit 2; fi' EXIT

input=$(cat)
tool=$(jq -r '.tool_name // ""' <<<"$input")
patch=""
if [[ "$tool" == apply_patch ]]; then
  patch=$(jq -r '.tool_input.command // .tool_input.patch // .tool_input.input // "" | if type == "array" then join("\n") else tostring end' <<<"$input")
else
  patch=$(jq -r 'if (.tool_input | type) == "object" then (.tool_input.command // "") else "" end | if type == "string" then . else "" end' <<<"$input")
  [[ "$patch" == *"*** Begin Patch"* ]] || patch=""
fi

if [[ "$tool" == apply_patch || -n "$patch" ]]; then
  paths=$(printf '%s\n' "$patch" | sed -n -E 's/^\*\*\* (Add|Update|Delete) File:[[:space:]]*(.*)$/\2/p; s/^\*\*\* Move to:[[:space:]]*(.*)$/\1/p' | sed -E 's/[[:space:]]+$//')
  if [[ -z "$paths" ]]; then
    echo "Blocked: no file path could be read from the patch." >&2
    exit 2
  fi
else
  paths=$(jq -r '.tool_input.file_path // ""' <<<"$input")
fi

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  base="${path##*/}"
  case "$base" in
    package-lock.json|yarn.lock|pnpm-lock.yaml|Cargo.lock|poetry.lock|Pipfile.lock|Gemfile.lock|composer.lock|uv.lock|bun.lockb|bun.lock)
      echo "Blocked: $base is a lock file. Lock files change only through the package manager (for example pnpm install, npm install or cargo update). Do not edit them directly." >&2
      exit 2
      ;;
  esac
done <<<"$paths"
exit 0
