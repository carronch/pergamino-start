#!/usr/bin/env bash
# Test harness for install.sh. Runs only in temporary folders: HOME, the kit copy and both brains
# are made up, and a fake qmd stands in for the real one, so no real search index is touched.
#
# Usage: bash scripts/install.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
check() { if [[ "$2" == 0 ]]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

T="$(mktemp -d)" && [ -d "$T" ] || { echo "mktemp failed" >&2; exit 1; }; trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)"
mkdir -p "$T/home" "$T/elsewhere" "$T/bin" "$T/nopy"

# The kit copy is its own git repository, so `git status` shows whatever install.sh leaves behind.
rsync -a --exclude .git --exclude 'pergamino.local.env*' --exclude 'AGENTS.local.md' \
  --exclude '.claude/settings.local.json*' "$HERE/" "$T/kit/"
git -C "$T/kit" init -q && git -C "$T/kit" add -A \
  && git -C "$T/kit" -c user.email=t@example.com -c user.name=t commit -qm base

# A fake qmd: two collections, `main` registered at an old path.
cat > "$T/bin/qmd" <<'FAKE'
#!/bin/bash
case "$1 $2" in
  "collection list") printf 'main (qmd://main/)\n  Path: x\nllm (qmd://llm/)\n' ;;
  "collection show") if [ "$3" = main ]; then echo "  Path:     /old/main"; else echo "  Path:     $QMD_LLM_PATH"; fi ;;
  "collection add") exit 0 ;;
  *) exit 1 ;;
esac
FAKE
chmod +x "$T/bin/qmd"

# A PATH without python3: every tool from /usr/bin and /bin except python3.
for f in /usr/bin/* /bin/*; do
  n="${f##*/}"; case "$n" in python3*|qmd) continue ;; esac
  [ -e "$T/nopy/$n" ] || ln -s "$f" "$T/nopy/$n"
done

inst() { (cd "$T/elsewhere" && env -i HOME="$T/home" PATH="$1" QMD_LLM_PATH="${QMD_LLM_PATH:-}" bash "$T/kit/install.sh" "${@:2}" 2>&1); }
dirty() { git -C "$T/kit" status --porcelain; }
envval() { sed -n "s/^$1=//p" "$T/kit/pergamino.local.env"; }

# 1. No python3: the install still finishes, and it writes no empty settings file.
out=$(inst "$T/nopy" --yes --main rel/main --llm rel/llm); rc=$?
[[ $rc == 0 && ! -e "$T/kit/.claude/settings.local.json" && "$out" == *"python3 is missing"* ]]
check "no python3: exit 0, a warning, and no settings.local.json" $?

# 2. Relative paths become absolute, from the folder the install ran in.
[[ "$(envval PERGAMINO_MAIN_BRAIN)" == "$T/elsewhere/rel/main" && "$(envval PERGAMINO_LLM_BRAIN)" == "$T/elsewhere/rel/llm" ]]
check "relative brain paths are saved as absolute paths" $?
[[ -d "$T/elsewhere/rel/main/beliefs" && -d "$T/elsewhere/rel/llm/wiki/workblocks" ]]
check "the brain folders are created at those paths" $?

# 3. With python3 back, a rerun writes valid settings that list both brains.
export QMD_LLM_PATH="$T/elsewhere/rel/llm"
out=$(inst "$T/bin:/usr/bin:/bin" --yes); rc=$?
python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["permissions"]["additionalDirectories"]==sys.argv[2:]' \
  "$T/kit/.claude/settings.local.json" "$T/elsewhere/rel/main" "$T/elsewhere/rel/llm"
check "rerun with python3: valid settings.local.json with both brains" $?

# 4. A collection registered at another path gets a warning with the fix.
[[ "$out" == *"qmd collection 'main' points at /old/main"* && "$out" == *"qmd collection 'llm' already exists"* ]]
check "qmd: a collection at the wrong path warns; a matching one is accepted" $?

# 5. A rerun leaves git clean.
inst "$T/bin:/usr/bin:/bin" --yes >/dev/null
d="$(dirty)"; [[ -z "$d" ]] || printf '%s\n' "$d" | sed 's/^/     /'
[[ -z "$d" ]]; check "a rerun leaves no untracked or changed file in the kit" $?

# 6. Moving a brain makes backups; git still shows nothing.
inst "$T/bin:/usr/bin:/bin" --yes --main "$T/home/NewMain" --llm "$T/home/NewLLM" >/dev/null
ls "$T/kit/.claude/" | grep -q 'settings.local.json.bak-' && ls -a "$T/kit" | grep -q 'pergamino.local.env.bak-'
check "moving a brain backs up the local settings and paths file" $?
[[ -z "$(dirty)" ]]; check "the backups are ignored by git" $?
[[ "$(envval PERGAMINO_MAIN_BRAIN)" == "$T/home/NewMain" ]]; check "the paths file holds the new Main brain" $?

# 7. The paths file holds only lines block-sensitive.sh allows: PERGAMINO_<NAME>=<path> or a comment without "=".
! grep -vE '^PERGAMINO_[A-Z_]+=.+$|^#[^=]*$|^$' "$T/kit/pergamino.local.env" >/dev/null
check "the paths file holds only PERGAMINO_ lines and plain comments" $?

if [[ $fails -eq 0 ]]; then echo "all checks passed"; else echo "$fails check(s) failed"; exit 1; fi
