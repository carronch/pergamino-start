#!/bin/bash
# Checks the /review-pr read guard without any model call (SKILL.md § Review, step 5).
#   1. reviewer-guard.sh, with stub codex and claude: refuses bad input and a reviewer's
#      folder in /tmp or $TMPDIR; writes every line of reviewer-guard.txt as the sandbox
#      sees it (~/ is the home folder, links resolved, a * in a path's first part kept with
#      one slash, plus the target of each link that a * rule matches, and for Codex each *
#      rule again with /** added); refuses a rule over the reviewer's folder, also when the
#      rule is written through a link (/var/tmp) or covers every path (/*); runs its Codex
#      check without the operator's Codex settings; stops and leaves no file when codex
#      cannot start its sandbox, can only read (a read-only fallback) or fails after its
#      probe, or when Claude Code's sandbox is off or not strict; adds a rule for each of the
#      kit's folders (from the environment or from the kit's settings file, read as text) and
#      for each line of reviewer-guard.local.txt, and stops on a kit folder that is not absolute.
#   2. The reviewer lines of SKILL.md, with stub reviewers: a missing guard file stops each
#      reviewer; the Codex line leaves out the operator's Codex settings and the skill list
#      and sets effort high; a Codex log without the workspace-write sandbox or without effort
#      high fails the Codex run; steps 2 and 3 make their folders in ~/.cache, and on a made-up repository step 8.6's commands
#      leave nothing there and no worktree record in git, also when a test left an untracked
#      file in the worktree; nor does step 2's stop when git worktree add fails, or stops
#      after it registered the folder; neither clean-up passes --force; step 8.6 keeps a
#      worktree only for a fix that is not committed, as step 7 does on a refused push; each
#      stop that removes them points at those commands; the text says what the checks check.
#   3. Codex's own sandbox under the rendered profile (`codex sandbox`, the policy that
#      `codex exec` applies, also without the operator's Codex settings: each Codex call
#      sets its own CODEX_HOME, and the operator's stand-in does not parse): a probe file at
#      each listed path cannot be read (for a *, also the name with no characters in its
#      place, a file in a folder that the * matches, and a link's target), a file next to it
#      can; /Vol* refuses /Volumes; in a copy a read, a test run and a write work, and a
#      write in the reviewer's folder does not; under the real profile, files in the copy
#      named like a * rule (-key, -token, _history) can be read: a * does not match a /; the
#      real ~/Documents cannot be listed or read; a probe in a brain folder named by
#      PERGAMINO_LLM_BRAIN cannot be read; the real codex and claude accept the guard,
#      also when the operator's config.toml does not parse or refuses the reviewer's folder;
#      with skills.include_instructions=false the model-visible prompt lists no skills, and
#      without it, it does (skipped when Codex finds no skill here: with the stub codex, a
#      home with no skill skips that check and a home with one fails it); inside a sandbox
#      this test exits 2 and says to run it outside; without timeout it exits 2 and says so.
# Claude Code cannot run a shell command in its sandbox without a model, so its denyRead is
# proven by live runs (PURPOSE.md). A check that cannot run here is skipped with
# its reason, and the test then exits 2, so a skip never reads as a pass.
# The probe files live in a fake home folder under ~/.cache/review-pr-test.*, which the test
# removes; no real file under a listed path is opened. Usage: bash reviewer-guard.test.sh.
# Exit 0: every check ran and passed; 1: a check failed; 2: no check failed, but some could
# not run here. Bash 3.2.
# REVIEWER_GUARD_TEST_INNER and REVIEWER_GUARD_TEST_NO_TIMEOUT are for its own self-checks.
set -u
# The kit's own folders and the user's local list would add rules to every rendering below:
# leave them out, and add them only in the checks that test them.
unset PERGAMINO_MAIN_BRAIN PERGAMINO_LLM_BRAIN PERGAMINO_HOME
export PERGAMINO_ENV_FILE="" REVIEWER_GUARD_LOCAL=""

HERE=$(cd "$(dirname "$0")" && pwd -P)
GUARD="$HERE/reviewer-guard.sh"
LIST="$HERE/../reviewer-guard.txt"
SKILL="$HERE/../SKILL.md"
NL='
'
pass=0 fail=0 skip=0 reasons=""
OUTSIDE="run this test from a shell outside any sandbox (for example in Terminal)"
R_SANDBOX="this shell runs in a sandbox, and macOS refuses a sandbox inside one: $OUTSIDE"
R_TEMP="this shell cannot make a folder in ~/.cache (a sandbox refuses it): $OUTSIDE"
R_DIRS="this shell cannot make a folder in /tmp or /var/tmp (a sandbox refuses it): $OUTSIDE"
R_TIMEOUT="the timeout command is missing: install it (brew install coreutils); step 5 needs it too"
R_SKILLS="Codex finds no skill on this machine (none in ~/.agents/skills, none bundled), so no prompt can show that skills.include_instructions=false hides them: install the kit's skills there first"

ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
no() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
skipped() { # name, reason
  skip=$((skip + 1)); printf 'skip %s\n' "$1"
  case "$NL$reasons" in *"$NL$2$NL"*) ;; *) reasons="$reasons$2$NL" ;; esac
}
works() { local name=$1; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else no "$name"; fi; }
fails() { local name=$1; shift; if "$@" >/dev/null 2>&1; then no "$name"; else ok "$name"; fi; }
has() { if grep -qF -- "$2" "$3" 2>/dev/null; then ok "$1"; else no "$1"; fi; }
finish() {
  printf '\n%s passed, %s failed, %s skipped\n' "$pass" "$fail" "$skip"
  [ "$fail" -eq 0 ] || exit 1
  [ "$skip" -eq 0 ] && exit 0
  printf 'INCOMPLETE: checks were skipped, because:\n%s' "$reasons" | sed '2,$s/^/- /'
  exit 2
}

# The renderer refuses a folder in /tmp or $TMPDIR, so the test works in ~/.cache, as step 3 does.
T=$(mkdir -p "$HOME/.cache" 2>/dev/null && mktemp -d "$HOME/.cache/review-pr-test.XXXXXX" 2>/dev/null) ||
  { skipped "every check" "$R_TEMP"; finish; }
T=$(cd "$T" && pwd -P)
trap 'rm -rf "$T"' EXIT

# Stub reviewers. codex: `sandbox` acts as $STUB_CODEX_SANDBOX says: ok; readonly, like a
# read-only fallback (/usr/bin/true runs, anything else is refused like a write); writefail,
# which writes the probe file and then fails; userconfig, which fails when the operator's
# config.toml is in its CODEX_HOME; or nested, like a shell inside a sandbox. `exec`
# notes its run, writes its -o file and logs a sandbox line; `debug prompt-input` prints a
# prompt that lists no skills. claude: `sandbox status` prints $STUB_CLAUDE_STATUS; -p notes
# its run.
mkdir -p "$T/stub"
cat > "$T/stub/codex" <<'EOF'
#!/bin/sh
case "$1" in
  sandbox)
    last=""; for a in "$@"; do last=$a; done
    case "${STUB_CODEX_SANDBOX:-ok}" in
      ok) exit 0 ;;
      readonly) [ "$last" = /usr/bin/true ] && exit 0
        echo "sh: .reviewer-guard-probe: Operation not permitted" >&2; exit 1 ;;
      writefail) echo probe > .reviewer-guard-probe; echo "error: the stub fails after its probe" >&2; exit 1 ;;
      userconfig) [ -e "${CODEX_HOME:-$HOME/.codex}/config.toml" ] || exit 0
        echo "error: the stub loaded the operator's config.toml" >&2; exit 1 ;;
    esac
    echo "sandbox-exec: sandbox_apply: Operation not permitted" >&2; exit 71 ;;
  exec)
    echo codex >> "${STUB_RAN:-/dev/null}"
    printf '%s\n' "$@" > "${STUB_ARGS:-/dev/null}"
    o="" prev=""
    for a in "$@"; do [ "$prev" = -o ] && o=$a; prev=$a; done
    [ -n "$o" ] && echo "stub review" > "$o"
    echo "sandbox: ${STUB_SANDBOX_LINE:-workspace-write [workdir, /tmp, \$TMPDIR]}"
    echo "reasoning effort: ${STUB_EFFORT:-high}"
    exit 0 ;;
  debug) echo '[{"type": "message", "role": "user", "text": "Review this."}]'; exit 0 ;;
esac
exit 64
EOF
cat > "$T/stub/claude" <<'EOF'
#!/bin/sh
s=${STUB_CLAUDE_STATUS:-}
[ -n "$s" ] || s='{"enabled":true,"strictMode":true}'
for a in "$@"; do
  case "$a" in
    status) printf '%s\n' "$s"; exit 0 ;;
    -p) echo claude >> "${STUB_RAN:-/dev/null}"; echo "stub review"; exit 0 ;;
  esac
done
exit 64
EOF
chmod +x "$T/stub/codex" "$T/stub/claude"
SP="$T/stub:$PATH"

# A copy of the renderer next to its own list, for the bad-input checks.
fake_skill() {
  rm -rf "$T/skill"; mkdir -p "$T/skill/scripts"
  cp "$GUARD" "$T/skill/scripts/reviewer-guard.sh"
  printf '%s\n' "$@" > "$T/skill/reviewer-guard.txt"
}
FG="$T/skill/scripts/reviewer-guard.sh"

echo "== 1. reviewer-guard.sh (stub codex and claude)"
mkdir -p "$T/rv" "$T/home/Documents/rv" "$T/home/realdir"
echo real > "$T/home/realfile"
ln -s "$T/home/realdir" "$T/home/linkdir"
ln -s realfile "$T/home/linkfile"
fails "refuses no argument" env PATH="$SP" bash "$GUARD"
fails "refuses a folder that does not exist" env PATH="$SP" bash "$GUARD" "$T/none"
fake_skill '# comments only' ''
fails "refuses a list with no paths" env PATH="$SP" bash "$FG" "$T/rv"
fake_skill 'Documents'
fails "refuses a path without ~/ or /" env PATH="$SP" bash "$FG" "$T/rv"
fake_skill '~/Docu"ments'
fails "refuses a path with a double quote" env PATH="$SP" bash "$FG" "$T/rv"
fake_skill '~/Docu?ments'
fails "refuses a path with a ?" env PATH="$SP" bash "$FG" "$T/rv"
fake_skill '~/Documents'
fails "refuses a rule over the reviewer's own folder" env PATH="$SP" HOME="$T/home" bash "$FG" "$T/home/Documents/rv"
fails "writes nothing when it refuses" test -e "$T/home/Documents/rv/codex-filesystem.toml"
fake_skill '~/Documents'
for top in /tmp "${TMPDIR:-/tmp}"; do
  if D=$(mktemp -d "${top%/}/reviewer-guard-test.XXXXXX" 2>/dev/null); then
    o=$(env PATH="$SP" HOME="$T/home" bash "$FG" "$D" 2>&1)
    case "$?:$o" in 1:*"where a reviewer's commands can write"*) ok "refuses a reviewer's folder in $top, where a reviewer can write" ;;
      *) no "accepts a reviewer's folder in $top: $o" ;; esac
    rm -rf "$D"
  else
    skipped "a reviewer's folder in $top" "$R_DIRS"
  fi
done
if D=$(mktemp -d /var/tmp/reviewer-guard-test.XXXXXX 2>/dev/null); then
  fake_skill '/var/tmp'
  o=$(env PATH="$SP" HOME="$T/home" bash "$FG" "$D" 2>&1)
  case "$?:$o" in 1:*"holds the reviewer's folder"*) ok "refuses a rule over the reviewer's folder written through a link (/var/tmp)" ;;
    *) no "does not refuse a rule over the reviewer's folder written as /var/tmp: $o" ;; esac
  rm -rf "$D"
else
  skipped "a rule over the reviewer's folder written as /var/tmp" "$R_DIRS"
fi
# A * rule that matches a link: the link's target gets a rule too.
mkdir -p "$T/home/.cache" "$T/home/config-store" "$T/rvlink"
echo secret > "$T/home/config-store/token"; echo other > "$T/home/config-store/other"
ln -s "$T/home/config-store/token" "$T/home/.cache/demo-token"
fake_skill '~/.cache/*-token'
env PATH="$SP" HOME="$T/home" bash "$FG" "$T/rvlink" >/dev/null 2>&1
has "a * rule keeps its pattern" "\"$T/home/.cache/*-token\" = \"deny\"" "$T/rvlink/codex-filesystem.toml"
has "a * rule adds the target of each link it matches" "\"$T/home/config-store/token\" = \"deny\"" "$T/rvlink/codex-filesystem.toml"
# Codex's * rule refuses the names it matches, not the files in a matched folder.
has "a * rule also refuses, for Codex, the files in a folder it matches (/**)" "\"$T/home/.cache/*-token/**\" = \"deny\"" "$T/rvlink/codex-filesystem.toml"
rm -f "$T/home/.cache/demo-token"  # the real-list checks below count one rule per line
fake_skill '/*'
fails "refuses a rule over every path (/*)" env PATH="$SP" HOME="$T/home" bash "$FG" "$T/rv"
fake_skill '/Vol*'
env PATH="$SP" HOME="$T/home" bash "$FG" "$T/rv" >/dev/null 2>&1
has "writes a * in a path's first part with one slash (/Vol*)" '{"/Vol*" = "deny", "/Vol*/**" = "deny"}' "$T/rv/codex-filesystem.toml"
fake_skill '  ~/Documents/  ' '# a comment' '/Volumes'
env PATH="$SP" HOME="$T/home" bash "$FG" "$T/rv" >/dev/null 2>&1
has "trims spaces and a trailing slash" "{\"$T/home/Documents\" = \"deny\", \"/Volumes\" = \"deny\"}" "$T/rv/codex-filesystem.toml"
fake_skill "/tmp/reviewer-guard-absent-$$/x" '~/linkdir' '~/linkfile' "/tmp/reviewer-guard-two-$$" "/private/tmp/reviewer-guard-two-$$"
env PATH="$SP" HOME="$T/home" bash "$FG" "$T/rv" >/dev/null 2>&1
has "writes an absolute path as the sandbox sees it (/tmp is /private/tmp)" "\"/private/tmp/reviewer-guard-absent-$$/x\" = \"deny\"" "$T/rv/codex-filesystem.toml"
has "writes a linked folder as its target" "\"$T/home/realdir\" = \"deny\"" "$T/rv/codex-filesystem.toml"
has "writes a linked file as its target" "\"$T/home/realfile\" = \"deny\"" "$T/rv/codex-filesystem.toml"
m=$(grep -o "\"/private/tmp/reviewer-guard-two-$$\" = \"deny\"" "$T/rv/codex-filesystem.toml" | wc -l | tr -d ' ')
if [ "$m" = 1 ]; then ok "writes one rule for two spellings of one path"; else no "writes $m rules for two spellings of one path"; fi
fake_skill '~/Documents'
o=$(env PATH="$SP" HOME="$T/home" STUB_CODEX_SANDBOX=nested bash "$FG" "$T/rv" 2>&1)
case "$?:$o" in 1:*"outside any sandbox"*) ok "stops when this shell runs in a sandbox, and says so" ;; *) no "does not stop in a sandboxed shell: $o" ;; esac
fails "leaves no file when it stops" test -e "$T/rv/claude-settings.json"
mkdir -p "$T/rv4"
env PATH="$SP" HOME="$T/home" STUB_CODEX_SANDBOX=writefail bash "$FG" "$T/rv4" >/dev/null 2>&1
fails "leaves no probe file when Codex fails after its probe" test -e "$T/rv4/.reviewer-guard-probe"
fails "leaves no Codex settings folder of its own when it stops" test -e "$T/rv4/.reviewer-guard-codex-home"
o=$(env PATH="$SP" HOME="$T/home" STUB_CODEX_SANDBOX=readonly bash "$FG" "$T/rv" 2>&1)
case "$?:$o" in 1:*"cannot write"*) ok "stops when Codex's sandbox can only read (a read-only fallback)" ;; *) no "does not stop on a read-only Codex sandbox: $o" ;; esac
# The review's Codex line passes --ignore-user-config, which `codex sandbox` does not take:
# the check runs with an empty CODEX_HOME instead.
mkdir -p "$T/ch-op"; echo 'model_reasoning_effort = "low"' > "$T/ch-op/config.toml"
o=$(env PATH="$SP" HOME="$T/home" CODEX_HOME="$T/ch-op" STUB_CODEX_SANDBOX=userconfig bash "$FG" "$T/rv" 2>&1)
case "$?:$o" in 0:*) ok "runs its Codex check without the operator's config.toml, as the review does" ;;
  *) no "runs its Codex check with the operator's config.toml: $o" ;; esac
fails "leaves no Codex settings folder of its own when it succeeds" test -e "$T/rv/.reviewer-guard-codex-home"
fails "stops when Claude Code's sandbox is off" env PATH="$SP" HOME="$T/home" STUB_CLAUDE_STATUS='{"enabled":false,"strictMode":false}' bash "$FG" "$T/rv"
fails "stops when Claude Code's sandbox is not strict" env PATH="$SP" HOME="$T/home" STUB_CLAUDE_STATUS='{"enabled":true,"strictMode":false}' bash "$FG" "$T/rv"

# The kit's own folders and the user's local list.
mkdir -p "$T/home/MainBrain" "$T/home/LLMBrain" "$T/home/kit" "$T/rvk"
fake_skill '~/Documents'
env PATH="$SP" HOME="$T/home" PERGAMINO_MAIN_BRAIN="$T/home/MainBrain" PERGAMINO_LLM_BRAIN='~/LLMBrain' \
  PERGAMINO_HOME="$T/home/kit/" bash "$FG" "$T/rvk" >/dev/null 2>&1
has "adds a rule for PERGAMINO_MAIN_BRAIN" "\"$T/home/MainBrain\" = \"deny\"" "$T/rvk/codex-filesystem.toml"
has "adds a rule for PERGAMINO_LLM_BRAIN written with ~/" "\"$T/home/LLMBrain\" = \"deny\"" "$T/rvk/codex-filesystem.toml"
has "adds a rule for PERGAMINO_HOME, without its trailing slash" "\"$T/home/kit\"" "$T/rvk/claude-settings.json"
rm -f "$T/rvk/"*
printf '# the kit settings\nexport PERGAMINO_LLM_BRAIN="$HOME/LLMBrain"\nPERGAMINO_MAIN_BRAIN=%s\n' "'$T/home/MainBrain'" > "$T/home/kit-settings.txt"
env PATH="$SP" HOME="$T/home" PERGAMINO_ENV_FILE="$T/home/kit-settings.txt" bash "$FG" "$T/rvk" >/dev/null 2>&1
has "reads PERGAMINO_LLM_BRAIN from the settings file (export, quotes, \$HOME/)" "\"$T/home/LLMBrain\" = \"deny\"" "$T/rvk/codex-filesystem.toml"
has "reads PERGAMINO_MAIN_BRAIN from the settings file (single quotes)" "\"$T/home/MainBrain\" = \"deny\"" "$T/rvk/codex-filesystem.toml"
rm -f "$T/rvk/"*
printf 'PERGAMINO_LLM_BRAIN=$(touch %s)\n' "$T/home/ran-it" > "$T/home/bad-settings.txt"
env PATH="$SP" HOME="$T/home" PERGAMINO_ENV_FILE="$T/home/bad-settings.txt" bash "$FG" "$T/rvk" >/dev/null 2>&1
fails "never runs the settings file: a command in a value does not run" test -e "$T/home/ran-it"
fails "stops on a kit folder that is not an absolute path" env PATH="$SP" HOME="$T/home" PERGAMINO_LLM_BRAIN=LLMBrain bash "$FG" "$T/rvk"
env PATH="$SP" HOME="$T/home" PERGAMINO_LLM_BRAIN="$T/home/no-such-brain" bash "$FG" "$T/rvk" >/dev/null 2>&1
m=$(grep -c 'no-such-brain' "$T/rvk/codex-filesystem.toml" 2>/dev/null)
if [ "${m:-x}" = 0 ]; then ok "a kit folder that does not exist adds no rule"; else no "a kit folder that does not exist: ${m:-no file written}"; fi
fails "stops on a rule over the reviewer's folder from a kit folder" env PATH="$SP" HOME="$T/home" PERGAMINO_HOME="$T" bash "$FG" "$T/rvk"
rm -f "$T/rvk/"*
printf '# mine\n~/private-notes\n' > "$T/home/local.txt"
env PATH="$SP" HOME="$T/home" REVIEWER_GUARD_LOCAL="$T/home/local.txt" bash "$FG" "$T/rvk" >/dev/null 2>&1
has "adds each line of the local list" "\"$T/home/private-notes\" = \"deny\"" "$T/rvk/codex-filesystem.toml"
printf 'private-notes\n' > "$T/home/local-bad.txt"
o=$(env PATH="$SP" HOME="$T/home" REVIEWER_GUARD_LOCAL="$T/home/local-bad.txt" bash "$FG" "$T/rvk" 2>&1)
case "$?:$o" in 1:*"reviewer-guard.local.txt line 1"*) ok "a bad line in the local list stops the script and names the list" ;; *) no "a bad local line: $o" ;; esac

# The real list, rendered for a fake home folder.
rm -rf "$T/rv/"*
works "renders the real list" env PATH="$SP" HOME="$T/home" bash "$GUARD" "$T/rv"
o=$(env PATH="$SP" HOME="$T/home" bash "$GUARD" "$T/rv" 2>&1)
case "$o" in *"does not show the read list"*) ok "the success line says that Claude Code's status does not show the read list" ;; *) no "the success line claims more than its checks: $o" ;; esac
C="$T/rv/codex-filesystem.toml" J="$T/rv/claude-settings.json"
lines=$(grep -cvE '^[[:space:]]*(#|$)' "$LIST")
n=$(plutil -extract sandbox.filesystem.denyRead raw -o - "$J" 2>/dev/null || echo 0)
if [ "$n" = "$lines" ]; then ok "claude-settings.json lists all $lines paths"; else no "claude-settings.json lists $n of $lines paths"; fi
stars=$(grep -vE '^[[:space:]]*(#|$)' "$LIST" | grep -c '\*')
m=$(grep -o '" = "deny"' "$C" 2>/dev/null | wc -l | tr -d ' ')
if [ "$m" = $((lines + stars)) ]; then ok "codex-filesystem.toml lists all $lines paths, and each of the $stars * rules with /**"
else no "codex-filesystem.toml has $m rules, not $lines paths and $stars * rules with /**"; fi
has "~/Documents becomes the home folder's Documents" "\"$T/home/Documents\" = \"deny\"" "$C"
has "a * stays a pattern" "\"$T/home/.cache/*-key\" = \"deny\"" "$C"
has "an absolute path that is no link stays as it is" "\"/Volumes\"" "$J"
works "claude-settings.json is JSON" plutil -convert xml1 -o /dev/null "$J"
for k in enabled:true autoAllowBashIfSandboxed:true allowUnsandboxedCommands:false; do
  v=$(plutil -extract "sandbox.${k%%:*}" raw -o - "$J" 2>/dev/null)
  if [ "$v" = "${k#*:}" ]; then ok "sandbox.${k%%:*} is ${k#*:}"; else no "sandbox.${k%%:*} is '$v', not ${k#*:}"; fi
done

echo "== 2. SKILL.md step 5, with stub reviewers"
block=$(awk '
  /^   ```bash$/ { inb = 1; s = ""; next }
  inb && /^   ```$/ { inb = 0; if (s ~ /codex exec/ && s ~ /claude -p/) { printf "%s", s; exit }; next }
  inb { sub(/^   /, ""); s = s $0 "\n" }' "$SKILL")
case "$block" in *"codex exec"*"claude -p"*) ok "finds the reviewer lines in SKILL.md" ;; *) no "finds the reviewer lines in SKILL.md" ;; esac
case "$block" in *"grep -q '^sandbox: workspace-write \\['"*)
  if grep -qF 'starts with `sandbox: workspace-write [`' "$SKILL"; then ok "the text names the sandbox prefix that the Codex line checks"
  else no "the text does not say that the Codex line checks the prefix sandbox: workspace-write ["; fi ;;
  *) no "the Codex line does not check its log's sandbox line" ;;
esac
if [ -n "${REVIEWER_GUARD_TEST_NO_TIMEOUT:-}" ] || ! command -v timeout >/dev/null 2>&1; then
  skipped "the reviewer lines of SKILL.md step 5" "$R_TIMEOUT"
else
  step5() { # folder, env settings...: runs the reviewer lines there with the stub reviewers
    local R=$1; shift
    mkdir -p "$R/repo"; : > "$R/prompt.txt"; : > "$T/ran"; : > "$T/args"
    printf '%s\n' "$block" | sed "s|<RV>|$R|g" > "$R/step5.sh"
    (cd "$R" && env PATH="$SP" STUB_RAN="$T/ran" STUB_ARGS="$T/args" "$@" bash "$R/step5.sh" 2>/dev/null)
  }
  mkdir -p "$T/s5a" "$T/s5c" "$T/s5d"; for d in s5a s5c s5d; do cp "$C" "$J" "$T/$d/"; done
  o=$(step5 "$T/s5a" STUB_X=1)
  case "$o" in *"codex exit=0"*) ok "with the guard files, the Codex line runs" ;; *) no "with the guard files, the Codex line says: $o" ;; esac
  case "$o" in *"claude exit=0"*) ok "with the guard files, the Claude line runs" ;; *) no "with the guard files, the Claude line says: $o" ;; esac
  if grep -qx -- '--ignore-user-config' "$T/args" && grep -qx 'model_reasoning_effort="high"' "$T/args"; then
    ok "the Codex line leaves out the operator's Codex settings and sets effort high"
  else no "the Codex line does not pass --ignore-user-config and model_reasoning_effort=\"high\""; fi
  if grep -qx 'skills.include_instructions=false' "$T/args"; then ok "the Codex line leaves the skill list out of the reviewer's prompt"
  else no "the Codex line does not pass skills.include_instructions=false"; fi
  o=$(step5 "$T/s5d" STUB_EFFORT=none)
  case "$o" in *"codex exit=0"*) no "a Codex log with another effort still passes" ;; *"codex exit="*) ok "a Codex log without effort high fails the Codex run" ;; *) no "the Codex line printed no exit: $o" ;; esac
  o=$(step5 "$T/s5b" STUB_X=1); ran=$(cat "$T/ran")
  case "$o" in *"codex exit=0"*) no "without codex-filesystem.toml, Codex still ran" ;; *"codex exit="*) ok "without codex-filesystem.toml, the Codex line stops" ;; *) no "the Codex line printed no exit: $o" ;; esac
  case "$o" in *"claude exit=0"*) no "without claude-settings.json, Claude still ran (with no sandbox)" ;; *"claude exit="*) ok "without claude-settings.json, the Claude line stops" ;; *) no "the Claude line printed no exit: $o" ;; esac
  if [ -z "$ran" ]; then ok "without the guard files, no reviewer starts"; else no "without the guard files, these started: $ran"; fi
  o=$(step5 "$T/s5c" STUB_SANDBOX_LINE=danger-full-access)
  case "$o" in *"codex exit=0"*) no "a Codex log without the workspace-write sandbox still passes" ;; *"codex exit="*) ok "a Codex log without the workspace-write sandbox fails the Codex run" ;; *) no "the Codex line printed no exit: $o" ;; esac
  # Steps 2 and 3: the worktree and <RV> lie where no reviewer's commands can write.
  if grep -qF 'RV="$(mkdir -p ~/.cache && mktemp -d ~/.cache/review-pr.XXXXXX)"' "$SKILL"; then ok "step 3 makes <RV> in ~/.cache"
  else no "step 3 does not make <RV> in ~/.cache"; fi
  if grep -qF 'WT="$(mkdir -p ~/.cache && mktemp -d ~/.cache/review-pr-wt.XXXXXX)"' "$SKILL"; then ok "step 2 makes the worktree in ~/.cache"
  else no "step 2 does not make the worktree in ~/.cache"; fi
fi
# Steps 2 and 3 as written, on a made-up repository in a fake home, then the commands of
# step 8.6: nothing may stay in ~/.cache, which macOS never empties.
skill_block() { # text: the first ```bash block of SKILL.md, indented 3 spaces, that holds it
  awk -v want="$1" '
    /^   ```bash$/ { inb = 1; s = ""; next }
    inb && /^   ```$/ { inb = 0; if (index(s, want)) { printf "%s", s; exit }; next }
    inb { sub(/^   /, ""); s = s $0 "\n" }' "$SKILL"
}
FH="$T/fakehome" MR="$T/made-up-repo"
mkdir -p "$FH"
# One file in the commit, so that a worktree whose checkout did not finish differs from it.
git init -q "$MR" && echo one > "$MR/README" && git -C "$MR" add README &&
  git -C "$MR" -c core.hooksPath=/dev/null -c commit.gpgsign=false -c user.name=t \
  -c user.email=t@example.invalid commit -q -m one
sha=$(git -C "$MR" rev-parse HEAD) && git -C "$MR" update-ref refs/remotes/origin/master "$sha"
skill_block 'worktree add --detach' | sed "s|<n>|7|g; s|<headRefOid>|$sha|g; s|<base>|master|g" > "$T/step2.sh"
steps23() { # steps 2 and 3 as written, in the made-up repository: sets wt, rv and o (step 3's output)
  o=$(cd "$MR" && HOME="$FH" bash "$T/step2.sh" 2>&1); wt=$(printf '%s\n' "$o" | sed -n 's/^WT=//p')
  skill_block 'mktemp -d ~/.cache/review-pr.XXXXXX' | sed "s|<worktree>|$wt|g" > "$T/step3.sh"
  o=$(cd "$MR" && HOME="$FH" bash "$T/step3.sh" 2>&1); rv=$(printf '%s\n' "$o" | sed -n 's/^RV=//p')
}
records() { git -C "$MR" worktree list --porcelain | grep -c '^worktree '; }  # 1: the repository alone
fresh() { rm -rf "$FH/.cache"; git -C "$MR" worktree prune; }  # each case below starts clean
# The clean-up commands run from a folder outside any repository, as in a session that ran step
# 8.2 from there; GIT_CEILING_DIRECTORIES keeps git from finding a repository above it.
NOREPO="$T/outside-any-repo"; mkdir -p "$NOREPO"
outside() { (cd "$NOREPO" && GIT_CEILING_DIRECTORIES="$T" HOME="$FH" bash "$1" >/dev/null 2>&1); }
steps23
case "$wt|$rv|$o" in "$FH/.cache/"*"|$FH/.cache/"*"|"*"copy ok"*) ok "steps 2 and 3 make the worktree and the copy in ~/.cache" ;;
  *) no "steps 2 and 3 as written: WT=$wt RV=$rv: $o" ;; esac
# Step 8.6's commands: each `...` on its line that names <worktree> or <RV>, in their order.
c86=$(grep -F 'worktree remove <worktree>' "$SKILL" | grep -F 'rm -rf <RV>' | grep -o '`[^`]*`' | tr -d '`' |
  grep -E '<worktree>|<RV>' | grep -E 'worktree (remove|prune)|rmdir|rm -rf')
step86() { # runs them on $wt and $rv, with the made-up repository as this machine's checkout
  printf '%s\n' "$c86" | sed "s|<worktree>|$wt|g; s|<RV>|$rv|g; s|<checkout>|$MR|g" > "$T/step8-6.sh"
  outside "$T/step8-6.sh"
}
step86
left=$(ls -A "$FH/.cache" 2>/dev/null)
if [ -n "$c86" ] && [ -n "$wt" ] && [ -z "$left" ]; then ok "step 8.6's commands leave nothing of the review in ~/.cache"
else no "step 8.6's commands leave this in ~/.cache: ${left:-nothing, but no worktree was made or no command ran}"; fi
# A test in step 7 can leave a file that git does not track, and then git worktree remove
# refuses the worktree. The case shows the end state; the text check
# below shows that the fallback runs only then.
fresh; steps23; [ -z "$wt" ] || echo artifact > "$wt/red-first.log"
step86
left=$(ls -A "$FH/.cache" 2>/dev/null); recs=$(records)
if [ -n "$wt" ] && [ -z "$left" ] && [ "$recs" = 1 ]; then ok "step 8.6's commands leave nothing in ~/.cache and no worktree record when a test left an untracked file"
else no "step 8.6's commands, after a test left an untracked file, leave this in ~/.cache: ${left:-nothing}; worktrees in git: $recs, not 1"; fi
# The fallback deletes what git worktree remove protects: a fix that is not committed. A clean
# worktree goes with the plain command even when its commits were never pushed, and step 7
# drops those on a refused push and starts again, so 8.6 must not say to keep it then.
has "step 8.6 runs the fallback only when no fix is left uncommitted" 'When it lists a fix that is not committed, keep the worktree' "$SKILL"
if grep -F 'worktree remove <worktree>' "$SKILL" | grep -F 'rm -rf <RV>' | grep -qi 'refused push.*keep the worktree'; then
  no "step 8.6 keeps the worktree on a refused push, but step 7 removes it then and starts again"
else ok "step 8.6 agrees with step 7 on a refused push"; fi
# A stop on a gitleaks finding leaves a clean worktree with a commit that is not pushed, and
# step 8.6 removes it, so the text must not say that a committed fix is always safe.
if grep -qF 'A committed fix needs no such care' "$SKILL"; then
  no "step 8.6 says a committed fix is always pushed or dropped, which a gitleaks stop is not"
else ok "step 8.6 makes no claim that a committed fix is always safe"; fi
# Step 2's stop when `git worktree add` fails (a commit that does not exist): there is no
# worktree, only the empty folder that mktemp made, and it must go too.
fresh; skill_block 'worktree add --detach' |
  sed "s|<n>|7|g; s|<headRefOid>|0000000000000000000000000000000000000000|g; s|<base>|master|g" > "$T/step2-bad.sh"
o=$(cd "$MR" && HOME="$FH" bash "$T/step2-bad.sh" 2>&1); wtb=$(printf '%s\n' "$o" | sed -n 's/^WT=//p')
stop=$(grep -F 'The last line prints the merge base' "$SKILL" | grep -o '`[^`]*`' | tr -d '`' | grep -F '<worktree>')
[ -n "$stop" ] || stop=$(printf '%s\n' "$c86" | grep -m1 'worktree remove')  # a stop that points at step 8.6
printf '%s\n' "$stop" | sed "s|<worktree>|$wtb|g; s|<checkout>|$MR|g" > "$T/step2-stop.sh"
outside "$T/step2-stop.sh"
left=$(ls -A "$FH/.cache" 2>/dev/null)
if [ -n "$wtb" ] && [ -n "$stop" ] && [ -z "$left" ]; then ok "step 2's stop leaves nothing in ~/.cache when git worktree add fails"
else no "step 2's stop leaves this in ~/.cache when git worktree add fails: ${left:-nothing, but no folder was made or no command ran}"; fi
# A git worktree add that stopped after it registered the folder (killed during its checkout)
# leaves the .git file in it and git's record of it. With --no-checkout,
# git worktree add leaves the same: a registered folder with no file of the commit in it.
fresh; mkdir -p "$FH/.cache"; wts=$(mktemp -d "$FH/.cache/review-pr-wt.XXXXXX") &&
  git -C "$MR" -c core.hooksPath=/dev/null worktree add --no-checkout --detach "$wts" "$sha" >/dev/null 2>&1 &&
  printf '%s\n' "$stop" | sed "s|<worktree>|$wts|g; s|<checkout>|$MR|g" > "$T/step2-stop2.sh" &&
  outside "$T/step2-stop2.sh"
left=$(ls -A "$FH/.cache" 2>/dev/null); recs=$(records)
if [ -n "$wts" ] && [ -n "$stop" ] && [ -z "$left" ] && [ "$recs" = 1 ]; then
  ok "step 2's stop leaves nothing in ~/.cache and no worktree record when git worktree add stopped after it registered the folder"
else no "step 2's stop, after git worktree add stopped, leaves this in ~/.cache: ${left:-nothing}; worktrees in git: $recs, not 1"; fi
case "$c86$NL$stop$NL" in *--force* | *" -f "* | *" -f$NL"*) no "a clean-up command passes --force, which deletes a fix that is not committed" ;;
  *) ok "the clean-up commands of steps 2 and 8.6 pass no --force" ;; esac
bad=$(awk '/^## Review/ { r = 1 } /^## Never/ { r = 0 } r' "$SKILL" | grep -i 'remove the worktree' |
  grep -v -e 'step 8\.6' -e 'worktree remove <worktree>')
if [ -z "$bad" ]; then ok "each stop that removes the worktree and the copy points at the commands of step 8.6"
else no "a stop removes the worktree and the copy with no command: $(printf '%s' "$bad" | cut -c1-100)"; fi
n5=$(awk '/^5\. \*\*Run the review/ { r = 1 } /^6\. \*\*Post the review/ { r = 0 } r' "$SKILL" | grep -o 'step 8\.6' | wc -l | tr -d ' ')
if [ "$n5" -ge 2 ]; then ok "step 5's two stops remove the worktree and the copy (step 8.6)"
else no "step 5's stops point at step 8.6 $n5 times, not 2"; fi
has "the text says why the Codex check runs with an empty CODEX_HOME" '`codex sandbox` has no `--ignore-user-config`' "$SKILL"

echo "== 3. Codex's sandbox under the rendered profile"
# An empty CODEX_HOME: the profile without the operator's config.toml, as the review applies it.
CH="$T/codex-home"; mkdir -p "$CH"
# A stand-in for the operator's Codex settings that does not parse: each Codex call below sets
# CODEX_HOME itself, and a call that read the operator's settings fails.
OP="$T/operator-codex-home"; mkdir -p "$OP"; echo 'this is = = not toml [[' > "$OP/config.toml"
export CODEX_HOME="$OP"
start=missing
if command -v codex >/dev/null 2>&1; then
  if start=$(cd "$T" && CODEX_HOME="$CH" codex sandbox -C "$T" -P ':workspace' -- /usr/bin/true 2>&1); then start=ok; fi
fi
if [ "$start" = missing ]; then
  no "codex is not installed (the skill needs it)"
elif [ "$start" != ok ]; then
  case "$start" in
    *sandbox_apply*) skipped "part 3" "$R_SANDBOX" ;;
    *) no "codex sandbox does not start: ${start:-no message}" ;;
  esac
else
  # The reviewer's copy: a file to read, a test to run, a file to write.
  mkdir -p "$T/copy"
  echo "copy file" > "$T/copy/a.txt"
  printf 'add() { echo $(($1 + $2)); }\n' > "$T/copy/lib.sh"
  printf '. ./lib.sh\n[ "$(add 2 3)" = 5 ]\n' > "$T/copy/test.sh"
  run() { (cd "$T/copy" && CODEX_HOME="$CH" codex sandbox -C "$T/copy" -P review_pr \
    -c 'permissions.review_pr.extends=":workspace"' -c "permissions.review_pr.filesystem=$(cat "$1")" -- "${@:2}"); }
  refused() { # name, rendered file, command, path: the sandbox refuses that path, not a missing file
    local name=$1 out; shift
    if out=$(run "$@" 2>&1); then no "$name (it worked)"
    else case "$out" in *"${!#}: Operation not permitted"*) ok "$name" ;; *) no "$name ($out)" ;; esac
    fi
  }
  # A probe at each listed path of the fake home, and a control file next to each.
  i=0
  while [ "$i" -lt "$n" ]; do
    p=$(plutil -extract "sandbox.filesystem.denyRead.$i" raw -o - "$J")
    i=$((i + 1))
    case "$p" in "$T/home/"*) ;; *)
      if [ -e "$p" ]; then refused "listing $p is refused" "$C" /bin/ls "$p"; fi
      continue ;;
    esac
    p0=$p
    p=$(printf '%s' "$p0" | sed 's/\*/probe/g')
    base=${p##*/}
    mkdir -p "${p%/*}"; echo control > "${p%/*}/control.txt"
    case "${base#.}" in
      *.*|*probe*|netrc|pgpass|npmrc|git-credentials)   # a file, as in a real home
        echo probe > "$p"; f=$p ;;
      *) mkdir -p "$p"; echo probe > "$p/probe.txt"; f="$p/probe.txt" ;;  # a folder
    esac
    refused "reading ${p#"$T/home/"} is refused" "$C" /bin/cat "$f"
    works "reading control.txt next to ${p#"$T/home/"} works" run "$C" /bin/cat "${p%/*}/control.txt"
    case "$p0" in *'*'*)  # a * also matches no characters: ~/.claude.json* covers ~/.claude.json
      e=$(printf '%s' "$p0" | sed 's/\*//g'); echo probe > "$e"
      refused "reading ${e#"$T/home/"} (no characters for the *) is refused" "$C" /bin/cat "$e"
      # A folder that the * matches: the files in it are refused too (for Codex, by the /** rule).
      d=$(printf '%s' "$p0" | sed 's/\*/dirprobe/g'); mkdir -p "$d"; echo probe > "$d/f"
      refused "reading a file in ${d#"$T/home/"}, a folder that the * matches, is refused" "$C" /bin/cat "$d/f" ;;
    esac
  done
  # Credential and settings files that a review once found missing from the list: each must
  # be refused, whether a line names it or a * covers it.
  for q in .netrc .pgpass .npmrc .git-credentials .docker/config.json .zsh_history \
      .bash_history .zsh_sessions/s.history .codex/config.toml .claude.json .claude.json.backup \
      .claude/settings.json .claude/settings.local.json .cursor/mcp.json; do
    case "$q" in */*) mkdir -p "$T/home/${q%/*}" ;; esac
    if [ -d "$T/home/$q" ]; then f="$T/home/$q/probe.txt"; else f="$T/home/$q"; fi
    [ -e "$f" ] || echo probe > "$f"
    refused "reading ~/$q is refused" "$C" /bin/cat "$f"
  done
  fake_skill '/Vol*'; mkdir -p "$T/vol"
  if bash "$FG" "$T/vol" >/dev/null 2>&1; then
    refused "a * in a path's first part (/Vol*) refuses /Volumes" "$T/vol/codex-filesystem.toml" /bin/ls /Volumes
  else
    no "/Vol* does not render with the real codex and claude"
  fi
  works "reading a file in the copy works" run "$C" /bin/cat a.txt
  works "running the copy's test works" run "$C" /bin/sh test.sh
  works "writing a file in the copy works" run "$C" /bin/sh -c 'echo x > out.txt && cat out.txt'
  o=$(run "$C" /bin/sh -c 'echo x > ../reviewer-folder-probe' 2>&1)
  if [ ! -e "$T/reviewer-folder-probe" ]; then ok "a command in the copy cannot write in the reviewer's folder (~/.cache)"
  else no "a command in the copy wrote in the reviewer's folder: $o"; fi
  refused "the target of a link that a * rule matches is refused" "$T/rvlink/codex-filesystem.toml" /bin/cat "$T/home/config-store/token"
  works "a file next to that target stays readable" run "$T/rvlink/codex-filesystem.toml" /bin/cat "$T/home/config-store/other"
  # Model-free: the prompt that Codex would send, with the Codex line's skills setting.
  (cd "$T/copy" && git init -q 2>/dev/null)
  if o=$(cd "$T/copy" && CODEX_HOME="$CH" codex debug prompt-input -c 'skills.include_instructions=false' "Review this." 2>/dev/null); then
    case "$o" in *"## Skills"*) no "with skills.include_instructions=false the prompt still lists skills" ;;
      *) ok "with skills.include_instructions=false the reviewer's prompt lists no skills" ;; esac
  else no "codex debug prompt-input fails"; fi
  # Without that setting the same prompt must list skills, or the check above proves nothing.
  # Codex lists the skills in ~/.agents/skills and the ones it bundles, which it writes into
  # CODEX_HOME/skills/.system (codex-cli 0.162.1). Where it finds none, no prompt can list a
  # skill, so the check is skipped, not failed.
  skills_listed() { # codex command, home folder, Codex home: prints ok, skip or fail
    local out f
    out=$(cd "$T/copy" && HOME="$2" CODEX_HOME="$3" "$1" debug prompt-input "Review this." 2>/dev/null)
    case "$out" in *"## Skills"*) echo ok; return ;; esac
    for f in "$2"/.agents/skills/*/SKILL.md "$3"/skills/.system/*/SKILL.md; do
      if [ -e "$f" ]; then echo fail; return; fi
    done
    echo skip
  }
  case $(skills_listed codex "$HOME" "$CH") in
    ok) ok "without that setting the same prompt lists skills, so the check above means something" ;;
    skip) skipped "without that setting the same prompt lists skills" "$R_SKILLS" ;;
    *) no "without skills.include_instructions=false the prompt lists no skills either: the check above proves nothing" ;;
  esac
  # The same decision with the stub codex, whose prompt lists no skills.
  mkdir -p "$T/noskill/home" "$T/noskill/codex-home" "$T/oneskill/home/.agents/skills/demo" "$T/oneskill/codex-home"
  printf -- '---\nname: demo\ndescription: a stand-in skill\n---\n' > "$T/oneskill/home/.agents/skills/demo/SKILL.md"
  r=$(skills_listed "$T/stub/codex" "$T/noskill/home" "$T/noskill/codex-home")
  if [ "$r" = skip ]; then ok "on a machine where Codex finds no skill, that check is skipped, not failed"
  else no "on a machine where Codex finds no skill, that check says $r, not skip"; fi
  r=$(skills_listed "$T/stub/codex" "$T/oneskill/home" "$T/oneskill/codex-home")
  if [ "$r" = fail ]; then ok "...but with a skill that the prompt does not list, it fails"
  else no "with a skill that the prompt does not list, that check says $r, not fail"; fi
  # The real home folder and the real reviewers: what the review gets on this machine.
  mkdir -p "$T/real"
  works "the real codex and claude accept the guard for the real home folder" bash "$GUARD" "$T/real"
  # The renderer's Codex check, like the review, runs without the operator's config.toml
  # : one that does not parse, or whose review_pr profile refuses the
  # reviewer's folder, would stop a review that would run.
  mkdir -p "$T/ch-prof" "$T/real2"
  printf '[permissions.review_pr.filesystem]\n"%s" = "deny"\n' "$T/real2" > "$T/ch-prof/config.toml"
  works "the Codex check ignores the operator's config.toml when it does not parse" env CODEX_HOME="$OP" bash "$GUARD" "$T/real2"
  works "the Codex check ignores a review_pr profile in the operator's config.toml" env CODEX_HOME="$T/ch-prof" bash "$GUARD" "$T/real2"
  refused "listing the real ~/Documents is refused" "$T/real/codex-filesystem.toml" /bin/ls "$HOME/Documents"
  case "$HERE/" in "$HOME/Documents/"*)
    refused "reading this test file under ~/Documents is refused" "$T/real/codex-filesystem.toml" /bin/cat "$HERE/reviewer-guard.test.sh" ;;
  esac
  works "the copy's test still runs under the real profile" run "$T/real/codex-filesystem.toml" /bin/sh test.sh
  # A brain folder named by PERGAMINO_LLM_BRAIN: a probe in it cannot be read.
  mkdir -p "$T/brainx" "$T/realb"; echo probe > "$T/brainx/page.md"
  if env PERGAMINO_LLM_BRAIN="$T/brainx" bash "$GUARD" "$T/realb" >/dev/null 2>&1; then
    refused "reading a page in the brain named by PERGAMINO_LLM_BRAIN is refused" "$T/realb/codex-filesystem.toml" /bin/cat "$T/brainx/page.md"
  else no "the guard does not render with PERGAMINO_LLM_BRAIN set"; fi
  # The copy lies under ~/.cache, below ~/.cache/*-key, ~/.cache/*-token and ~/.*_history. A *
  # matches no /, so files and folders in it named like those rules stay readable (Claude
  # Code's sandbox too, by a live run recorded in PURPOSE.md).
  mkdir -p "$T/copy/lib/get-key" "$T/copy/node_modules/csrf-token" "$T/copy/src/old_history"
  for f in api-key lib/get-key/f b-token node_modules/csrf-token/index.js .zsh_history \
      src/price_history.sql src/old_history/f; do
    echo probe > "$T/copy/$f"
    works "reading copy/$f works under the real profile" run "$T/real/codex-filesystem.toml" /bin/cat "$f"
  done
  if [ -z "${REVIEWER_GUARD_TEST_INNER:-}" ]; then
    o=$(REVIEWER_GUARD_TEST_INNER=1 sandbox-exec -p '(version 1)(allow default)(deny file-read* (literal "/private/var/empty/reviewer-guard-probe"))' \
      /bin/bash "$HERE/reviewer-guard.test.sh" 2>&1)
    case "$?:$o" in 2:*"outside any sandbox"*) ok "inside a sandbox, this test exits 2 and says where to run it" ;; *) no "inside a sandbox, this test does not exit 2: ${o##*"$NL"}" ;; esac
    o=$(REVIEWER_GUARD_TEST_INNER=1 REVIEWER_GUARD_TEST_NO_TIMEOUT=1 /bin/bash "$HERE/reviewer-guard.test.sh" 2>&1)
    case "$?:$o" in
      2:*"timeout command is missing"*)
        case "$o" in *"outside any sandbox"*) no "without timeout, INCOMPLETE also blames a sandbox" ;;
          *) ok "without timeout, this test exits 2 and names timeout, not a sandbox" ;; esac ;;
      *) no "without timeout, this test does not exit 2 naming timeout: ${o##*"$NL"}" ;;
    esac
  fi
fi

finish
