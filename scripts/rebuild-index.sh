#!/usr/bin/env bash
# Rebuild <LLM brain>/wiki/_index.md by walking the folder tree and reading
# the YAML frontmatter of every .md file, then <LLM brain>/wiki/_graph.json
# (build-graph.py, in this folder).
#
# Deterministic: no LLM. Safe to re-run. Replaces any hand-edited content
# in _index.md.
#
# Usage:
#   bash "$PERGAMINO_HOME/scripts/rebuild-index.sh" "$PERGAMINO_LLM_BRAIN"
#   bash scripts/rebuild-index.sh            # argument 1 defaults to $PERGAMINO_LLM_BRAIN
#                                            # (the environment, else pergamino.local.env)
#
# Called by:
#   - the agent after an ingest, and the lint and maintain skills
#   - the Stop hook hooks/post-session-index.sh
#   - by hand when you want a fresh index
#
# Requires: python3.

set -euo pipefail

# Resolve through symlinks: a brain may hold this script as a link into the kit. BASH_SOURCE gives
# the link's path, and a dirname-only lookup would miss lib/paths.sh and build-graph.py.
RESOLVED_SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || true)"
[ -n "$RESOLVED_SELF" ] || RESOLVED_SELF="${BASH_SOURCE[0]}"
SELF_DIR="$(cd "$(dirname "$RESOLVED_SELF")" && pwd)"
. "$SELF_DIR/../hooks/lib/paths.sh"

VAULT_ROOT="${1:-${PERGAMINO_LLM_BRAIN:-}}"
if [ -z "$VAULT_ROOT" ]; then
  echo "ERROR: no LLM brain given. Pass its path, or set PERGAMINO_LLM_BRAIN (pergamino.local.env)." >&2
  echo "Usage: $0 [llm-brain-root]" >&2
  exit 1
fi
WIKI="$VAULT_ROOT/wiki"
INDEX="$WIKI/_index.md"

if [ ! -d "$WIKI" ]; then
  echo "ERROR: wiki directory not found at $WIKI" >&2
  echo "Usage: $0 [llm-brain-root]" >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 required for index rebuild" >&2
  exit 1
fi

export WIKI INDEX

python3 - <<'PYEOF'
import os
import re
from pathlib import Path
from datetime import datetime
from collections import defaultdict

WIKI = Path(os.environ["WIKI"]).resolve()
INDEX = Path(os.environ["INDEX"]).resolve()

SKIP_NAMES = {"_index.md", "index.md", "log.md", "todo.md", "RESOLVER.md", "README.md"}
SKIP_DIRS = {".state", ".raw", ".obsidian", ".trash"}

# MECE grouping matches RESOLVER.md taxonomy
GROUPS = [
    ("Operating", ["business", "client", "project", "decision", "meeting", "tool", "vendor"]),
    ("Exploring", ["venture"]),
    ("Research", ["theme", "thinker", "concept"]),
    ("Both", ["summary", "synthesis"]),
]

KIND_HEADERS = {
    "business": "Businesses",
    "client": "Clients",
    "project": "Projects",
    "decision": "Decisions",
    "meeting": "Meetings",
    "tool": "Tools",
    "vendor": "Vendors",
    "venture": "Ventures",
    "theme": "Themes",
    "thinker": "Thinkers",
    "concept": "Concepts",
    "summary": "Summaries",
    "synthesis": "Syntheses",
}

DIR_TO_KIND = {
    "businesses": "business",
    "clients": "client",
    "projects": "project",
    "ventures": "venture",
    "decisions": "decision",
    "meetings": "meeting",
    "tools": "tool",
    "vendors": "vendor",
    "themes": "theme",
    "thinkers": "thinker",
    "concepts": "concept",
    "summaries": "summary",
    "syntheses": "synthesis",
}

ALL_KINDS = {k for _, ks in GROUPS for k in ks}


def parse_frontmatter(text):
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    fm_text = text[3:end].strip()
    fm = {}
    for line in fm_text.split("\n"):
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        if val.startswith("[") and val.endswith("]"):
            val = val[1:-1].strip()
        fm[key] = val
    return fm


def first_h1(text):
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            text = text[end + 4:]
    m = re.search(r"^#\s+(.+)$", text, re.MULTILINE)
    return m.group(1).strip() if m else None


def tldr(text):
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            text = text[end + 4:]
    # Prefer first non-header, non-HTML-comment paragraph
    for block in text.split("\n\n"):
        block = block.strip()
        if not block or block.startswith("#") or block.startswith("<!--") or block.startswith("---"):
            continue
        first_line = block.split("\n")[0].strip()
        if first_line and not first_line.startswith("<!--"):
            return first_line[:120] + ("…" if len(first_line) > 120 else "")
    return ""


pages_by_kind = defaultdict(list)
total = 0

for md_path in sorted(WIKI.rglob("*.md")):
    if md_path.name in SKIP_NAMES:
        continue
    if any(part in SKIP_DIRS for part in md_path.parts):
        continue

    try:
        text = md_path.read_text(encoding="utf-8")
    except Exception as e:
        print(f"  (skipped {md_path}: {e})")
        continue

    fm = parse_frontmatter(text)
    # Support both `type:` (new) and `kind:` (legacy) frontmatter
    kind = (fm.get("type", "") or fm.get("kind", "")).strip()

    if not kind:
        parts = md_path.relative_to(WIKI).parts
        if parts:
            kind = DIR_TO_KIND.get(parts[0], "")

    if kind not in ALL_KINDS:
        continue

    title = (fm.get("title", "") or "").strip() or first_h1(text) or md_path.stem
    summary = tldr(text)
    updated = fm.get("updated", "")
    rel_path = md_path.relative_to(WIKI).as_posix()

    pages_by_kind[kind].append({
        "title": title,
        "summary": summary,
        "updated": updated,
        "path": rel_path,
        "slug": md_path.stem,
    })
    total += 1

for kind in pages_by_kind:
    pages_by_kind[kind].sort(
        key=lambda p: (p["updated"] or "0000-00-00", p["title"]),
        reverse=True,
    )

now = datetime.now().strftime("%Y-%m-%d %H:%M")
lines = [
    "---",
    "type: index",
    f"updated: {now}",
    "derived: true",
    "generated_by: scripts/rebuild-index.sh",
    "---",
    "",
    "# LLM brain wiki index",
    "",
    "**This file is derived — rebuilt from the directory tree by",
    "`scripts/rebuild-index.sh`. Do not edit by hand.**",
    "",
    f"Total pages: **{total}**",
    "",
]

for group_name, kinds in GROUPS:
    # Only emit group header if at least one kind in it has pages
    if not any(pages_by_kind.get(k) for k in kinds):
        continue
    lines.append(f"## {group_name}")
    lines.append("")
    for kind in kinds:
        pages = pages_by_kind.get(kind, [])
        if not pages:
            continue
        header = KIND_HEADERS[kind]
        lines.append(f"### {header} ({len(pages)})")
        lines.append("")
        for p in pages:
            summary_suffix = f" — {p['summary']}" if p["summary"] else ""
            updated_suffix = f" _(updated {p['updated']})_" if p["updated"] else ""
            lines.append(f"- [[wiki/{p['path']}|{p['title']}]]{summary_suffix}{updated_suffix}")
        lines.append("")

# Atomic replace: write a sibling temp file, then rename over the target.
# An in-place open(mode="w") on the existing _index.md once failed with EPERM
# (Operation not permitted) under a scheduled job for weeks, while sibling
# files wrote fine; the rename creates a fresh inode and is also the correct
# way to publish a derived file that readers (qmd, Obsidian) may have open.
import tempfile
fd, tmp = tempfile.mkstemp(prefix="._index.", suffix=".md.tmp", dir=str(INDEX.parent))
try:
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    os.chmod(tmp, 0o644)  # mkstemp defaults to 0600
    os.replace(tmp, INDEX)
except BaseException:
    try:
        os.unlink(tmp)
    except OSError:
        pass
    raise
print(f"✓ rebuilt {INDEX} — {total} pages across {len(pages_by_kind)} kinds")
PYEOF

# Derived graph (wiki/_graph.json): same philosophy as the index: compiled
# after the fact, regenerated on every rebuild, never hand-edited.
# Non-fatal: an index rebuild must never fail because the graph pass did.
# The graph is authoritative for lint, so a skipped rebuild must be loud.
GRAPH_SCRIPT="$SELF_DIR/build-graph.py"
if [ -f "$GRAPH_SCRIPT" ]; then
  python3 "$GRAPH_SCRIPT" "$VAULT_ROOT" || echo "WARN: graph rebuild failed (index is fine)" >&2
else
  echo "WARN: build-graph.py not found at $GRAPH_SCRIPT — wiki/_graph.json is STALE" >&2
fi
