#!/usr/bin/env bash
# pergamino.ai/install — one-line bootstrap
#
# Hosted target for:
#   curl -fsSL pergamino.ai/install | bash
#
# To wire the URL: in Cloudflare, add a Page Rule on `pergamino.ai/install`
# that 301-redirects to:
#   https://raw.githubusercontent.com/carronch/pergamino-start/main/bootstrap.sh
# Or serve it via a tiny Cloudflare Worker / Pages function. Either works.
#
# What this script does (in order):
#   1. Detect OS (Mac, Linux, WSL).
#   2. Ensure `git` is installed.
#   3. Clone or update the pergamino-start kit at $PERGAMINO_HOME.
#   4. Run the kit's install.sh.
#   5. Best-effort install of an LLM CLI (claude by default).
#   6. Print clear next steps.
#
# Idempotent. Safe to re-run. Override via env vars:
#   PERGAMINO_REPO   default: https://github.com/carronch/pergamino-start.git
#   PERGAMINO_HOME   default: $HOME/Pergamino
#   PERGAMINO_LLM    default: claude  (also: aider | gemini | none)

set -euo pipefail

PERGAMINO_REPO="${PERGAMINO_REPO:-https://github.com/carronch/pergamino-start.git}"
PERGAMINO_HOME="${PERGAMINO_HOME:-$HOME/Pergamino}"
PERGAMINO_LLM="${PERGAMINO_LLM:-claude}"

# ─── colors ───────────────────────────────────────────
if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi
log()  { echo "${CYAN}[pergamino]${RESET} $1"; }
ok()   { echo "${GREEN}✓${RESET}  $1"; }
warn() { echo "${YELLOW}⚠${RESET}  $1"; }
err()  { echo "${RED}✗${RESET}  $1" >&2; }

# ─── OS detection ─────────────────────────────────────
case "$(uname -s)" in
  Darwin) OS=mac ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      OS=wsl
    else
      OS=linux
    fi
    ;;
  *)
    err "Unsupported OS: $(uname -s). Pergamino supports macOS, Linux, and WSL."
    err "On Windows, install WSL first: https://learn.microsoft.com/windows/wsl/install"
    exit 1
    ;;
esac

echo ""
echo "${BOLD}Pergamino bootstrap${RESET}"
echo "${CYAN}— two scrolls, one author, one librarian —${RESET}"
echo ""
log "OS detected: ${BOLD}$OS${RESET}"
log "Install target: ${BOLD}$PERGAMINO_HOME${RESET}"
log "LLM choice: ${BOLD}$PERGAMINO_LLM${RESET}"
echo ""

# ─── Step 1: ensure git ───────────────────────────────
if ! command -v git >/dev/null 2>&1; then
  case "$OS" in
    mac)
      warn "git is not installed. Triggering Xcode Command Line Tools install..."
      xcode-select --install 2>/dev/null || true
      echo ""
      echo "    A popup will appear. Click ${BOLD}Install${RESET}."
      echo "    Wait until it finishes (~5 minutes), then run this script again."
      echo ""
      exit 1
      ;;
    linux|wsl)
      err "git is not installed. Install it with one of:"
      err "    apt:    sudo apt-get install -y git"
      err "    dnf:    sudo dnf install -y git"
      err "    pacman: sudo pacman -S --noconfirm git"
      err "Then re-run this script."
      exit 1
      ;;
  esac
fi
ok "git present ($(git --version | awk '{print $3}'))"

# ─── Step 2: clone or update the kit ──────────────────
if [ -d "$PERGAMINO_HOME" ]; then
  if [ -d "$PERGAMINO_HOME/.git" ]; then
    log "kit already at $PERGAMINO_HOME — pulling latest..."
    git -C "$PERGAMINO_HOME" pull --ff-only --quiet || warn "git pull failed; continuing with existing copy"
  else
    err "$PERGAMINO_HOME exists and is not a git clone."
    err "Move it aside (e.g. mv $PERGAMINO_HOME ${PERGAMINO_HOME}.bak) and re-run."
    exit 1
  fi
else
  log "cloning kit to $PERGAMINO_HOME..."
  git clone --quiet "$PERGAMINO_REPO" "$PERGAMINO_HOME"
fi
ok "kit at $PERGAMINO_HOME"

# ─── Step 3: run the kit's install.sh ─────────────────
echo ""
log "running the kit's install.sh..."
echo ""
bash "$PERGAMINO_HOME/install.sh"
echo ""

# ─── Step 4: best-effort LLM install ──────────────────
install_claude() {
  command -v claude >/dev/null 2>&1 && { ok "claude already installed"; return 0; }
  log "installing Claude Code..."
  if command -v npm >/dev/null 2>&1; then
    if npm install -g @anthropic-ai/claude-code >/dev/null 2>&1; then
      ok "claude installed via npm"; return 0
    fi
  fi
  if [ "$OS" = "mac" ] && command -v brew >/dev/null 2>&1; then
    if brew install --cask claude >/dev/null 2>&1; then
      ok "claude installed via brew"; return 0
    fi
  fi
  warn "could not auto-install Claude. Install manually: https://claude.com/code"
  return 1
}

install_aider() {
  command -v aider >/dev/null 2>&1 && { ok "aider already installed"; return 0; }
  log "installing aider..."
  if [ "$OS" = "mac" ] && command -v brew >/dev/null 2>&1; then
    brew install aider >/dev/null 2>&1 && { ok "aider installed via brew"; return 0; }
  fi
  if command -v pipx >/dev/null 2>&1; then
    pipx install aider-chat >/dev/null 2>&1 && { ok "aider installed via pipx"; return 0; }
  fi
  if command -v pip3 >/dev/null 2>&1; then
    pip3 install --user aider-chat >/dev/null 2>&1 && { ok "aider installed via pip3"; return 0; }
  fi
  warn "could not auto-install aider. See https://aider.chat for manual install."
  return 1
}

install_gemini() {
  command -v gemini >/dev/null 2>&1 && { ok "gemini already installed"; return 0; }
  log "installing Gemini CLI..."
  if command -v npm >/dev/null 2>&1; then
    npm install -g @google/gemini-cli >/dev/null 2>&1 && { ok "gemini installed via npm"; return 0; }
  fi
  warn "could not auto-install Gemini. See https://github.com/google-gemini/gemini-cli"
  return 1
}

case "$PERGAMINO_LLM" in
  claude) install_claude || true ;;
  aider)  install_aider  || true ;;
  gemini) install_gemini || true ;;
  none)   log "skipping LLM install (PERGAMINO_LLM=none)" ;;
  *) warn "unknown PERGAMINO_LLM='$PERGAMINO_LLM' — skipping LLM install" ;;
esac

# ─── Step 5: final message ────────────────────────────
echo ""
echo "${BOLD}🎉  Pergamino is ready.${RESET}"
echo ""
echo "${BOLD}Open your kit:${RESET}"
echo "    1. ${CYAN}cd $PERGAMINO_HOME${RESET}"
if command -v "$PERGAMINO_LLM" >/dev/null 2>&1; then
  echo "    2. ${CYAN}$PERGAMINO_LLM${RESET}   ${YELLOW}# opens the librarian inside the kit${RESET}"
else
  echo "    2. install your LLM (see warnings above), then run it from this folder"
fi
echo "    3. type ${CYAN}/pergamino-intake${RESET} — answer 8 questions; the kit creates your two vaults."
echo ""
echo "${BOLD}Then try:${RESET}"
echo "    • ${CYAN}/interview-executive --role ceo${RESET}   capture a leader's knowledge"
echo "    • drop a URL or PDF in chat and say ${CYAN}\"ingest this\"${RESET}"
echo "    • ask ${CYAN}\"what do I think about <topic>?\"${RESET}   the librarian searches and cites"
echo ""
echo "${BOLD}License:${RESET} personal use is free. Commercial: licensing@pergamino.ai"
echo "${CYAN}— pergamino.ai${RESET}"
echo ""
