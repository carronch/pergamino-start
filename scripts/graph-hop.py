#!/usr/bin/env python3
"""1-hop graph retrieval over <LLM brain>/wiki/_graph.json.

Companion to build-graph.py. Given one or more wiki page ids (the top
hits of a qmd query), print their 1-hop neighborhood ranked by backlink
count, so an agent can decide which neighbors to pull into context.

Mention edges are shown but marked — they are weaker signal than links
(gbrain rule: mentions never count toward ranking).

Usage:
  graph-hop.py wiki/clients/example-client [wiki/tools/qmd ...]
  graph-hop.py --excerpt wiki/themes/knowledge-systems   # + intro lines
  graph-hop.py --vault /path/to/llm-brain --top 12 <ids...>

--vault defaults to $PERGAMINO_LLM_BRAIN.

Ids may be given with or without the wiki/ prefix or .md suffix;
unique-basename resolution applies (same as build-graph.py).
"""

import argparse
import json
import os
import re
import sys

FM_RE = re.compile(r"\A---\n.*?\n---\n?", re.S)
EXCERPT_LINES = 10
# structural hub pages: they link/get-linked by everything, so as seeds
# or neighbors they only add noise — never entity signal
HUB_IDS = {"wiki/log", "wiki/index", "wiki/todo", "wiki/next-actions"}
HUB_TYPES = {"log", "index"}


def load_graph(vault):
    path = os.path.join(vault, "wiki", "_graph.json")
    try:
        return json.load(open(path, encoding="utf-8"))
    except FileNotFoundError:
        sys.exit(f"ERROR: {path} not found — run build-graph.py first")


def resolve(g, raw):
    # tolerate qmd output pasted verbatim: ANSI colors, qmd:// prefix,
    # :line suffixes, #docid tokens
    raw = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", raw)
    raw = re.sub(r"^qmd://[^/]+/", "", raw)
    raw = re.sub(r"(:\d+)?(\s*#\S+)?$", "", raw.strip())
    t = raw.removesuffix(".md").strip("/")
    if t in g["nodes"]:
        return t
    if "wiki/" + t in g["nodes"]:
        return "wiki/" + t
    base = t.rsplit("/", 1)[-1]
    cands = [n for n in g["nodes"] if n.rsplit("/", 1)[-1] == base]
    if len(cands) == 1:
        return cands[0]
    return None


def excerpt(vault, node_path, n=EXCERPT_LINES):
    try:
        text = open(os.path.join(vault, node_path), encoding="utf-8").read()
    except OSError:
        return ""
    body = FM_RE.sub("", text).strip()
    lines = [l for l in body.split("\n")]
    return "\n".join(lines[:n]).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="+")
    ap.add_argument("--vault", default=os.environ.get("PERGAMINO_LLM_BRAIN", ""),
                    help="the LLM brain (default: $PERGAMINO_LLM_BRAIN)")
    ap.add_argument("--top", type=int, default=15, help="max neighbors shown")
    ap.add_argument("--excerpt", action="store_true", help="print intro lines per neighbor")
    ap.add_argument("--rel", help="only follow edges of this kind (e.g. served_through, blocks)")
    args = ap.parse_args()
    if not args.vault:
        sys.exit("ERROR: no LLM brain given. Pass --vault, or set PERGAMINO_LLM_BRAIN.")

    g = load_graph(args.vault)
    bl_count = {k: len(v) for k, v in g["backlinks"].items()}

    def is_hub(nid):
        return nid in HUB_IDS or g["nodes"][nid].get("type") in HUB_TYPES

    seeds = []
    for raw in args.ids:
        r = resolve(g, raw)
        if r is None:
            print(f"?? not in graph: {raw}", file=sys.stderr)
        elif is_hub(r):
            print(f"?? hub page skipped as seed: {r}", file=sys.stderr)
        else:
            seeds.append(r)
    if not seeds:
        sys.exit(1)
    seed_set = set(seeds)

    # neighbor -> (edge kinds seen, seeds it touches)
    neighbors = {}
    for e in g["edges"]:
        if args.rel and e["kind"] != args.rel:
            continue
        pair = None
        if e["from"] in seed_set and e["to"] not in seed_set:
            pair = e["to"]
        elif e["to"] in seed_set and e["from"] not in seed_set:
            pair = e["from"]
        if pair is None or is_hub(pair):
            continue
        seed = e["from"] if e["from"] in seed_set else e["to"]
        cur = neighbors.setdefault(pair, {"kinds": set(), "seeds": set()})
        cur["kinds"].add(e["kind"])
        cur["seeds"].add(seed)

    ranked = sorted(
        neighbors.items(),
        key=lambda kv: (
            kv[1]["kinds"] == {"mention"},    # curated structure first
            -len(kv[1]["seeds"]),             # touches more seeds first
            -bl_count.get(kv[0], 0),          # then global backlink count
            kv[0],
        ),
    )[: args.top]

    for seed in seeds:
        n = g["nodes"][seed]
        print(f"seed: {seed}  [{n['type']}] {n['title']}  ({bl_count.get(seed, 0)} backlinks)")
    print()
    if not ranked:
        print("no neighbors in graph")
        return
    for nid, info in ranked:
        n = g["nodes"][nid]
        kinds = sorted(info["kinds"])
        tag = "MENTION" if kinds == ["mention"] else "+".join(k for k in kinds if k != "mention")
        print(
            f"- {nid}  [{n['type']}] {n['title']}  "
            f"({tag}; touches {len(info['seeds'])} seed(s); {bl_count.get(nid, 0)} backlinks)"
        )
        if args.excerpt:
            ex = excerpt(args.vault, n["path"])
            if ex:
                print("    " + "\n    ".join(ex.split("\n")) + "\n")


if __name__ == "__main__":
    main()
