# Skill: Research a theme

Research is different from building. Building produces artifacts and has
a "done" state; research deepens over time and produces understanding.

Use this skill when the author says:
- "I want to go deeper on <topic>"
- "Let's research <theme>"
- "What do we know about <topic>?" and the answer reveals a thin theme
- "Help me build a view on <topic>"

## What research looks like in this vault

Research produces:

- **Theme pages** (`wiki/themes/`) — the hub where sources, thinkers,
  concepts, and synthesis compile over time
- **Thinker pages** (`wiki/thinkers/`) — intellectual influences tracked
- **Mental model pages** (`wiki/concepts/` with `subkind: mental-model`) —
  reusable frameworks extracted
- **Source summaries** (`wiki/summaries/`) — one per book, essay, talk,
  podcast ingested under the theme
- **Eventually**: essays, decisions, beliefs graduated to the MainBrain, or projects

## Phase 1 — Establish the theme

When the author first mentions a research topic, walk RESOLVER. Almost certainly
→ `themes/`.

1. **Determine the cluster** (mandatory `cluster:` field):
   - `work` — feeds a business, project, or venture. Mental models for
     decision-making, operational tactics, market dynamics relevant to
     the company's vertical.
   - `interest` — curiosity. Topics the author is drawn to without an
     immediate operational use. May produce nothing beyond enjoyment.
   - `teaching` — aimed at creating output for others. Material the
     author plans to share, teach, or publish. These themes graduate
     into curriculum, essays, or workshops.

   Ask the author if not obvious: *"Is this for work (feeds a business or
   project), personal interest, or for teaching others?"*

2. Create `wiki/themes/<slug>.md` from `wiki-templates/theme.md` with the
   cluster field set.
3. Populate what's already known from existing wiki content:
   ```bash
   grep -rl "<theme keywords>" ~/LLM{{SLUG}}Brain/wiki/
   ```
   Any existing summaries, concepts, or syntheses that touch the theme get
   linked into the theme page.
4. Check the MainBrain for existing positions:
   ```bash
   grep -rl "<theme keywords>" ~/Main{{SLUG}}Brain/
   ```
   If the author already has a belief on this topic, note it prominently in
   the theme page's "Current thesis" section as the starting point.
5. Propose 3–5 open questions. These seed the research direction.

## Phase 2 — Source gathering

The author ingests sources under the theme. For each source:

1. Run the normal `ingest` skill.
2. Make sure the summary links back to `[[themes/<slug>]]` in its
   "Projects this bears on" section (which, for research, is the theme).
3. The theme page's "Sources consumed" section gets a new entry.
4. If a new thinker shows up in the source:
   - Check if `thinkers/<slug>.md` exists
   - If notable and the author engages with their ideas, create the page
   - Cross-link from the theme page's "Key thinkers"
5. If a new mental model or framework appears:
   - Create a concept page with `subkind: mental-model` (use the
     `wiki-templates/mental-model.md`)
   - Link from the theme page's "Related concepts"

## Phase 3 — Synthesis

After 3+ sources on the theme, the agent should proactively propose
synthesis:

> "You've ingested 4 sources under `themes/<theme-slug>`. Three of
> them emphasize <pattern> as the most useful framework. Want me to
> extract `concepts/<pattern-slug>.md` as a mental model page and cross-link?"

Synthesis moves include:
- Extracting a recurring pattern into a concept page
- Surfacing a contradiction between sources for the author to resolve
- Proposing an "open question" has been answered (move to "Key claims")
- Suggesting the theme's current thesis be updated

**Never rewrite the thesis without the author's input.** Propose a revision
in chat; let them commit or redirect.

## Phase 4 — Graduation

Watch for signs the theme is producing output:

- **Essay or teaching material**: if the author is writing about the theme,
  offer to extract an outline from the theme page as a starting draft.
- **Committed belief**: if the thesis has stabilized for 60+ days, prompt:
  > "Your thesis on this theme hasn't changed in 60 days. Want to commit
  > it to the MainBrain `beliefs/`?"
- **Concrete project**: if the theme suggests something to build, propose
  a project page spin-off.
- **Decision**: if research has informed a specific choice, propose an ADR.

The theme page stays — but now it has graduation links showing what the
research produced.

## Research vs. ingest

Normal ingest handles one source at a time. Research is the **longer arc**
that that single source contributes to.

When ingesting under an active theme:
- Think about the theme's open questions — does this source answer any?
- Think about the theme's current thesis — does this source strengthen or
  challenge it?
- If either, propose updating the theme page in Phase 3 style.

## Rules

- **Themes don't have a `status: shipped`.** Don't try to finish them.
- **Never fill a thinker page with a Wikipedia summary.** The value is
  the author's engagement with their ideas — agreement, disagreement,
  adopted positions. Empty sections are better than imported filler.
- **Mental model pages need counterexamples.** A model without its edge
  cases isn't a model; it's a slogan. If you can't name when it doesn't
  apply, the page is incomplete.
- **Cross-link aggressively.** A theme is a network node. The more
  summaries, thinkers, concepts, and projects link to it, the more
  useful it becomes.
