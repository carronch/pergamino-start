---
name: teach
description: "Explain a body of work plainly so that the author actually understands it: what it is, how it works and why it is built that way, built up step by step and diagram by diagram. Use for 'teach me this', 'help me really understand X', 'explain this change or subsystem to me', 'walk me through how this works'."
disable-model-invocation: true
---

# Teach

Adapted from pstack's `teach` skill (Lauren Tan, MIT licence; `cursor/plugins`, commit `9d76bca`). pstack builds it on its `how` and `why` skills, which this kit does not have; this copy does that digging itself, with the two brains as sources and the kit's writing rules.

**You explain what a thing is, how it works and why it is built that way, in one plain account at the author's pace. The goal is that the author understands it, not that you change anything.**

## Steps

1. **Decide what the author should walk away understanding.** Choose the few points from why the author is asking (about to change it, reviewing it, debugging it, new to it) and from what the author already knows. Read both from the conversation and the brains; do not quiz the author. Skip what the author plainly knows. Put the depth where the question is.
2. **Dig before you explain.** For *how*: read the code, or the wiki page that owns the system (`qmd search "<topic>" -c llm`, then the tool, project or client page it finds). For *why*: read the history — `git log` and `git blame` on the lines, the pull requests, the card's timeline in `"$PERGAMINO_LLM_BRAIN"/wiki/workblocks/`, `"$PERGAMINO_LLM_BRAIN"/wiki/log.md`, and the summary or decision that motivated it. Keep the confidence of what you found: "the commit message says", "probably, because" and "no record" are findings, not style.
3. **Start with a plain definition.** Name the thing and say what it is in general terms, with its common name if it has one. Anchor the technical term, then explain it in plain words. Then tie it to the case in front of the author ("in this checkout flow, this is the part that …") and build from there: how it works, the deeper reasons, the edge cases. For each part, say the problem it solves and how it actually works. Listing functions and constants is reference, not teaching.
4. **Give the smallest complete answer first**, a sentence or two, then stop. Add layers when the author asks. Never a wall of text.
5. **Keep it a conversation.** Offer to go deeper or move on, and follow the author's lead. No quizzes, no "pause here", no announcing that a part is important or hard. Just say it.
6. **Show, do not only tell, and build the picture up.** Open the diff or the code when that lands it fastest. For anything with three or more moving parts, draw a short series of diagrams: each one redraws the last and adds a single part, so that the author watches the system assemble. Use Mermaid for flows and structures. If you have no image-generation tool, draw a spatial idea (layout, scroll position, a before and after) in plain text or a small SVG, or use `/visualize-work` for a larger visual. A single simple point needs no figure.

## Writing

Use Simplified Technical English: main point first, active voice, one topic per sentence, the same term for the same thing. Spell out every abbreviation the first time. Write in the language the author wrote to you in, in the author's own register. State the concrete mechanism, not a metaphor or a preview of what is coming. Do not print framing labels such as "the key insight" or "TL;DR".

**Reply:** the explanation itself, never a report about what you did. Lead with the main point, then the plain account of what it is, how it works and why, then the threads worth chasing next.
