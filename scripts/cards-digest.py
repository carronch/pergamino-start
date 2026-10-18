#!/usr/bin/env python3
"""Compact, read-only digest of every open workblock card, for /triage-cards.

Reads the cards in <LLM brain>/wiki/workblocks (top level only) and prints, per card that is
not `done`: its lane, whether it is on the north, the date of its newest real movement, the
idle days, the length of its status_note, its open and checked items, the newest dated
entries and the first open items. A triage session reads this digest instead of whole cards.
The newest entries keep every entry of the last date that they show, in the card's order:
some cards list a day's entries oldest first and some newest first, so a cut inside a day
can drop the newest one.

Movement is the newest dated timeline line or dated heading that is not upkeep: lint passes,
the Stop-hook guard, the vault-navigation audit, link fixes, triage runs and "No change" lines
do not count. A "No change" line is upkeep only when its first words say that nothing moved
(NO_CHANGE): "No change needed; work continues" is movement.
A card with no such line falls back to `updated:`, then `created:`, then its file name.
Lines in a fenced code block (``` or ~~~) are examples: they are not movement and not items.
An opening fence that never closes is an ordinary line, so a stray fence cannot hide the rest
of a card.

Open items tagged #author wait on the author; other open items are agent work. An untagged
open item that names the author ("the author", or a name given with --author-name) is counted
apart, so that a triage can tag it.

The north set (the cards that serve the author's main goal) is: every card with `north: true`
(or yes) in its frontmatter; the north card, if it exists, and the cards that its
"## North cards" section links; and, when --portfolio is given, the cards that the portfolio
file links in its sections, except a section whose heading starts with the word closed, paused
or archived. A link above the first section does not count. The north card defaults to
DIR/north.md. A missing default north card is not a problem; a missing north card or portfolio
that was named on the command line gives a warning.

The card folder: --dir DIR, else BRAIN/wiki/workblocks, where BRAIN is the first argument or
else the PERGAMINO_LLM_BRAIN environment variable.

Usage:
  python3 -I cards-digest.py [BRAIN] [--dir DIR] [--today YYYY-MM-DD] [--format json|md]
                             [--max-items N] [--max-entries N]
                             [--north-card PATH] [--portfolio PATH] [--author-name NAME]...

Exits 2, with a message, when no card folder is given, or when DIR is missing or cannot be
read: an empty queue would be false. Also exits 2, with a one-line message, when --today is
not a date.
"""
import argparse
import datetime
import glob
import json
import os
import re
import signal
import sys

CANONICAL = ("someday-maybe", "active", "waiting-for", "done")
DATE_LINE = re.compile(r"^\s*- \**(\d{4}-\d{2}-\d{2})")
DATE_HEADING = re.compile(r"^#{1,6}\s.*?(\d{4}-\d{2}-\d{2})")
BOX = re.compile(r"^(\s*)- \[([ xX])\]\s*(.*)$")
LIST_LINE = re.compile(r"^\s*([-*+]|\d+\.)\s")
FILE_DATE = re.compile(r"^(\d{4}-\d{2}-\d{2})-")
# The date prefix of a timeline line, in every form DATE_LINE accepts: "- 2026-10-13:",
# "- **2026-10-13** |" and "- 2026-10-13 (label):".
PREFIX = re.compile(r"^\s*- \**\d{4}-\d{2}-\d{2}\**(?:\s*\([^)]*\))?\s*[:|]?\s*")
UPKEEP_SOURCE = re.compile(r"^(lint\b|workblock-status-guard|triage-cards)|navigation audit|\blink fix", re.I)
# A "No change" upkeep line, after the date prefix and any [source: …]: the words alone ("No
# change.", "No change; …"), or then only since when or what did not change ("No change today",
# "No change since the 2026-10-11 entry", "No change to this card", "No change in state"). Any
# other word after "No change" makes a real line, as in "No change needed; work continues".
NO_CHANGE = re.compile(r"\**No changes?\**(?:\s*(?:[.;:,(—–-]|$)|\s+(?:today|yet|since"
                       r"|(?:to|in|on)\s+(?:(?:this|the)\s+)?(?:card|plan|state|status))\b)", re.I)
NORTH_HEADING = "## North cards"
# The north heading at the start of a line, the file's first line too; never inside a line.
NORTH_START = re.compile("^" + re.escape(NORTH_HEADING), re.M)
PORTFOLIO_SKIP = ("closed", "paused", "archived")
# A portfolio section is skipped when its heading text starts with a skip word, as a whole word in
# any case: "Closed or paused", "Archived projects", "Paused, for later". A skip word later in
# the heading, or the start of a hyphenated word, skips nothing: "Operating businesses
# (closed-loop)" and "Closed-loop recycling" count.
PORTFOLIO_SKIP_HEADING = re.compile(r"^(?:%s)(?![\w-])" % "|".join(PORTFOLIO_SKIP), re.I)
# A card link: by path ([[wiki/workblocks/<card>]], [[workblocks/<card>]]) or by its dated bare name.
CARD_LINK = re.compile(r"\[\[((?:wiki/)?workblocks/[^\]|#]+|\d{4}-\d{2}-\d{2}-[^\]|#/]+)")
# A fence line: its indentation, three or more backticks or tildes, and the rest (the info string).
FENCE = re.compile(r"^(\s*)(`{3,}|~{3,})(.*)$")
# The tag on an item that waits on the author, and the words that name the author in an untagged
# item ("ask the author"). --author-name adds names.
TAG = "#author"
TAG_RE = re.compile(r"#author(?![\w-])")
AUTHOR_WORDS = re.compile(r"\bthe author\b", re.I)


def parse_frontmatter(text):
    """Return (fields, body). Reads simple `key: value` lines only."""
    if not text.startswith("---"):
        return {}, text
    end = text.find("\n---", 3)
    if end < 0:
        return {}, text
    fields = {}
    for line in text[3:end].splitlines():
        m = re.match(r"^([A-Za-z_]+):\s*(.*)$", line)
        if m:
            value = m.group(2).strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            fields[m.group(1)] = value
    return fields, text[end + 4:]


def to_date(s):
    try:
        return datetime.date.fromisoformat(s[:10])
    except (ValueError, TypeError):
        return None


def is_upkeep(line):
    """True for a dated timeline line that records upkeep, not progress on the card. Headings are
    never upkeep: in the cards, a dated heading that names a lint or an audit opens real work."""
    m = PREFIX.match(line)
    if not m:
        return False
    rest = line[m.end():]
    src = re.match(r"\[source:\s*([^\]]{0,80})", rest)
    if src and UPKEEP_SOURCE.search(src.group(1)):
        return True
    rest = re.sub(r"^\[source:.*?\]\s*", "", rest)
    return NO_CHANGE.match(rest) is not None


def card_names(text):
    """The card names that a text links, without a folder or a .md suffix."""
    names = set()
    for raw in CARD_LINK.findall(text):
        name = raw.strip().rsplit("/", 1)[-1]
        names.add(name[:-3] if name.endswith(".md") else name)
    return names


def closes_fence(line, fence):
    """True when the line closes a fence that opened with `fence`: the same character, at least
    as many of it, and nothing after them."""
    m = FENCE.match(line)
    return bool(m) and m.group(2)[0] == fence[0] and len(m.group(2)) >= len(fence) and not m.group(3).strip()


def outside_fences(lines):
    """The lines without their fenced code blocks, whose examples are not entries or items. A fence
    at the margin leaves one blank line, which ends an item as the fence did; an indented fence
    sits inside an item and leaves no line, so the item's text after it still counts. An opening
    fence with no closing fence is an ordinary line."""
    out, i = [], 0
    while i < len(lines):
        m = FENCE.match(lines[i])
        # A backtick fence's info string has no backtick: "```code``` text" is inline code.
        if m and not (m.group(2)[0] == "`" and "`" in m.group(3)):
            end = next((j for j in range(i + 1, len(lines)) if closes_fence(lines[j], m.group(2))), None)
            if end is not None:
                if not m.group(1):
                    out.append("")
                i = end + 1
                continue
        out.append(lines[i])
        i += 1
    return out


def items(lines):
    """Yield (checked, text) per checkbox item. An item's text runs on over its indented
    continuation lines and stops at a blank line, a heading or the next list line, so a
    nested box is its own item."""
    cur = None
    for line in lines:
        m = BOX.match(line)
        if m:
            if cur:
                yield cur
            cur = [m.group(2) != " ", m.group(3).strip()]
            continue
        if cur and line.strip() and line[0] in " \t" and not LIST_LINE.match(line):
            cur[1] += " " + line.strip()
            continue
        if cur:
            yield cur
            cur = None
    if cur:
        yield cur


def north_set(north_card, portfolio, north_named=True):
    """Return (set of card names, list of warnings). A missing north card warns only when it was
    named on the command line (north_named); portfolio None means no portfolio."""
    north, warnings = set(), []
    if north_card and os.path.exists(north_card):
        north.add(os.path.basename(north_card)[:-3])
        text = open(north_card, encoding="utf-8", errors="replace").read()
        heading = NORTH_START.search(text)
        if not heading:
            warnings.append("no '%s' heading in %s" % (NORTH_HEADING, north_card))
        else:
            rest = text[heading.start():]
            nxt = rest.find("\n## ")
            north.update(card_names(rest if nxt < 0 else rest[:nxt]))
    elif north_card and north_named:
        warnings.append("north card not found: " + north_card)
    if portfolio is None:
        pass
    elif os.path.exists(portfolio):
        counts = False  # a link above the first "## " heading is in no section: it does not count
        for line in open(portfolio, encoding="utf-8", errors="replace"):
            if line.startswith("## "):
                counts = not PORTFOLIO_SKIP_HEADING.match(line[3:].strip())
            if counts:
                north.update(card_names(line))
    else:
        warnings.append("portfolio not found: " + portfolio)
    return north, warnings


def digest(path, today, max_items, max_entries, north=frozenset(), names=None):
    text = open(path, encoding="utf-8", errors="replace").read()
    fields, body = parse_frontmatter(text)
    name = os.path.basename(path)[:-3]
    status = fields.get("status", "")
    lines = outside_fences(body.splitlines())
    dated = []
    for line in lines:
        m = DATE_LINE.match(line) or DATE_HEADING.match(line)
        if m and not is_upkeep(line):
            d = to_date(m.group(1))
            if d and d <= today:
                dated.append((d, line.strip()))
    dated.sort(key=lambda x: x[0], reverse=True)  # stable: one day's entries keep the card's order
    last, last_from = (dated[0][0], "entry") if dated else (None, None)
    # Keep every entry of the last date shown: the card's order inside one day is not known.
    newest = dated[:max_entries]
    if newest:
        newest = [e for e in dated if e[0] >= newest[-1][0]]
    if last is None:
        m = FILE_DATE.match(name)
        for source, value in (("updated", fields.get("updated")), ("created", fields.get("created")),
                              ("file name", m.group(1) if m else None)):
            d = to_date(value)
            if d and d <= today:
                last, last_from = d, source
                break
    names = names or AUTHOR_WORDS
    open_author, open_agent, checked, names_author = [], [], 0, 0
    for done, item in items(lines):
        if done:
            checked += 1
        elif TAG_RE.search(item):
            open_author.append(item)
        else:
            open_agent.append(item)
            if names.search(item):
                names_author += 1
    note = fields.get("status_note", "")
    return {
        "card": name,
        "title": fields.get("title", ""),
        "status": status,
        "canonical": status in CANONICAL,
        "north": name in north or fields.get("north", "").strip().lower() in ("true", "yes"),
        "last": last.isoformat() if last else None,
        "last_from": last_from,
        "idle_days": (today - last).days if last else None,
        "updated": fields.get("updated", ""),
        "status_note_chars": len(note),
        "status_note": note[:400],
        "open_author": len(open_author),
        "open_agent": len(open_agent),
        "open_names_author": names_author,
        "checked": checked,
        "bytes": len(text.encode("utf-8")),
        "newest_entries": [e[1][:240] for e in newest],
        "first_open_items": [(TAG + " " if TAG_RE.search(i) else "") + i[:160] for i in (open_author + open_agent)[:max_items]],
    }


def main(argv):
    # A reader such as `| head` may close the pipe early; end quietly instead of with a traceback.
    if hasattr(signal, "SIGPIPE"):
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    ap = argparse.ArgumentParser(description="Read-only digest of the open workblock cards.")
    ap.add_argument("brain", nargs="?", default=None,
                    help="the LLM brain folder; default: $PERGAMINO_LLM_BRAIN")
    ap.add_argument("--dir", default=None, help="the card folder; default: BRAIN/wiki/workblocks")
    ap.add_argument("--today", default=datetime.date.today().isoformat())
    ap.add_argument("--format", choices=("json", "md"), default="json")
    ap.add_argument("--max-items", type=int, default=8)
    ap.add_argument("--max-entries", type=int, default=3)
    ap.add_argument("--north-card", default=None, help="default: DIR/north.md, if it exists")
    ap.add_argument("--portfolio", default=None, help="a file that links cards in sections; default: none")
    ap.add_argument("--author-name", action="append", default=[],
                    help="a name that marks an untagged item as the author's; repeat for more")
    a = ap.parse_args(argv)
    if a.dir is None:
        brain = a.brain or os.environ.get("PERGAMINO_LLM_BRAIN", "")
        if not brain:
            print("cards-digest: give the LLM brain folder as the first argument, set "
                  "PERGAMINO_LLM_BRAIN, or give --dir", file=sys.stderr)
            return 2
        a.dir = os.path.join(os.path.expanduser(brain), "wiki", "workblocks")
    # A folder that is missing or cannot be read must fail: glob would report an empty queue.
    try:
        os.listdir(a.dir)
    except OSError as e:
        print("cards-digest: cannot read the card folder %s: %s" % (a.dir, e.strerror or e), file=sys.stderr)
        return 2
    try:
        today = datetime.date.fromisoformat(a.today)
    except ValueError:
        print("cards-digest: --today must be a date as YYYY-MM-DD, not %r" % a.today, file=sys.stderr)
        return 2
    north_card = a.north_card or os.path.join(a.dir, "north.md")
    north, warnings = north_set(north_card, a.portfolio, north_named=a.north_card is not None)
    names = AUTHOR_WORDS
    if a.author_name:
        names = re.compile(AUTHOR_WORDS.pattern + "|" + "|".join(
            r"\b%s\b" % re.escape(n) for n in a.author_name if n.strip()), re.I)
    cards = []
    for path in sorted(glob.glob(os.path.join(a.dir, "*.md"))):
        if os.path.basename(path).lower() == "readme.md":
            continue
        d = digest(path, today, a.max_items, a.max_entries, north, names)
        # "Done" and " done " are closed too. A card with no status: has "" and stays.
        if d["status"].strip().lower() != "done":
            cards.append(d)
    # Oldest activity first; cards with no date at all come first.
    cards.sort(key=lambda c: (c["idle_days"] is not None, -(c["idle_days"] or 0), c["card"]))
    if a.format == "json":
        json.dump(cards, sys.stdout, ensure_ascii=False, indent=1)
        sys.stdout.write("\n")
        for w in warnings:
            print("warning: north set: " + w, file=sys.stderr)
        return 0
    lanes = {}
    for c in cards:
        key = c["status"] if c["canonical"] else ("(no status)" if not c["status"] else "not a lane: " + c["status"])
        lanes[key] = lanes.get(key, 0) + 1
    print("# Open cards: %d" % len(cards))
    for key in sorted(lanes, key=lambda k: (-lanes[k], k)):
        print("- %s: %d" % (key, lanes[key]))
    print("- on the north: %d" % sum(c["north"] for c in cards))
    print("- open %s items: %d; open items that name the author without the tag: %d"
          % (TAG, sum(c["open_author"] for c in cards), sum(c["open_names_author"] for c in cards)))
    for w in warnings:
        print("- WARNING, north set: %s. Judge 'on the north' from the north card itself." % w)
    print()
    for c in cards:
        if c["idle_days"] is None:
            idle = "no date"
        elif c["last_from"] == "entry":
            idle = "idle %d days (last %s)" % (c["idle_days"], c["last"])
        else:
            idle = "idle %d days (no real entry; %s %s)" % (c["idle_days"], c["last_from"], c["last"])
        lane = c["status"] or "(no status)"
        if not c["canonical"]:
            lane += " [not a kanban lane]"
        if c["north"]:
            lane += " · north"
        print("## %s\n- %s · %s · %d %s · %d agent (%d name the author) · %d checked · note %d chars · %d bytes"
              % (c["card"], lane, idle, c["open_author"], TAG, c["open_agent"], c["open_names_author"],
                 c["checked"], c["status_note_chars"], c["bytes"]))
        if c["title"]:
            print("- title: " + c["title"])
        if c["updated"]:
            print("- updated: " + c["updated"])
        if c["status_note"]:
            print("- note: " + c["status_note"])
        for e in c["newest_entries"]:
            print("- entry: " + e)
        for i in c["first_open_items"]:
            print("- open: " + i)
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
