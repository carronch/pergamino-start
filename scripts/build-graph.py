#!/usr/bin/env python3
"""Compile <LLM brain>/wiki/_graph.json from wiki page frontmatter + wikilinks.

Deterministic — no LLM. Safe to re-run. The output is a derived artifact;
never hand-edit it. Design reference: gbrain's links table (mention edges
are excluded from backlink counts — traversal only).

Nodes:  every wiki/**/*.md with a `type:` (or `kind:`) frontmatter key.
Edges:  kind "link"    — [[wikilinks]] in body + wiki paths in frontmatter
                         `related:`/`relates:` lists.
        kind "mention" — body text that names another node's title/alias
                         without linking it. Guardrails: name >= 4 chars,
                         word boundary, code blocks stripped, names that
                         match in more than MENTION_CAP pages are dropped
                         as too generic (reported in stats).
Backlinks map counts "link" edges only.
Orphans: pages with no INBOUND link/typed edge declared by ANOTHER page
(outbound links, mentions, and self-declared blocked_by inversions don't
count), minus the orphan-by-design exemptions (READMEs, workblocks, dated
research reports, operational ids) — see the lint skill, checks 1–2.
Memory cards (<LLM brain>/memory/*.md, when the brain has that folder) are
valid link targets by bare name, as in Obsidian, but not graph nodes.

Usage: build-graph.py [llm-brain-root]   # default $PERGAMINO_LLM_BRAIN
rebuild-index.sh runs it after each index rebuild.
"""

import json
import os
import re
import sys
from datetime import datetime, timezone

MENTION_CAP = 60          # a name matching in more pages than this is generic
MIN_NAME_LEN = 4
STOPNAMES = {"index", "log", "todo", "notes", "author"}
# `frame` = per-article thinker sub-pages (~1,500 raw dumps). Not entity
# pages; including them multiplies the scan ~6x and drowns the graph.
SKIP_TYPES = {"frame", "raw", "capture"}
# frontmatter keys that carry typed relations (edge label = value).
# blocked_by is inverted at emit time: A blocked_by B => B blocks A.
TYPED_KEYS = {
    "served_through": "served_through",
    "lead_thinkers": "lead_thinker",
    "blocks": "blocks",
    "blocked_by": "blocked_by",
}
DIR_KINDS = {
    "workblocks": "workblock", "clients": "client", "themes": "theme",
    "tools": "tool", "projects": "project", "concepts": "concept",
    "syntheses": "synthesis", "summaries": "summary", "thinkers": "thinker",
    "businesses": "business", "ventures": "venture", "research": "research",
    "species": "species", "meetings": "meeting",
}
# Orphan-by-design exclusions (lint skill conventions): pages linked FROM cards rather than TO, plus
# operational surfaces. READMEs are structural; workblocks are the queue;
# dated research reports are export series; todo/next-actions/log are
# operational files.
ORPHAN_EXEMPT_IDS = {"wiki/todo", "wiki/next-actions", "wiki/log"}
ORPHAN_EXEMPT_PREFIXES = ("wiki/workblocks/",)  # node ids, not link targets
DATED_RESEARCH_RE = re.compile(r"(?<!\d)\d{4}-(?:0[1-9]|1[0-2])(?!\d)", re.ASCII)

VAULT = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("PERGAMINO_LLM_BRAIN", "")
if not VAULT:
    sys.exit("ERROR: no LLM brain given. Pass its path, or set PERGAMINO_LLM_BRAIN.")
WIKI = os.path.join(VAULT, "wiki")
OUT = os.path.join(WIKI, "_graph.json")

FM_RE = re.compile(r"\A---\n(.*?)\n---\n?", re.S)
# Target and heading may not span lines; the ALIAS class deliberately
# still may: real links wrap alias text across lines. A newline-tolerant
# heading would let stray prose fabricate inbound edges.
WIKILINK_RE = re.compile(r"\[\[([^\]|#\n]+)(?:#[^\]|\n]*)?(?:\|[^\]]*)?\]\]")
CODE_RE = re.compile(r"```.*?```|`[^`\n]*`", re.S)


def parse_frontmatter(text):
    m = FM_RE.match(text)
    if not m:
        return {}, "", text
    fm = {}
    for line in m.group(1).split("\n"):
        km = re.match(r"^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$", line)
        if km:
            fm[km.group(1)] = km.group(2).strip()
    return fm, m.group(1), text[m.end():]


def parse_inline_list(value):
    value = value.strip()
    if not value.startswith("["):
        return [value] if value else []
    items = value.strip("[]").split(",")
    return [i.strip().strip("'\"") for i in items if i.strip()]


def norm_target(raw):
    t = raw.strip().removesuffix(".md")
    return t


def main():
    nodes = {}
    bodies = {}
    excluded = set()
    typed_raw = {}
    underscore_files = set()
    fm_paths = {}
    wiki_dirs = set()  # vault-relative wiki folders, from the trusted walk
    for root, dirs, files in os.walk(WIKI):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        wiki_dirs.add(os.path.relpath(root, VAULT))
        for f in files:
            if not f.endswith(".md"):
                continue
            if f.startswith("_"):
                # operational files (queues, index): not nodes, but links
                # to them are valid — record for exact-path scope checks
                rel_u = os.path.relpath(os.path.join(root, f), VAULT).removesuffix(".md")
                underscore_files.add(rel_u)
                continue
            path = os.path.join(root, f)
            rel = os.path.relpath(path, VAULT).removesuffix(".md")
            try:
                text = open(path, encoding="utf-8").read()
            except (UnicodeDecodeError, OSError):
                continue
            fm, fm_text, body = parse_frontmatter(text)
            ntype = fm.get("type") or fm.get("kind")
            if ntype in SKIP_TYPES:
                excluded.add(rel)
                continue
            if not ntype:
                # pre-lint-hook pages lack type: — infer from directory,
                # but only for pages that do carry frontmatter
                parent = rel.split("/")[1] if rel.count("/") >= 2 else ""
                ntype = DIR_KINDS.get(parent)
                if not fm or not ntype:
                    excluded.add(rel)
                    continue
            nodes[rel] = {
                "path": rel + ".md",
                "type": ntype,
                "title": fm.get("title", "").strip("'\""),
                "aliases": parse_inline_list(fm.get("aliases", "")),
                "status": fm.get("status", "").strip("'\"") or None,
            }
            # typed relations from existing frontmatter conventions
            tr = {}
            for key, label in TYPED_KEYS.items():
                if fm.get(key):
                    tr[label] = parse_inline_list(fm[key])
            if tr:
                typed_raw[rel] = tr
            # frontmatter links: [[...]] anywhere in it, plus bare wiki/...
            # path tokens (covers multi-line related:/relates: lists)
            fm_links = WIKILINK_RE.findall(fm_text)
            # bare wiki/... path tokens; the lookbehind rejects tokens
            # embedded in URLs or paths (en.wikipedia.org/wiki/Foo).
            # A token that ends a sentence keeps the period: strip it.
            # Folder tokens are filtered after the walk.
            # Explicit [[...]] links were read above, as written: scan only the
            # text outside them, so the period strip never changes a link.
            fm_paths[rel] = [
                p.rstrip(".")
                for p in re.findall(r"(?<![\w./-])(wiki/[A-Za-z0-9._/-]+)",
                                    WIKILINK_RE.sub(" ", fm_text))
            ]
            bodies[rel] = (body, fm_links)

    # A bare path that names a wiki folder ("notes in wiki/meetings") is
    # prose, not a link — unless a page of the same name exists. Checked
    # against the walked folder set, never by probing the filesystem.
    for rel, paths in fm_paths.items():
        bodies[rel][1].extend(
            p for p in paths
            if p.rstrip("/") not in wiki_dirs or norm_target(p) in nodes
        )

    basenames = {}
    for nid in nodes:
        basenames.setdefault(nid.rsplit("/", 1)[-1], []).append(nid)

    def resolve(target):
        t = norm_target(target)
        if t in nodes:
            return t
        if "wiki/" + t in nodes:
            return "wiki/" + t
        cands = basenames.get(t.rsplit("/", 1)[-1], [])
        if len(cands) == 1:
            return cands[0]
        return None

    excluded_basenames = {e.rsplit("/", 1)[-1] for e in excluded}

    # Link-target allowlist: the vault's real top-level directories
    # (derived once from a trusted listdir, never from link content),
    # minus wiki/ (the graph itself) and bare workblocks/ — card-shaped
    # [[workblocks/<card>]] shorthand resolves via resolve() above, and
    # only the archive holds legit direct targets; a broken card link
    # must surface as unresolved, not be swallowed.
    vault_prefixes = ["workblocks/archive/"]
    for d in sorted(os.listdir(VAULT)):
        if d.startswith(".") or d in ("wiki", "workblocks"):
            continue
        if os.path.isdir(os.path.join(WIKI, d)):
            # name collides with a wiki/ subdir (research/, themes/, …):
            # shorthand links must keep resolving to card/page nodes and
            # broken ones must surface — never swallow by prefix
            continue
        if os.path.isdir(os.path.join(VAULT, d)):
            vault_prefixes.append(d + "/")
    vault_prefixes = tuple(vault_prefixes)

    # Memory cards: Obsidian resolves [[<card>]] by bare name across the
    # vault. Names come from a trusted listdir; they are targets, not nodes.
    mem_dir = os.path.join(VAULT, "memory")
    memory_names = set()
    if os.path.isdir(mem_dir):
        memory_names = {
            f.removesuffix(".md") for f in os.listdir(mem_dir)
            if f.endswith(".md") and not f.startswith(".")
        }

    def is_out_of_scope(t):
        # links to excluded pages (frames/raw dumps) or non-wiki targets
        if t in excluded or "wiki/" + t in excluded:
            return True
        if t in underscore_files or "wiki/" + t in underscore_files:
            return True  # operational _files exist; exact path only
        if t.rsplit("/", 1)[-1] in excluded_basenames:
            return True
        if t in memory_names:  # bare name only; memory/<card> is a prefix
            return True
        # Valid vault paths outside the wiki graph are real Obsidian
        # links, not graph targets — resolve against the WHOLE vault
        # Deterministic prefix allowlist on purpose: no filesystem
        # probing on link-derived strings (directories, case-insensitive
        # disks, symlinks and ../ traversal all bite).
        return t.startswith(vault_prefixes)

    edge_count = {}
    unresolved = {}
    skipped_out_of_scope = 0
    # inbound edges declared by ANOTHER page — the orphan test set.
    # A blocked_by inversion is declared by its own target, so it never
    # lands here (no self-exemption from orphanhood).
    inbound_real = set()
    for nid, (body, fm_links) in bodies.items():
        # strip code blocks first: bash `[[ ... ]]` snippets are not links
        targets = WIKILINK_RE.findall(CODE_RE.sub(" ", body)) + fm_links
        for raw in targets:
            r = resolve(raw)
            if r is None:
                t = norm_target(raw)
                if is_out_of_scope(t):
                    skipped_out_of_scope += 1
                else:
                    unresolved.setdefault(t, []).append(nid)
            elif r != nid:
                edge_count[(nid, r, "link")] = edge_count.get((nid, r, "link"), 0) + 1
                inbound_real.add(r)

    # typed edges from frontmatter conventions
    for nid, rels in typed_raw.items():
        for label, values in rels.items():
            for raw in values:
                r = resolve(raw)
                if r is None or r == nid:
                    continue
                if label == "blocked_by":  # invert: B blocks A
                    edge_count[(r, nid, "blocks")] = 1
                    # target nid declared this itself — not real inbound
                else:
                    edge_count[(nid, r, label)] = 1
                    inbound_real.add(r)

    # mention edges: names -> nodes, scan link-stripped, code-stripped bodies
    names = {}
    for nid, n in nodes.items():
        for name in [n["title"]] + n["aliases"]:
            name = name.strip()
            if len(name) >= MIN_NAME_LEN and name.lower() not in STOPNAMES:
                names.setdefault(name.lower(), set()).add(nid)
    name_res = {k: list(v)[0] for k, v in names.items() if len(v) == 1}
    # one combined alternation, longest-first, scanned once per body
    alts = sorted((re.escape(k) for k in name_res), key=len, reverse=True)
    combined = re.compile(
        r"(?<![\w-])(?:" + "|".join(alts) + r")(?![\w-])", re.I
    ) if alts else None
    linked_pairs = {(a, b) for (a, b, _k) in edge_count}
    mention_hits = {}
    for nid, (body, _) in bodies.items():
        if combined is None:
            break
        clean = CODE_RE.sub(" ", WIKILINK_RE.sub(" ", body))
        seen_here = set()
        for m in combined.finditer(clean):
            key = m.group(0).lower()
            tgt = name_res.get(key)
            if tgt is None or tgt == nid or key in seen_here:
                continue
            if (nid, tgt) in linked_pairs:
                continue
            seen_here.add(key)
            mention_hits.setdefault(key, []).append(nid)
    dropped_generic = sorted(k for k, v in mention_hits.items() if len(v) > MENTION_CAP)
    for key, srcs in mention_hits.items():
        if key in dropped_generic:
            continue
        for nid in srcs:
            edge_count[(nid, name_res[key], "mention")] = 1

    edges = [
        {"from": a, "to": b, "kind": k, "n": n}
        for (a, b, k), n in sorted(edge_count.items())
    ]
    backlinks = {}
    for e in edges:
        if e["kind"] != "mention":  # links + typed edges are curated structure
            backlinks.setdefault(e["to"], []).append(e["from"])
    for v in backlinks.values():
        v.sort()

    # An orphan is a page with no INBOUND links (lint skill, check 1).
    # inbound_real holds link + typed edges declared by other pages;
    # outbound links, mentions, and self-declared blocked_by inversions
    # do not make a page non-orphan.
    linked_nodes = inbound_real

    def orphan_exempt(nid):
        base = nid.rsplit("/", 1)[-1]
        if base.lower() == "readme" or nid in ORPHAN_EXEMPT_IDS:
            return True
        if nid.startswith(ORPHAN_EXEMPT_PREFIXES):
            return True
        # dated report series only — a standing (undated) research brief
        # still flags
        return nid.startswith("wiki/research/") and bool(
            DATED_RESEARCH_RE.search(base)
        )

    raw_orphans = set(nodes) - linked_nodes
    orphans = sorted(nid for nid in raw_orphans if not orphan_exempt(nid))
    orphans_exempt = len(raw_orphans) - len(orphans)

    graph = {
        "generated": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "version": 1,
        "stats": {
            "nodes": len(nodes),
            "link_edges": sum(1 for e in edges if e["kind"] == "link"),
            "typed_edges": sum(1 for e in edges if e["kind"] not in ("link", "mention")),
            "mention_edges": sum(1 for e in edges if e["kind"] == "mention"),
            "unresolved_targets": len(unresolved),
            "out_of_scope_links_skipped": skipped_out_of_scope,
            "excluded_pages": len(excluded),
            "orphans": len(orphans),
            "orphans_exempt": orphans_exempt,
            "generic_names_dropped": dropped_generic,
        },
        "nodes": dict(sorted(nodes.items())),
        "edges": edges,
        "backlinks": dict(sorted(backlinks.items())),
        "unresolved": {k: sorted(v) for k, v in sorted(unresolved.items())},
        "orphans": orphans,
    }
    tmp = OUT + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(graph, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    os.replace(tmp, OUT)
    s = graph["stats"]
    print(
        f"✓ rebuilt {OUT} — {s['nodes']} nodes, {s['link_edges']} link edges, "
        f"{s['typed_edges']} typed edges, {s['mention_edges']} mention edges, "
        f"{s['unresolved_targets']} unresolved, {s['orphans']} orphans"
    )


if __name__ == "__main__":
    main()
