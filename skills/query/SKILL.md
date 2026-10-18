---
name: query
description: "Answer a question from both brains: hybrid search, a one-hop graph walk over the wiki, the Main brain as the authority, citations on every claim; then file a new synthesis back to the wiki and stage any belief-shaped finding in the tray. Use when the author asks 'what do I think about <topic>?', 'find everything I have on <subject>', 'what did <person> say about <thing>?', 'have I read anything that contradicts <claim>?', or types /query."
---

# Skill: Answer a query from the brains

Run this when the author asks a question that the brains might answer. Small clarifications and chat-level back-and-forth do not need a full query pass. Typical questions:

- "What do I think about `<topic>`?"
- "Find me everything I have on `<subject>`."
- "What did `<person>` say about `<thing>`?"
- "Have I read anything that contradicts `<claim>`?"

Paths are relative to the LLM brain (`$PERGAMINO_LLM_BRAIN`). The Main brain is `$PERGAMINO_MAIN_BRAIN`.

## Requires

- optional: `qmd` (hybrid search over the two collections `main` and `llm`). Check with `command -v qmd`. Without it, read `wiki/_index.md`, then use `grep -rli` on `wiki/`, `raw/` and the Main brain, in the same order as below.
- optional: `python3` (the graph hop in step 2).

## Before you search

If the question is ambiguous, restate it in one sentence and name the kind of answer that would help (a synthesis, a list of citations, a single fact, a contradiction check). Ask only when the restatement could go two ways. A bad search wastes time.

## Search order

1. **Both brains through qmd.** `qmd query "<query>"`: hybrid keyword + vector search with a rerank, over both collections. Read the top 3–5 hits. Concept and theme pages are pre-synthesized and usually more useful than raw sources, so read them first.
2. **Graph hop on the top wiki hits.** Search finds pages that *say* the
   query words. The graph finds pages that *belong with* them:

   ```bash
   python3 "$PERGAMINO_HOME/scripts/graph-hop.py" --vault "$PERGAMINO_LLM_BRAIN" <top wiki hit paths...>
   ```

   Pass the top 3–5 wiki paths from step 1 (not `raw/` hits and not Main
   brain hits). qmd result paths work verbatim: the script strips `qmd://`
   prefixes, `:line` suffixes and color codes, and it skips hub pages like
   `wiki/log`. Read the ranked neighbor list, and pull in the neighbors
   that bear on the question (add `--excerpt` to preview intros before you
   open full pages). Rules of thumb:
   - **Always hop for relational questions**: "what touches X?", "what
     came out of Y?", "how do X and Y connect?". The neighbors are the
     answer.
   - `link` neighbors are curated structure: trust them. `MENTION`
     neighbors are weaker (detected automatically, excluded from ranking). Follow
     them only when they are clearly on-topic.
   - A neighbor that touches several seeds is usually the connective page
     that the question is really about.
   - Skip the hop only for pure factual lookups that the step-1 hits already
     answer.

   The graph (`wiki/_graph.json`) is rebuilt on every index rebuild. If
   it is missing or stale, run
   `python3 "$PERGAMINO_HOME/scripts/build-graph.py" "$PERGAMINO_LLM_BRAIN"`.
3. **The Main brain specifically.** `qmd search "<query>" -c main`, when
   the author's own positions are the core of the answer. A hit here is
   authoritative. Always check the Main brain for a relevant belief or
   principle: the author's own position is the truth anchor.
   If your host keeps an agent memory (feedback rules, past decisions),
   search it too when the question touches how the author works. On a conflict,
   the more recently dated statement wins. Flag the drift for the next lint.
4. **`raw/` in the LLM brain.** `qmd search "<query>" -c llm`: if the wiki
   coverage is thin, drop to the raw sources. Reading raw is expensive, so use it sparingly.
5. **Web or external tools.** The last resort. Use them only when the brains have nothing,
   and say so in the answer.

## Response shape

Answer first. The author does not need to read your search process unless they ask for it.

Lead with the synthesized answer from the wiki. If the Main brain has a position, lead with that position and show it prominently:

```
> **Your position (Main brain: beliefs/<file>.md):** <quoted>
```

Cite as you go:
- Wiki pages: `[[wiki/tools/name.md]]` (Obsidian wikilinks render in preview)
- Sources: `[Source: raw/articles/slug.md]`
- Main brain: `[Main brain: beliefs/<file>.md#section]`

If sources contradict each other, say so explicitly: "Source A says X. Source B says Y. Your belief at `beliefs/<slug>.md` aligns with A."

End with what the answer does not cover:
- Sources that you would want to read but that are not ingested yet.
- Adjacent questions that the search surfaced.
- Main brain gaps ("You have no belief on this. It might be worth writing one.").

## When the Main brain contradicts the wiki

The Main brain wins. Say so explicitly:

> The wiki says X [Source: ...]. Your Main brain position disagrees:
> "<Main brain quote>" [Main brain: ...]. I go with your position.

Do not silently overwrite the wiki. Note the contradiction for the next lint.

## Output formats

Not every answer is prose. Pick the shape that fits the question:

| Question shape | Best format |
|---|---|
| Factual lookup ("when was X?") | One-line answer with citation |
| Comparison ("X vs Y") | Markdown table |
| Process or flow ("how does X work?") | Numbered list or Mermaid diagram |
| Data over time ("how has X changed?") | Chart (Python + matplotlib, saved to `wiki/syntheses/assets/`) |
| Presentation to someone else ("walk me through X") | Marp slide deck in `wiki/syntheses/decks/` |
| Open exploration ("what do we know about X?") | Prose synthesis |

For **Marp decks**: wrap the markdown in Marp frontmatter (`marp: true`), one
slide per `---`. The Obsidian Marp plugin renders them. Ask the author before
you generate a deck: decks are slower to produce.

For **charts**: save matplotlib figures as PNG, and reference them in a markdown
synthesis page. Keep the generating script inline, so that the author can run it again with
new data.

## Filing good answers back

Karpathy's rule: good explorations should compound like ingested sources do.
The wiki is a persistent artifact. Do not let a synthesis disappear into chat
history. But not every answer deserves a page: over-filing is as bad as
under-filing.

### When to file (the heuristic)

**Default: file.** The answer is a synthesis, a comparison, an analysis or a
connection that was not explicit before. It reads as new content, not
retrieved content. → Offer to file it to `wiki/syntheses/<slug>.md`.

**Default: do not file.** The answer is pure retrieval ("what does the
wiki say about X?"), and a future reader would get the same value from
running the query again. Chat is fine.

**The test:** if the answer *did not exist* in the wiki before you
composed it, it should persist. If you only pulled up what is
already written, it should not.

### How to offer

> This produced a synthesis worth keeping. File it as
> `wiki/syntheses/<slug>.md`, link it from [[...]] and [[...]], and append
> to log.md?

File only after the author confirms. Append one entry to `wiki/log.md`:
```
## [YYYY-MM-DD] query | <question paraphrase>
- synthesis: wiki/syntheses/<slug>.md
- linked from: <page>, <page>
```

A substantive query that you do not file (3 or more pages read) can still get a short log entry with `- synthesis filed: no`. Trivial queries need no entry.

## Staging to `outputs/mainvault-pending/`

The Main brain (beliefs, principles, life-decisions, people, heartbeats) is
read-only for agents. Agents never edit it. But queries often surface
material that *should* change what the Main brain says: contradictions,
extensions, or new positions that the author has not yet written down.

This section makes staging mandatory, not optional.

### Mandatory check after every query

Before you finish the response, ask:

1. **Contradiction**: does the answer conflict with an existing Main brain
   belief, principle or life-decision? (Search order step 3 already surfaces
   these.)
2. **Extension**: does the answer strengthen, qualify or add nuance to an
   existing Main brain position in a way that the current text does not reflect?
3. **New principle-shaped claim**: does the answer surface something that
   *reads* like the author's own position (a rule they live by, a belief about
   the world, a decision about how they work) but has no Main brain page yet?

If none applies → continue with the normal response. You are done.

If any applies → **stage a proposed Main brain change** in `outputs/mainvault-pending/`.
Do not ask permission to stage: staging is the safe default. The author promotes
or discards it on their own schedule.

### Staging format

Create `outputs/mainvault-pending/YYYY-MM-DD-<slug>.md`:

```markdown
<!-- target: <path-in-main-brain, e.g. beliefs/<file>.md> -->
---
type: main-brain-pending
target: "beliefs/<file>.md" | "principles/<file>.md" | "life-decisions/<file>.md"
action: extend | contradict | new
slug: <descriptive-slug>
trigger_query: "<the question the author asked>"
sources: [wiki/summaries/<slug>, wiki/summaries/<slug>]
staged: YYYY-MM-DD
promoted: false
caveats: "<what the agent is unsure about>"
---

# Proposed <action>: <one-line summary>

## Why now

Two or three sentences on what query surfaced this, and why it looks
like a Main brain matter (not only an LLM brain matter).

## Current Main brain position

Quote the existing belief or principle verbatim, with the file path. Or write
"no existing position — candidate for a new page."

## Proposed change

The specific edit. For `extend`: the new sentences or section.
For `contradict`: the new position and what it replaces.
For `new`: a draft belief or principle page in the author's voice.

## Evidence

- [[wiki/summaries/<slug>]] — one-line relevance
- [[wiki/summaries/<slug>]] — one-line relevance

## Caveats

What the agent is unsure about. What the author should check before
promoting.
```

The `<!-- target: ... -->` marker is the first line, because the promotion script reads it there. Then, in chat, one line to the author:

> I staged a proposed Main brain <action> at
> `outputs/mainvault-pending/YYYY-MM-DD-<slug>.md`. Run
> `"$PERGAMINO_HOME/scripts/promote-to-mainvault.sh"` when you want to review it.

Do not mention it again on later turns. Once it is staged, it belongs to the author.

### What does NOT get staged

- Retrieval-only answers (no new position surfaced).
- Topic-specific takes that belong in a theme's `## In my own words`
  section, not in the Main brain. (If in doubt, ask: "Is this a rule the author lives by,
  or a current reading of a topic?" The second → theme, not Main brain.)
- Claims that the author already states in the Main brain. Do not stage a duplicate
  because the query found it again.

## Rules

- **Answer first, then explain how you got there.**
- **Do not invent citations.** If you do not know the source, say so.
- **Cite, do not paraphrase without a source.** Every claim has a source.
- **The Main brain is the truth anchor.** Lead with the author's own position when it exists.
- **Do not re-derive what the wiki already synthesizes.** Concept and theme pages exist *to be cited*. Trust them.
- Short wiki citations look like `[[tools/roam]]`, not full paths, inside Obsidian.
- Never quote more than 15 words from any single source (copyright).
- Never read the Main brain and then echo its contents as your own synthesis.
  When the Main brain is the answer, say so.

## What this skill does not do

- It does not ingest new sources. If the answer needs a source that the author has not ingested, name the gap, or offer `deep-ingest`.
- It does not edit the Main brain, even if the answer suggests the author should. It stages a tray proposal at most.
