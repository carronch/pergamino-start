#!/usr/bin/env bash
# pergamino-start — install.sh
# Sets up the kit on this computer: the two brain folders, the local paths file,
# the search collections and the hook permissions. Then it points you at the first skill.
#
# Usage:  bash install.sh [--main PATH] [--llm PATH] [--yes]
#   --main PATH   the Main brain (the author's; the agent never writes there)
#   --llm PATH    the LLM brain (the librarian's)
#   --yes         no questions; use the flags, the existing paths file, or the defaults
#
# Safe to run again. It creates only what is missing. It never overwrites
# pergamino.local.env, AGENTS.local.md, a brain file, or your own host settings.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi
ok()   { echo "${GREEN}✓${RESET}  $1"; }
warn() { echo "${YELLOW}⚠${RESET}  $1"; }
err()  { echo "${RED}✗${RESET}  $1" >&2; }

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$KIT/pergamino.local.env"
MAIN_ARG=""; LLM_ARG=""; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --main) MAIN_ARG="${2:?--main needs a path}"; shift 2 ;;
    --llm)  LLM_ARG="${2:?--llm needs a path}"; shift 2 ;;
    --yes|-y) YES=1; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) err "Unknown option: $1"; exit 2 ;;
  esac
done
[ -t 0 ] || YES=1

echo ""
echo "${BOLD}Installing Pergamino${RESET}"
echo "${CYAN}— two scrolls, one author, one librarian —${RESET}"
echo ""

# ── 1. The kit is complete ─────────────────────────────
for f in AGENTS.md SCHEMA.md RESOLVER.md prompt-for-llm.md; do
  [ -f "$KIT/$f" ] || { err "Missing $KIT/$f — this copy of the kit is incomplete."; exit 1; }
done
if [ ! -L "$KIT/CLAUDE.md" ]; then
  warn "CLAUDE.md is not a link to AGENTS.md. Claude Code may read other rules."
fi
SKILLS=0; for d in "$KIT"/skills/*/; do [ -f "$d/SKILL.md" ] && SKILLS=$((SKILLS + 1)); done
ok "Rules and $SKILLS skills present"

# ── 2. The paths file ──────────────────────────────────
# KEY=value lines only. Read without `source`, so a stray command in the file never runs.
read_env() {
  [ -f "$ENV_FILE" ] || return 0
  sed -n "s/^$1=//p" "$ENV_FILE" | tail -1 | sed -e 's/^"//' -e 's/"$//' -e "s|^~|$HOME|"
}
# Expand ~ and make the path absolute: hooks resolve paths from the kit folder, not from here.
expand() {
  local p="${1/#\~/$HOME}"
  case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
  printf '%s' "${p%/}"
}

# An older kit used ~/Main<Name>Brain and ~/LLM<Name>Brain. Offer one if it is there.
guess() {
  local prefix="$1" found=""
  for d in "$HOME/$prefix"*Brain; do [ -d "$d" ] && { found="$d"; break; }; done
  printf '%s' "${found:-$HOME/${prefix}Brain}"
}

MAIN="$(read_env PERGAMINO_MAIN_BRAIN)"; LLM="$(read_env PERGAMINO_LLM_BRAIN)"
[ -n "$MAIN_ARG" ] && MAIN="$(expand "$MAIN_ARG")"
[ -n "$LLM_ARG" ] && LLM="$(expand "$LLM_ARG")"
if [ -z "$MAIN" ] || [ -z "$LLM" ]; then
  [ -n "$MAIN" ] || MAIN="$(guess Main)"
  [ -n "$LLM" ] || LLM="$(guess LLM)"
  if [ "$YES" = 0 ]; then
    echo "Where do the two brains live? Press Enter to accept the default."
    read -r -p "  Main brain (yours; the agent only reads it) [$MAIN]: " a || true
    read -r -p "  LLM brain (the librarian's)                 [$LLM]: " b || true
    [ -n "${a:-}" ] && MAIN="$(expand "$a")"
    [ -n "${b:-}" ] && LLM="$(expand "$b")"
  fi
fi
if [ "$MAIN" = "$LLM" ]; then err "The two brains must be different folders."; exit 1; fi

if [ -f "$ENV_FILE" ] && [ "$(read_env PERGAMINO_MAIN_BRAIN)" = "$MAIN" ] && [ "$(read_env PERGAMINO_LLM_BRAIN)" = "$LLM" ]; then
  ok "pergamino.local.env already up to date"
elif [ -f "$ENV_FILE" ] && [ -z "$MAIN_ARG$LLM_ARG" ]; then
  ok "pergamino.local.env kept as it is"
else
  [ -f "$ENV_FILE" ] && cp -p "$ENV_FILE" "$ENV_FILE.bak-$(date +%Y%m%d-%H%M%S)"
  tmp="$(mktemp "$KIT/.pergamino.env.XXXXXX")"
  {
    echo "# Written by install.sh. Local to this computer; never committed."
    echo "PERGAMINO_HOME=$KIT"
    echo "PERGAMINO_MAIN_BRAIN=$MAIN"
    echo "PERGAMINO_LLM_BRAIN=$LLM"
  } > "$tmp"
  mv "$tmp" "$ENV_FILE"
  ok "Wrote pergamino.local.env"
fi

# ── 3. The brain folders ───────────────────────────────
made=0
mk() { [ -d "$1" ] || { mkdir -p "$1"; made=$((made + 1)); }; }
for d in beliefs principles life-decisions people heartbeats; do mk "$MAIN/$d"; done
# The tree in templates/RESOLVER.md.
for d in inbox Clippings reminders personal outputs/mainvault-pending \
         raw/articles raw/papers raw/books raw/transcripts raw/web raw/notes raw/media \
         wiki/businesses wiki/clients wiki/projects wiki/decisions wiki/tools wiki/vendors \
         wiki/ventures wiki/themes wiki/thinkers wiki/concepts wiki/meetings wiki/workblocks \
         wiki/summaries wiki/syntheses; do mk "$LLM/$d"; done
seed() { [ -e "$2" ] || { cp "$1" "$2"; made=$((made + 1)); }; }
[ -f "$LLM/wiki/log.md" ] || { printf '# Log\n\nAppend-only. One entry per operation: `## [YYYY-MM-DD] <operation> | <title>`.\n' > "$LLM/wiki/log.md"; made=$((made + 1)); }
# The brain's RESOLVER.md wins at runtime; setup-interview tailors it. Updates never overwrite it.
[ -f "$KIT/templates/RESOLVER.md" ] && seed "$KIT/templates/RESOLVER.md" "$LLM/RESOLVER.md"
[ -f "$KIT/templates/lessons.md" ] && seed "$KIT/templates/lessons.md" "$LLM/lessons.md"
[ -f "$KIT/templates/main-vault-starter.md" ] && seed "$KIT/templates/main-vault-starter.md" "$MAIN/README.md"
ok "Brain folders ready ($made items created)"
echo "     Main brain: $MAIN"
echo "     LLM brain:  $LLM"

# ── 4. Skills for every host, hooks executable ────────
# .claude/skills and .agents/skills are links to skills/ in the repository.
for link in .claude/skills .agents/skills; do
  if [ ! -e "$KIT/$link" ]; then
    mkdir -p "$KIT/$(dirname "$link")"; ln -s ../skills "$KIT/$link"
  fi
done
find "$KIT/hooks" "$KIT/scripts" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} + 2>/dev/null || true
ok "Skills linked for Claude Code and Codex; hooks executable"

# ── 4b. Let Claude Code work in the two brains ────────
# The brains sit outside the kit folder, so Claude Code would ask for every file.
# .claude/settings.local.json is yours and never committed; add the two paths to it.
LOCAL_SETTINGS="$KIT/.claude/settings.local.json"
if ! command -v python3 >/dev/null 2>&1; then
  warn "python3 is missing, so .claude/settings.local.json was not written. Install python3 and run install.sh again."
elif [ ! -f "$LOCAL_SETTINGS" ]; then
  tmp="$(mktemp "$KIT/.claude/.settings.local.XXXXXX")"
  if python3 -I -c 'import json,sys; print(json.dumps({"permissions":{"additionalDirectories":sys.argv[1:]}},indent=2))' "$MAIN" "$LLM" > "$tmp"; then
    mv "$tmp" "$LOCAL_SETTINGS"; ok "Claude Code may work in both brains (.claude/settings.local.json)"
  else
    rm -f "$tmp"; warn "Could not write .claude/settings.local.json."
  fi
elif python3 -I - "$LOCAL_SETTINGS" "$MAIN" "$LLM" <<'PYADD'
import json, os, shutil, sys, tempfile, time
path, dirs = sys.argv[1], sys.argv[2:]
with open(path) as f:
    data = json.load(f)
have = data.setdefault("permissions", {}).setdefault("additionalDirectories", [])
new = [d for d in dirs if d not in have]
if not new:
    sys.exit(0)
shutil.copy2(path, path + time.strftime(".bak-%Y%m%d-%H%M%S"))
have.extend(new)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
with os.fdopen(fd, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
PYADD
then
  ok "Both brains listed in .claude/settings.local.json"
else
  warn "Could not read .claude/settings.local.json. Add both brain paths to permissions.additionalDirectories by hand."
fi

# ── 5. Search ──────────────────────────────────────────
if command -v qmd >/dev/null 2>&1; then
  have="$(qmd collection list 2>/dev/null || true)"
  for pair in "main:$MAIN" "llm:$LLM"; do
    name="${pair%%:*}"; path="${pair#*:}"
    if printf '%s\n' "$have" | grep -q "^$name "; then
      registered="$(qmd collection show "$name" 2>/dev/null | sed -n 's/^ *Path: *//p' | head -1)"
      if [ -z "$registered" ] || [ "${registered%/}" = "${path%/}" ]; then
        ok "qmd collection '$name' already exists"
      else
        warn "qmd collection '$name' points at $registered, not $path. To move it:"
        echo "       qmd collection remove $name && qmd collection add \"$path\" --name $name"
      fi
    elif qmd collection add "$path" --name "$name" >/dev/null 2>&1; then
      ok "qmd collection '$name' → $path"
    else
      warn "Could not add qmd collection '$name'. Run: qmd collection add \"$path\" --name $name"
    fi
  done
else
  warn "qmd is not installed. The skills search the brains with it. See docs/search-setup.md."
fi

# ── 6. Tools the skills use ────────────────────────────
missing=()
for t in git python3 jq; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
[ ${#missing[@]} -eq 0 ] && ok "git, python3 and jq present" || warn "Missing: ${missing[*]} (hooks and scripts need them)"
opt=()
for t in gh ffmpeg yt-dlp whisper-cli codex; do command -v "$t" >/dev/null 2>&1 || opt+=("$t"); done
[ ${#opt[@]} -eq 0 ] || echo "     Optional, for some skills: ${opt[*]}"

LLM_FOUND=""
for cmd in claude codex cursor-agent gemini aider; do
  command -v "$cmd" >/dev/null 2>&1 && { LLM_FOUND="$cmd"; break; }
done

echo ""
echo "${BOLD}Pergamino is installed.${RESET}"
echo ""
echo "    1. ${CYAN}cd $KIT${RESET}"
echo "    2. ${CYAN}${LLM_FOUND:-claude}${RESET}"
echo "    3. First time: ${CYAN}/setup-interview${RESET} (solo) or ${CYAN}/pergamino-intake${RESET} (a company)."
echo "       You already have an agent setup: ${CYAN}/adopt-pergamino${RESET} merges the kit into it."
echo ""
echo "    Update later: ${CYAN}git -C $KIT pull && bash $KIT/install.sh${RESET}"
echo "    Your own rules go in ${CYAN}AGENTS.local.md${RESET}, so updates never conflict."
echo ""
echo "${CYAN}— pergamino.ai${RESET}"
echo ""
