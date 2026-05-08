#!/usr/bin/env bash
# pergamino-start — install.sh
# Verifies the kit and points you at the next step (/pergamino-intake).
#
# Usage:  ./install.sh
# Idempotent: re-running is safe.

set -euo pipefail

# Colors (with fallback if stdout isn't a tty)
if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "${BOLD}Installing Pergamino${RESET}"
echo "${CYAN}— two scrolls, one author, one librarian —${RESET}"
echo ""

# ──────────────────────────────────────────────────────
# 1. Confirm the kit's rules folder is in place
# ──────────────────────────────────────────────────────

REQUIRED_FILES=(AGENTS.md CLAUDE.md RESOLVER.md prompt-for-llm.md)
for f in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$SCRIPT_DIR/$f" ]; then
    echo "${RED}✗${RESET}  Missing $SCRIPT_DIR/$f — your install is incomplete."
    exit 1
  fi
done
echo "${GREEN}✓${RESET}  Rules folder present (AGENTS.md, CLAUDE.md, RESOLVER.md, prompt-for-llm.md)"

# ──────────────────────────────────────────────────────
# 2. Confirm the skills folder
# ──────────────────────────────────────────────────────

REQUIRED_SKILLS=(ingest deep-ingest query lint maintain enrich research truth-aware karpathy-discipline pergamino-intake interview-executive)
MISSING_SKILLS=()
for s in "${REQUIRED_SKILLS[@]}"; do
  if [ ! -f "$SCRIPT_DIR/skills/$s/SKILL.md" ]; then
    MISSING_SKILLS+=("$s")
  fi
done
if [ ${#MISSING_SKILLS[@]} -gt 0 ]; then
  echo "${YELLOW}⚠${RESET}  Missing skills: ${MISSING_SKILLS[*]}"
  echo "      The kit may be a partial copy. Some commands won't work."
else
  echo "${GREEN}✓${RESET}  All ${#REQUIRED_SKILLS[@]} skills present"
fi

# ──────────────────────────────────────────────────────
# 3. Confirm the templates folder
# ──────────────────────────────────────────────────────

if [ -d "$SCRIPT_DIR/templates/agents-md-library" ] && [ -d "$SCRIPT_DIR/templates/reviewer-agents" ]; then
  echo "${GREEN}✓${RESET}  Templates folder present (agents-md-library, reviewer-agents)"
else
  echo "${YELLOW}⚠${RESET}  Some template subfolders missing"
fi

# ──────────────────────────────────────────────────────
# 4. Detect available LLMs
# ──────────────────────────────────────────────────────

LLM_FOUND=""
for cmd in claude codex gpt gemini aider; do
  if command -v "$cmd" >/dev/null 2>&1; then
    LLM_FOUND="$cmd"
    break
  fi
done

# ──────────────────────────────────────────────────────
# 5. Print next steps
# ──────────────────────────────────────────────────────

echo ""
echo "${BOLD}🎉  Pergamino kit installed.${RESET}"
echo ""
echo "${BOLD}Next:${RESET} run /pergamino-intake inside your LLM CLI"
echo "to configure this kit for your company. The setup interview"
echo "will create your Main{{SLUG}}Brain and LLM{{SLUG}}Brain vaults"
echo "at the right paths and substitute the {{SLUG}} placeholders."
echo ""
echo "    1. ${CYAN}cd $SCRIPT_DIR${RESET}"
if [ -n "$LLM_FOUND" ]; then
  echo "    2. ${CYAN}$LLM_FOUND${RESET}    ${YELLOW}# detected on your system${RESET}"
else
  echo "    2. ${CYAN}claude${RESET}        ${YELLOW}# or 'codex', 'gemini', 'aider', or any CLI LLM${RESET}"
fi
echo "    3. Type ${CYAN}/pergamino-intake${RESET} as your first message."
echo ""
echo "${BOLD}If you are deploying for a 5+ person company:${RESET}"
echo "    See README.md > 'Multi-user deployment' for the pergamino-deploy"
echo "    CLI flow (heartbeat Worker, GitHub teams, Cloudflare Access —"
echo "    all generated from the intake YAML)."
echo ""
echo "${CYAN}— pergamino.ai${RESET}"
echo ""
