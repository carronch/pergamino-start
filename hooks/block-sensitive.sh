#!/usr/bin/env bash
# PreToolUse guard: block tool calls that read or write secret files.
# Wire it on PreToolUse(Bash) and PreToolUse(Edit|Write|Read|MultiEdit|Grep), through run-guard.sh.
#
# What it covers
# - File tools (Read, Edit, MultiEdit, Write; Grep from Claude Code and Cursor; Codex's
#   apply_patch): the path as given and its real path on disk (symlinks resolved, the name as
#   the disk stores it), in any letter case: this disk ignores case and folds look-alike
#   letters, so COOKIES.ENV opens cookies.env.
# - Shell commands (Claude Code's Bash, Cursor's Shell, Codex's Bash): the command text is
#   scanned for names of secret files whatever the quoting (python -c, node -e, file:// URLs,
#   $( ), a pipe into xargs). A named file that exists and is secret blocks the command, unless
#   every command in it only looks at names or metadata (ls, test, stat, chmod, rm, echo, find
#   without -exec, ...). An ssh key given to ssh with -i, -F or IdentityFile is allowed.
#   Here-document bodies written to files are skipped; those fed to a shell, an interpreter
#   or ssh are scanned.
# - Shell writes: a file a command writes (a > or >> redirect, also 2>name,
#   &>name, >&name and a > right after - or =; tee, also after --; the destination of cp, mv or
#   install, also before 2>&1 or an option (GNU cp a b -v), and the folder of -t DIR or
#   --target-directory[=]DIR (also shortened) with each source's name inside it; touch's
#   operands; the output option of sort -o, curl -o/-D/-c/
#   --stderr/--trace and wget -O/-o/-a, also shortened (--out=) or in a cluster (-sSLo), with
#   curl --output-dir and wget -P put in front) is checked whether it exists or not, also when
#   echo or printf is the only command and in any letter case (TOUCH, Tee). A target may be
#   part quoted ("$HOME"/.ssh/key), in $'...' (escapes such as \x2e and \056 decoded) or $"...",
#   or split by a line continuation. Brace expansion is followed: .ss{,h}/key, {g..i},
#   {0..9}, nested and several groups (also in for f in ... and cd); a form the guard does not
#   expand ({01..03}, {1..9..2}, more than 256 names) or a $'...' escape it does not decode
#   (\u, \c) blocks the target (fail closed). A variable set in the same
#   command text is filled in with every value the text gives it (f=.dev.vars; printf ... >
#   "$f"; also export/local/declare f=..., f+=..., for f in ..., and a value built from another
#   variable, f=$d/key), and ${f:-name} with its default too, whatever f holds (a false block
#   when f holds a harmless name); a variable the text does not set stays as it is, so
#   "$d"/cookies.env is still blocked by its name. After cd into a folder the command makes
#   (mkdir -p .ssh && cd .ssh, also cd -P, -L, --), writes count as inside it; a cd, pushd or
#   popd that may not run, fail or end with a subshell (its folder is missing now, no && follows
#   it, a command before it is not joined by && to the start of the text, or the text has ( `
#   or |) adds its folders to the ones before;
#   cd -P follows links on disk; popd goes back to the folder before the matching pushd; after
#   cd -, pushd -n, a popd past what the command pushed, or a pushd or popd that may not run with
#   more on the stack, a write is checked in every folder
#   the command has been in or named. The reference-file exception (below) does not apply: the
#   shell's new text cannot be checked; edit a reference file with Write or Edit.
# - Searches over a folder (grep -r, rg, find -exec or | xargs, the Grep tool): blocked when
#   the folder is or holds a protected folder (~/.ssh, ~/.aws, ~/.config/op, ...), when an
#   --include, -g or glob selects secret names, or when the search would open a secret file:
#   one that git does not ignore (grep, rg and Grep skip ignored files; find does not), that no
#   --exclude covers, and, for rg without --hidden, that is not hidden.
#
# Doors it does not close (the operating-system sandbox and fewer secrets on disk are the fixes):
# - a program that reaches a file the command never names;
# - Codex's and Cursor's plain grep -r also reads files git ignores (Claude Code's grep skips them);
# - a search started below the .gitignore that ignores a secret (grep reads it there);
# - secrets deeper than 6 folders, or inside node_modules, .git, .wrangler or .venv;
# - a name split by quotes or a backslash (~/.config/"op"/..., cred\entials.json), written with
#   $'...' escapes or braces in a command that reads it (only write targets and cd folders are
#   decoded and expanded), or built in a variable other than HOME or in code;
# - a copy made and read in one command (cp -R ~/.config /tmp/c && cat /tmp/c/...): a name is
#   checked only against files that exist when the command starts. The second command of the
#   two-step form is blocked;
# - a write to a new file through any other program or output option (dd of=, ln, rsync,
#   python open(..., "w"), curl -O and wget's names taken from the URL outside a protected
#   folder, -o of other programs); a write target that is only a variable the command text does
#   not set ("$out"); a target made by a command (> $(echo name), > `echo name`) or by another
#   ${...} form (${f%.x}, ${f/a/b}); a cd through a variable; the folder cd - or popd returns to
#   when it was set before this command (only folders this command names are checked); and -> or
#   => inside quotes, which count as text, also in bash -c "echo x ->name". The other way round,
#   a quoted text that holds ">" and then a secret name is taken as a redirect and blocked;
#   more than 64 ways to fill in the variables of one target block the command (fail closed);
#   braces are expanded also where quotes made them text in tee, touch and cp words (the guard
#   reads those words with quotes removed), and a write target over 1,024 characters that holds
#   braces blocks (fail closed);
# - a ~ in a file tool's path (Read ~/.config/./op/...): not expanded here, which matters
#   only if the host expands it.
#
# Exceptions: committed templates (.env.example, .dev.vars.example, <name>.env.example) stay
# readable and editable; an untracked copy stays blocked when opened directly, because it may
# hold real values, but it does not stop a search. An env file whose lines are all 1Password
# secret references (NAME=<the op scheme>vault/item/field), blank, or comments without "="
# holds references, not secrets: it stays readable, and Write/Edit may change it as long as it
# stays that way (apply_patch may not). The kit's own pergamino.local.env stays readable and
# editable the same way while its lines are all PERGAMINO_<NAME>=<path>, blank, or comments
# without "=".
#
# Fails closed: any unexpected error (also a temp file the shell cannot write: every read of
# the command text checks its own result; a program that fails while the text is split into
# simple commands or scanned for globs and names), a patch with no readable file path, or a
# check that runs past 5 seconds exits 2 (block) — an exit of 1 would let the tool call through.
# Written for macOS /bin/bash 3.2. Tests: hooks/hooks.test.sh
set -euo pipefail
shopt -s nocaseglob
trap 'rc=$?; if [[ $rc -ne 0 && $rc -ne 2 ]]; then echo "block-sensitive: internal error (exit $rc); blocking to fail closed." >&2; exit 2; fi' EXIT

input=$(cat)
field() { jq -r "$1" <<<"$input"; }
tool=$(field '.tool_name // ""')
cwd=$(field '.cwd // ""')
if [[ -n "$cwd" && -d "$cwd" ]]; then cd "$cwd" 2>/dev/null || exit 2; fi
ORIG_PWD="$PWD"
BUDGET=5

REFS_OK=1     # 0 turns off the reference-file exceptions (apply_patch, shell writes)
NEW_TEXT=""   # the text a Write or Edit would put into the file
HAS_NEW=0
SHELL_MODE=0  # 1 while checking a shell command: .git/ is not protected there

block() {  # block <what> <rule>
  echo "Blocked: $1 matches the sensitive-files policy ($2). Secrets stay out of agent sessions: run the command through your password manager's runner (for example op run), read the .example template, or ask the author to do it outside the agent." >&2
  exit 2
}
in_time() { (( SECONDS < BUDGET )) || block "this command" "too large to check within $BUDGET seconds; split it into smaller commands"; }

# Folders and files that a search must never run over (by real path: searches compare real paths).
RHOME=$(/bin/realpath -q -- "$HOME" 2>/dev/null || printf '%s' "$HOME")
# To protect another token folder, add it here, to the case list in check(), and to IND in
# shell_command(); then add a test to hooks/hooks.test.sh.
PROTECTED=("$RHOME/.ssh" "$RHOME/.gnupg" "$RHOME/.aws" "$RHOME/.config/op" "$RHOME/.config/gh/hosts.yml" "$RHOME/.codex/auth.json" "$RHOME/.config/gcloud/credentials.db")

# A line that holds nothing secret: blank, a comment without "=", or NAME=<1Password reference>.
# The reference scheme is written op:/[/] below: the same pattern, in a form a text search for the
# scheme does not flag.
REF_LINE='^[[:space:]]*(#[^=]*)?$|^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*(op:/[/][^[:space:]"'"'"'#]+|"op:/[/][^"]+"|'"'"'op:/[/][^'"'"']+'"'"')[[:space:]]*$'
REF_ANY='=[[:space:]]*["'"'"']?op:/[/]'
# The kit's pergamino.local.env: blank lines, comments without "=", and PERGAMINO_<NAME>=<path>.
# A value may not hold a backtick or parentheses, so the file stays safe to source.
KIT_ENV_NAME=pergamino.local.env
KIT_LINE='^[[:space:]]*(#[^=]*)?$|^[[:space:]]*(export[[:space:]]+)?PERGAMINO_[A-Z0-9_]+=[^`()]*$'

kit_file() {  # true when the file holds only kit path lines, blank lines and comments
  local size rc=0
  [[ -f "$1" && -r "$1" ]] || return 1
  size=$(wc -c < "$1" 2>/dev/null) || return 1
  (( size <= 65536 )) || return 1
  LC_ALL=C grep -Eqv "$KIT_LINE" "$1" 2>/dev/null || rc=$?
  [[ $rc -eq 1 ]]   # 1 = no line fell outside the pattern; 0 = one did; 2 = error
}

kit_text() {  # the same test on text a Write or Edit is about to put in
  local rc=0
  printf '%s\n' "$1" | LC_ALL=C grep -Eqv "$KIT_LINE" || rc=$?
  [[ $rc -eq 1 ]]
}

refs_file() {  # true when the file holds references and nothing else but blank lines and comments
  local size rc=0
  [[ -f "$1" && -r "$1" ]] || return 1
  size=$(wc -c < "$1" 2>/dev/null) || return 1
  (( size <= 65536 )) || return 1
  LC_ALL=C grep -Eqv "$REF_LINE" "$1" 2>/dev/null || rc=$?
  [[ $rc -eq 1 ]] || return 1  # 1 = no line fell outside the pattern; 0 = one did; 2 = error
  LC_ALL=C grep -Eq "$REF_ANY" "$1" 2>/dev/null  # an empty or comment-only file is not a reference file
}

refs_text() {  # the same test on text a Write or Edit is about to put in (it may drop lines)
  local rc=0
  printf '%s\n' "$1" | LC_ALL=C grep -Eqv "$REF_LINE" || rc=$?
  [[ $rc -eq 1 ]]
}

# A template is allowed when it doesn't exist yet (an agent creating it) or when
# git tracks it. Anything else (untracked copy, no repository, git missing) fails.
template_ok() {
  local p="$1" dir
  [[ -e "$p" || -L "$p" ]] || return 0
  dir="${p%/*}"
  [[ "$dir" == "$p" ]] && dir="."
  [[ -z "$dir" ]] && dir="/"
  git -C "$dir" ls-files --error-unmatch -- "${p##*/}" >/dev/null 2>&1
}

env_secret() {  # env_secret <path> <rule>: an env file passes only as a reference file
  if (( REFS_OK )); then
    if [[ "${1##*/}" == "$KIT_ENV_NAME" ]]; then   # the kit's path file (nocasematch is on in check)
      if [[ -e "$1" ]]; then
        kit_file "$1" || refs_file "$1" || block "$1" "$2; $KIT_ENV_NAME holds a line that is not PERGAMINO_<NAME>=<path>"
      fi
      if (( HAS_NEW )); then
        kit_text "$NEW_TEXT" || block "$1" "$2; the new text holds a line that is not PERGAMINO_<NAME>=<path>"
      fi
      return 0
    fi
    if [[ -e "$1" ]]; then
      refs_file "$1" || block "$1" "$2"
    elif (( ! HAS_NEW )); then
      block "$1" "$2"
    fi
    if (( HAS_NEW )); then
      refs_text "$NEW_TEXT" || block "$1" "$2; the new text holds a value that is not a 1Password reference"
    fi
    return 0
  fi
  block "$1" "$2"
}

check() {  # check <path>: blocks a secret file or a path inside a protected folder
  local p="$1" base="${1##*/}"
  shopt -s nocasematch

  # .env and .env.<anything>; the template .env.example only when committed or new
  if [[ "$base" == .env.example ]]; then
    template_ok "$p" || block "$p" ".env.example that git does not track"
  elif [[ "$base" == .env || "$base" == .env.* ]]; then
    env_secret "$p" ".env*"
  fi

  # Cloudflare local secrets (.dev.vars, .dev.vars.<environment>); the template as above
  if [[ "$base" == .dev.vars.example ]]; then
    template_ok "$p" || block "$p" ".dev.vars.example that git does not track"
  elif [[ "$base" == .dev.vars || "$base" == .dev.vars.* ]]; then
    env_secret "$p" ".dev.vars*"
  fi

  # Named env files (cookies.env, tokens.env, prod.env.local); <name>.env.example as above
  if [[ "$base" == *.env.example ]]; then
    template_ok "$p" || block "$p" "<name>.env.example that git does not track"
  elif [[ "$base" == *.env || "$base" == *.env.* ]]; then
    env_secret "$p" "*.env*"
  fi

  # Common secret filenames; .p12/.pfx are private certificates.
  case "$base" in
    credentials.json|secrets.yaml|secrets.yml|secrets.json|.netrc|.pgpass|id_rsa|id_rsa.pub|id_ed25519|id_ed25519.pub|id_dsa|id_ecdsa|*.p12|*.pfx)
      block "$p" "$base"
      ;;
  esac

  # Protected folders ("/" in front so relative paths match too)
  case "/$p" in
    */.ssh|*/.ssh/*|*/.gnupg|*/.gnupg/*|*/.aws/credentials|*/.config/gcloud/credentials.db|*/.codex/auth.json|*/.config/gh/hosts.yml|*/.config/op|*/.config/op/*)
      block "$p" "inside a protected folder"
      ;;
  esac
  # .git/ holds hooks and remote credentials; shell commands may still name it
  # (cp a hook into .git/hooks), file tools may not.
  if (( ! SHELL_MODE )); then
    case "/$p" in */.git|*/.git/*) block "$p" "inside .git/" ;; esac
  fi
  shopt -u nocasematch
  return 0
}

check_file() {  # check_file <path>: a path a file tool is about to open
  local path="$1" real="" dir rdir
  check "$path"
  # Same checks on the real path: catches a harmless-looking symlink to
  # ~/.aws/credentials and look-alike letters. For a file that doesn't exist yet
  # (Write), resolve its folder instead.
  if [[ -e "$path" || -L "$path" ]]; then
    real=$(/bin/realpath -q -- "$path" 2>/dev/null || true)
  else
    dir="${path%/*}"
    [[ "$dir" == "$path" ]] && dir="."
    [[ -z "$dir" ]] && dir="/"
    rdir=$(/bin/realpath -q -- "$dir" 2>/dev/null || true)
    [[ -n "$rdir" ]] && real="${rdir%/}/${path##*/}"
  fi
  if [[ -n "$real" && "$real" != "$path" ]]; then check "$real"; fi
  return 0
}

check_existing() {  # a name found in a command: only a file or folder that exists can be read
  local p="$1" r
  [[ -e "$p" || -L "$p" ]] || return 0
  check "$p"
  if [[ -L "$p" ]]; then
    r=$(/bin/realpath -q -- "$p" 2>/dev/null || true)
    if [[ -n "$r" && "$r" != "$p" ]]; then check "$r"; fi
  fi
  return 0
}

selects_secret() {  # a name pattern (glob, --include, -g, find -name) that selects secret names
  local g="${1##*/}" pre body post alt s
  local -a alts
  [[ -z "$g" ]] && return 1
  if [[ "$g" == *"{"*","*"}"* ]]; then  # one level of braces: *.{env,ts}
    pre="${g%%\{*}"; body="${g#*\{}"; post="${body#*\}}"; body="${body%%\}*}"
    IFS=',' read -r -a alts <<<"$body" || exit 2
    for alt in ${alts[@]+"${alts[@]}"}; do
      if selects_secret "$pre$alt$post"; then return 0; fi
    done
    return 1
  fi
  shopt -s nocasematch
  if [[ "$g" =~ (env|vars|cred|secret|id_|p12|pfx|netrc|pgpass) ]]; then
    for s in .env .env.local .env.production .dev.vars .dev.vars.staging tokens.env cookies.env credentials.json secrets.json secrets.yml id_rsa id_ed25519 cert.p12 cert.pfx .netrc .pgpass; do
      # $g unquoted on purpose: it is the pattern
      if [[ "$s" == $g ]]; then shopt -u nocasematch; return 0; fi
    done
  fi
  shopt -u nocasematch
  return 1
}

# ---------- searches over a folder ----------
# INCL / EXCL / EXCLD are filled by the caller: include globs, exclude globs, excluded folder globs.
INCL=(); EXCL=(); EXCLD=()

search() {  # search <grep|rg|find|Grep> <reads hidden 0/1> <reads ignored 0/1> <folder>
  local mode="$1" hidden="$2" ignored="$3" d="$4" dreal p f base rel e covered inc
  dreal=$(/bin/realpath -q -- "$d" 2>/dev/null || true)
  [[ -n "$dreal" && -d "$dreal" ]] || return 0
  [[ "$dreal" == / ]] && block "$d" "a search over the whole disk"
  for p in "${PROTECTED[@]}"; do
    if [[ "$p" == "$dreal" || "$p" == "$dreal"/* || "$dreal" == "$p"/* ]]; then
      block "$d" "a search over it would read $p"
    fi
  done
  while IFS= read -r f; do
    in_time
    [[ -z "$f" ]] && continue
    base="${f##*/}"
    rel="${f#"$d"/}"
    [[ "$base" == *.example ]] && continue  # templates don't stop a search, tracked or not
    covered=0
    # $inc and $e unquoted on purpose: these are globs
    if (( ${#INCL[@]} > 0 )); then
      covered=1
      for inc in "${INCL[@]}"; do
        if [[ "$base" == $inc || "$rel" == $inc ]]; then covered=0; break; fi
      done
    fi
    for e in ${EXCL[@]+"${EXCL[@]}"}; do
      if [[ "$base" == $e || "$rel" == $e ]]; then covered=1; break; fi
    done
    for e in ${EXCLD[@]+"${EXCLD[@]}"}; do
      case "/$rel" in */$e/*) covered=1; break ;; esac
    done
    (( covered )) && continue
    if (( ! hidden )); then
      case "/$rel" in */.*) continue ;; esac
    fi
    if (( ! ignored )) && git -C "${f%/*}" check-ignore -q -- "$base" 2>/dev/null; then
      continue
    fi
    refs_file "$f" && continue
    block "$f" "a $mode search over $d would open it; exclude it (--exclude, rg -g '!name'), or ask the author"
  done < <(find "$d" -maxdepth 6 \( -name node_modules -o -name .git -o -name .wrangler -o -name .venv \) -prune -o -type f \( -iname '.env' -o -iname '.env.*' -o -iname '.dev.vars' -o -iname '.dev.vars.*' -o -iname '*.env' -o -iname '*.env.*' -o -iname '*.p12' -o -iname '*.pfx' -o -iname 'credentials.json' -o -iname 'secrets.json' -o -iname 'secrets.y*ml' -o -iname '.netrc' -o -iname '.pgpass' -o -iname 'id_rsa' -o -iname 'id_ed25519' -o -iname 'id_dsa' -o -iname 'id_ecdsa' \) -print 2>/dev/null | head -n 200 || true)
  return 0
}

include_glob() {  # an include pattern: blocks when it selects secret names, else narrows the search
  if selects_secret "$1"; then block "$1" "an include pattern that selects secret files"; fi
  INCL+=("$1")
  return 0
}

# ---------- shell commands ----------
# Commands that only look at names or metadata, never at contents
SAFE=" ls test [ [[ stat file wc chmod chown rm rmdir mkdir touch echo printf du pwd which type basename dirname readlink realpath true false : cd pushd popd for in case esac "
# Words before the real command: keywords, wrappers
SKIP=" if then else elif fi do done while until ! { } time sudo env command builtin exec nohup nice caffeinate "
SHELLS=" bash sh zsh dash "
# A here-document fed to a shell (or ssh, sudo, xargs) is scanned as shell commands; one fed to
# an interpreter is scanned for secret names only (its * are not shell globs); others are skipped.
SHELL_RUNNERS=" bash sh zsh dash fish ssh sudo xargs "
CODE_RUNNERS=" python python3 node deno bun ruby perl php osascript "

ALL_SAFE=1
HAS_XARGS=0
CD_DIRS=()
ALLOWED=()   # ssh keys given to ssh as an identity: used, not read
GLOBS=()     # unquoted shell globs, expanded only if some command in the text reads files
LINKS=()     # symlinks named in the command: a harmless name may point at a secret

VARS_K=(); VARS_V=()   # NAME=value assignments in the command text, for write targets

# $'...' and $"...": the shell reads $"x" as "x" and decodes the escapes of $'x' (\x2e is a dot).
# An escape the guard does not decode (\u, \U, \c), a line break and a NUL become UNSURE: a write
# target or cd folder that holds it blocks (fail closed); any other word may hold it.
UNSURE=$'\003'
DQ=""
dq_decode() {  # dq_decode <text>: DQ = the text with $"..." as "..." and each $'...' decoded into '...'
  local s="$1" out="" body c e i n k ch digs
  if [[ "$s" != *'$'[\'\"]* ]]; then DQ="$s"; return 0; fi
  s="${s//\$\"/\"}"
  while [[ "$s" == *"\$'"* ]]; do
    out="$out${s%%\$\'*}"; s="${s#*\$\'}"
    body=""; i=0; n=${#s}
    while (( i < n )); do
      c="${s:i:1}"
      [[ "$c" == "'" ]] && break
      if [[ "$c" != "\\" ]]; then body="$body$c"; i=$((i+1)); continue; fi
      e="${s:i+1:1}"; i=$((i+2)); ch="$UNSURE"
      case "$e" in
        t) ch=$'\t' ;; r) ch=$'\r' ;; a) ch=$'\a' ;; b) ch=$'\b' ;; f) ch=$'\f' ;; v) ch=$'\v' ;;
        e|E) ch=$'\033' ;;
        \\|\'|\"|\?) ch="$e" ;;
        x) digs=""; for (( k=0; k<2; k++ )); do
             [[ "${s:i:1}" == [0-9A-Fa-f] ]] || break
             digs="$digs${s:i:1}"; i=$((i+1))
           done
           if [[ -n "$digs" ]]; then printf -v ch "\\x$digs"; fi ;;
        [0-7]) digs="$e"; for (( k=0; k<2; k++ )); do
             [[ "${s:i:1}" == [0-7] ]] || break
             digs="$digs${s:i:1}"; i=$((i+1))
           done
           printf -v ch "\\$digs" ;;
      esac
      [[ -z "$ch" || "$ch" == $'\n' ]] && ch="$UNSURE"   # a NUL or a line break
      body="$body$ch"
    done
    s="${s:i+1}"
    out="$out'$body'"
  done
  DQ="$out$s"
}

# Brace expansion: .ss{,h}/key writes .ss/key and .ssh/key. Each {a,b}, {1..3} or {a..c} outside
# quotes (not ${NAME}), nested or several in one word. A form the guard does not expand ({01..03},
# {1..9..2}: bash 3.2, bash 5 and zsh differ) or more than BRACE_MAX words: the caller blocks.
BRACE_MAX=256
LETTERS='ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz'
BG_PRE=""; BG_POST=""; BG_ALTS=(); BG_OK=1
brace_group() {  # brace_group <word>: the first brace expression in it (BG_PRE, BG_ALTS, BG_POST;
  local s="$1" n=${#1} i=0 j c q="" top body a b x pre   # BG_OK=0 when the guard cannot expand
  local -a stk cl cm cuts                                # it); returns 1 when none
  local nre='^(-?[0-9]+)\.\.(-?[0-9]+)(\.\.-?[0-9]+)?$' lre='^([A-Za-z])\.\.([A-Za-z])(\.\.-?[0-9]+)?$'
  BG_OK=1; BG_ALTS=()
  # One pass: each { outside quotes is matched with its } (cl) and notes its own commas (cm).
  # ${NAME...} is a variable, not a brace expansion (-1 on the stack).
  while (( i < n )); do
    c="${s:i:1}"
    if [[ -n "$q" ]]; then
      if [[ "$c" == "$q" ]]; then q=""; elif [[ "$q" == '"' && "$c" == "\\" ]]; then i=$((i+1)); fi
      i=$((i+1)); continue
    fi
    case "$c" in
      "\\") i=$((i+1)) ;;
      "'"|'"') q="$c" ;;
      '{') if (( i > 0 )) && [[ "${s:i-1:1}" == '$' ]]; then stk+=(-1); else stk+=("$i"); fi ;;
      '}'|',')
        if (( ${#stk[@]} > 0 )); then
          top=${stk[${#stk[@]}-1]}
          if [[ "$c" == "}" ]]; then
            unset "stk[$((${#stk[@]}-1))]"
            if (( top >= 0 )); then cl[top]=$i; fi
          elif (( top >= 0 )); then
            cm[top]="${cm[top]:-} $i"
          fi
        fi ;;
    esac
    i=$((i+1))
  done
  # The first matched { that holds a comma or a sequence; {x}, {} and an unmatched { are text.
  for i in ${cl[@]+"${!cl[@]}"}; do
    j=${cl[i]}
    body="${s:i+1:j-i-1}"; BG_PRE="${s:0:i}"; BG_POST="${s:j+1}"
    if [[ -n "${cm[i]:-}" ]]; then
      read -r -a cuts <<<"${cm[i]}" || exit 2
      a=$((i+1))
      for x in "${cuts[@]}"; do BG_ALTS+=("${s:a:x-a}"); a=$((x+1)); done
      BG_ALTS+=("${s:a:j-a}")
      return 0
    fi
    if [[ "$body" =~ $nre ]]; then
      a="${BASH_REMATCH[1]}"; b="${BASH_REMATCH[2]}"
      if [[ -n "${BASH_REMATCH[3]}" || "$a" =~ ^-?0[0-9] || "$b" =~ ^-?0[0-9] ]] || (( ${#a} > 6 || ${#b} > 6 )); then BG_OK=0; return 0; fi
      if (( (a > b ? a - b : b - a) >= BRACE_MAX )); then BG_OK=0; return 0; fi
      x=$(( a <= b ? 1 : -1 ))
      while :; do BG_ALTS+=("$a"); (( a == b )) && break; a=$((a + x)); done
      return 0
    fi
    if [[ "$body" =~ $lre ]]; then
      if [[ -n "${BASH_REMATCH[3]}" ]]; then BG_OK=0; return 0; fi
      pre="${LETTERS%%"${BASH_REMATCH[1]}"*}"; a=${#pre}
      pre="${LETTERS%%"${BASH_REMATCH[2]}"*}"; b=${#pre}
      x=$(( a <= b ? 1 : -1 ))
      while :; do BG_ALTS+=("${LETTERS:a:1}"); (( a == b )) && break; a=$((a + x)); done
      return 0
    fi
  done
  return 1
}

BR=()
brace_expand() {  # brace_expand <word>: BR = each word the shell's brace expansion makes of it;
  local -a work=("$1")   # returns 1 (BR = the word as it is) when it cannot expand one of them
  local w a
  BR=()
  while (( ${#work[@]} > 0 )); do
    in_time
    w="${work[${#work[@]}-1]}"; unset "work[$((${#work[@]}-1))]"
    if [[ "$w" != *"{"*"}"* ]]; then BR+=("$w"); continue; fi
    if (( ${#w} > 1024 )); then BR=("$1"); return 1; fi   # too long to scan character by character
    if ! brace_group "$w"; then BR+=("$w"); continue; fi
    if (( ! BG_OK )); then BR=("$1"); return 1; fi
    for a in "${BG_ALTS[@]}"; do work+=("$BG_PRE$a$BG_POST"); done
    if (( ${#work[@]} + ${#BR[@]} > BRACE_MAX )); then BR=("$1"); return 1; fi
  done
  return 0
}

VV=""
var_value() {  # var_value <value as written>: sets VV to it with quotes removed, ~ and $HOME
  local s="$1" out="" pre q="'" re='^([A-Za-z_][A-Za-z0-9_]*)(.*)$'   # expanded, other $NAME
  dq_decode "$s"; s="$DQ"                                            # written ${NAME}
  s="${s//\"/}"; s="${s//$q/}"
  s="${s//\$\{HOME\}/$HOME}"; s="${s//\$HOME/$HOME}"
  [[ "$s" == "~" ]] && s="$HOME"
  [[ "$s" == "~/"* ]] && s="$HOME/${s#\~/}"
  while [[ "$s" == *'$'* ]]; do   # f=$d/key: ${d} is filled in like any other variable
    pre="${s%%\$*}"; s="${s#*\$}"
    if [[ "$s" =~ $re ]]; then out="$out$pre\${${BASH_REMATCH[1]}}"; s="${BASH_REMATCH[2]}"
    else out="$out$pre\$"
    fi
  done
  VV="$out$s"
}

add_var() {  # add_var <name> <value> [append]: note a value; with append, NAME+=value adds to each known value
  local i n=${#VARS_K[@]} found=0
  if [[ -n "${3:-}" ]]; then
    for (( i=0; i<n; i++ )); do
      [[ "${VARS_K[i]}" == "$1" ]] || continue
      VARS_K+=("$1"); VARS_V+=("${VARS_V[i]}$2"); found=1
    done
    (( found )) && return 0
  fi
  VARS_K+=("$1"); VARS_V+=("$2")
}

collect_vars() {  # collect_vars <text>: note each value a variable gets: NAME=value, NAME+=value
  local line rest name plus w b q="'"   # (also after export, local, declare), for NAME in words
  local -a ws
  # A value may mix quoted and unquoted parts (f="fresh"'.env'), as in REDIR_RE. The last group
  # is the rest of the line: cutting a long match off with ${rest#*"$match"} takes seconds.
  local re="(^|[[:space:];&|(])([A-Za-z_][A-Za-z0-9_]*)([+]?)=((\"[^\"]*\"|$q[^$q]*$q|[^[:space:];&|()<>\"$q]+)*)(.*)\$"
  local fre='(^|[[:space:];&|(])for[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]+in([^;&|()]*)(.*)$'
  while IFS= read -r line; do
    rest="$line"
    while [[ "$rest" =~ $re ]]; do
      name="${BASH_REMATCH[2]}"; plus="${BASH_REMATCH[3]}"
      rest="${BASH_REMATCH[6]}"
      var_value "${BASH_REMATCH[4]}"   # (var_value runs =~ itself: BASH_REMATCH read before it)
      add_var "$name" "$VV" "$plus"
    done
    rest="$line"
    while [[ "$rest" =~ $fre ]]; do
      name="${BASH_REMATCH[2]}"
      rest="${BASH_REMATCH[4]}"
      read -r -a ws <<<"${BASH_REMATCH[3]}" || exit 2
      for w in ${ws[@]+"${ws[@]}"}; do
        # for f in .ss{,h}/key: each brace word is a value; one the guard cannot expand is UNSURE
        if [[ "$w" == *"{"* ]]; then
          if brace_expand "$w"; then
            for b in "${BR[@]}"; do var_value "$b"; add_var "$name" "$VV"; done
          else
            add_var "$name" "$UNSURE"
          fi
          continue
        fi
        var_value "$w"; add_var "$name" "$VV"
      done
    done
  done <<<"$1" || exit 2
}

EXP_N=0; EXP_T=0
expand_vars() {  # expand_vars <text> <depth>: prints the text once for each way to fill in its ${NAME}
  local s="$1" n="$2" whole name has_def def i k=0 val pre post seen=$'\001'
  local re='\$\{([A-Za-z_][A-Za-z0-9_]*)(:?[-=]([^}]*))?\}'
  in_time
  # More ways than the cap (a for loop over many names): too many to check, so block.
  (( EXP_N < 64 )) || block "this command" "more than 64 ways to fill in the variables of one write target; split it into smaller commands"
  (( EXP_T < BRACE_MAX )) || block "this command" "more than $BRACE_MAX names for one write target; split it into smaller commands"
  if (( n >= 8 )) || ! [[ "$s" =~ $re ]]; then
    EXP_N=$((EXP_N + 1)); EXP_T=$((EXP_T + 1)); printf '%s\n' "$s"; return 0
  fi
  whole="${BASH_REMATCH[0]}"; name="${BASH_REMATCH[1]}"; has_def="${BASH_REMATCH[2]}"; def="${BASH_REMATCH[3]}"
  pre="${s%%"$whole"*}"; post="${s#*"$whole"}"   # (not ${s/x/y}: bash 5.2 reads & in y as the match)
  # Every value the command text gives the variable, not only the last one: a later
  # f=notes.txt must not hide an earlier write to "$f".
  for (( i=0; i<${#VARS_K[@]}; i++ )); do
    [[ "${VARS_K[i]}" == "$name" ]] || continue
    val="${VARS_V[i]}"; k=1
    [[ "$seen" == *$'\001'"$val"$'\001'* ]] && continue
    seen="$seen$val"$'\001'
    expand_vars "$pre$val$post" $((n + 1))
  done
  # ${f:-name}, ${f-name}, ${f:=name}: the default is a target too, whatever the text gives f
  # (a value it cannot fill in, a later or quoted f=, unset -- f all leave the default in play).
  if [[ -n "$has_def" ]]; then
    expand_vars "$pre$def$post" $((n + 1))
  elif (( ! k )); then             # not set in the text: kept as $NAME; the rest of the path is still checked
    expand_vars "$pre\$$name$post" $((n + 1))
  fi
  return 0
}

expand_all() {  # expand_all <word>: $'...' decoded, braces expanded, quotes and backslashes removed,
  local s q="'" b   # ~ and $HOME expanded, and one line for each way to fill in the variables the
  local -a alts     # command text sets (EXP_T counts them over all brace words)
  dq_decode "$1"
  if [[ "$DQ" == *"{"* ]]; then
    brace_expand "$DQ" || block "$1" "a brace expansion the guard cannot expand in a write target (more than $BRACE_MAX names, {01..03}, {1..9..2})"
    alts=("${BR[@]}")
  else
    alts=("$DQ")
  fi
  EXP_T=0
  for s in "${alts[@]}"; do
    # $f -> ${f} first, so a quote removed next to it cannot join it to the text after it ("$f"_x)
    if [[ "$s" == *'$'[A-Za-z_]* ]]; then
      s=$(printf '%s' "$s" | sed -E 's/\$([A-Za-z_][A-Za-z0-9_]*)/${\1}/g') || exit 2
    fi
    s="${s//\$\{HOME\}/$HOME}"
    s="${s//\"/}"; s="${s//$q/}"; s="${s//\\/}"
    [[ "$s" == "~" ]] && s="$HOME"
    [[ "$s" == "~/"* ]] && s="$HOME/${s#\~/}"
    EXP_N=0
    expand_vars "$s" 0
  done
}

# The folders a relative write target may be in. One while cd is followed, also into a folder
# not made yet; a cd that may fail adds its folder to the ones before; after cd -, pushd -n or a
# popd past what the command pushed, every folder seen or named so far.
WDIRS=(); SEEN=$'\n'
DSTACK=(); DSTACK_OK=1   # pushd/popd: each entry holds the folders before a pushd, one per line
AND=0                    # 1 when && follows the simple command being checked
CHAIN=1                  # 1 while && follows every simple command before it: it runs only if they worked
SUBSH=0                  # 1 when the text has ( ` or |: a cd there may run in a subshell that ends
CD_SURE=0                # 1 when the last cd or pushd replaced the folders (it surely ran and worked)

seen_add() {  # seen_add <folder>...: folders a later cd -, popd or pushd rotation may go back to
  local d
  for d in "$@"; do
    [[ "$SEEN" == *$'\n'"$d"$'\n'* ]] || SEEN="$SEEN$d"$'\n'
    if [[ -d "$d" ]]; then CD_DIRS+=("$d"); fi
  done
  return 0
}

wdirs_set() {  # wdirs_set <folder>...: relative writes land in these folders from now on
  WDIRS=("$@")
  seen_add "$@"
  # The guard follows a single known folder, so names in later commands are found there.
  if (( $# == 1 )) && [[ -d "$1" ]]; then cd "$1" 2>/dev/null || true; fi
  return 0
}

wdirs_unknown() {  # cd -, popd +N, pushd -n, ...: the folder is not known; check in every folder seen
  local -a all=()
  local d
  while IFS= read -r d; do
    if [[ -n "$d" ]]; then all+=("$d"); fi
  done <<<"$SEEN" || exit 2
  WDIRS=("${all[@]}")
}

PP=""
phys_path() {  # phys_path <absolute path>: PP = the path as the disk resolves it (links, ..) as far
  local head="$1" tail="" r   # as it exists, the rest as text; "" when it cannot be resolved
  while [[ -n "$head" && ! -e "$head" ]]; do
    tail="/${head##*/}$tail"; head="${head%/*}"
  done
  [[ -z "$head" ]] && head="/"
  r=$(/bin/realpath -q -- "$head" 2>/dev/null) || r=""
  PP=""
  if [[ -n "$r" ]]; then tidy_path "${r%/}$tail"; PP="$TP"; fi
  return 0
}

DIRS_NEW=()
cd_dirs() {  # cd_dirs <folder as written> <1 = -P>: adds to DIRS_NEW where the cd lands, from each
  local d p lex ok=1   # folder in WDIRS; returns 1 when one of them is missing now (the cd may fail)
  local -a bases
  if [[ "$1" == /* ]]; then bases=(""); else bases=("${WDIRS[@]}"); fi
  for d in "${bases[@]}"; do
    if [[ -n "$d" ]]; then p="$d/$1"; else p="$1"; fi
    tidy_path "$p"; lex="$TP"
    # cd -P resolves name/.. on disk (the folder that holds the link's target); cd -L reads it as
    # text, and falls back to the disk when that folder is missing. Without .. both agree.
    if [[ "/$1/" == */../* ]]; then phys_path "$p"; else PP="$lex"; fi
    if (( $2 )) && [[ -n "$PP" ]]; then
      dirs_add "$PP"; [[ -d "$PP" ]] || ok=0
    else
      dirs_add "$lex"
      if [[ ! -d "$lex" ]]; then ok=0; if [[ -n "$PP" ]]; then dirs_add "$PP"; fi; fi
    fi
  done
  (( ok ))
}

dirs_add() {  # dirs_add <folder>: add to DIRS_NEW once
  local x
  for x in ${DIRS_NEW[@]+"${DIRS_NEW[@]}"}; do [[ "$x" == "$1" ]] && return 0; done
  DIRS_NEW+=("$1")
  return 0
}

cd_dirs_all() {  # cd_dirs_all <folder as written> <1 = -P>: DIRS_NEW = where the cd may land; returns
  local b ok=1   # 1 when a folder is missing now or the word names more than one ({a,b}, cd may fail)
  [[ "$1" == *"$UNSURE"* ]] && block "cd $1" "a \$'...' escape the guard cannot decode in a cd folder"
  DIRS_NEW=()
  if [[ "$1" == *"{"* ]]; then
    brace_expand "$1" || block "cd $1" "a brace expansion the guard cannot expand in a cd folder"
  else
    BR=("$1")
  fi
  (( ${#BR[@]} == 1 )) || ok=0
  for b in "${BR[@]}"; do cd_dirs "$b" "$2" || ok=0; done
  (( ok ))
}

sure() {  # true when the simple command being checked surely runs, in this shell, and the next one
  (( AND && CHAIN && ! SUBSH ))   # runs only if it worked: && before and after it, no ( ` or |
}

cd_to() {  # cd_to <folder as written> <1 = -P>: follow a cd. The shell stays where it was when the
  local x   # cd does not run, fails or runs in a subshell, so the new folders replace the old ones
  local -a old=("${WDIRS[@]}")   # only when they exist now and sure() holds; else they are added
  CD_SURE=0
  if cd_dirs_all "$1" "$2" && sure; then
    CD_SURE=1
    wdirs_set "${DIRS_NEW[@]}"
  else
    for x in "${old[@]}"; do dirs_add "$x"; done
    wdirs_set "${DIRS_NEW[@]}"
  fi
}

write_path() {  # write_path <path>: one filled-in write target; blocks a secret whether it exists or not
  local t="$1" d REFS_OK=0   # no reference-file exception: the shell's new text cannot be checked
  [[ "$t" == *"$UNSURE"* ]] && block "$t" "a \$'...' escape the guard cannot decode in a write target"
  [[ -z "$t" || "$t" == - ]] && return 0
  if [[ "$t" == /* ]]; then check_file "$t"; return 0; fi
  for d in "${WDIRS[@]}"; do check_file "$d/$t"; done
  return 0
}

OPT_HITS=(); OPT_CONSUME=0
opt_scan() {  # opt_scan <-cluster> <letters that take a value> <letters to report>: OPT_HITS = each
  local o="${1#-}" c first=""   # reported letter followed by its value in the same word ("" = the
  OPT_HITS=(); OPT_CONSUME=0    # next word); OPT_CONSUME = 1 when the next word is a value.
  # Every reported letter counts, also after a letter that takes the rest of the cluster as its
  # value (curl -Ho name): when unsure, a word is a possible target (fail closed).
  while [[ -n "$o" ]]; do
    c="${o:0:1}"; o="${o:1}"
    if [[ -n "$3" && "$3" == *"$c"* ]]; then OPT_HITS+=("$c$o"); fi
    if [[ -z "$first" && "$2" == *"$c"* ]]; then
      first="$c"
      if [[ -z "$o" ]]; then OPT_CONSUME=1; fi
    fi
  done
  return 0
}

long_match() {  # long_match <--name> <options>: true when --name is an option of the list or a
  local o   # shortened form of one (getopt takes any start that is not ambiguous: --out, --outp)
  (( ${#1} > 2 )) || return 1
  for o in $2; do
    if [[ "$o" == "$1"* ]]; then return 0; fi
  done
  return 1
}

write_target() {  # write_target <word>: a file a shell command writes, as written in the command
  local exps t
  exps=$(expand_all "$1") || exit 2
  while IFS= read -r t; do write_path "$t"; done <<<"$exps" || exit 2
  return 0
}

# An output redirect and its target: >, >>, >|, N>, &> and >&name (shell_command rewrites those
# two as >). A target may mix quoted and unquoted parts ("$HOME"/.ssh/key). Not => or -> inside
# quotes (code, commit messages): shell_command puts a space in front of > outside quotes.
REDIR_RE="(^|[^=>-])>>?\|?[[:space:]]*((\"[^\"]*\"|'[^']*'|[^[:space:]<>;|&()\"']+)+)"

redirects() {  # redirects <one simple command>: checks each file it writes through a redirect
  local rest="$1"
  while [[ "$rest" =~ $REDIR_RE ]]; do
    write_target "${BASH_REMATCH[2]}"
    rest="${rest#*"${BASH_REMATCH[0]}"}"
  done
  return 0
}

LC=""
lower() {  # lower <word>: LC = the word in lower case. The disk ignores case, so TOUCH runs touch.
  LC="$1"
  if [[ "$LC" == *[[:upper:]]* ]]; then LC=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]') || exit 2; fi
  return 0
}

command_word() {  # command_word <text>: the command a simple command runs (lower case), past assignments and wrappers
  local -a w
  local i=0 n t c wrapped=0
  read -r -a w <<<"$1" || exit 2
  n=${#w[@]}
  while (( i < n )); do
    t="${w[i]}"; lower "${t##*/}"; c="${LC#\\}"
    if [[ "$t" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then i=$((i+1)); continue; fi
    if (( wrapped )) && [[ "$t" == -* ]]; then i=$((i+1)); continue; fi
    if [[ "$SKIP" == *" $c "* ]]; then wrapped=1; i=$((i+1)); continue; fi
    printf '%s' "$c"; return 0
  done
  return 0
}

strip_heredocs() {  # the command, minus bodies of here-documents written to files
  local line cmp term="" dash=0 keep=0 in_doc=0 before w
  local re='(^|[^<])<<(-?)[[:space:]]*["'"'"'\\]?([A-Za-z_][A-Za-z0-9_]*)'
  while IFS= read -r line || [[ -n "$line" ]]; do
    if (( in_doc )); then
      cmp="$line"
      (( dash )) && cmp="${cmp#"${cmp%%[!$'\t']*}"}"
      if [[ "$cmp" == "$term" ]]; then in_doc=0; continue; fi
      if (( keep == 1 )); then printf '%s\n' "$line"
      elif (( keep == 2 )); then printf '\001%s\n' "$line"   # code: names only
      fi
      continue
    fi
    printf '%s\n' "$line"
    if [[ "$line" =~ $re ]]; then
      dash=0; [[ -n "${BASH_REMATCH[2]}" ]] && dash=1
      term="${BASH_REMATCH[3]}"
      before="${line%%<<*}"
      before="${before##*[;&|(]}"
      w=$(command_word "$before") || exit 2
      keep=0
      if [[ "$SHELL_RUNNERS" == *" $w "* ]]; then keep=1
      elif [[ "$CODE_RUNNERS" == *" $w "* ]]; then keep=2
      fi
      in_doc=1
    fi
  done <<<"$1" || exit 2
}

words_of() {  # words_of <segment>: its text with quotes and backslashes removed, $HOME expanded,
  local s="$1"  # output redirects and their targets left out (redirects() checks those); $'...' decoded
  # (a number in front of > is part of the redirect: cp a b 2>/dev/null keeps b as the last word)
  dq_decode "$s"; s="$DQ"
  if [[ "$s" == *">"* ]]; then
    s=$(printf '%s' "$s" | sed -E "s/(^|[[:space:]])[0-9]+>/\1>/g; s/(^|[^=>-])>>?\|?[[:space:]]*((\"[^\"]*\"|'[^']*'|[^[:space:]<>;|&()\"']+)+)/\1 /g") || exit 2
  fi
  s="${s//\$\{HOME\}/$HOME}"; s="${s//\$HOME/$HOME}"
  s="${s//\"/}"; s="${s//\'/}"; s="${s//\\/}"
  s="${s//</ }"; s="${s//>/ }"
  printf '%s' "$s"
}

segment() {  # segment <one simple command>: classify it, note cd targets, ssh keys, and searches
  local seg n i=0 j wrapped=0 cmd lc t sub take="" rec=0 hid=0 ign=0 files=0 mode="" saw_ssh=0 dd=0 exps
  local d v h vl outs longs dl dlongs lo ld hasv phys
  local -a w dirs dests outt odirs pos raw tdirs srcs
  [[ "$1" =~ ^[[:space:]]*# ]] && return 0   # a comment line
  # Every step checks its own result (a failed read would empty the command): exit 2, not a pass.
  if [[ "$1" == *">"* ]]; then redirects "$1"; fi
  seg=$(words_of "$1") || exit 2
  read -r -a w <<<"$seg" || exit 2
  n=${#w[@]}
  (( n > 0 )) || return 0
  for (( j=0; j<n; j++ )); do
    t="${w[j]}"
    if [[ "$t" == "~" ]]; then w[j]="$HOME"
    elif [[ "$t" == "~/"* ]]; then w[j]="$HOME/${t#\~/}"
    fi
    if [[ -L "${w[j]}" ]]; then LINKS+=("$PWD/${w[j]#"$PWD/"}"); fi
  done

  # ssh keys given as an identity, anywhere in the segment (GIT_SSH_COMMAND="ssh -i key" too)
  for (( j=0; j<n; j++ )); do
    t="${w[j]}"
    case "$t" in
      ssh|scp|sftp|ssh-add|ssh-copy-id|*=ssh) saw_ssh=1 ;;
      -i|-F) if (( saw_ssh && j + 1 < n )); then ALLOWED+=("${w[j+1]}"); fi ;;
      IdentityFile=*|-oIdentityFile=*) ALLOWED+=("${t#*IdentityFile=}") ;;
    esac
  done

  # The command word: past assignments, keywords, wrappers and their options, sh -c
  while (( i < n )); do
    t="${w[i]}"; lower "${t##*/}"; cmd="${LC#\\}"
    if [[ "$t" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then i=$((i+1)); continue; fi
    if (( wrapped )) && [[ "$t" == -* ]]; then i=$((i+1)); continue; fi
    if [[ "$SKIP" == *" $cmd "* ]]; then wrapped=1; i=$((i+1)); continue; fi
    if [[ "$SHELLS" == *" $cmd "* ]] && (( i + 1 < n )) && [[ "${w[i+1]}" =~ ^-[a-z]*c[a-z]*$ ]]; then
      i=$((i+2)); wrapped=0; continue
    fi
    break
  done
  (( i < n )) || return 0
  cmd="${w[i]##*/}"; cmd="${cmd#\\}"
  lower "$cmd"; lc="$LC"   # programs in any case (TOUCH, Tee); cd, pushd, popd are shell builtins: exact

  # Files the command writes: tee's files (after --, every word); the destination of cp, mv
  # and install (a folder: each source's name inside it).
  case "$lc" in
    tee)
      for (( j=i+1; j<n; j++ )); do
        if (( ! dd )) && [[ "${w[j]}" == -- ]]; then dd=1; continue; fi
        if (( dd )) || [[ "${w[j]}" != -* ]]; then write_target "${w[j]}"; fi
      done ;;
    cp|mv|install)
      # The destination: the folder of -t DIR, -tDIR or --target-directory[=]DIR (also shortened,
      # --target=), else the last word that is not an option. GNU cp reads options anywhere
      # (cp a b -v), and an option value may be a name (install -S takes one in GNU, none in
      # BSD): the last such word counts both with and without option values skipped.
      if [[ "$lc" == install ]]; then vl=BfgmoNSt; longs="--group --mode --owner --suffix --strip-program --target-directory"
      else vl=St; longs="--suffix --target-directory --no-preserve --sparse"; fi
      pos=(); raw=(); tdirs=(); srcs=()
      for (( j=i+1; j<n; j++ )); do
        t="${w[j]}"
        if (( dd )) || [[ "$t" != -* || "$t" == - ]]; then pos+=("$t"); raw+=("$t"); continue; fi
        if [[ "$t" == -- ]]; then dd=1; continue; fi
        if [[ "$t" == --* ]]; then
          if [[ "${t%%=*}" != --strip ]] && long_match "${t%%=*}" "$longs"; then
            if [[ "$t" == *=* ]]; then v="${t#*=}"; else j=$((j+1)); v="${w[j]:-}"; raw+=("$v"); fi
            if long_match "${t%%=*}" "--target-directory"; then tdirs+=("$v"); fi
          fi
          continue
        fi
        opt_scan "$t" "$vl" t
        for h in ${OPT_HITS[@]+"${OPT_HITS[@]}"}; do
          v="${h:1}"
          if [[ -z "$v" ]]; then v="${w[j+1]:-}"; fi
          tdirs+=("$v")
        done
        if (( OPT_CONSUME )); then j=$((j+1)); raw+=("${w[j]:-}"); fi
      done
      if (( ${#tdirs[@]} > 0 )); then
        dests=("${tdirs[@]}"); srcs=(${pos[@]+"${pos[@]}"})
      elif (( ${#raw[@]} >= 2 )); then
        dests=("${raw[${#raw[@]}-1]}")
        if (( ${#pos[@]} > 0 )) && [[ "${pos[${#pos[@]}-1]}" != "${dests[0]}" ]]; then dests+=("${pos[${#pos[@]}-1]}"); fi
        for t in "${raw[@]}"; do
          if [[ " ${dests[*]} " != *" $t "* ]]; then srcs+=("$t"); fi
        done
      else
        dests=()
      fi
      # Each source's name, as it lands inside a destination folder
      outt=()
      for t in ${srcs[@]+"${srcs[@]}"}; do
        exps=$(expand_all "$t") || exit 2
        while IFS= read -r v; do
          v="${v%/}"; v="${v##*/}"
          if [[ -n "$v" ]]; then outt+=("$v"); fi
        done <<<"$exps" || exit 2
      done
      for t in ${dests[@]+"${dests[@]}"}; do
        exps=$(expand_all "$t") || exit 2
        odirs=()
        while IFS= read -r v; do
          [[ -z "$v" ]] && continue
          if [[ "$v" == /* ]]; then odirs+=("$v"); else for d in "${WDIRS[@]}"; do odirs+=("$d/$v"); done; fi
        done <<<"$exps" || exit 2
        for d in ${odirs[@]+"${odirs[@]}"}; do
          if (( ${#tdirs[@]} > 0 )) || [[ -d "$d" ]]; then
            if (( ${#tdirs[@]} > 0 )); then write_path "$d"; fi
            for v in ${outt[@]+"${outt[@]}"}; do write_path "$d/$v"; done
          else
            write_path "$d"
          fi
        done
      done ;;
    touch|sort|curl|wget)
      # touch: every operand (options -r, -t, -d and -A take a value). The others: the file an
      # output option names (sort -o; curl -o/-D/-c, --stderr, --trace; wget -O/-o/-a), also a
      # long option shortened (--out=name, --outp name) and every output letter in a cluster
      # (-sSLo); curl --output-dir and wget -P put a folder in front of each, and are checked too.
      dl=""; dlongs=""
      case "$lc" in
        touch) vl=rtdA; outs=""; longs="" ;;
        sort) vl=kotTS; outs=o; longs="--output" ;;
        curl) vl=AbcCdDeEFHKmoPQrtTuUwxXyYz; outs=oDc
              longs="--output --dump-header --cookie-jar --stderr --trace --trace-ascii --libcurl --etag-save"
              dlongs="--output-dir" ;;
        wget) vl=OoaPeUtTwQiBDIXARl; outs=Ooa; dl=P
              longs="--output-document --output-file --append-output"; dlongs="--directory-prefix" ;;
      esac
      for (( j=i+1; j<n; j++ )); do
        t="${w[j]}"
        if (( dd )) || [[ "$t" != -* || "$t" == - ]]; then
          if [[ "$lc" == touch ]]; then outt+=("$t"); fi
          continue
        fi
        if [[ "$t" == -- ]]; then dd=1; continue; fi
        if [[ "$t" == --* ]]; then
          v=""; hasv=0; lo=0; ld=0
          if [[ "$t" == *=* ]]; then v="${t#*=}"; hasv=1; fi
          if long_match "${t%%=*}" "$longs"; then lo=1; fi
          if long_match "${t%%=*}" "$dlongs"; then ld=1; fi
          if (( (lo || ld) && ! hasv )); then j=$((j+1)); v="${w[j]:-}"; fi
          if (( lo )); then outt+=("$v"); fi
          if (( ld )); then odirs+=("$v"); fi
          continue
        fi
        opt_scan "$t" "$vl" "$outs$dl"
        for h in ${OPT_HITS[@]+"${OPT_HITS[@]}"}; do
          v="${h:1}"
          if [[ -z "$v" ]]; then v="${w[j+1]:-}"; fi
          if [[ -n "$dl" && "$dl" == *"${h:0:1}"* ]]; then odirs+=("$v"); else outt+=("$v"); fi
        done
        if (( OPT_CONSUME )); then j=$((j+1)); fi
      done
      for t in ${outt[@]+"${outt[@]}"}; do
        write_target "$t"
        for d in ${odirs[@]+"${odirs[@]}"}; do write_target "$d/$t"; done
      done
      for d in ${odirs[@]+"${odirs[@]}"}; do write_target "$d"; done ;;
  esac

  case "$cmd" in
    cd|pushd)
      # Options: -P follows links on disk, -L (the default) reads the path as text, -- ends them.
      # cd - (the folder before) and pushd's stack forms (pushd alone, +N, -N) leave the folder
      # unknown; pushd -n DIR only adds DIR to the stack, which a later popd may enter.
      t=""; phys=0; h=0
      for (( j=i+1; j<n; j++ )); do
        t="${w[j]}"
        if (( ! dd )); then
          if [[ "$t" == -- ]]; then dd=1; t=""; continue; fi
          if [[ "$cmd" == pushd && "$t" == -n ]]; then h=1; t=""; continue; fi
          if [[ "$cmd" == pushd && "$t" == [+-][0-9]* ]]; then t=-; break; fi
          [[ "$t" == - ]] && break
          if [[ "$t" == -* ]]; then
            v="${t#-}"
            while [[ -n "$v" ]]; do
              case "${v:0:1}" in P) phys=1 ;; L) phys=0 ;; esac
              v="${v:1}"
            done
            t=""; continue
          fi
        fi
        break
      done
      if [[ "$cmd" == pushd ]] && (( h )); then
        DSTACK_OK=0
        if [[ -n "$t" && "$t" != - ]]; then
          cd_dirs_all "$t" "$phys" || true   # (missing or not: the folder is named either way)
          seen_add "${DIRS_NEW[@]}"
        fi
        wdirs_unknown
        return 0
      fi
      if [[ "$cmd" == pushd ]]; then
        [[ -z "$t" ]] && t=-
        if [[ "$t" == - ]]; then DSTACK_OK=0
        else
          d=""; for sub in "${WDIRS[@]}"; do d="$d$sub"$'\n'; done
          DSTACK+=("$d")
        fi
      fi
      if [[ "$t" == - ]]; then wdirs_unknown
      else
        # A folder that does not exist yet (mkdir -p .ssh && cd .ssh): later writes land in it.
        cd_to "${t:-$HOME}" "$phys"
        # A pushd that may not have run: a later popd may pop the entry below this one instead.
        if [[ "$cmd" == pushd ]] && (( ! CD_SURE && ${#DSTACK[@]} > 1 )); then DSTACK_OK=0; fi
      fi
      return 0 ;;
    popd)   # back to the folders before the matching pushd; popd +N, -N, -n or past the stack: unknown
      t=""
      for (( j=i+1; j<n; j++ )); do
        if (( ! dd )) && [[ "${w[j]}" == -- ]]; then dd=1; continue; fi
        t="${w[j]}"; break
      done
      j=${#DSTACK[@]}
      if (( DSTACK_OK && j > 0 )) && [[ -z "$t" ]]; then
        dests=()
        while IFS= read -r d; do
          if [[ -n "$d" ]]; then dests+=("$d"); fi
        done <<<"${DSTACK[j-1]}" || exit 2
        unset "DSTACK[$((j-1))]"
        # Like cd_to: a popd that may not run (false && popd; popd in ( )) keeps the folders it
        # would leave and adds those it returns to; the stack is then unknown.
        if sure; then
          wdirs_set "${dests[@]}"
        else
          DIRS_NEW=()
          for d in "${WDIRS[@]}" "${dests[@]}"; do dirs_add "$d"; done
          wdirs_set "${DIRS_NEW[@]}"
          DSTACK_OK=0
        fi
      else
        wdirs_unknown
      fi
      return 0 ;;
  esac
  if [[ "$SAFE" == *" $lc "* ]]; then return 0; fi
  if [[ "$lc" == find ]]; then
    case " ${w[*]} " in
      *" -exec "*|*" -execdir "*|*" -ok "*|*" -okdir "*) mode=find ;;
      *) (( HAS_XARGS )) && mode=find ;;
    esac
    [[ -z "$mode" ]] && return 0   # find that only lists names
  fi
  if [[ "$lc" == git ]]; then  # git subcommands that never print file contents
    j=$((i+1)); sub=""
    while (( j < n )); do
      t="${w[j]}"
      case "$t" in
        -C|-c|--git-dir|--work-tree) j=$((j+2)); continue ;;
        -*) j=$((j+1)); continue ;;
      esac
      sub="$t"; break
    done
    case "$sub" in check-ignore|ls-files|rm|status) return 0 ;; esac
  fi
  ALL_SAFE=0
  case "$lc" in
    grep|egrep|fgrep) mode=grep; hid=1 ;;  # Claude Code's grep reads hidden files, skips ignored ones
    rg) mode=rg; rec=1 ;;
  esac
  [[ -z "$mode" ]] && return 0

  # A search: its flags (case matters here: rg -U is not -u), include/exclude patterns, folders
  INCL=(); EXCL=(); EXCLD=()
  if [[ "$mode" == find ]]; then rec=1; hid=1; ign=1; fi
  for (( j=i+1; j<n; j++ )); do
    t="${w[j]}"
    if [[ -n "$take" ]]; then
      case "$take" in
        incl) if [[ "${t:0:1}" == "!" ]]; then EXCL+=("${t:1}"); else include_glob "$t"; fi ;;
        excl) EXCL+=("$t") ;;
        excld) EXCLD+=("$t") ;;
      esac
      take=""; continue
    fi
    case "$mode" in
      grep)
        case "$t" in
          --recursive|--dereference-recursive|--directories=recurse) rec=1; continue ;;
          --include=*) include_glob "${t#*=}"; continue ;;
          --include) take=incl; continue ;;
          --exclude=*) EXCL+=("${t#*=}"); continue ;;
          --exclude) take=excl; continue ;;
          --exclude-dir=*) EXCLD+=("${t#*=}"); continue ;;
          --exclude-dir) take=excld; continue ;;
          -e|-f|-m|-A|-B|-C|--regexp|--file) take=skip; continue ;;
          --*) continue ;;
          -*) if [[ "$t" == *[rR]* ]]; then rec=1; fi; continue ;;
        esac ;;
      rg)
        case "$t" in
          --hidden|-.) hid=1; continue ;;
          --no-ignore*) ign=1; continue ;;
          --glob=*|--iglob=*)
            t="${t#*=}"
            if [[ "${t:0:1}" == "!" ]]; then EXCL+=("${t:1}"); else include_glob "$t"; fi
            continue ;;
          -g|--glob|--iglob) take=incl; continue ;;
          -t|--type|--type=*) return 0 ;;   # a typed search never opens env files
          -T|--type-not|-e|--regexp|-f|--file|-m|-A|-B|-C|-j|-M|--max-depth|-d) take=skip; continue ;;
          --*) continue ;;
          -*)
            case "$t" in *uu*) hid=1; ign=1 ;; *u*) ign=1 ;; esac
            continue ;;
        esac ;;
      find)
        case "$t" in
          -name|-iname|-path|-ipath|-wholename|-iwholename) take=incl; continue ;;
          -*|'!') continue ;;
        esac ;;
    esac
    if [[ -d "$t" ]]; then dirs+=("$t"); elif [[ -f "$t" ]]; then files=1; fi
  done
  (( rec )) || return 0
  if (( ${#dirs[@]} == 0 )); then
    (( files )) && return 0   # only files given: the names were checked with the rest of the command
    dirs=(".")
  fi
  for t in "${dirs[@]}"; do
    search "$mode" "$hid" "$ign" "$t"
  done
  return 0
}

TP=""
tidy_path() {  # tidy_path <absolute path>: TP = it with /./ and name/.. taken out, as text (the folder may not exist)
  local p="$1" re='^(.*/)?([^/]+)/\.\.(/.*)?$'
  while [[ "$p" == *"/./"* ]]; do p="${p//\/.\//\/}"; done
  p="${p%/.}"
  while [[ "$p" =~ $re && "${BASH_REMATCH[2]}" != .. ]]; do
    p="${BASH_REMATCH[1]}${BASH_REMATCH[3]#/}"
    [[ -z "$p" ]] && p="/"
  done
  [[ "$p" == / ]] || p="${p%/}"
  TP="$p"
}

# Outside quotes, put a space between - or = and a > that follows (a redirect: echo x ->f.env);
# inside quotes, => and -> stay text. Lines of code fed to an interpreter (\001) stay as they are.
SPLIT_ARROWS='
BEGIN { st = 0 }
substr($0, 1, 1) == "\001" { print; next }
{
  out = ""; n = length($0); i = 1
  while (i <= n) {
    c = substr($0, i, 1)
    if (st == 0) {
      if (c == "\\") { out = out substr($0, i, 2); i += 2; continue }
      if (c == "\047") st = 1
      else if (c == "\"") st = 2
      else if (c == "#" && (i == 1 || substr($0, i - 1, 1) ~ /[ \t;&|(]/)) { out = out substr($0, i); break }
      else if ((c == "-" || c == "=") && substr($0, i + 1, 1) == ">") { out = out c " "; i++; continue }
    } else if (st == 1) {
      if (c == "\047") st = 0
    } else {
      if (c == "\\") { out = out substr($0, i, 2); i += 2; continue }
      if (c == "\"") st = 0
    }
    out = out c; i++
  }
  print out
}'

gq() {  # gq <grep arguments>: grep in the C locale where "no line matched" (exit 1) is not a failure
  local r=0
  LC_ALL=C grep "$@" || r=$?
  (( r <= 1 ))
}

candidate() {  # candidate <name found in the command text>
  local c="$1" d a m
  [[ -z "$c" ]] && return 0
  [[ "$c" == //[!/]* ]] && c="${c#//}"   # file://name
  for a in ${ALLOWED[@]+"${ALLOWED[@]}"}; do
    [[ "$c" == "$a" ]] && return 0
  done
  if [[ "$c" == *"**"* ]] && selects_secret "$c"; then
    block "$c" "a recursive glob that selects secret files"
  fi
  if [[ "$c" == /* ]]; then
    if [[ "$c" == *[\*\?]* ]]; then
      while IFS= read -r m; do [[ -n "$m" ]] && check_existing "$m"; done < <(compgen -G "$c" 2>/dev/null || true)
    else
      check_existing "$c"
    fi
    return 0
  fi
  for d in "$PWD" "$ORIG_PWD" ${CD_DIRS[@]+"${CD_DIRS[@]}"}; do
    in_time
    if [[ "$c" == *[\*\?]* ]]; then
      while IFS= read -r m; do
        [[ -n "$m" ]] && check_existing "$d/$m"
      done < <(cd "$d" 2>/dev/null && compgen -G "$c" 2>/dev/null || true)
    else
      check_existing "$d/$c"
    fi
  done
  return 0
}

shell_command() {  # shell_command <text>
  local text="$1" seg c end ended
  local D="[^[:space:]\"'(),;|&<>=:\`\\\\{}]"
  local IND='\.env|\.dev\.vars|credentials|secrets\.(json|ya?ml)|\.netrc|\.pgpass|id_(rsa|dsa|ecdsa|ed25519)|\.p12|\.pfx|\.ssh|\.gnupg|\.aws|\.config/(op|gh)|hosts\.yml|auth\.json'
  local g seen=" " bsnl=$'\\\n'
  WDIRS=("$PWD"); SEEN=$'\n'"$PWD"$'\n'
  text="${text//"$bsnl"/}"   # a line continuation: the next line is the same command
  text=$(strip_heredocs "$text") || exit 2
  collect_vars "$text"
  text="${text//>|/>}"   # >| (write even with noclobber) is a redirect, not a pipe
  # Redirects with &, before the split at &: a copy or close of a numbered output (2>&1, >&2,
  # 2>&-) writes no file and goes; >&name and &>name write the file name, so they become > name.
  text=$(printf '%s\n' "$text" | sed -E 's/(^|[[:space:]])[0-9]*[<>]&[[:space:]]*([0-9]+|-)([[:space:];|&()<>]|$)/\1 \3/g; s/[<>]&[[:space:]]*([0-9]+|-)([[:space:];|&()<>]|$)/ \2/g; s/>&[[:space:]]*/> /g; s/&>/ >/g' | awk "$SPLIT_ARROWS") || exit 2
  [[ "$text" == *xargs* ]] && HAS_XARGS=1
  if [[ "$text" == *[\(\`\|]* ]]; then SUBSH=1; fi
  # One simple command per line: split at ; & | ( ) ` and line breaks. Lines of code fed
  # to an interpreter (marked \001) are not shell commands. A command followed by && carries
  # a \002 mark: a cd there is followed only when it worked. The split ends with a line of its
  # own only when every program in it worked: without that line the command blocks (exit 2).
  end=$'\004'"end-$RANDOM-$RANDOM-$$"; ended=0; CHAIN=1
  while IFS= read -r seg; do
    in_time
    if [[ "$seg" == "$end" ]]; then ended=1; continue; fi
    AND=0
    if [[ "$seg" == *$'\002'* ]]; then AND=1; seg="${seg//$'\002'/}"; fi
    segment "$seg"
    if [[ "$seg" == *[![:space:]]* ]] && (( ! AND )); then CHAIN=0; fi
  done < <(printf '%s\n' "$text" | LC_ALL=C grep -v $'^\001' | LC_ALL=C sed $'s/&&/ \002\\&\\&/g' | tr ';&|()`' '\n\n\n\n\n\n' && printf '%s\n' "$end")
  (( ended )) || block "this command" "the command text could not be split into simple commands (a program failed)"
  (( ALL_SAFE )) && return 0
  for g in ${LINKS[@]+"${LINKS[@]}"}; do
    in_time
    check_existing "$g"
  done
  # Unquoted shell globs (quoted strings and code fed to interpreters are not expanded by the
  # shell): what they match now is what the command would read.
  # (Each scan below also ends with the end line: a program that fails blocks, as in the split.)
  ended=0
  while IFS= read -r g; do
    if [[ "$g" == "$end" ]]; then ended=1; continue; fi
    [[ -n "$g" ]] && GLOBS+=("$g")
  done < <(printf '%s\n' "$text" | LC_ALL=C grep -v $'^\001' | sed -E "s/\"[^\"]*\"/ /g; s/'[^']*'/ /g" \
             | tr ';&|()`<>' '        ' | tr -s ' \t' '\n\n' | gq '[*?]' && printf '%s\n' "$end")
  (( ended )) || block "this command" "the command text could not be scanned for globs (a program failed)"
  text=$(printf '%s\n' "$text" | LC_ALL=C sed $'s/^\001//') || exit 2
  for g in ${GLOBS[@]+"${GLOBS[@]}"}; do
    in_time
    g="${g//\$\{HOME\}/$HOME}"; g="${g//\$HOME/$HOME}"
    [[ "$g" == "~/"* ]] && g="$HOME/${g#\~/}"
    [[ "$seen" == *" $g "* ]] && continue
    seen="$seen$g "
    candidate "$g"
  done

  # Exclude arguments name files in order to skip them: drop them before the name scan.
  text=$(printf '%s\n' "$text" | sed -E "s/--exclude(-dir)?(=|[[:space:]]+)(\"[^\"]*\"|'[^']*'|[^[:space:]]+)//g; s/(-g|--glob|--iglob)(=|[[:space:]]+)[\"']?![^[:space:]\"']*[\"']?//g") || exit 2
  # Home spellings, then every name that looks like a secret, quoted or not.
  text="${text//\$\{HOME\}/$HOME}"; text="${text//\$HOME/$HOME}"
  text=$(printf '%s\n' "$text" | sed -E "s#(^|[[:space:]\"'=:(])~/#\1$HOME/#g") || exit 2
  ended=0
  while IFS= read -r c; do
    in_time
    if [[ "$c" == "$end" ]]; then ended=1; continue; fi
    # A name with * or ? here is a pattern: quoted, so the shell never expands it (--exclude='*.env'),
    # or unquoted, and already expanded above with the other globs.
    [[ "$c" == *[\*\?]* ]] && continue
    candidate "$c"
  done < <( { printf '%s\n' "$text" | gq -oiE "$D*($IND)$D*" &&
              printf '%s\n' "$text" | gq -oE "\"[^\"]*\"|'[^']*'" | gq -iE "$IND" | sed -E "s/^[\"']//; s/[\"']\$//"
            } 2>/dev/null | sort -u && printf '%s\n' "$end")
  (( ended )) || block "this command" "the command text could not be scanned for secret names (a program failed)"
  return 0
}

# ---------- dispatch ----------
patch=""
if [[ "$tool" == apply_patch ]]; then
  patch=$(field '.tool_input.command // .tool_input.patch // .tool_input.input // "" | if type == "array" then join("\n") else tostring end')
elif [[ "$tool" != Bash && "$tool" != Shell && "$tool" != run_terminal_command ]]; then
  patch=$(field 'if (.tool_input | type) == "object" then (.tool_input.command // "") else "" end | if type == "string" then . else "" end')
  [[ "$patch" == *"*** Begin Patch"* ]] || patch=""
fi

if [[ "$tool" == apply_patch || -n "$patch" ]]; then
  REFS_OK=0
  paths=$(printf '%s\n' "$patch" | sed -n -E 's/^\*\*\* (Add|Update|Delete) File:[[:space:]]*(.*)$/\2/p; s/^\*\*\* Move to:[[:space:]]*(.*)$/\1/p' | sed -E 's/[[:space:]]+$//')
  [[ -n "$paths" ]] || block "the patch" "no file path could be read from it"
  while IFS= read -r p; do
    if [[ -n "$p" ]]; then check_file "$p"; fi
  done <<<"$paths" || exit 2
  exit 0
fi

case "$tool" in
  Bash|Shell|run_terminal_command)
    SHELL_MODE=1
    cmd=$(field '.tool_input.command // "" | if type == "array" then join(" ") else tostring end')
    [[ -z "$cmd" ]] && exit 0
    shell_command "$cmd"
    ;;
  Grep)
    p=$(field '.tool_input.path // .tool_input.file_path // ""')
    g=$(field '.tool_input.glob // ""')
    ty=$(field '.tool_input.type // ""')
    [[ -n "$g" ]] && include_glob "$g"
    if [[ -n "$p" && ! -d "$p" ]]; then
      check_file "$p"
    elif [[ -z "$ty" ]]; then
      search Grep 1 0 "${p:-.}"
    fi
    ;;
  *)
    case "$tool" in
      Write) NEW_TEXT=$(field '.tool_input.content // ""'); HAS_NEW=1 ;;
      Edit) NEW_TEXT=$(field '.tool_input.new_string // ""'); HAS_NEW=1 ;;
      MultiEdit) NEW_TEXT=$(field '[.tool_input.edits[]?.new_string // ""] | join("\n")'); HAS_NEW=1 ;;
    esac
    path=$(field '.tool_input.file_path // ""')
    [[ -z "$path" ]] && exit 0
    check_file "$path"
    ;;
esac
exit 0
