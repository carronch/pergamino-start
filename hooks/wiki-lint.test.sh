#!/usr/bin/env bash
# Test harness for hooks/wiki-lint.sh, the hook that checks the frontmatter of each page of <LLM brain>/wiki/
# a tool call writes: an Edit or Write by its path, a shell command by the pages that changed while it ran.
# Runs only in a temporary folder, under made-up HOMEs, kit roots and LLM brains, so it never reads the real
# brains: the first HOME has no memory folder; the second has a memory folder in Claude Code's folder for the
# kit (check 4 and the shell checks); the third has the memory folder in the LLM brain.
# HOOK_SHELL=/bin/bash runs the hook under macOS's bash 3.2.
#
# Usage: bash hooks/wiki-lint.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="${HOOK:-$HERE/wiki-lint.sh}"
SH="${HOOK_SHELL:-$(command -v bash)}"
fails=0
check() { if [[ "$2" == 0 ]]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

tmp="$(mktemp -d)" && [ -d "$tmp" ] || { echo "mktemp failed" >&2; exit 1; }; trap 'rm -rf "$tmp"' EXIT
W="$tmp/LLMBrain/wiki"; mkdir -p "$W" "$tmp/home" "$tmp/kit"
KIT="$tmp/kit"
page() {  # page <file> <frontmatter lines> <body lines> <line width> [first frontmatter line]
  local f="$1" fm="$2" body="$3" long i
  long=$(head -c "$4" /dev/zero | tr '\0' x)
  { echo ---; echo "${5:-title: t}"; for ((i = 2; i <= fm; i++)); do echo "note$i: $long"; done; echo ---
    for ((i = 1; i <= body; i++)); do echo "$long"; done; } > "$f"
}
lint() {  # lint <file>: runs the hook on a write to that file; exit code in $rc
  printf '{"tool_input":{"file_path":"%s"}}' "$1" | env -i HOME="$tmp/home" PATH=/usr/bin:/bin PERGAMINO_HOME="$KIT" PERGAMINO_LLM_BRAIN="$tmp/LLMBrain" "$SH" "$HOOK" 2>/dev/null
  rc=$?
}

page "$W/short.md" 1 3 20; lint "$W/short.md"; [[ $rc == 0 ]]; check "a short page with frontmatter passes" $?
page "$W/long-body.md" 1 100 1000; lint "$W/long-body.md"; [[ $rc == 0 ]]
check "a page whose first 80 lines exceed the pipe buffer passes" $?
page "$W/long-fm.md" 50 1 2000; lint "$W/long-fm.md"; [[ $rc == 0 ]]
check "a 50-line frontmatter over the pipe buffer passes" $?
page "$W/close-80.md" 78 0 10; lint "$W/close-80.md"; [[ $rc == 0 ]]; check "a closing --- on line 80 passes" $?
page "$W/close-81.md" 79 0 10; lint "$W/close-81.md"; [[ $rc == 2 ]]; check "a closing --- on line 81 is blocked" $?
printf -- '---\ntitle: t\nbody\n' > "$W/open.md"; lint "$W/open.md"; [[ $rc == 2 ]]; check "no closing --- is blocked" $?
echo '# Title' > "$W/none.md"; lint "$W/none.md"; [[ $rc == 2 ]]; check "no frontmatter is blocked" $?
page "$W/untitled.md" 3 1 10 "status: active"; lint "$W/untitled.md"; [[ $rc == 2 ]]
check "frontmatter without kind, type or title is blocked" $?
echo '# x' > "$tmp/LLMBrain/outside.md"; lint "$tmp/LLMBrain/outside.md"; [[ $rc == 0 ]]; check "a file outside wiki/ is skipped" $?

# Check 3 reads the first 40 lines of the frontmatter.
page "$W/untitled-long.md" 50 1 2000 "status: active"; lint "$W/untitled-long.md"; [[ $rc == 2 ]]
check "a 50-line frontmatter over the pipe buffer without kind, type or title is blocked with exit 2" $?
title_at() {  # title_at <file> <line>: a page whose title is on that line of its frontmatter
  local i; { echo ---; for ((i = 1; i < $2; i++)); do echo "note$i: x"; done; echo "title: t"; echo ---; } > "$1"
}
title_at "$W/title-40.md" 40; lint "$W/title-40.md"; [[ $rc == 0 ]]; check "a title on frontmatter line 40 passes" $?
title_at "$W/title-41.md" 41; lint "$W/title-41.md"; [[ $rc == 2 ]]; check "a title on frontmatter line 41 is blocked" $?

# A second HOME with an LLM brain, and a memory folder in Claude Code's folder for the kit: check 4, and pages
# written through the shell.
H="$tmp/h"; B="$H/LLMBrain"; V="$B/wiki"; MEM="$H/.claude/projects/$(printf '%s' "$KIT" | sed 's/[^A-Za-z0-9]/-/g')/memory"
mkdir -p "$V/concepts" "$MEM"
for m in feedback-x shared-name MEMORY; do echo x > "$MEM/$m.md"; done
good() { printf -- '---\ntitle: t\n---\n%s\n' "${2:-body}" > "$1"; }   # good <file> [body line]: a page that passes
good "$V/concepts/shared-name.md"
hook() {  # hook <event> <tool> <call id> [file_path]: one run in session s1; exit code in $rc, stderr in $err
  err=$(printf '{"hook_event_name":"%s","tool_name":"%s","session_id":"s1","tool_use_id":"%s","tool_input":{"file_path":"%s"}}' \
    "$1" "$2" "$3" "${4:-}" | env -i HOME="$H" PATH=/usr/bin:/bin PERGAMINO_HOME="$KIT" PERGAMINO_LLM_BRAIN="$B" "$SH" "$HOOK" 2>&1 >/dev/null)
  rc=$?
}

good "$V/memory-link.md" 'see [[feedback-x]]'; hook PostToolUse Write w1 "$V/memory-link.md"
[[ $rc == 2 && $err == *feedback-x* ]]; check "check 4: a [[memory slug]] link is blocked" $?
good "$V/memory-alias.md" 'see [[memory: feedback-x|the rule]]'; hook PostToolUse Edit w2 "$V/memory-alias.md"
[[ $rc == 2 && $err == *feedback-x* ]]; check "check 4: a [[memory: slug|alias]] link is blocked" $?
good "$V/not-memory.md" 'see [[shared-name]], [[feedback-x-2]], [[MEMORY]] and [[concepts/feedback-x]]'
hook PostToolUse Edit w3 "$V/not-memory.md"; [[ $rc == 0 ]]
check "check 4: a slug that is also a page's name, a longer name, MEMORY and a folder path pass" $?
good "$V/todo.md" 'quoted: [[feedback-x]]'; hook PostToolUse Edit w4 "$V/todo.md"; [[ $rc == 0 ]]
check "check 4: wiki/todo.md is exempt" $?

# Slugs are fixed text: a slug that went unescaped into an extended regex, in the per-slug greps or in the one-grep
# shortcut before them, would let a slug a.b also match [[aXb]].
echo x > "$MEM/a.b.md"
good "$V/dot-other.md" 'see [[aXb]]'; hook PostToolUse Edit w5 "$V/dot-other.md"; [[ $rc == 0 ]]
check "check 4: a memory slug a.b does not match [[aXb]]" $?
good "$V/dot-same.md" 'see [[a.b]]'; hook PostToolUse Edit w6 "$V/dot-same.md"; [[ $rc == 2 && $err == *a.b* ]]
check "check 4: [[a.b]] is still blocked" $?
good "$V/dot-both.md" 'see [[feedback-x]] and [[aXb]]'; hook PostToolUse Edit w9 "$V/dot-both.md"
[[ $rc == 2 && $err == *feedback-x* && $err != *a.b* ]]; check "check 4: a page that links a slug and [[aXb]] names the slug only" $?
mkdir -p "$tmp/gbin"; : > "$tmp/greps"
cat > "$tmp/gbin/grep" <<EOF
#!/bin/sh
# Stub: notes each extended-regex grep of dot-other.md (the shortcut, then one per slug), then runs the real grep.
for last; do :; done
[ "\$1" = -qE ] && [ "\$last" = "$V/dot-other.md" ] && echo x >> "$tmp/greps"
exec /usr/bin/grep "\$@"
EOF
chmod +x "$tmp/gbin/grep"
printf '{"hook_event_name":"PostToolUse","tool_name":"Edit","session_id":"s1","tool_use_id":"w7","tool_input":{"file_path":"%s"}}' \
  "$V/dot-other.md" | env -i HOME="$H" PATH="$tmp/gbin:/usr/bin:/bin" PERGAMINO_HOME="$KIT" PERGAMINO_LLM_BRAIN="$B" "$SH" "$HOOK" >/dev/null 2>&1
[[ $(wc -l < "$tmp/greps") -eq 1 ]]; check "check 4's shortcut: a page that links [[aXb]] needs no per-slug grep" $?
echo x > "$MEM/q?b.md"; good "$V/concepts/qXb.md"
good "$V/glob-link.md" 'see [[q?b]]'; hook PostToolUse Edit w8 "$V/glob-link.md"; [[ $rc == 2 && $err == *'q?b'* ]]
check "check 4: a slug q?b links as itself, and a page qXb.md does not share its name" $?

# Pages written through the shell. The hook gets no path: PreToolUse leaves a stamp for the call, and the run
# after the call (PostToolUse, or PostToolUseFailure when the command failed) lints the pages changed since.
hook PreToolUse Bash b1; pre=$rc; printf '# no frontmatter\n' > "$V/shell-bad.md"; hook PostToolUse Bash b1
[[ $pre == 0 && $rc == 2 && $err == *shell-bad.md* ]]; check "a page without frontmatter written through the shell is blocked" $?
hook PostToolUse Bash b1; [[ $rc == 0 ]]; check "the stamp goes after its run: a second run for the same call lints nothing" $?
hook PreToolUse Bash b2; good "$V/shell-good.md"; hook PostToolUse Bash b2; [[ $rc == 0 ]]
check "a good page written through the shell passes; the broken page from the call before is not linted again" $?
printf '# x\n' > "$V/before.md"; hook PreToolUse Bash b3; hook PostToolUse Bash b3; [[ $rc == 0 ]]
check "a page changed before the call started is not linted (another session's earlier write)" $?
hook PreToolUse Bash b4; printf '# x\n' > "$V/failed.md"; hook PostToolUseFailure Bash b4
[[ $rc == 2 && $err == *failed.md* ]]; check "a call that fails after it wrote a page still gets the page linted" $?
printf '# x\n' > "$tmp/moved.md"; touch -t 202501010000 "$tmp/moved.md"
hook PreToolUse Bash b5; mv "$tmp/moved.md" "$V/moved.md"; hook PostToolUse Bash b5
[[ $rc == 2 && $err == *moved.md* ]]; check "a page moved in with an old modification time is linted (change time)" $?
good "$V/sed.md"; hook PreToolUse Bash b6; sed -i.bak 1d "$V/sed.md"; rm -f "$V/sed.md.bak"; hook PostToolUse Bash b6
[[ $rc == 2 && $err == *sed.md* ]]; check "an in-place sed that deletes the opening --- is blocked" $?
good "$V/append.md"; hook PreToolUse Bash b7; echo 'see [[feedback-x]]' >> "$V/append.md"; hook PostToolUse Bash b7
[[ $rc == 2 && $err == *feedback-x* ]]; check "a shell append that links a memory slug is blocked (check 4)" $?
hook PreToolUse Bash b8; echo 'quoted: [[feedback-x]]' >> "$V/todo.md"; hook PostToolUse Bash b8; [[ $rc == 0 ]]
check "wiki/todo.md keeps its check-4 exemption through the shell" $?
hook PreToolUse Bash b9; printf '# x\n' > "$V/concepts/many-1.md"; printf '# x\n' > "$V/many-2.md"; good "$V/many-3.md"
hook PostToolUse Bash b9; [[ $rc == 2 && $err == *many-1.md* && $err == *many-2.md* && $err != *many-3.md* ]]
check "a call that writes several pages names each broken one" $?
hook PreToolUse Bash b10; hook PreToolUse Bash b11; printf '# x\n' > "$V/parallel.md"
hook PostToolUse Bash b10; r10=$rc; hook PostToolUse Bash b11; [[ $r10 == 2 && $rc == 2 ]]
check "two calls at once: the run after each call lints the page written while it ran" $?
hook PreToolUse Bash b12; printf '# x\n' > "$B/outside.md"; echo '{}' > "$V/_graph.json"
hook PostToolUse Bash b12; [[ $rc == 0 ]]; check "a file outside wiki/, or one that is not a page, is skipped" $?
hook PostToolUse Bash b13; [[ $rc == 0 ]]; check "a run after a call that left no stamp lints nothing" $?

# Fails open.
err=$(printf 'not json' | env -i HOME="$H" PATH=/usr/bin:/bin PERGAMINO_HOME="$KIT" PERGAMINO_LLM_BRAIN="$B" "$SH" "$HOOK" 2>&1 >/dev/null); rc=$?
[[ $rc == 0 ]]; check "input that is not JSON: exit 0" $?
H="$tmp/h2"; B="$H/LLMBrain"; mkdir -p "$B/wiki"; echo x > "$H/.cache"   # no state folder can be made here
hook PreToolUse Bash c1; pre=$rc; printf '# x\n' > "$B/wiki/no-state.md"; hook PostToolUse Bash c1
[[ $pre == 0 && $rc == 0 && -z "$err" ]]; check "no state folder: the shell check is skipped, never blocks and prints nothing" $?

# Check 4's memory folder: the one in the LLM brain when it exists. Claude Code's folder for the kit is the
# fallback when the brain has none (the second HOME above has only that one).
H="$tmp/h3"; B="$H/LLMBrain"; V="$B"; mkdir -p "$V/wiki" "$V/memory"; echo x > "$V/memory/vault-slug.md"
good "$V/wiki/vault-link.md" 'see [[vault-slug]]'; hook PostToolUse Edit m1 "$V/wiki/vault-link.md"
[[ $rc == 2 && $err == *vault-slug* ]]; check "check 4: a memory folder in the LLM brain is read" $?
MEM="$H/.claude/projects/$(printf '%s' "$KIT" | sed 's/[^A-Za-z0-9]/-/g')/memory"; mkdir -p "$MEM"; echo x > "$MEM/old-slug.md"
good "$V/wiki/old-link.md" 'see [[old-slug]]'; hook PostToolUse Edit m2 "$V/wiki/old-link.md"
[[ $rc == 0 ]]; check "check 4: when the LLM brain has a memory folder, Claude Code's folder for the kit is not read" $?

# The LLM brain path through a link: an Edit that names the page by its real path is still linted.
mkdir -p "$tmp/real-brain/wiki"; ln -s "$tmp/real-brain" "$tmp/brain-link"; printf '# x\n' > "$tmp/real-brain/wiki/linked.md"
printf '{"tool_input":{"file_path":"%s"}}' "$(cd "$tmp/real-brain" && pwd -P)/wiki/linked.md" \
  | env -i HOME="$tmp/home" PATH=/usr/bin:/bin PERGAMINO_HOME="$KIT" PERGAMINO_LLM_BRAIN="$tmp/brain-link" "$SH" "$HOOK" 2>/dev/null; rc=$?
[[ $rc == 2 ]]; check "a page named by its real path, with the LLM brain set through a link, is linted" $?
printf '{"tool_input":{"file_path":"%s"}}' "$W/none.md" | env -i HOME="$tmp/home" PATH=/usr/bin:/bin PERGAMINO_HOME="$KIT" "$SH" "$HOOK" 2>/dev/null; rc=$?
[[ $rc == 0 ]]; check "no LLM brain set: the hook lints nothing and exits 0" $?

echo
if [[ $fails -eq 0 ]]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
exit $(( fails > 0 ? 1 : 0 ))
