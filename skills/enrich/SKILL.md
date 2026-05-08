# Skill: Enrich a wiki page

When ingest encounters a business, venture, tool, project, concept,
theme, thinker, or decision worth having its own page — this skill
handles it. Identity resolution, dedup, and back-linking. No tiers. No
external API lookups. Just keeping the wiki consistent.

Called by: `ingest`, `maintain`, `research`. Not called directly by the author.

## Inputs

- **target_kind**: business | venture | tool | project | concept | theme | thinker | decision
- **name**: the name as it appeared in the source
- **signal**: the raw text where it was mentioned
- **source_ref**: path to the source file or the origin context

## Step 1 — Resolve identity

Before creating anything, check if a page already exists. Use whatever
search tool is available (`grep`, `qmd`, `ripgrep`, the librarian's own tooling):

```bash
grep -rl "title:.*<name>\|aliases:.*<name>" ~/LLM{{SLUG}}Brain/wiki/<target_kind>s/
```

Three outcomes:

- **Match found.** Update the existing page (Step 2).
- **Close match but uncertain.** Ask the author:
  > "Found `tools/cloudflare-workers.md` — same thing as 'CF Workers' in
  > this source?"
- **No match.** Create a new page (Step 3).

## Step 2 — Update path

1. Read the existing page.
2. If the name variant is new, add it to `aliases:` in frontmatter.
3. Extract signal from the source:
   - Tool: new strength/weakness/pitfall observed? → update the relevant
     section. New pattern or gotcha? → add to "Your experience" or
     "Pitfalls".
   - Project: meaningful progress or pivot? → update "Current focus" and
     append to Timeline.
   - Business: operational change, new metric, pivot? → update "State"
     and append to Timeline. Never change `legal_entity` from a source —
     that's a real-world action.
   - Venture: new evidence for/against commitment? → update relevant
     section, consider if stage should change. Propose the stage change
     in chat; never auto-advance a venture to `committed` or `killed`.
   - Concept: new example or refinement? → update.
   - Theme: new sources, thinkers, or claims? → update the relevant
     section. Flag if the current thesis may need revision, but don't
     rewrite it without proposing in chat.
   - Decision: if a source relates to an existing decision, link it from
     the decision's "Related" section.
4. Append a Timeline entry:
   ```
   - **YYYY-MM-DD** | <source> — <one-line what was observed>. [Source: raw/...]
   ```
5. Update `updated:` in frontmatter.
6. Revise compiled truth (above `---`) **only if the new signal materially
   changes the picture**. Don't rewrite for minor additions.
7. Flag contradictions; never silently resolve them:
   ```
   **CONTRADICTION (YYYY-MM-DD):** This source claims X. The tool page
   previously stated Y based on [[summaries/...]]. Unresolved — needs
   the author's call.
   ```

## Step 3 — Create path

1. Walk `RESOLVER.md` (unless already confirmed by ingest) to confirm
   destination. State in chat:
   > "New <kind> page for <name>, matches RESOLVER rule #<n>. Filing to
   > `wiki/<dir>/<slug>.md`."
2. Use the relevant template from `wiki-templates/`:
   - Business → `wiki-templates/business.md`
   - Venture → `wiki-templates/venture.md`
   - Tool → `wiki-templates/tool.md`
   - Project → `wiki-templates/project.md` (set `business:` field)
   - Concept → `wiki-templates/concept.md` (or `wiki-templates/mental-model.md` for Munger-style)
   - Theme → `wiki-templates/theme.md` (set `cluster:` field)
   - Thinker → `wiki-templates/thinker.md`
   - Decision → `wiki-templates/decision.md` (set `business:` field if applicable)
3. Populate what the source and the author's corpus already tell you. Leave
   unknown sections as `[No data yet]` or omit them — **don't invent content
   to fill template sections.** Empty sections are prompts for future
   enrichment, not failure modes.
4. Search `raw/` and existing summaries for prior mentions:
   ```bash
   grep -rl "<name>" ~/LLM{{SLUG}}Brain/raw/ ~/LLM{{SLUG}}Brain/wiki/summaries/
   ```
   If the tool/concept has been mentioned before, add those references to
   the new page's Timeline.
5. For tools: check the MainBrain for any existing position the author has on
   this tool:
   ```bash
   grep -rl "<name>" ~/Main{{SLUG}}Brain/
   ```
   If found, note it as:
   ```
   **The author's position on this:** [Main{{SLUG}}Brain: principles/<file>.md#section]
   ```
   Link to the MainBrain, never copy its content into the wiki page.
6. Write the first Timeline entry:
   ```
   - **YYYY-MM-DD** | <source> — Page created. Encountered in <context>. [Source: raw/...]
   ```

## Step 4 — Back-reference (mandatory)

The iron rule: every page mentioning this subject MUST link from this
page, and vice versa.

1. If the subject came up in a summary, ensure the summary's "Entities
   mentioned" (or "Tools mentioned", etc.) section lists this page.
2. If it's a tool used by a project, link from the project's "Tools in use".
3. If it's a concept embodied by a project, link from the project's
   "Concepts it embodies".
4. If it's a decision, link the affected projects from the decision's
   frontmatter `projects:` field.

## Step 5 — Validation

Before writing, check:

- [ ] Slug is lowercase-hyphenated, matches naming in the target README
- [ ] No duplicate slug, no alias collision
- [ ] Back-links set up (Step 4)
- [ ] Every factual claim carries a source citation
- [ ] No invented content in template sections — empty is better than fake

## What this skill does NOT do

- **No external API lookups.** The corpus and web search on request are it.
  No external enrichment services, no auto-fetch from LinkedIn or Pitchbook.
- **No tiers.** Every page gets the same care. Depth is determined by what
  the source and your own work actually tell you — not by budget.
- **Never writes to the MainBrain.** Ever.
- **Never creates a second page for something that already has one.** Dedup
  first via Step 1.
- **Never uses generic marketing descriptions** on tool pages. The official
  blurb is worth less than the author's experience with the tool.
