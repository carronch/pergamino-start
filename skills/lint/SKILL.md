---
name: lint
description: "Health-check the LLM brain's wiki and propose fixes without applying them: orphans, broken wikilinks, missing compiled truth, contradictions, wiki versus Main brain disagreements, stale summaries and claims, uncited claims, missing back-links, schema drift, themes without the author's own words, and tray hygiene. Use weekly, every 20–30 ingests, or when the author says 'run lint', 'clean up the wiki', 'what's stale?' or types /lint."
---

# Skill: Lint the wiki

Run it weekly, every 20–30 ingests, or when the author asks. This is diagnostic: **propose fixes, do not
apply them on your own.**

Paths are relative to the LLM brain (`$PERGAMINO_LLM_BRAIN`). The Main brain is `$PERGAMINO_MAIN_BRAIN`.

## Requires

- `python3` (the graph builder reads and writes `wiki/_graph.json`).
- optional: `qmd` (contradiction and Main brain checks). Check with `command -v qmd`.

## Before the checks: rebuild the index and the graph

```bash
bash "$PERGAMINO_HOME/scripts/rebuild-index.sh" "$PERGAMINO_LLM_BRAIN"
```

The rebuild writes `wiki/_index.md` and `wiki/_graph.json`. If the graph is
missing after the rebuild, run
`python3 "$PERGAMINO_HOME/scripts/build-graph.py" "$PERGAMINO_LLM_BRAIN"`.
Check that the graph's `generated:` timestamp is from this run before you trust it.
Use the absolute kit path above, not a copy or a symbolic link inside the brain: a stale copy can skip the graph silently.

## Checks

### 1. Orphans

Pages with no inbound wikilinks. Outbound links do not count, and neither do
mention edges. **Method:** read `wiki/_graph.json` → `.orphans`. `build-graph.py`
computes inbound-only orphans. Do not re-derive them with `grep`: a `grep` loop matches
name substrings and cannot apply the exclusions below.

**Exclusions** (orphans by design; drop them from the report if the graph lists them):

- `wiki/workblocks/*.md`: work cards. The kanban and the cards digest read them; pages link from them, not to them.
- `README.md` files: structural (see `RESOLVER.md` § When to expand the tree).
- `_`-prefixed queue files (for example `wiki/<dir>/_queue.md`): read by scheduled jobs.
- Dated reports in `wiki/research/` (the basename contains a `YYYY-MM` date): cards link to them when relevant. An undated research brief still counts.
- The operational surfaces `wiki/todo.md`, `wiki/next-actions.md` and `wiki/log.md`.

For a real orphan, two outcomes:
- The page holds a useful fact or claim → propose cross-links to existing concept or theme pages.
- The page is a dead end → propose archival to `wiki/<dir>/archive/<slug>.md`. Do not delete.

**Parsing rule:** strip fenced code blocks and inline code
BEFORE you extract wikilinks. Bash `[[ ... ]]` conditionals and TOML
`[[tables]]` inside code blocks are not wikilinks. A naive `grep` produces many false positives. Also require that the
link target contains no newline.

### 2. Broken wikilinks

Wikilinks that point to files that do not exist. **Method:** read
`wiki/_graph.json` → `.unresolved` (target → citing pages). Resolve targets
against the WHOLE LLM brain, not only `wiki/`: `[[raw/...]]` and `[[workblocks/...]]`
links are valid Obsidian links. The builder accepts links into the brain's real top-level
directories by prefix. Known blind spot: a link accepted by prefix is not
verified to exist on disk. That is the price of never passing link text to
filesystem calls. A periodic manual spot-check of the `out_of_scope_links_skipped`
targets covers it.

**Memory references.** A `[[...]]` link to an agent memory slug is always broken. Memory references are plain text (`` `memory: <slug>` ``). Propose the plain-text form.

### 3. Missing compiled-truth sections

Entity pages that 3 or more sources reference but that do not OPEN with a compiled
synthesis: an intro paragraph (or principle section) that states what the thing
is and why it matters, in the brain's own words. Do NOT test for a literal
"## Summary" heading: the convention is an H1 and an intro synthesis. A page that
is only a status one-liner, a list of versions or components, a link dump or a bare timeline fails.

### 4. Contradictions within the wiki

Walk the theme and concept pages. For each `## Current thesis` or `## Key claims` block, check whether another page makes a conflicting claim about the same entity or fact.

- Both claims cite different sources → normal disagreement. Propose a note on the page: "Sources differ; see X vs. Y."
- Both claims cite the same source → one of them is wrong. Flag both.

Do not resolve them yourself. The author decides.

### 5. Wiki versus Main brain disagreements

For each claim in the Main brain, check whether a wiki page contradicts it. Flag
the wiki page. The Main brain is the authority, but never edit the Main brain, and
never silently edit the wiki to match. Ask the author. If the disagreement suggests that the author's belief may be out of date, stage a proposal in `outputs/mainvault-pending/` (see `skills/query/SKILL.md` § Staging format).

### 6. Stale summaries and stale claims

- Summaries older than 90 days: check whether a newer source supersedes them. Suggest a revision.
- Pages with `confidence: forming` or `confidence: low` and `updated:` more than 6 months ago: flag them for review. The author's confidence may have changed.
- Sources still marked `processed: false` in `raw/` that a page cites: list the sources that wait for an ingest.

### 7. Uncited claims

Wiki pages with factual claims that have no `[Source: ...]` attribution.

### 8. Missing cross-references

A summary mentions an entity that has a wiki page, but the entity page's timeline
does not link the summary. That is a back-link gap. Cross-links go both ways.

### 9. Schema drift

For each page in `wiki/`, check that the frontmatter matches its template in `"$PERGAMINO_HOME/wiki-templates/"` (the right `kind` or `type`, the required fields, valid `confidence` values), and that its sections match the type (for example, a summary has a TL;DR and Key claims, and every entity page keeps the compiled truth above the timeline). Flag drift. Do not fix it without the author's nod: drift is sometimes intentional.

### 10. Themes without the author's own words

Niklas Luhmann's rule: translation into your own words is what converts information
into knowledge. Skill-written summaries are in the model's voice. Themes need a periodic
pass in the author's voice, so that the brain does not drift into polished notes that nobody owns.

**Flag a theme if ALL of these hold:**
- The theme is NOT marked `status: dormant` in frontmatter (parked themes
  opt out; remove the field to re-arm the check).
- `wiki/themes/<slug>.md` was created or last substantively updated 30 or more days ago
  (check frontmatter `updated:` or the file's git log, whichever is more recent).
- The file does NOT contain a section titled `## In my own words`,
  `## My reading` or `## My position`.
- The theme has at least one source consumed (otherwise there is nothing yet
  to translate).

**Detection:**
```bash
to_epoch() { date -j -f "%Y-%m-%d" "$1" +%s 2>/dev/null || date -d "$1" +%s 2>/dev/null || echo 0; }
for f in "$PERGAMINO_LLM_BRAIN"/wiki/themes/*.md; do
  # frontmatter-scoped and quote-tolerant: body prose that mentions the
  # convention must not opt a theme out
  sed -n '2,/^---$/p' "$f" | grep -qE '^status:[[:space:]]*["'"'"']?dormant' && continue
  updated=$(grep -E "^updated:" "$f" | head -1 | sed -E 's/updated: *//; s/"//g')
  [ -z "$updated" ] && continue
  age_days=$(( ( $(date +%s) - $(to_epoch "$updated") ) / 86400 ))
  [ "$age_days" -lt 30 ] && continue
  has_voice=$(grep -cE "^## (In my own words|My reading|My position)" "$f")
  has_sources=$(grep -cE "^## Sources consumed" "$f")
  [ "$has_voice" -eq 0 ] && [ "$has_sources" -gt 0 ] && echo "stale-voice: $f ($age_days days)"
done
```

**Proposed fix in the lint report:**

> **Theme `<slug>` — `N days` stale, not in your words.**
> "Do you want to sit with this theme and write an `## In my own words`
> section? It covers sources X, Y, Z. It takes 10–15 minutes."

Do NOT generate the section yourself. This check exists to
create the prompt for the author. If you write the content, the check loses its purpose.
If the author declines (the theme is parked, not active), offer to mark it
`status: dormant` in frontmatter so that it stops being flagged.

### 11. Tray hygiene

Walk `outputs/mainvault-pending/`:
- A staged proposal older than 7 days → surface it: "This proposal has waited since `<date>`. Promote, archive or revise?"
- A proposal marked resolved or archived but still in the tray → propose its removal.

## Output

A markdown checklist in chat. Each item: the issue, the file or files, the proposed
fix. Nothing changes until the author approves. Put the items that block more ingests first.

```
## Lint report — YYYY-MM-DD

### Orphans (3)
- [ ] wiki/tools/xyz.md — no inbound links. Delete or link from ___?

### Broken links (1)
- [ ] wiki/summaries/abc.md → [[nonexistent]]. Fix to [[actual]]?

### Wiki/Main brain disagreements (1)
- [ ] wiki/tools/x.md says X. Main brain beliefs/y.md says Y.
  Keep both with a note, or revise the wiki?

...

### Stats
- Pages: N concepts, N themes, N summaries, ...
- Orphans: N · broken links: N · stale (over 6 months): N · tray pending: N
```

A purely mechanical fix (the index rebuild, a missing back-link) can be applied in the same pass if the author approved the report. Anything that needs judgment waits for the author.

After the author approves, apply the fixes and log:
```
## [YYYY-MM-DD] lint | weekly pass
- fixed 3 orphans, 1 broken link
- flagged 1 wiki/Main brain tension (pending decision)
```

## Rules

- **Lint is read-mostly.** Its job is to surface, not to act.
- **Never delete pages.** Propose archival. Deletion is the author's manual choice.
- **Never edit the Main brain.** Stage proposals.
- **Do not lint during an ingest.** They are separate operations.
- **The second time is a pattern.** If the same finding appears in two consecutive passes, propose a deterministic check (in the index or graph scripts, or a hook) so that the next pass does not need a model for it.
