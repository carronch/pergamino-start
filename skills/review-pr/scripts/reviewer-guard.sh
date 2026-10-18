#!/bin/bash
# Renders the /review-pr read guard (../reviewer-guard.txt) for the machine that runs it, into
# the reviewer's temporary folder (<RV> in SKILL.md § Review, step 5):
#   codex-filesystem.toml  the filesystem table of the reviewers' Codex permission profile,
#                          one TOML inline table: {"<home>/Documents" = "deny", ...}
#   claude-settings.json   Claude Code's --settings: its sandbox on, the paths in denyRead
# The rules come from three places, in this order:
#   1. ../reviewer-guard.txt, the tracked list;
#   2. the kit's own folders: $PERGAMINO_MAIN_BRAIN, $PERGAMINO_LLM_BRAIN and $PERGAMINO_HOME,
#      each from the environment or else from the kit's pergamino.local.env (read as text,
#      never run; PERGAMINO_ENV_FILE names another file, and an empty value names none). A
#      value that does not exist on disk adds no rule; a value that is not an absolute path
#      (after ~/ or $HOME/) stops the script;
#   3. the kit's reviewer-guard.local.txt, the user's own list in the same format, not
#      tracked (REVIEWER_GUARD_LOCAL names another file, and an empty value names none).
# The kit folder is three levels above this script (skills/review-pr/scripts).
# Each path is written as the sandbox sees it: ~/ becomes this user's home folder and links
# are resolved (/tmp becomes /private/tmp), so the same list works on every machine. A * rule
# also gets a rule for the target of each link that it matches when the script runs. In
# Codex's sandbox a * rule refuses each name that it matches, but not the files in a matched
# folder, so the Codex table also gets the rule with /** added (Claude Code's sandbox refuses
# those files already; tested 2026-10-15).
# The folder must lie outside /tmp, $TMPDIR and /var/folders: Codex's commands can write there, so make it with mktemp -d ~/.cache/review-pr.XXXXXX (SKILL.md, step 3).
# Then it checks both reviewers. `codex sandbox` must start with the profile and write a file
# in the folder: it cannot start in a shell that is itself in a sandbox (then no reviewer can
# sandbox its commands), and a profile it cannot apply falls back to read-only. It runs with
# CODEX_HOME set to an empty folder: `codex sandbox` has no --ignore-user-config (codex-cli
# 0.162.1), and it reads $CODEX_HOME/config.toml, whose permissions tables merge into the
# profile. So the check, like the review, runs without this Mac's Codex settings. `claude ...
# sandbox status` must report the sandbox on, in strict mode: Claude Code ignores a settings
# file it cannot read, and then runs with no sandbox. That status does not show the read
# list, so the denyRead entries themselves are proven only by live runs (PURPOSE.md).
# Usage: reviewer-guard.sh <folder>. Exit 0: the files written and checked. Exit 1: the
# reason on stderr and none of the files left in the folder; stop the review. Bash 3.2.
set -u

out=""
die() {
  if [ -n "$out" ]; then
    rm -f "$out/codex-filesystem.toml" "$out/claude-settings.json" "$out/.reviewer-guard-probe"
    rm -rf "$out/.reviewer-guard-codex-home"
  fi
  printf 'reviewer-guard: %s\n' "$1" >&2
  exit 1
}

# Prints $1 as the sandbox sees it: a link at the end is followed, then the longest folder
# that exists is resolved with pwd -P. From the first part with a *, the rest stays as written.
resolve() {
  local p=$1 d rest="" t n=0
  case "$p" in
    *'*'*) d=${p%%\**}; d=${d%/*}; rest=${p#"$d"}; [ -n "$d" ] || d=/ ;;  # /Vol*: d is /
    *)
      while [ -L "$p" ] && [ "$n" -lt 40 ]; do
        t=$(readlink "$p") || break
        case "$t" in /*) p=$t ;; *) p="${p%/*}/$t" ;; esac
        n=$((n + 1))
      done
      d=$p ;;
  esac
  while [ ! -d "$d" ]; do rest="/${d##*/}$rest"; d=${d%/*}; [ -n "$d" ] || d=/; done
  d=$(cd "$d" && pwd -P) || return 1
  [ "$d" != / ] || d=""
  printf '%s%s\n' "$d" "$rest"
}

[ $# -eq 1 ] || die "usage: reviewer-guard.sh <folder>"
out=$(cd "$1" 2>/dev/null && pwd -P) || { out=""; die "no folder: $1"; }
# Codex's sandbox lets commands write in /tmp, $TMPDIR and /var/folders: there, one reviewer
# could rewrite another's report, the prompt or these files.
tmpd=$(cd "${TMPDIR:-/tmp}" 2>/dev/null && pwd -P) || tmpd=""
for w in /private/tmp /private/var/folders ${tmpd:+"$tmpd"}; do
  case "$out/" in "$w"/*) die "the reviewer's folder $out lies under $w, where a reviewer's commands can write: make it with mktemp -d ~/.cache/review-pr.XXXXXX" ;; esac
done
list="$(cd "$(dirname "$0")/.." && pwd -P)/reviewer-guard.txt" || die "cannot find the skill folder"
[ -r "$list" ] || die "cannot read $list"
kit=$(cd "$(dirname "$0")/../../.." && pwd -P) || die "cannot find the kit folder"
envfile=${PERGAMINO_ENV_FILE-"$kit/pergamino.local.env"}
local_list=${REVIEWER_GUARD_LOCAL-"$kit/reviewer-guard.local.txt"}
home=$(cd "${HOME:?}" 2>/dev/null && pwd -P) || die "cannot open the home folder: ${HOME:-}"
[ "$home" != / ] || die "the home folder is /"

NL='
'
toml="" json="" seen="" n=0 ln=0
# Adds one rule: path as the sandbox sees it, list line number, the line as written.
add_rule() {
  [ -n "$1" ] || die "line $2: $3 resolves to /"
  # A rule over the reviewer's own folder would hide the copy from the reviewer. The
  # pattern is unquoted on purpose, so that a * in the rule matches. In a case pattern a *
  # also matches a /, which the sandboxes' * does not: this check refuses more, never less.
  case "$out/" in $1/*) die "line $2: $1 holds the reviewer's folder $out" ;; esac
  case "$NL$seen" in *"$NL$1$NL"*) return 0 ;; esac
  seen="$seen$1$NL"
  toml="$toml${toml:+, }\"$1\" = \"deny\""
  case "$1" in *'*'*) toml="$toml, \"$1/**\" = \"deny\"" ;; esac  # the files in a matched folder
  json="$json${json:+,}
        \"$1\""
  n=$((n + 1))
}
# Reads one list file: $1 the file, $2 its name in messages.
read_list() {
local src=$1 name=$2
ln=0
while IFS= read -r line || [ -n "$line" ]; do
  ln=$((ln + 1))
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  case "$line" in '' | '#'*) continue ;; esac
  case "$line" in
    '~/'?*) path="$home/${line:2}" ;;
    /?*) path=$line ;;
    *) die "$name line $ln: a path starts with ~/ or /: $line" ;;
  esac
  case "$path" in *'"'* | *'\'* | *'?'* | *'['*) die "$name line $ln: a path with \", \\, ? or [ is not supported: $line" ;; esac
  path=$(resolve "${path%/}") || die "$name line $ln: cannot resolve $line"
  add_rule "$path" "$ln" "$line"
  # A * rule matches link names, but the sandbox checks where a link leads: each match
  # that is a link today also gets a rule for its target.
  case "$path" in *'*'*)
    shopt -s dotglob; oldifs=$IFS; IFS=$NL
    for m in $path; do
      [ -L "$m" ] || continue
      t=$(resolve "$m") || die "$name line $ln: cannot resolve the link $m"
      add_rule "$t" "$ln" "$line (the link $m)"
    done
    IFS=$oldifs; shopt -u dotglob ;;
  esac
done < "$src"
}
read_list "$list" reviewer-guard.txt
[ "$n" -gt 0 ] || die "no paths in $list"

# The kit's own folders. A value comes from the environment, else from the env file, read as
# text: the last line NAME=value or export NAME=value, with one pair of quotes removed.
kit_value() {
  local v
  v=$(printenv "$1" 2>/dev/null) || v=""
  if [ -z "$v" ] && [ -n "$envfile" ] && [ -r "$envfile" ]; then
    v=$(sed -n "s/^[[:space:]]*\(export[[:space:]][[:space:]]*\)\{0,1\}$1=//p" "$envfile" | tail -n 1)
    v="${v%"${v##*[![:space:]]}"}"
    case "$v" in \"*\" | \'*\') v=${v:1:${#v}-2} ;; esac
  fi
  case "$v" in
    '~') v=$home ;; '~/'*) v="$home/${v:2}" ;;
    '$HOME') v=$home ;; '$HOME/'*) v="$home/${v:6}" ;;
    '${HOME}') v=$home ;; '${HOME}/'*) v="$home/${v:8}" ;;
  esac
  printf '%s' "$v"
}
for var in PERGAMINO_MAIN_BRAIN PERGAMINO_LLM_BRAIN PERGAMINO_HOME; do
  v=$(kit_value "$var")
  [ -n "$v" ] || continue
  case "$v" in /*) ;; *) die "$var is not an absolute path: $v" ;; esac
  case "$v" in *'"'* | *'\'* | *'?'* | *'['* | *'*'*) die "$var: a path with \", \\, ?, [ or * is not supported: $v" ;; esac
  [ -e "$v" ] || continue
  path=$(resolve "${v%/}") || die "cannot resolve $var: $v"
  add_rule "$path" 0 "$var"
done
if [ -n "$local_list" ] && [ -e "$local_list" ]; then
  [ -r "$local_list" ] || die "cannot read $local_list"
  read_list "$local_list" reviewer-guard.local.txt
fi

printf '{%s}\n' "$toml" > "$out/codex-filesystem.toml" || die "cannot write $out/codex-filesystem.toml"
cat > "$out/claude-settings.json" <<EOF || die "cannot write $out/claude-settings.json"
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "allowUnsandboxedCommands": false,
    "filesystem": {
      "denyRead": [$json
      ]
    }
  }
}
EOF

command -v codex >/dev/null 2>&1 || die "codex is not installed"
ch="$out/.reviewer-guard-codex-home"  # empty: no config.toml, as with --ignore-user-config
rm -rf "$ch" && mkdir "$ch" || die "cannot make $ch"
if ! msg=$(cd "$out" && CODEX_HOME="$ch" codex sandbox -C "$out" -P review_pr \
    -c 'permissions.review_pr.extends=":workspace"' \
    -c "permissions.review_pr.filesystem=$(cat "$out/codex-filesystem.toml")" \
    -- /bin/sh -c 'echo probe > .reviewer-guard-probe && rm .reviewer-guard-probe' 2>&1); then
  case "$msg" in
    *sandbox_apply*) die "this shell runs in a sandbox, and macOS refuses a sandbox inside one, so no reviewer could sandbox its commands: run the review from a shell outside any sandbox" ;;
    *"Operation not permitted"* | *read-only*) die "codex's sandbox with this profile cannot write in the reviewer's folder (a read-only fallback): ${msg:-no message}" ;;
    *) die "codex does not start its sandbox with this profile: ${msg:-no message}" ;;
  esac
fi
rm -f "$out/.reviewer-guard-probe"
rm -rf "$ch"
command -v claude >/dev/null 2>&1 || die "claude is not installed"
st=$(claude --setting-sources "" --settings "$out/claude-settings.json" sandbox status 2>&1)
case "$st" in *'"enabled":true'*) ;; *) die "Claude Code does not turn its sandbox on with claude-settings.json: $st" ;; esac
case "$st" in *'"strictMode":true'*) ;; *) die "Claude Code's sandbox is not in strict mode with claude-settings.json: $st" ;; esac
printf 'reviewer-guard: %s paths denied, for %s; wrote codex-filesystem.toml and claude-settings.json in %s. Codex starts its sandbox with the profile, without this machine'"'"'s Codex settings, and writes in the folder; Claude Code reports its sandbox on and strict (its status does not show the read list)\n' "$n" "$home" "$out"
