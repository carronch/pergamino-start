# RESOLVER — Where does this go?

**Read this before you create any new page in the LLM brain.**

Every piece of knowledge has exactly one home. Walk the rules from top to bottom; the first match wins. One subject → one page → one directory, with no overlaps and no gaps. Cross-references keep related pages connected.

The LLM brain supports three kinds of work:

- **Operating**: things the author runs and ships (businesses, clients, projects, decisions, tools, vendors)
- **Exploring**: business ideas not yet committed (ventures)
- **Research**: what the author thinks about (themes, thinkers, concepts)

`businesses/` is the operating hub. `themes/` is the research hub.

The install copies this file to `RESOLVER.md` in the LLM brain (`$PERGAMINO_LLM_BRAIN`). The copy in the brain is authoritative at runtime, and `setup-interview` customizes it. The kit's copy is the default for new brains.

---

## The tree

```
<LLM brain>/
├── RESOLVER.md                ← this file
├── lessons.md                 ← corrections that apply to every session
├── inbox/                     ← captures waiting for deep-ingest (Shape A)
├── Clippings/                 ← Obsidian Web Clipper files waiting for deep-ingest (Shape B)
├── raw/                       ← immutable sources, processed: false until ingested
│   ├── articles/
│   ├── papers/
│   ├── books/
│   ├── transcripts/
│   ├── podcast-episodes/
│   ├── correspondence/
│   ├── code/                  ← a summary of a repository studied as an artifact
│   ├── media/                 ← images, each with a .md description
│   ├── web/                   ← URL-fetched pages (the provenance is the URL)
│   ├── notes/                 ← text-only captures and snippets (no URL)
│   └── autoresearch/          ← sources fetched by deep-ingest and autoresearch, by date
├── reminders/                 ← dated reminders (frontmatter due: YYYY-MM-DD) for the author
├── wiki/
│   ├── _index.md              ← master index, rebuilt by a script, never hand-edited
│   ├── _graph.json            ← link graph, rebuilt with the index
│   ├── log.md                 ← append-only log of ingests, queries, lints and sweeps
│   ├── todo.md                ← lint findings
│   │
│   ├── businesses/            ← the author's operating entities
│   ├── clients/               ← customers served through one of the businesses
│   ├── projects/              ← specific work inside a business or for a client
│   ├── decisions/             ← technical and business decision records
│   ├── tools/                 ← external software, platforms, APIs, protocols
│   ├── vendors/               ← services the author pays for or depends on
│   │
│   ├── ventures/              ← business ideas not yet committed
│   │
│   ├── themes/                ← long-running research threads
│   ├── thinkers/              ← intellectual influences (engaged through their work)
│   ├── concepts/              ← frameworks, patterns, mental models
│   │
│   ├── meetings/              ← one note per meeting (ingest-meeting)
│   ├── workblocks/            ← work cards: one card per project or plan (the kanban)
│   ├── summaries/             ← one summary per ingested source
│   └── syntheses/             ← cross-source analysis, board memos, sweep reports, kept answers
│
├── personal/                  ← the author's personal domains, portfolio list, access notes
└── outputs/                   ← generated on demand: reports, decks, handoff texts
    └── mainvault-pending/     ← the tray: proposals back to the Main brain
```

The truth zone (**the author's authoritative principles, beliefs, life-level decisions, heartbeats and private reads on people**) lives in the Main brain (`$PERGAMINO_MAIN_BRAIN`), not here. Agents are read-only on the Main brain; only `soul-audit`, invoked by name, writes there. Never create or edit belief, principle or life-decision pages in the LLM brain.

---

## Decision tree

Start: **what is the primary subject of this page?**

### Raw source first

0. **An article, paper, post, transcript, PDF or image to process** → `raw/<kind>/<slug>` with `processed: false`. `ingest` routes it to `wiki/summaries/<slug>.md` and extracts entities. A file in `raw/` does not ingest itself: the author, or a calling skill, starts the ingest.
   - **A URL** (the provenance is the URL itself) → `raw/web/<YYYY-MM-DD>-<slug>.md`. `deep-ingest` fetches and saves it. A URL that points at a PDF → `raw/papers/` with `source_type: paper`.
   - **A local file** → by extension and content:

     | Extension or shape | Goes to | `source_type` |
     |---|---|---|
     | `.pdf` (academic, journal article) | `raw/papers/<slug>.pdf` | paper |
     | `.pdf` (book) | `raw/books/<slug>.pdf` | book |
     | Markdown article (clean text body) | `raw/articles/<slug>.md` | article |
     | Email export | `raw/correspondence/<YYYY-MM-DD>-<slug>.md` | correspondence |
     | Voice memo or audio transcript | `raw/transcripts/<YYYY-MM-DD>-<slug>.md` | transcript |
     | Code repository (studied as an artifact) | `raw/code/<slug>.md` (a *summary* of the repository, not the code) | code |
     | Image (diagram, photo) | `raw/media/<slug>.<ext>` and a `.md` description next to it | media |
     | Anything you cannot classify | Ask the author. Do not guess into a wrong folder. | |

   - **A text snippet or a text-only capture** (an `inbox/` file with `urls: []`) → `raw/notes/<YYYY-MM-DD>-<slug>.md` with `source_type: note`. `deep-ingest` files it and skips the research pass.
   - **An instruction to the agent** ("remind me to…", "make a note that…") → not a source. Act on it: a dated reminder in `reminders/`, or an item on the right card in `wiki/workblocks/`.
   - **A meeting transcript** → `ingest-meeting`. It writes `wiki/meetings/` (rule 12) and links the transcript where it already lives.

### Operating

1. **One of the author's operating entities**: it has a legal entity or is incorporating, it has accounting, it has operations → `wiki/businesses/<slug>.md`

2. **A customer served through one of the businesses** (pays the author, receives work) → `wiki/clients/<slug>.md`

3. **Something actively built inside a business or for a client**: a campaign, a feature, a property improvement, a funnel → `wiki/projects/<slug>.md`, with `business:` or `client:` frontmatter that points to the parent

4. **A decision worth explaining or revisiting** → `wiki/decisions/<slug>.md`, with `business:` or `client:` if it affects a specific one

5. **An external software tool, platform, library, API, service or protocol** → `wiki/tools/<slug>.md`

6. **A service the author pays for or depends on** → `wiki/vendors/<slug>.md`

7. **The plan and the state of current work on a project** → its card in `wiki/workblocks/YYYY-MM-DD-<slug>.md`, from `templates/workblock.md`. One card per project or plan. New work inside a project goes on its existing card; do not open a second card.

### Exploring

8. **A business idea not yet committed** → `wiki/ventures/<slug>.md`

### Research

9. **A long-running research thread**: a topic that deepens over weeks or months → `wiki/themes/<slug>.md` with `cluster: work | interest | teaching`

10. **A person whose ideas the author tracks**: an intellectual influence, engaged through their work, not a contact → `wiki/thinkers/<slug>.md` (or `wiki/thinkers/<slug>/` with an index and `frames/`, when the thinker has many frames)

11. **A reusable mental model, framework, pattern or thesis** → `wiki/concepts/<slug>.md`, with `subkind: mental-model` for Munger-style frameworks (from `wiki-templates/mental-model.md`)

### Both

12. **A meeting** → `wiki/meetings/<YYYY-MM-DD>-<slug>.md` (`ingest-meeting`)

13. **A record of one source** that the author ingested → `wiki/summaries/<slug>.md`

14. **A cross-source analysis, or a kept answer to a question the author asked** → `wiki/syntheses/<slug>.md`, OR `outputs/YYYY-MM-DD-<slug>.md` if it was generated on demand and is not knowledge (a report, a deck, a handoff text)

15. **A proposed change to the Main brain** → `outputs/mainvault-pending/YYYY-MM-DD-<slug>.md`, with `<!-- target: <path-in-main-brain> -->` as the first line. The author promotes it with `"$PERGAMINO_HOME/scripts/promote-to-mainvault.sh"` or by hand.

16. **A correction that applies to every session** → `lessons.md` (from `templates/lessons.md`). A correction that belongs to one project → that project's card, under `## Lessons`.

17. **Personal, not work**: health, family, finances → `personal/`. Agents read it on request, and never surface it on their own.

18. **Nothing fits cleanly** → `inbox/YYYY-MM-DD-<slug>.md`. Flag it in chat. The next `deep-ingest` or `maintain` pass sorts it.

---

## Disambiguation rules

- **Business vs. client:** A business is one of the author's own entities. A client pays the author through one of those businesses. If both are true (a client that uses the author's services AND in which the author has invested), file it as a client, and note the equity on the page.

- **Business vs. venture:** A business has a legal entity (or is incorporating), accounting and operations. A venture is an idea without a commitment. **Test: does it have accounting?** Yes → business. No → venture.

- **Venture vs. project:** A venture is a whole business in waiting. A project is a specific piece of work inside an existing business. A note-taking app (as an idea) is a venture; "build the note-taking app's first version" as a task inside an operating business would be a project.

- **Project vs. business:** A project lives *inside* a business. If the work would need its own entity, accounting or independent operations, it is a venture (before commitment) or a business (after) — not a project.

- **Project page vs. card:** The project page in `wiki/projects/` holds the compiled truth about the project. The card in `wiki/workblocks/` holds the plan, the next actions and the dated timeline of the work. The card links to the page; it does not restate it.

- **Theme vs. concept:** A theme is a topic area. A concept is one framework within it. "Munger's mental models" is a theme. "Inversion" is a concept.

- **Theme vs. venture:** Themes deepen understanding. Ventures evaluate whether to commit. Research on "prediction markets" is a theme. "Should I build a prediction market platform?" is a venture.

- **Theme vs. project:** A project ships. A theme deepens. Research on AI agent infrastructure is a theme. A trading bot built inside one of the businesses is a project that draws from that theme.

- **Thinker vs. a person in the Main brain:** Thinker pages are for intellectual influences, engaged through their work. Business partners, family and contacts live in the Main brain's `people/` (the author's zone). Munger → thinker. A business partner → the Main brain, not a wiki page. Meeting attendees resolve to their organization's page.

- **Mental model vs. regular concept:** A mental model uses the Munger-style structure (when it applies, when it does not, counterexamples). Both live in `concepts/`. Mental models use `subkind: mental-model`.

- **Decision vs. truth:** `wiki/decisions/` holds technical and business decision records. Life-level decisions ("leave my job", "move countries") live in the Main brain's truth zone.

- **Tool vs. vendor:** A tool is a thing the author uses in their work (the software itself). A vendor is the relationship (whom the author pays, what the contract covers, what is at stake if it disappears). Cloudflare Workers = tool. Cloudflare, the company that holds the author's account = vendor.

- **Tool vs. project:** A tool exists in the world (Cloudflare Workers). A project is the author's work. A lending protocol is a tool; the author's bot that trades on it is a project inside one of the businesses.

---

## Page structure — every wiki page

All `wiki/**` entity pages follow the compiled-truth-plus-timeline pattern. The templates in `wiki-templates/` set the fields for each kind.

```markdown
---
kind: business | client | project | decision | tool | vendor | venture | theme | thinker | concept | summary | synthesis
title: ""
slug: ""
aliases: []                  # all known variants
tags: []
sources: [raw/<kind>/<slug>]
created: YYYY-MM-DD
updated: YYYY-MM-DD
confidence: high | medium | low
---

# {{ title }}

<!-- Compiled truth: the current best understanding. Rewrite it when the evidence changes. -->

[One-paragraph summary: who or what it is, and why it matters.]

## State
[Current state: active or inactive, relationship, open threads, key facts.]

## Links
- Related project: [[wiki/projects/<slug>]]
- Related thinker: [[wiki/thinkers/<slug>]]

<!-- timeline -->
<!-- Append-only evidence log. Never rewrite or delete past entries. -->
- YYYY-MM-DD: [source:raw/articles/<slug>] First mention, in an article about X.
- YYYY-MM-DD: [source:wiki/meetings/YYYY-MM-DD-<slug>] Role confirmed in the kickoff meeting.
```

**Rules:**
- The compiled truth above `<!-- timeline -->` is the current state. Rewrite it when reality changes. It keeps no history.
- The timeline below is append-only. Every entry has a date and a source reference.
- Never mix the two. If you catch yourself editing a timeline entry, stop, and write a new entry instead.
- Cite every factual claim: `[Source: raw/...]` or `[source:...]` in a timeline entry.
- One home per fact. When a fact changes, update its home page first. Other pages and cards link to it; they do not copy it.

Work cards in `wiki/workblocks/` use the same split, with their own fields: see `templates/workblock.md`.

---

## Naming — slugs

Lowercase, hyphens, no spaces, no accents. At most 60 characters. **Same input → same slug**, always.

- **People (thinkers):** `first-last` (for example `charlie-munger`). Put variants in `aliases: []`.
- **Businesses, clients, vendors, tools:** a short handle.
- **Projects:** one canonical slug per repository. All other names (repository clone suffixes, names in another language, old internal code names) go in the page's `aliases: []` frontmatter, not in separate slugs.
- **Concepts:** descriptive kebab-case.
- **Dated pages** (meetings, cards, raw web pages, notes, outputs): `YYYY-MM-DD-<slug>`.
- **From a URL:** derive the slug from the URL path. Strip `www.`, query strings and anchors first. `https://every.to/guides/compound-engineering` → `compound-engineering`.
- **From a file:** the basename without the extension, lowercased, with spaces and underscores as hyphens.

The **canonical slug list for the author's portfolio** lives in `personal/my-portfolio.md` in the LLM brain, not in this template. `skills/setup-interview/` writes it on the first run. Agents consult that file before they invent a name.

---

## Back-links — the iron law

Every `[[wiki/path/slug]]` reference needs a link back from the target. `enrich` maintains back-links when it creates or updates a page. `lint` reports the gaps. If you hand-edit a page to reference another, add the back-link on the target's timeline in the same edit.

Memory references are plain text (`` `memory: <slug>` ``), never `[[wikilinks]]`. `[[...]]` is only for paths inside the LLM brain.

---

## Never file here

- `raw/` is read-only after capture. `ingest` sets `processed: true` and changes nothing else.
- `wiki/_index.md` and `wiki/_graph.json` are derived. Rebuild them with `bash "$PERGAMINO_HOME/scripts/rebuild-index.sh" "$PERGAMINO_LLM_BRAIN"`.
- Beliefs, principles, life-decisions, heartbeats and private notes on people **live in the Main brain, not in the LLM brain.** Never create or edit them here.
- `inbox/_processed/`, `inbox/_dead-letter/`, `Clippings/_processed/` and `Clippings/_dead-letter/` are the capture audit trail. Do not file new material there.

---

## Cross-references do not duplicate

One business page per entity. One venture page per idea. One card per project. Projects and decisions link to their business through `business:` frontmatter. Themes link to businesses where relevant. Do not copy content between pages: link.

---

## Promotion gate

Nothing moves from the LLM brain's `outputs/` to the Main brain automatically. The author reviews each proposal in the tray, and only the author promotes it (or sets `promoted: true`). The `caveats:` field tells the author what the agent was unsure about.

---

## When the agent walks this tree

Before you create a page, state the destination in chat:

> "New page for <title>. Walking the resolver: it matches rule #<n>, because <reason>. Filing to `wiki/<dir>/<slug>.md`."

Then write it. A new page is small and reversible, so the author can redirect afterwards. After three clean walks in the same category, proceed silently in that category. Before you claim that a page does not exist, search for it (`qmd search "<name>" -c llm`, and `-c main`), with its aliases.

---

## When to expand the tree

Add a new top-level directory when:
1. A category has more than 30 pages and needs its own resolver.
2. The category has fundamentally different rules (for example `meetings/` has date-based slugs, not kebab-case).

When that happens: add it here first, add a `README.md` to the new directory, then start filing. Never let a directory exist without a README that explains what belongs in it.
