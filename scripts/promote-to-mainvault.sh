#!/usr/bin/env bash
# promote-to-mainvault.sh
# Promote a staged document from the tray, <LLM brain>/outputs/mainvault-pending/, into the
# Main brain. Agent-staged, human-gated: agents can fill the tray; only the author runs this.
# It asks for a typed "y" before it writes, so an agent cannot run it unattended.
#
# Paths: PERGAMINO_LLM_BRAIN and PERGAMINO_MAIN_BRAIN, from the environment or the kit's
# pergamino.local.env (hooks/lib/paths.sh).
# Usage:
#   bash "$PERGAMINO_HOME/scripts/promote-to-mainvault.sh"            # list the tray
#   bash "$PERGAMINO_HOME/scripts/promote-to-mainvault.sh" <file.md>  # promote one file

set -euo pipefail

RESOLVED_SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || true)"
[ -n "$RESOLVED_SELF" ] || RESOLVED_SELF="${BASH_SOURCE[0]}"
. "$(cd "$(dirname "$RESOLVED_SELF")" && pwd)/../hooks/lib/paths.sh"

if [[ -z "${PERGAMINO_LLM_BRAIN:-}" || -z "${PERGAMINO_MAIN_BRAIN:-}" ]]; then
  printf 'Set PERGAMINO_LLM_BRAIN and PERGAMINO_MAIN_BRAIN first (pergamino.local.env in the kit root).\n' >&2
  exit 1
fi
STAGE="$PERGAMINO_LLM_BRAIN/outputs/mainvault-pending"
MAIN="$PERGAMINO_MAIN_BRAIN"
LOG="$STAGE/_log.md"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
dim()   { printf '\033[2m%s\033[0m\n' "$*"; }

usage() {
  cat <<EOF
Usage: promote-to-mainvault.sh [source-filename]

With no args:  lists files currently staged for promotion.
With a name:   shows a diff (or preview), asks to confirm, then copies.

Staging rules (see $STAGE/README.md):
- Each file must start with '<!-- target: path/in/the/Main/brain.md -->'
- The marker is stripped when the file is copied out.
- Source is deleted on success; an audit line is appended to _log.md.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -d "$STAGE" ]]; then
  red "Staging directory not found: $STAGE"
  exit 1
fi

extract_target() {
  # First line matching <!-- target: PATH -->
  grep -m1 -E '^<!-- *target:' "$1" 2>/dev/null \
    | sed -E 's|^<!-- *target: *([^ ]+) *-->.*$|\1|'
}

# List mode -----------------------------------------------------------------
if [[ $# -eq 0 ]]; then
  echo "Staged for promotion to the Main brain:"
  echo
  shopt -s nullglob
  found=0
  for f in "$STAGE"/*.md; do
    name=$(basename "$f")
    case "$name" in _*|README.md) continue ;; esac
    target=$(extract_target "$f" || true)
    if [[ -n "$target" ]]; then
      if [[ -f "$MAIN/$target" ]]; then
        printf '  %-40s → Main brain/%s  (overwrites)\n' "$name" "$target"
      else
        printf '  %-40s → Main brain/%s  (new)\n' "$name" "$target"
      fi
    else
      red "  $name  (missing '<!-- target: ... -->' marker)"
    fi
    found=1
  done
  if [[ $found -eq 0 ]]; then
    dim "  (queue is empty)"
  fi
  echo
  dim "Run: promote-to-mainvault.sh <source-filename>"
  exit 0
fi

# Promote mode --------------------------------------------------------------
SOURCE="$1"
case "$SOURCE" in
  */*|..*)
    red "Give a file name from the tray, not a path: $SOURCE"
    exit 1
    ;;
esac
SRC_FILE="$STAGE/$SOURCE"

if [[ ! -f "$SRC_FILE" ]]; then
  red "Not found: $SRC_FILE"
  exit 1
fi

TARGET=$(extract_target "$SRC_FILE" || true)
if [[ -z "$TARGET" ]]; then
  red "No '<!-- target: PATH -->' marker in $SRC_FILE"
  exit 1
fi

# Path safety: no absolute, no ..
case "$TARGET" in
  /*|*..*)
    red "Target rejected (must be relative, no '..'): $TARGET"
    exit 1
    ;;
esac

DST_FILE="$MAIN/$TARGET"

echo
echo "Source: $SRC_FILE"
echo "Target: $DST_FILE"
echo

# Build the promoted content (marker stripped) into a temp file.
# Use awk for portability: strip ONLY the first matching marker line.
TMP=$(mktemp)
awk '
  BEGIN { stripped = 0 }
  !stripped && /^<!-- *target:.*-->[[:space:]]*$/ { stripped = 1; next }
  { print }
' "$SRC_FILE" > "$TMP"

if [[ -f "$DST_FILE" ]]; then
  echo "--- diff ($TARGET exists in the Main brain, will be overwritten) ---"
  diff -u "$DST_FILE" "$TMP" || true
  echo "--- end diff ---"
else
  echo "--- new file preview ---"
  head -30 "$TMP"
  total=$(wc -l < "$TMP" | tr -d ' ')
  if [[ "$total" -gt 30 ]]; then
    dim "... ($total lines total, showing first 30)"
  fi
  echo "--- end preview ---"
fi

echo
read -r -p "Confirm promote to Main brain/$TARGET? [y/N] " CONFIRM || CONFIRM=""
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  rm -f "$TMP"
  echo "aborted"
  exit 0
fi

# Ensure target dir exists, then copy
mkdir -p "$(dirname "$DST_FILE")"
mv "$TMP" "$DST_FILE"

# Log
TODAY=$(date +%Y-%m-%d)
if [[ ! -f "$LOG" ]]; then
  {
    echo "# Promotion log"
    echo
    echo "Append-only record of promotions from the tray to the Main brain."
    echo
  } > "$LOG"
fi
echo "- $TODAY: \`$SOURCE\` → \`$TARGET\`" >> "$LOG"

# Remove source so it can't be re-promoted by accident
rm "$SRC_FILE"

green "✓ Promoted to $DST_FILE"
dim "  Source removed from staging. Audit line appended to $LOG."
