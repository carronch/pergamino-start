<!-- SCHEMA.md — the schema layer: how the catalog is organized.
     For the rule of the house, see AGENTS.md.
     For routing (where new files go), see RESOLVER.md. -->

# Pergamino — Catalog Schema

This file tells you (the librarian) **how the wiki is organized**. Read it alongside `AGENTS.md` before you create or change a page. When the author edits this file, you adopt the new schema in the next session.

## Frontmatter — every page has it

Every file in `<LLM brain>/wiki/` and every staged file in `outputs/mainvault-pending/` carries YAML frontmatter at the top:

```yaml
---
type: <summary | concept | theme | project | synthesis | thinker | tool | workblock | log | index>
title: "Human-readable title"
slug: lowercase-hyphenated-id
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [tag1, tag2]
sources: []         # optional — wiki/summaries/<slug> wiki-links to source pages
backlinks: []       # optional — auto-maintained by lint
confidence: low | medium | high | strongly-held
---
```

When you create a page, fill these in. When you update a page, bump `updated`. When you discover wrong frontmatter (a `type` that doesn't fit), correct it and note in your session log.

## Page types

### `summary`

One per ingested source. Lives in `<LLM brain>/wiki/summaries/<slug>.md`. The slug matches the raw file's slug.

Standard sections:
- `# <Source title>` (H1)
- `**Source:** [[raw/<path>/<slug>]]`
- `## TL;DR` — 2–4 sentences, dated
- `## Key claims` — each with a `[Source: raw/...]` citation
- `## Tools / concepts / projects / themes` — wiki-links to entity pages
- `## Connections` — what this source bears on, in the author's existing context
- `## Tension with truth` (optional) — if this source contradicts a Main brain position
- `## Open threads` — questions surfaced by this source
- `## Timeline` — bullet log of when this was ingested and updated

### `concept`

A framework, mental model, or pattern the author tracks. Lives in `<LLM brain>/wiki/concepts/<slug>.md`. Created when three or more sources have referenced the same underlying idea (the **rule of three** — don't promote a one-off mention to a concept page).

Standard sections:
- `# <Concept name>` (H1)
- 1-paragraph definition
- `## Key claims` — citing the sources that established this
- `## Lineage` — upstream concepts and downstream applications
- `## How the author uses it` — connect to Main brain if a belief or principle bears on it
- `## Open threads`
- `## Sources` — wiki-links to summary pages
- `## Related` — links to themes, projects, other concepts
- `<!-- timeline -->` — append-only log of edits

### `theme`

A long-running topic the author researches across many sources. Lives in `<LLM brain>/wiki/themes/<slug>.md`. A theme is broader than a concept — it's an *ongoing inquiry*, not a single framework.

Standard sections:
- `# <Theme name>` (H1)
- `## Current thesis` — 2–3 sentences, *dated*. **Tentative.** If the author has a Main brain belief on this, prepend it as the starting position.
- `## Key claims` — each with `[Source: [[summaries/<slug>]]]`
- `## Open questions` — 3–5 active inquiries
- `## Sources consumed` — one line per ingested source, with takeaway
- `## Related concepts / thinkers / projects`
- `## Timeline` — append-only

Themes are mature when 10+ sources have been consumed and the thesis has been stable across at least two updates.

### `project`

A piece of active work the author is doing. Lives in `<LLM brain>/wiki/projects/<slug>.md`. Distinct from themes (theme = research; project = building).

Standard sections:
- `# <Project name>` (H1)
- `## State` — current status, ~5 bullets
- `## Links` — businesses, ventures, themes, related concepts
- `## Sources` — what informed this project
- `<!-- timeline -->`

### `synthesis`

The author's own writing, drawn from the catalog. Lives in `<LLM brain>/wiki/syntheses/<slug>.md`. Unlike summaries (which compress sources) and concepts (which abstract patterns), syntheses are the author's *position* on something, written deliberately.

You may *propose* a synthesis when several concepts seem to converge, but the author writes it. Stage a proposal at `outputs/mainvault-pending/<slug>.md` with `<!-- target: ../wiki/syntheses/<slug>.md -->` if the synthesis should live in the librarian's catalog, or `<!-- target: beliefs/<slug>.md -->` if it should crystallize into a Main brain belief.

### `thinker` and `tool`

People whose ideas the author tracks (`thinkers/`) and tools/services the author uses or considers (`tools/`). Both are entity pages that get cited from summaries.

### `workblock`

A card: one per project or plan. Lives in `<LLM brain>/wiki/workblocks/YYYY-MM-DD-<slug>.md`, from `templates/workblock.md`. The frontmatter carries `status:` (`someday-maybe`, `active`, `waiting-for`, `done`) and `status_note:` (the current state, about 300 characters). The body holds the plan, open `#author` items, and a dated timeline below `<!-- timeline -->`. See `AGENTS.md` § Cards.

### `log` and `index`

`log.md` is append-only chronological. `_index.md` is content-organized. You maintain both.

## File-naming conventions

- All slugs lowercase, hyphenated, max 60 characters.
- Summary slugs derive from the raw source slug — same input always produces same slug, defeats duplicate ingestion.
- Concept and theme slugs are author-blessed (you propose; author confirms).
- No spaces, no uppercase, no punctuation other than hyphens.

## When a single ingest touches many pages

Healthy ingest typically touches **10–15 pages**. The pattern:

1. New summary page (1 file).
2. Updates to 2–4 concept pages it cross-references.
3. Updates to 1–2 theme pages it extends.
4. New entries in `_index.md` and `log.md`.
5. Possibly: a new concept page if this source is the third to reference an idea.
6. Possibly: a tray staging if this source contradicts a Main brain belief.

If your ingest touches **more than 15 pages**, stop and ask the author. You're either over-eager or the source warrants a synthesis (which the author writes, not you).

## When something doesn't fit the schema

Tell the author. Don't invent a new page type without permission. If the schema is wrong-shaped for what you're seeing, propose an addition to this file (stage at `outputs/mainvault-pending/SCHEMA.md` with the proposed new section) — the author updates the schema before you adopt it.

## Backlinks and the index

You don't manually maintain `_index.md` cross-references — the `lint` skill regenerates them. But you DO maintain individual page backlinks (`backlinks: []` in frontmatter) when you cross-link.

When you create page B that links to page A, append page B's slug to page A's `backlinks` list. The lint skill will catch missed ones.

## Versioning the schema

When the author updates this `SCHEMA.md`, log it:

```
## [YYYY-MM-DD] schema | <one-line summary of change>
```

in `<LLM brain>/wiki/log.md`. Schema changes are rare but consequential — the catalog inherits the change going forward.

---

That's the schema. To change it, edit this file. The next session reads it.

*— pergamino.ai*
