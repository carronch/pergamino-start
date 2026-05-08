# RESOLVER — Where Does This Go?

**Read this before creating any new page in `wiki/`.**

Every piece of knowledge has exactly one home. Walk top to bottom; the first match wins. MECE: one subject → one page → one directory. Cross-references preserve adjacency.

This vault supports three kinds of work:

- **Operating** — things the author runs and ships (businesses, clients, projects, decisions, tools, vendors)
- **Exploring** — business ideas not yet committed (ventures)
- **Research** — what the author thinks about (themes, thinkers, concepts)

`businesses/` is the operating hub. `themes/` is the research hub.

The kit's install script copies this file to `~/LLM{{SLUG}}Brain/RESOLVER.md` on first run — the vault-local copy is authoritative at runtime; the repo copy is the source of truth across projects.

---

## The tree

```
LLM{{SLUG}}Brain/
├── RESOLVER.md                ← this file
├── raw/                       ← unprocessed sources, processed: false
│   ├── articles/
│   ├── papers/
│   ├── transcripts/
│   ├── podcast-episodes/
│   ├── web/                   ← URL-fetched pages (provenance is the URL)
│   ├── notes/                 ← text-only captures from inbox/ (no URL)
│   └── assets/
├── inbox/                     ← unclassified; /compile sorts it
├── wiki/
│   ├── _index.md              ← master index, never edit manually
│   ├── log.md                 ← append-only ingest log
│   ├── todo.md                ← lint findings
│   │
│   ├── businesses/            ← the author's operating entities (e.g. {{ENTITY_EXAMPLE_1}}, {{ENTITY_EXAMPLE_2}})
│   ├── clients/               ← customers served through one of the businesses
│   ├── projects/              ← specific work inside a business
│   ├── decisions/             ← technical + business ADRs
│   ├── tools/                 ← external software, platforms, APIs, protocols
│   ├── vendors/               ← services the author pays for or depends on
│   │
│   ├── ventures/              ← business ideas not yet committed
│   │
│   ├── themes/                ← long-running research threads
│   ├── thinkers/              ← intellectual influences (engaged through their work)
│   ├── concepts/              ← frameworks, patterns, mental models
│   │
│   ├── summaries/             ← one summary per ingested source
│   └── syntheses/             ← cross-source analysis, dashboards, kept Q&A
│
├── personal/                  ← personal domains (not studio work)
├── plans/                     ← session plans (from /plan); project repos symlink docs/plans here
├── solutions/                 ← solution write-ups; project repos symlink docs/solutions here
└── outputs/                   ← Q&A, slides, reports — promoted: false until the author says so
```

`plans/` and `solutions/` are agent-owned work artifacts shared across project repos. Each project's `docs/plans/` and `docs/solutions/` is a symlink into these directories (created by the install script). Plans and solutions are not knowledge artifacts — they don't get filed by `/compile` or indexed in `wiki/_index.md`.

Truth zone — **the author's authoritative principles, beliefs, life-level decisions, and private reads on people in their life** — lives in `~/Main{{SLUG}}Brain/`, not here. Agents are read-only on the MainBrain. Never create or edit belief/principle/life-decision pages in the LLMBrain.

---

## Decision tree

Start: **what is the primary subject of this page?**

### Raw source first

0. **An article, paper, tweet, transcript, PDF, image you want processed** → `raw/<kind>/<slug>` with `processed: false`. `/compile` routes it to `wiki/summaries/<slug>.md` and extracts concepts. **URL-fetched pages** (where provenance is the URL itself, not a paper or podcast) → `raw/web/<YYYY-MM-DD>-<slug>.md`; the `deep-ingest` skill handles fetch + save. **Text-only captures** from `inbox/` (a `type: capture` file with `urls: []`) → `raw/notes/<YYYY-MM-DD>-<slug>.md`; `deep-ingest` files them and skips the research pass since there's nothing external to fetch.

### Operating

1. **One of the operating entities** — has legal entity or is incorporating, has accounting, has operations → `wiki/businesses/<slug>.md`

2. **A customer served through one of the businesses** (pays the author, the author delivers work) → `wiki/clients/<slug>.md`

3. **Something being actively built inside a business or client** — campaign, feature, property improvement, funnel → `wiki/projects/<slug>.md` with `business:` or `client:` frontmatter pointing to the parent

4. **A decision worth explaining or revisiting** → `wiki/decisions/<slug>.md` with `business:` or `client:` if it affects a specific one

5. **An external software tool, platform, library, API, service, or protocol** → `wiki/tools/<slug>.md`

6. **A service the author pays for or depends on** → `wiki/vendors/<slug>.md`

### Exploring

7. **A business idea not yet committed** → `wiki/ventures/<slug>.md`

### Research

8. **A long-running research thread** — a topic deepening over weeks or months → `wiki/themes/<slug>.md` with `cluster: work | interest | teaching`

9. **A person whose ideas the author tracks** — an intellectual influence, engaged through their work, not a contact → `wiki/thinkers/<slug>.md`

10. **A reusable mental model, framework, pattern, or thesis** → `wiki/concepts/<slug>.md` — with `subkind: mental-model` for Munger-style frameworks (uses `wiki-templates/mental-model.md`)

### Both

11. **A record of one source** the author has ingested → `wiki/summaries/<slug>.md`

12. **A cross-source analysis or kept answer to a question the author asked** → `wiki/syntheses/<slug>.md` OR `outputs/YYYY-MM-DD-<slug>.md` if generated on demand

13. **Personal, not studio work** — health, family, finances — → `personal/`. Agents read on request, never proactively surface.

14. **Nothing fits cleanly** → `inbox/YYYY-MM-DD-<slug>.md`. Flag in chat. `/compile` sorts it on next run.

---

## Disambiguation rules

- **Business vs. Client:** A business is one of the author's own entities. A client pays the author through one of those businesses. If both are true (a customer is using the services AND the author is invested), file as client; note the equity in the page.

- **Business vs. Venture:** A business has a legal entity (or is incorporating), accounting, operations. A venture is an idea not committed to. **Test: does it have accounting?** Yes → business. No → venture.

- **Venture vs. Project:** A venture is a whole business-in-waiting. A project is a specific piece of work inside an existing business. A new product idea (as a concept) is a venture; "Build the MVP for that idea" as a dev task inside an operating entity would be a project.

- **Project vs. Business:** A project lives *inside* a business. If the work would warrant its own entity, accounting, or independent operations, it's a venture (pre-commit) or business (committed) — not a project.

- **Theme vs. Concept:** A theme is a topic area; a concept is one framework within it. "Mental models" is a theme. "Inversion" is a concept.

- **Theme vs. Venture:** Themes deepen understanding. Ventures evaluate whether to commit. Research on "prediction markets" is a theme. "Should I build a prediction market platform" is a venture.

- **Theme vs. Project:** A project ships. A theme deepens. Research on AI agent infrastructure is a theme. A concrete bot the author is shipping is a project inside one of the businesses that draws from that theme.

- **Thinker vs. Person-in-the-MainBrain:** Thinker pages are for intellectual influences engaged through their work. Business partners, family, contacts live in `~/Main{{SLUG}}Brain/` (the author's zone). Munger → thinker. A business partner → MainBrain, not a wiki page.

- **Mental model vs. regular concept:** Mental model uses Munger-style structure (when it applies / doesn't / counterexamples). Both live in `concepts/`; mental models use `subkind: mental-model`.

- **Decision vs. Truth:** `wiki/decisions/` holds technical and business ADRs. Life-level decisions ("quit finance", "move home") live in the MainBrain's truth zone.

- **Tool vs. Vendor:** A tool is a thing the author uses in their work (the software itself). A vendor is the relationship (who they pay, what the contract covers, what's at stake if they disappear). Cloudflare Workers = tool. Cloudflare (the company they have an account with) = vendor.

- **Tool vs. Project:** A tool exists in the world (Cloudflare Workers). A project is the author's work. A protocol or library is a tool; a bot built on top of it is a project inside one of the businesses.

---

## Page structure — every wiki page

All `wiki/**` pages follow the compiled-truth-plus-timeline pattern.

```markdown
---
type: business | client | project | decision | tool | vendor | venture | theme | thinker | concept | summary | synthesis
title: ""
slug: ""
aliases: []                  # all known variants
tags: []
sources: [raw/<kind>/<slug>]
backlinks: []                # populated by /compile
created: YYYY-MM-DD
updated: YYYY-MM-DD
confidence: high | medium | low
---

# {{ title }}

<!-- Compiled truth: current best understanding. Rewritten when evidence changes. -->

[One-paragraph summary — who/what/why they matter.]

## State
[Current state: active/inactive, relationship, open threads, key facts.]

## Links
- Related project: [[wiki/projects/<slug>]]
- Related thinker: [[wiki/thinkers/<slug>]]

<!-- timeline -->
<!-- Append-only evidence log. Never rewrite or delete past entries. -->
- 2026-04-20: [source:raw/articles/<slug>] First mention in conversation about X.
- 2026-04-22: [source:meeting/2026-04-22-<slug>-kickoff] Confirmed role as CTO.
```

**Rules:**
- Compiled truth above `<!-- timeline -->` is the current state. Rewrite when reality changes. No history kept.
- Timeline below is append-only. Every entry has a date and a source reference.
- Never mix the two. If you catch yourself editing a timeline entry, stop — write a new entry instead.

Page templates for each `type` live in [`wiki-templates/`](../wiki-templates/).

---

## Naming — slugs

Lowercase, hyphens, no spaces, no accents. Max 60 chars.

- **People (thinkers):** `first-last` (e.g. `charlie-munger`). Use `aliases: []` for variants.
- **Businesses / clients / vendors / tools:** short handle.
- **Projects:** one canonical slug per repo. All alternative names (repo-clone suffixes, language variants, old internal codenames) go in the page's `aliases: []` frontmatter — not as separate slugs.
- **Concepts:** descriptive kebab-case.

The **canonical slug list for the portfolio** lives in the local vault, not this template. The setup interview (`pergamino-intake`) populates `~/LLM{{SLUG}}Brain/personal/my-portfolio.md` during first-run configuration. Agents consult that file before inventing names.

---

## Backlinks — the Iron Law

Every `[[wiki/path/slug]]` reference creates a backlink on the target. `/compile` maintains these. If you hand-edit a wiki page to reference another, you don't need to touch the target — `/compile` adds the backlink on next run.

---

## Never file here

- `raw/` — read-only after ingest. `/compile` sets `processed: true` but doesn't rewrite.
- Beliefs, principles, life-decisions, private people notes — **live in the MainBrain, not the LLMBrain.** Never create or edit here.

---

## Cross-references don't duplicate

One business page per entity. One venture page per idea. Projects and decisions link to their business via `business:` frontmatter. Themes link to businesses where relevant. Don't copy content between pages — link.

---

## Promotion gate

Nothing moves from `LLM{{SLUG}}Brain/outputs/` to the MainBrain automatically. The author reviews, and only the author sets `promoted: true`. The `caveats:` field tells them what the agent was uncertain about.

---

## When the agent walks this tree

Before creating any page, state in chat:

> "New page for <title>. Walking the resolver: matches rule #<n>, because <reason>. Filing to `wiki/<dir>/<slug>.md`. Any objection?"

The author redirects before the write. After three clean walks in the same category, proceed silently on that category.

---

## When to expand the tree

Add a new top-level directory when:
1. A category has more than 30 pages and should have its own resolver.
2. The category has fundamentally different rules (e.g. `meetings/` has date-based slugs, not kebab-case).

When that happens: add it here first, add a `README.md` to the new directory, then start filing. Never let the directory exist without a README explaining what belongs in it.
