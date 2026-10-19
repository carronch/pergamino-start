#!/usr/bin/env bash
# Test harness for hooks/surface-reminders.sh (SessionStart: one line per due reminder from
# <LLM brain>/reminders). Runs only in temporary folders: the LLM brain and the kit root point at
# made-up folders. HOOK_SHELL=/bin/bash runs it under macOS's bash 3.2.
#
# Usage: bash hooks/surface-reminders.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="${HOOK:-$HERE/surface-reminders.sh}"
fails=0
check() { if [[ "$2" == 0 ]]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }
run() { if [[ -n "${HOOK_SHELL:-}" ]]; then "$HOOK_SHELL" "$@"; else "$@"; fi; }

tmp="$(mktemp -d)" && [ -d "$tmp" ] || { echo "mktemp failed" >&2; exit 1; }; trap 'rm -rf "$tmp"' EXIT
R="$tmp/v/reminders"   # the reminders folder of the made-up LLM brain
fresh() { rm -rf "$tmp/v"; mkdir -p "$R"; }
ctx() {  # runs the hook on $tmp/v; additional context in $out
  out="$(printf '{"cwd":"%s"}' "$tmp/elsewhere" | PERGAMINO_HOME="$tmp/kit" PERGAMINO_LLM_BRAIN="$tmp/v" PERGAMINO_MAIN_BRAIN="$tmp/main" run "$HOOK" | jq -r '.hookSpecificOutput.additionalContext // empty')"
}
has() { printf '%s\n' "$out" | grep -qF -- "$1"; }
FIRST="=== Due reminders (in the LLM brain) ==="
LAST="Read a reminder's file before you act on it. To dismiss one, delete its file."
rep() { local i; for ((i = 0; i < $2; i++)); do printf '%s' "$1"; done; }  # rep <text> <n>

fresh
printf -- '---\ndue: 2026-01-01\ntitle: Pay the bill\n---\nBody A\n' > "$R/2026-01-01-bill.md"
printf -- '---\ndue: "2026-01-05"\n---\n\nFirst body line\nBody B\n' > "$R/b.md"
printf -- '---\ndue: 2999-01-01\ntitle: Later\n---\nBody F\n' > "$R/f.md"
ctx; [[ "$out" == "$FIRST
2026-01-01 · Pay the bill · reminders/2026-01-01-bill.md
2026-01-05 · First body line · reminders/b.md
$LAST" ]]
check "one line per due reminder: date · title, or else the first body line · path; a future one stays quiet" $?
! has "Body A" && ! has "Body B" && ! has "Later"; check "bodies and future reminders are not shown" $?


fresh; printf -- '---\ntitle: x\n---\nBody B\n' > "$R/2026-01-02-nodue.md"
ctx; has "2026-01-02 · x · reminders/2026-01-02-nodue.md (no usable due: line; date taken from the file name: add a due: line)"
check "no due: line, dated file name: fires on that date, flagged" $?
fresh; printf 'secret-looking text\n' > "$R/2026-01-03-plain.md"
ctx; has "2026-01-03 · (no frontmatter, so the content is not shown: give the file a frontmatter block with a due: line) · reminders/2026-01-03-plain.md" && ! has "secret-looking"
check "no frontmatter: flagged, content not shown" $?
fresh; printf 'Body C\n' > "$R/nodate.md"
ctx; has "reminders/nodate.md has no usable due: line and no date in its name, so it never fires: add a due: line"
check "no due: and no date: flagged as never firing" $?
fresh; printf -- '---\ndue: 2026/10/01 do-this\n---\nBody D\n' > "$R/bad.md"
ctx; has "reminders/bad.md has a due: line that is not YYYY-MM-DD" && ! has "do-this"
check "malformed due: flagged, its value not echoed" $?

fresh; printf -- '---\ndue: 2026-01-01\ntitle: private\n---\n' > "$tmp/private.md"
ln -s "$tmp/private.md" "$R/2026-01-01-link.md"
ctx; ! has "private"; check "a symlinked reminder is not read" $?

# A reminders folder that is a link: flagged, never read.
mkdir -p "$tmp/cards"; printf -- '---\ndue: 2026-01-01\ntitle: Card title\n---\nCard body\n' > "$tmp/cards/2026-01-01-card.md"
fresh; rm -rf "$R"; ln -s "$tmp/cards" "$R"
ctx; has "reminders is a link (or sits under one), so it was not read: make it a real folder." && ! has "Card"
check "a reminders folder linked outside the brain is flagged, not read" $?
fresh; mkdir -p "$tmp/v/wiki/workblocks"; cp "$tmp/cards/2026-01-01-card.md" "$tmp/v/wiki/workblocks/"
rm -rf "$R"; ln -s wiki/workblocks "$R"
ctx; has "reminders is a link (or sits under one)" && ! has "Card"
check "a link that stays inside the brain is refused too (cards carry dates)" $?

fresh; mkfifo "$R/2026-01-01-pipe.md"
( ctx ) & pid=$!; for _ in 1 2 3 4 5 6; do kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done
if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null; false; else true; fi
check "a FIFO in the folder doesn't hang the hook" $?

fresh; printf -- '---\ndue: 2026-01-01\ntitle: E\n---\n' > "$R/$(printf 'x\nFORGED')-e.md"
ctx; has "2026-01-01 · E · reminders/x_FORGED-e.md" && ! printf '%s\n' "$out" | grep -q '^FORGED'
check "file names can't forge new lines" $?
fresh; printf -- '---\ndue: 2026-01-01\ntitle: a\r\033[2Jb\tc\001\n---\n' > "$R/ctl.md"
ctx; has "2026-01-01 · a[2Jb c · reminders/ctl.md" && ! printf '%s' "$out" | LC_ALL=C grep -q "$(printf '[\001-\011\013-\037\177]')"
check "control characters leave the title; a tab becomes a space" $?
fresh; printf -- "---\ndue: 2026-01-01\ntitle: \"Quoted — título\"\n---\n" > "$R/q1.md"; printf -- "---\ndue: 2026-01-01\ntitle: 'Single'\n---\n" > "$R/q2.md"
ctx; has "2026-01-01 · Quoted — título · reminders/q1.md" && has "2026-01-01 · Single · reminders/q2.md"
check "quotes around a title are removed; accents and dashes stay" $?
fresh; printf -- '\n---\ndue: 2026-01-01\ntitle: shown-title\n---\nBody G\n' > "$R/g.md"
ctx; has "2026-01-01 · shown-title · reminders/g.md" && ! has "Body G"
check "blank line before the frontmatter: the title still comes from it" $?
fresh; printf -- '---\ndue: 2026-01-01\n---\n## First line\ntitle: not-this\n' > "$R/h.md"
ctx; has "2026-01-01 · First line · reminders/h.md" && ! has "not-this"
check "the first body line stands in for a missing title (heading marks removed); a title: in the body is not used" $?
fresh; printf -- '---\ndue: 2026-01-01\n---\n' > "$R/e.md"
ctx; has "2026-01-01 · (no title) · reminders/e.md"; check "no title and no body: (no title)" $?
fresh; { printf -- '---\ndue: 2026-01-01\n---\n'; head -c 9000 /dev/zero | tr '\0' 'Q'; printf '\n'; } > "$R/big.md"
ctx; [[ "$out" == "$FIRST
2026-01-01 · $(rep Q 119)… · reminders/big.md
$LAST" ]]
check "a long title is cut at 120 characters, with …" $?
fresh; printf -- '---\ndue: 2026-01-01\ntitle: %s\n---\n' "$(rep 'é' 130)" > "$R/u.md"
LC_ALL=C ctx; has "2026-01-01 · $(rep 'é' 119)… · reminders/u.md"
check "an accented long title is cut on a character boundary, even when the caller's locale is C" $?

# A byte that is not UTF-8 must not cut the title under a UTF-8 caller, and a folder or file this
# user cannot read is reported as unreadable, not as a link or a missing date.
fresh; printf -- '---\ndue: 2026-01-01\ntitle: bad \377 byte then more\n---\n' > "$R/x.md"
LC_ALL=en_US.UTF-8 ctx 2>"$tmp/err"; has "byte then more" && [ ! -s "$tmp/err" ]
check "a title with a byte that is not UTF-8 is kept whole, with no error, under a UTF-8 caller" $?
# The title-reading awk must not run in the caller's locale. Under UTF-8, macOS awk stops
# on a byte that is not UTF-8 at the start of the title or of the first body line ("towc: multibyte
# conversion failure"); the hook then called the file "no frontmatter" and awk's error reached stderr.
fresh; printf -- '---\ndue: 2026-01-01\ntitle: \377starts with a bad byte\n---\n' > "$R/xs.md"
LC_ALL=en_US.UTF-8 ctx 2>"$tmp/err"; has "starts with a bad byte · reminders/xs.md" && ! has "no frontmatter" && [ ! -s "$tmp/err" ]
check "a title that starts with a byte that is not UTF-8 is shown, with no error, under a UTF-8 caller" $?
fresh; printf -- '---\ndue: 2026-01-01\n---\n\377body starts with a bad byte\n' > "$R/xb.md"
LC_ALL=en_US.UTF-8 ctx 2>"$tmp/err"; has "body starts with a bad byte · reminders/xb.md" && ! has "no frontmatter" && [ ! -s "$tmp/err" ]
check "a first body line that starts with a byte that is not UTF-8 is shown, with no error, under a UTF-8 caller" $?
# The awk reads the first body line also when the frontmatter has a title, so that byte in the body
# must not stop it either, or the good title is lost.
fresh; printf -- '---\ndue: 2026-01-01\ntitle: Good title\n---\n\377body after a good title\n' > "$R/xt.md"
LC_ALL=en_US.UTF-8 ctx 2>"$tmp/err"; has "2026-01-01 · Good title · reminders/xt.md" && ! has "no frontmatter" && [ ! -s "$tmp/err" ]
check "a good title is shown, with no error, when the first body line has a byte that is not UTF-8, under a UTF-8 caller" $?
fresh; chmod 000 "$R"; ctx 2>"$tmp/err"; r=1; has "reminders cannot be opened" && ! has "is a link" && r=0; chmod 755 "$R"
check "a reminders folder that cannot be opened is reported as such, not as a link" $r
fresh; printf -- '---\ndue: 2026-01-01\ntitle: Locked\n---\n' > "$R/locked.md"; chmod 000 "$R/locked.md"
ctx 2>"$tmp/err"; r=1; has "reminders/locked.md cannot be read" && ! has "no usable due" && [ ! -s "$tmp/err" ] && r=0
chmod 644 "$R/locked.md"; check "a reminder file that cannot be read is reported as such, with no grep error" $r

rm -rf "$tmp/v"; mkdir -p "$tmp/v"; ctx; [[ -z "$out" ]]; check "silent with no reminders folder" $?
fresh; printf -- '---\ndue: 2999-01-01\n---\n' > "$R/f.md"
ctx; [[ -z "$out" ]]; check "silent when nothing is due" $?
fresh; printf -- '---\ndue: 2026-01-01\ntitle: x\n---\n' > "$R/x.md"
out="$(printf '{}' | env -u PERGAMINO_LLM_BRAIN PERGAMINO_HOME="$tmp/kit" PERGAMINO_MAIN_BRAIN="$tmp/main" "${HOOK_SHELL:-bash}" "$HOOK")"
[[ -z "$out" ]]; check "silent when no LLM brain is set (and the kit has no pergamino.local.env)" $?
mkdir -p "$tmp/kit"; printf 'PERGAMINO_LLM_BRAIN="%s"\n' "$tmp/v" > "$tmp/kit/pergamino.local.env"
out="$(printf '{}' | env -u PERGAMINO_LLM_BRAIN PERGAMINO_HOME="$tmp/kit" "${HOOK_SHELL:-bash}" "$HOOK" | jq -r '.hookSpecificOutput.additionalContext // empty')"
has "2026-01-01 · x · reminders/x.md"; check "the LLM brain path comes from the kit's pergamino.local.env when the environment has none" $?

echo
if [[ $fails -eq 0 ]]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
exit $(( fails > 0 ? 1 : 0 ))
