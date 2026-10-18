---
name: convene-the-board
description: "Run a problem or decision past a panel of the thinkers who have thinker pages in the LLM brain. Each seated thinker answers through their own cited frames; then the skill maps where they disagree and writes a dated board memo in wiki/syntheses/. Use when the author says 'convene the board on <problem>', 'what would the board do with <decision>?', 'run this past the panel' or 'what would <thinker> do with <X>?'."
---

# Skill: Convene the Board

Run a problem or decision past a **panel of grounded thinkers**. Each one answers
*in their own frames, and cites them*. Then surface where they disagree, and
write a board memo. This turns the familiar move "what would <thinker> do with this?"
into an answer grounded in the sources the author has actually ingested, not in
generic impressions.

Paths are relative to the LLM brain (`$PERGAMINO_LLM_BRAIN`). The Main brain is `$PERGAMINO_MAIN_BRAIN`.

## Trigger phrases

- "Convene the board on `<problem>`"
- "What would the board do with `<decision>`?"
- "Run this past the panel: `<problem>`"
- "What would `<thinker>` do with `<X>`?" (one voice or several)

## The panel — built from the LLM brain

The panel is every thinker with a page in `wiki/thinkers/`. A thinker page has one of two shapes:

- **A single page**: `wiki/thinkers/<slug>.md` (from `wiki-templates/thinker.md`). Its frames are the "Signature ideas" and "Mental models from them" sections, and the linked `concepts/` pages.
- **A corpus folder**: `wiki/thinkers/<slug>/`, with an index page (`<slug>/index.md` or `<slug>/<Name>-index.md`) and one atomic note per frame in `<slug>/frames/`. Use this shape when a thinker has many frames.

Build the panel at the start of each convening:

```bash
ls "$PERGAMINO_LLM_BRAIN/wiki/thinkers/"
```

For each thinker, read the frontmatter: `known_for:`, `domains:` (what they are best for) and `grounded:`.

**Grounding rule.** A thinker is **grounded** when the page has `grounded: true`: its frames cite
ingested sources (`[Source: [[summaries/...]]]`). A grounded thinker speaks through those frames.
An ungrounded thinker may still speak, but label every take of theirs **`⚠ ungrounded lens`**,
so that it is never mistaken for research. Set `grounded: true` only after the frames cite sources;
the `research` skill builds that grounding.

If `wiki/thinkers/` is empty, stop and say so: "There are no thinker pages yet. Name 3–5 thinkers, and I will create their pages through `enrich`, or run `research` to ground them first."

## Steps

1. **Restate the problem** in one or two sentences. If it is vague, ask the author one
   clarifying question before you convene: a sharp problem gets sharp frames.
   Then search the brains for prior work on the problem's concept (not only the names in your head):
   `qmd search "<problem concept>" -c llm` and `-c main`. Open the top results, and list the
   prior work you found in the memo's Problem section.

2. **Panel selection.** Do not seat everyone every time. Pick the 3–5 thinkers
   whose `domains:` and frames fit the problem. State whom you seated and why. As a rule of thumb, seat
   at least one thinker likely to disagree with the others. The author can override the seating.

3. **A grounded pass for each panelist.** For each seated thinker:
   - Read their page or corpus index for their top frames (and an application protocol, if the page has one).
     Then open the 2–5 most relevant **frame notes** or concept pages.
   - Answer the problem **through that thinker's frames**, and apply their application
     protocol. **Cite the specific frames**: `[[thinkers/<slug>/frames/<frame>]]`,
     `[[concepts/<frame>]]` or `[[thinkers/<slug>#<section>]]`.
   - Keep each voice to about 4–8 sentences. Stay in character through the frames, not through
     style. If you cannot ground a claim in a frame, do not put it in the thinker's mouth.

4. **Cross-examine.** The product is the **disagreement**. Surface 2–4 explicit
   tensions where panelists pull in opposite directions (for example, patience and a margin of
   safety against fast, cheap experiments; the smallest viable market against a bet on
   scale). Name who is on each side and which frame drives them.

5. **Board memo.** Write `wiki/syntheses/board-<problem-slug>-<YYYY-MM-DD>.md`:
   - `## Problem`: the restated question, and the prior work you found in step 1.
   - `## Panel`: who was seated and why.
   - `## Each voice`: one block per panelist, with their take and the cited frames.
   - `## Where they disagree`: the tension map from step 4.
   - `## Synthesis`: your integrated recommendation: what the convergence says,
     how you would resolve the key tension, and the one or two moves to make. Tentative
     and dated, like a theme thesis. **Do not bury the disagreement**: honest
     tensions are more useful than a forced consensus.

   If the author has a Main brain position on the problem, quote it in the Synthesis as the starting point. Never edit the Main brain.

6. **Rebuild the index and log.**
   ```bash
   bash "$PERGAMINO_HOME/scripts/rebuild-index.sh" "$PERGAMINO_LLM_BRAIN"
   ```
   Append to `wiki/log.md`:
   ```
   ## [YYYY-MM-DD] convene-the-board | <problem>
   - memo: wiki/syntheses/board-<problem-slug>-<YYYY-MM-DD>.md
   - panel: <slug>, <slug>, <slug>
   ```

7. **Report** in chat: the seating, the headline of each voice, the sharpest
   disagreement and your synthesis, in about 8 lines. Link the memo.

## Rules

- **Grounded, or labelled.** An ungrounded voice gets `⚠ ungrounded lens`. Never
  present a generic impression as a researched take.
- **Cite frames.** Every panelist claim links to the frame or frames it came from. A take
  without a citation is a vibe: cut it, or find the frame.
- **Disagreement is the deliverable.** If the panel "agrees on everything", you
  seated too few contrarians or read too little. Add a contrarian voice, or open more frames.
- **Do not seat the whole panel by default.** 3–5 relevant voices beat 8 generic
  ones. Match domains to the problem.
- **One memo per convening**, in `wiki/syntheses/`. A new run on the
  same problem is a new dated memo; do not rewrite the old one.

## Scaling (optional)

For a heavy convening, the per-panelist passes can fan out to subagents (one
subagent per seated thinker, each reading its corpus in parallel, then one synthesis step
for the cross-examination and the memo). The inline version (read each corpus in
turn) is the default, and it is fine for most problems.

## What this skill does NOT do

- **Build new corpora.** Grounding a thinker is `research` and `ingest` work. This skill
  only *reads* thinker pages.
- **Write to the Main brain.** Belief updates go through the tray (`outputs/mainvault-pending/`), never through direct edits.
