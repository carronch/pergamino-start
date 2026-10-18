#!/usr/bin/env bash
# Resolve the kit's three paths. Hooks and scripts source this file:
#
#   . "$(dirname "$0")/lib/paths.sh"            # from hooks/
#   . "$(dirname "$0")/../hooks/lib/paths.sh"   # from scripts/
#
# It sets and exports:
#   PERGAMINO_HOME        the kit root. From the environment, else the folder above hooks/.
#   PERGAMINO_MAIN_BRAIN  the Main brain (the author's own notes; read only for agents).
#   PERGAMINO_LLM_BRAIN   the LLM brain (the agent's curated layer).
#
# Each brain path comes from the environment first. A value that the environment does not set
# comes from "$PERGAMINO_HOME/pergamino.local.env" (written by install.sh, never committed).
# That file is parsed, not sourced: only KEY=value lines for the two brain keys count, with an
# optional "export " in front and optional quotes around the value. A leading ~/ and $HOME or
# ${HOME} are expanded. Nothing else is expanded and nothing in the file runs.
# A trailing slash is removed. A path that is not set stays empty: callers decide what to do.
#
# Run it directly to print the three values as shell assignments:
#   bash hooks/lib/paths.sh
# Works under macOS /bin/bash 3.2. Never exits the shell that sources it.

_pergamino_lib_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)
if [ -z "${PERGAMINO_HOME:-}" ]; then
  PERGAMINO_HOME=$(cd "$_pergamino_lib_dir/../.." 2>/dev/null && pwd -P)
fi
PERGAMINO_HOME=${PERGAMINO_HOME%/}

_pergamino_expand() {  # _pergamino_expand <value>: quotes removed, ~/ and $HOME expanded, trailing / removed
  local v="$1"
  v=${v%$'\r'}
  # Trim surrounding blanks.
  v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
  case "$v" in
    \"*\") v=${v#\"}; v=${v%\"} ;;
    \'*\') v=${v#\'}; v=${v%\'} ;;
  esac
  case "$v" in
    "~") v="${HOME:-}" ;;
    "~/"*) v="${HOME:-}/${v#\~/}" ;;
  esac
  v=${v//\$\{HOME\}/${HOME:-}}
  v=${v//\$HOME/${HOME:-}}
  [ "$v" = "/" ] || v=${v%/}
  printf '%s' "$v"
}

_pergamino_read_env() {  # _pergamino_read_env <file>: fills each brain key the environment left unset
  local file="$1" line key val
  [ -f "$file" ] && [ -r "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?(PERGAMINO_MAIN_BRAIN|PERGAMINO_LLM_BRAIN)[[:space:]]*=(.*)$ ]] || continue
    key=${BASH_REMATCH[2]}
    val=${BASH_REMATCH[3]}
    case "$key" in
      PERGAMINO_MAIN_BRAIN) [ -n "${PERGAMINO_MAIN_BRAIN:-}" ] || PERGAMINO_MAIN_BRAIN=$(_pergamino_expand "$val") ;;
      PERGAMINO_LLM_BRAIN)  [ -n "${PERGAMINO_LLM_BRAIN:-}" ]  || PERGAMINO_LLM_BRAIN=$(_pergamino_expand "$val") ;;
    esac
  done < "$file"
  return 0
}

if [ -z "${PERGAMINO_MAIN_BRAIN:-}" ] || [ -z "${PERGAMINO_LLM_BRAIN:-}" ]; then
  _pergamino_read_env "$PERGAMINO_HOME/pergamino.local.env"
fi
PERGAMINO_MAIN_BRAIN=$(_pergamino_expand "${PERGAMINO_MAIN_BRAIN:-}")
PERGAMINO_LLM_BRAIN=$(_pergamino_expand "${PERGAMINO_LLM_BRAIN:-}")
export PERGAMINO_HOME PERGAMINO_MAIN_BRAIN PERGAMINO_LLM_BRAIN
unset _pergamino_lib_dir

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  printf 'PERGAMINO_HOME=%q\nPERGAMINO_MAIN_BRAIN=%q\nPERGAMINO_LLM_BRAIN=%q\n' \
    "$PERGAMINO_HOME" "$PERGAMINO_MAIN_BRAIN" "$PERGAMINO_LLM_BRAIN"
fi
