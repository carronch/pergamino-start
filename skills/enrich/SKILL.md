---
name: enrich
description: "Create or update one wiki page in the LLM brain for a business, venture, tool, project, concept, theme, thinker or decision: identity resolution, deduplication, the right template and back-links. Called by ingest, maintain, research, ingest-meeting and setup-interview for each reference they find; not invoked directly by the author."
---

# Skill: Enrich a wiki page

When ingest encounters a business, venture, tool, project, concept,
theme, thinker or decision that deserves its own page, this skill
handles it: identity resolution, deduplication and back-linking. No tiers. No
external API lookups. It only keeps the wiki consistent.

Called by: `ingest`, `maintain`, `research`, `ingest-meeting`, `setup-interview`. The author does not call it directly.

Paths are relative to the LLM brain (`$PERGAMINO_LLM_BRAIN`). The Main brain is `$PERGAMINO_MAIN_BRAIN`.

## Inputs

- **target_kind**: business | venture | tool | project | concept | theme | thinker | decision
- **name**: the name as it appeared in the source
- **signal**: the raw text where it was mentioned
- **source_ref**: path to the source file or the origin context

## Step 1 — Resolve identity

Before you create anything, check if a page already exists. Try aliases too: with and without accents, the short name, common spelling variants.

```bash
qmd search "<name>" -c llm
grep -rliE "^(title|aliases):.*<name>" "$PERGAMINO_LLM_BRAIN/wiki/<target_kind>s/"
```

Without `qmd`, use the `grep` line alone, and add `grep -rli "<name>" "$PERGAMINO_LLM_BRAIN/wiki/"`.

Three outcomes:

- **Match found.** Update the existing page (Step 2).
- **Close match but uncertain.** Ask the author:
  > "Found `tools/cloudflare-workers.md`. Is it the same thing as 'CF Workers' in
  > this source?"
- **No match.** Create a new page (Step 3).

## Step 2 — Update path

1. Read the existing page.
2. If the name variant is new, add it to `aliases:` in frontmatter.
3. Extract signal from the source:
   - Tool: a new strength, weakness or pitfall? → update the relevant
     section. A new pattern or gotcha? → add it to "Your experience" or
     "Pitfalls".
   - Project: meaningful progress or a pivot? → update "Current focus" and
     append to the Timeline.
   - Business: an operational change, a new metric, a pivot? → update "State"
     and append to the Timeline. Never change `legal_entity` from a source:
     that is a real-world action.
   - Venture: new evidence for or against commitment? → update the relevant
     section, and consider whether the stage should change. Propose the stage change
     in chat. Never auto-advance a venture to `committed` or `killed`.
   - Concept: a new example or refinement? → update.
   - Theme: new sources, thinkers or claims? → update the relevant
     section. Flag it if the current thesis may need revision, but do not
     rewrite the thesis without a proposal in chat.
   - Decision: if a source relates to an existing decision, link it from
     the decision's "Related" section.
4. Append a Timeline entry:
   ```
   - **YYYY-MM-DD** | <source> — <one-line what was observed>. [Source: raw/...]
   ```
5. Update `updated:` in frontmatter.
6. Revise the compiled truth (the section above the timeline) **only if the new signal materially
   changes the picture**. Do not rewrite for minor additions.
7. Flag contradictions. Never resolve them silently:
   ```
   **CONTRADICTION (YYYY-MM-DD):** This source claims X. The tool page
   previously stated Y based on [[summaries/...]]. Unresolved — needs
   the author's call.
   ```

## Step 3 — Create path

1. Walk `RESOLVER.md` in the LLM brain (unless ingest already confirmed it)
   to confirm the destination. State in chat:
   > "New <kind> page for <name>, matches RESOLVER rule #<n>. Filing to
   > `wiki/<dir>/<slug>.md`."
2. Use the relevant template from `"$PERGAMINO_HOME/wiki-templates/"`:
   - Business → `wiki-templates/business.md`
   - Venture → `wiki-templates/venture.md`
   - Tool → `wiki-templates/tool.md`
   - Project → `wiki-templates/project.md` (set the `business:` field)
   - Concept → `wiki-templates/concept.md` (or `wiki-templates/mental-model.md` for a Munger-style model)
   - Theme → `wiki-templates/theme.md` (set the `cluster:` field)
   - Thinker → `wiki-templates/thinker.md`
   - Decision → `wiki-templates/decision.md` (set the `business:` field if applicable)
3. Fill in what the source and the author's corpus already tell you. Leave
   unknown sections as `[No data yet]` or omit them. **Do not invent content
   to fill template sections.** Empty sections are prompts for future
   enrichment, not failures.
4. Search `raw/` and existing summaries for prior mentions:
   ```bash
   qmd search "<name>" -c llm
   ```
   If the tool or concept has come up before, add those references to
   the new page's Timeline.
5. For tools: check the Main brain for an existing position that the author has on
   this tool:
   ```bash
   qmd search "<name>" -c main
   ```
   If you find one, note it as:
   ```
   **Your position on this:** [Main brain: principles/<file>.md#section]
   ```
   Link to the Main brain. Never copy its content into the wiki page.
6. Write the first Timeline entry:
   ```
   - **YYYY-MM-DD** | <source> — Page created. Encountered in <context>. [Source: raw/...]
   ```

## Step 4 — Back-reference (mandatory)

The iron rule: every page that mentions this subject MUST be linked from this
page, and the reverse.

1. If the subject came up in a summary, make sure that the summary's "Entities
   mentioned" (or "Tools mentioned", and so on) section lists this page.
2. If it is a tool that a project uses, link it from the project's "Tools in use".
3. If it is a concept that a project embodies, link it from the project's
   "Concepts it embodies".
4. If it is a decision, link the affected projects from the decision's
   frontmatter `projects:` field.

## Step 5 — Validation

Before you write, check:

- [ ] The slug is lowercase and hyphenated, and matches the naming rules in `RESOLVER.md`
- [ ] No duplicate slug, no alias collision
- [ ] Back-links set up (Step 4)
- [ ] Every factual claim carries a source citation
- [ ] No invented content in template sections: empty is better than fake

## What this skill does NOT do

- **No external API lookups.** The corpus, and a web search on request, are all.
  No external enrichment services, no auto-fetch from LinkedIn or Pitchbook.
- **No tiers.** Every page gets the same care. What the source and the
  author's own work actually say decides the depth, not a budget.
- **Never writes to the Main brain.** Ever.
- **Never creates a second page for something that already has one.** Deduplicate
  first, in Step 1.
- **Never uses generic marketing descriptions** on tool pages. The official
  blurb is worth less than the author's experience with the tool.
