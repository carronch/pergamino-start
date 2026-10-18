#!/usr/bin/env bash
# PreToolUse(Bash) guard: block obviously destructive shell patterns.
# rm -rf on home or root, fork bombs, a download piped into a shell, force-push to protected
# branches, a hard git reset, dd to a device file, chmod -R 777 on home or root.
# Run it through run-guard.sh. Tests: hooks/hooks.test.sh.
set -euo pipefail

cmd=$(jq -r '.tool_input.command // ""')

block() {
  echo "Blocked by destructive-guard: $1" >&2
  exit 2
}

# Normalize whitespace for matching.
norm=$(echo "$cmd" | tr -s '[:space:]' ' ')

# rm -rf on dangerous roots
if [[ "$norm" =~ rm[[:space:]]+-[rRf]+[[:space:]]+(/|/\*|~|\$HOME|\$\{HOME\})($|[[:space:]]) ]]; then
  block "rm -rf on / or \$HOME. Refuse, and confirm with the author."
fi

# Fork bomb pattern
if [[ "$norm" =~ :\(\)\{[[:space:]]*: ]] || [[ "$norm" =~ \(\)\{\ :\|: ]]; then
  block "fork-bomb pattern detected"
fi

# curl/wget piped to shell
if [[ "$norm" =~ (curl|wget).*\|[[:space:]]*(sh|bash|zsh|fish)([[:space:]]|$) ]]; then
  block "a download piped into a shell. Refuse untrusted code execution: download, read, then run."
fi

# Force push to protected branches. No \b here: bash's regular expressions on macOS do not
# support it, and with it a force-push to main passed.
if [[ "$norm" =~ git[[:space:]]+push.*(--force|-f)[[:space:]](.*[^[:alnum:]_-])?(main|master|production|prod|release)([^[:alnum:]_-]|$) ]]; then
  block "force-push to a protected branch. Confirm with the author first."
fi

# A hard git reset (allowed only with the author's explicit go)
if [[ "$norm" =~ git[[:space:]]+reset[[:space:]]+--hard ]]; then
  echo "A hard git reset is destructive. Confirm with the author before you continue: there may be work in progress that it deletes." >&2
  exit 2
fi

# dd of=/dev/...
if [[ "$norm" =~ dd[[:space:]]+.*of=/dev/ ]]; then
  block "dd to a device file. Refuse."
fi

# chmod -R 777 on broad paths
if [[ "$norm" =~ chmod[[:space:]]+-R[[:space:]]+777[[:space:]]+(/|~|\$HOME) ]]; then
  block "chmod -R 777 on home or root"
fi

exit 0
