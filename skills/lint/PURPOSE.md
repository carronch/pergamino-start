# Purpose: lint

## Why it exists

A compiled wiki drifts: orphans accumulate, wikilinks break, contradictions
survive side by side, claims lose their citations. Humans do not sustain the
bookkeeping (the classic failure of personal Zettelkasten systems). This skill is the
periodic diagnostic that keeps the model-maintained layer honest:
**propose fixes, never apply them on your own.**

## Motivating evidence

- Maintenance cost that outgrows value is why personal knowledge systems die.
  The "LLM wiki" thesis gives this exact job to the agent.
- One lint pass found that most broken links in a wiki came from memory slugs
  written as `[[wikilinks]]`. That finding became the rule that memory
  references are plain text. The diagnostic catches real classes of drift.
- The orphan exclusions (work cards, READMEs, queue files, dated reports) each came
  from a lint finding that turned into a rule instead of a one-off fix.
- Research on agent skill libraries names "no pruning mechanism" as a missing
  piece. This skill, with `maintain`, is that piece here.

## Would be retired when

Never fully. It shrinks as checks move to deterministic layers (the index
rebuild, the graph builder, a wiki-lint hook, a retrieval evaluation), and leaves
only the semantic checks (contradictions, uncited claims) that need a model.
