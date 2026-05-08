# Skill: Query the vault

Run this when the author asks a question that should be answered from the catalog. Not every question — small clarifications and chat-level back-and-forth don't need a full query pass. Invoke this when the author asks something like:

- *"What do I think about <topic>?"*
- *"Find me everything I have on <subject>."*
- *"What did <person> say about <thing>?"*
- *"Have I read anything that contradicts <claim>?"*

## Steps

### 1. Restate the question

Before searching, repeat the question in your own words and check with the author. Specifically:
- What's the question, in one sentence?
- What kind of answer would be useful — a synthesis, a list of citations, a single fact, a contradiction check?

Wait for confirmation if the question is ambiguous. A bad search wastes time.

### 2. Search the wiki and raw layers

In order:

**a. Index first.** Read `~/LLM{{SLUG}}Brain/wiki/_index.md` for the relevant section. Often the answer is two clicks away.

**b. Concept and theme pages.** If the topic has a concept page or theme page, read it. These are pre-synthesized and usually more useful than raw sources.

**c. Summaries.** Search `~/LLM{{SLUG}}Brain/wiki/summaries/` for the topic. Use whatever search tool is available (`grep`, `qmd`, `ripgrep`, the librarian's own tooling). Read the matching summaries' TL;DRs and key claims.

**d. Raw sources.** Only descend to `~/LLM{{SLUG}}Brain/raw/` if the wiki layer is thin. Reading raw is expensive — use sparingly.

**e. Main{{SLUG}}Brain.** Always check Main{{SLUG}}Brain for relevant beliefs or principles. The author's own position is the truth-anchor.

### 3. Synthesize

Write a 2–4 paragraph answer. Every factual claim cites the source: `[Source: wiki/summaries/<slug>]` or `[Source: Main{{SLUG}}Brain: beliefs/<slug>]`. Do not paraphrase without citing.

If Main{{SLUG}}Brain has a position on the question, **lead with it**. The author's own writing is the truth-anchor; the wiki is supporting structure.

If sources contradict each other, **say so explicitly** — *"Source A says X; Source B says Y; the author's belief at Main{{SLUG}}Brain: beliefs/<slug>.md aligns with A."*

### 4. Surface what's missing

Tell the author what your answer doesn't cover:
- Sources you'd want to read but haven't been ingested yet.
- Adjacent questions the search surfaced.
- Main{{SLUG}}Brain gaps (e.g., "you don't have a belief on this; it might be worth writing one").

### 5. Optionally — file the answer

If the answer is substantial and the author wants to keep it, ask: *"Should I file this as a synthesis at `wiki/syntheses/<slug>.md`?"* Default is no — most queries don't deserve filing. File only when:
- The answer surfaces a perspective the author hasn't written before.
- Future questions are likely to repeat this one.
- The author explicitly asks.

If filing, write a `synthesis` page per the schema in `CLAUDE.md`. Stage it for author review at `outputs/mainvault-pending/syntheses-<slug>.md` if it should crystallize into Main{{SLUG}}Brain, or write directly to `wiki/syntheses/` if it's a librarian-side synthesis.

### 6. Log

If the query was substantive (took more than 30 seconds, touched 3+ pages), append to `wiki/log.md`:

```
## [YYYY-MM-DD HH:MM] query | <question one-line>
- pages read: N
- synthesis filed: <yes | no>
```

Trivial queries don't need a log entry.

## Rules

- **Answer first, then explain how you got there.** The author shouldn't have to read your search process unless they want to.
- **Cite, don't paraphrase.** Every claim has a source.
- **Main{{SLUG}}Brain is the truth-anchor.** Lead with the author's own position when it exists.
- **Don't re-derive what the wiki already synthesizes.** Concept and theme pages exist *to be cited from*. Trust them.
- **Default to no synthesis filing.** Most queries are conversational; filing turns the catalog into noise.

## What this skill does not do

- It doesn't fetch new sources. If the answer requires a source the author hasn't ingested, surface that gap rather than scraping the web.
- It doesn't update Main{{SLUG}}Brain, even if the answer suggests the author should. Stage a tray proposal at most.
