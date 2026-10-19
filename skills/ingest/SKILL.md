---
name: ingest
description: "Compile one new source from raw/ in the LLM brain into the wiki: a summary page, every entity it names resolved through enrich, a check against the Main brain, fresh indexes and a log entry. Use when the author drops a file in raw/, says 'ingest this', 'process this paper' or 'add this to the wiki', or when deep-ingest, research or autoresearch hand over a new raw file."
---

# Skill: Ingest a new source

Run this when the author drops a file in `raw/` or asks you to "ingest" something. `deep-ingest`, `research` and `autoresearch` also call it for each source that they file.

Paths in this skill are relative to the LLM brain (`$PERGAMINO_LLM_BRAIN`). The Main brain is `$PERGAMINO_MAIN_BRAIN`.

## Requires

- optional: `qmd` (search and index). Check with `command -v qmd`. Without it, search with `grep -rli` and skip step 8b.

## Triggers

- "Ingest this article" or "Process this paper".
- "Read `<URL>` and add it to the wiki". For a URL, prefer `deep-ingest`: it fetches and saves the page, then calls this skill.
- A new file in `raw/` with `processed: false`, and the author asks you to handle it.

## Steps

0. **Read the author's intent.** Before the body, check the raw file's frontmatter for `intent:`. The Obsidian Web Clipper asks the author for it at clip time: one line on why they save the source and what they want the brain to do with it.
   - **Present and non-empty** → it steers this ingest. Echo it in step 2's brief. Let it bias step 5 (favor the entities it names), step 6 (the existing pages that `enrich` updates) and step 7 (Main brain keywords beyond the source's own). When it names a project, a belief or a business, search the Main brain for that name.
   - **Missing or empty** → proceed neutrally. Never invent an intent.
   - **Record it verbatim** in an `## Intent at capture` block on the summary page (step 4). Without an intent, omit the block. Do not write "none".

   The intent is the author's framing, not the source's. A logistics article with `intent: "fit for my delivery business?"` becomes a fit memo for that business, not a logistics recap.
1. **Read the source in full.** You are the one who compiles it. Do not skim. For a PDF, read all pages. If the source is mostly noise (a JavaScript shell with no content, a PDF of images that you cannot read), stop and tell the author. A bad summary is worse than no summary.
2. **Brief the author, then proceed.** Tell them in 3–5 sentences what the source is, the 1–3 ideas that matter most and where you will file it. Continue without waiting: filing a source is small and reversible, so do it, then report. If the author redirects, follow the redirect.
3. **Pre-ingest orientation.** Run maintain mode 1 (`skills/maintain/SKILL.md`): look at the recent `wiki/log.md` entries and the open threads across active projects. Give the author one line, such as: "The last 3 ingests touched [X]. This source looks related to [[projects/Y]], so I will extend that page and not create a new one."
4. **Create the summary page** `wiki/summaries/<slug>.md` from `"$PERGAMINO_HOME/wiki-templates/summary.md"`. The slug is lowercase and hyphenated, comes from the source title, and matches the source file's slug in `raw/` (so `raw/web/2026-05-06-foo.md` gives `summaries/foo.md`).
5. **Extract references.** Before you touch any other file, list every mention of these kinds. The list is your checklist for steps 6 and 7.
   - Businesses (the author's, or other businesses that affect the author's) and ventures (business ideas that relate to ones the author tracks).
   - Tools: software, platforms, application programming interfaces (APIs), libraries, services, protocols.
   - Projects: the author's active work, named or implied.
   - Decisions: an existing one that the source informs, or a new one that it suggests.
   - Concepts and mental models: frameworks, patterns.
   - Themes: topics the author researches. Check whether the source extends one.
   - Thinkers: people whose ideas the author tracks.
6. **Call `skills/enrich/SKILL.md` for each reference**, with the target kind, the name, the signal (where it appeared) and the source reference. `enrich` handles identity resolution (an existing page? a known alias?), deduplication, the template and back-links. Create pages only through `enrich`. Apply the rule of three: do not promote a one-off mention to a concept page until 3 sources reference it, or the author asks.
7. **Check against the Main brain.** Run `qmd search "<key claim>" -c main` for the key claims. If the Main brain contradicts the source, note it in the summary's "Tension with truth" section. Leave the Main brain unchanged, and let the wiki disagree: record the disagreement and move on. If the contradiction is strong enough that the author may want to change a belief, stage a proposal in `outputs/mainvault-pending/<slug>.md` with a `<!-- target: beliefs/<filename>.md -->` marker (see `skills/query/SKILL.md` § Staging). Never edit the Main brain.
8. **Rebuild both indexes.** Both go stale silently.
   - a. `wiki/_index.md` (navigation) is derived, so never hand-edit it. The rebuild is deterministic, takes under a second and overwrites hand edits:
     ```bash
     bash "$PERGAMINO_HOME/scripts/rebuild-index.sh" "$PERGAMINO_LLM_BRAIN"
     ```
   - b. The qmd search index (keyword re-scan and vector embeddings), so that "search before claiming" sees your new pages. If you skip it, the next search misses these pages and a duplicate page follows:
     ```bash
     qmd update && qmd embed
     ```
9. **Append to `wiki/log.md`**, with a line only for each kind that you touched. The log is append-only: one self-contained entry each time.
   ```
   ## [YYYY-MM-DD] ingest | <source title>
   - summary: wiki/summaries/<slug>.md
   - businesses touched: a.md
   - ventures touched: b.md
   - projects touched: c.md
   - decisions touched: YYYY-MM-DD-d.md
   - tools touched: e.md, f.md
   - themes touched: g.md
   - thinkers touched: h.md
   - concepts touched: i.md
   - Main brain check: aligns | tension staged | no relevant content
   ```
10. **Mark the source processed.** Change the raw file's frontmatter from `processed: false` to `processed: true`. This is the one edit allowed in `raw/`, and it prevents a second ingest.
11. **Post-ingest settling.** Run maintain mode 2 (`skills/maintain/SKILL.md`): re-read what you wrote, verify the back-links and flag emerging patterns (three sources on one topic → propose a concept page).
12. **Report back** in chat, in under 10 lines: what you filed, what you back-linked, and any contradictions or open questions.

## Rules

- **One source, one ingest.** Batch only when the author asks.
- **More than 15 files:** pause and check with the author first. A healthy ingest touches 10–15 pages. More means you are over-eager, or the source needs a synthesis that the author writes.
- **Never write to the Main brain.** Stage proposals in the tray (`outputs/mainvault-pending/`).
- **Never rewrite `raw/`.** Sources are immutable. The `processed:` flag in step 10 is the only change.
- **No auto-ingest.** A file in `raw/` waits until the author or a calling skill asks for it.
- **Cite every factual claim:** `[Source: raw/...]`.
- **Memory references are plain text** (`` `memory: <slug>` ``), never `[[wikilinks]]`. `[[...]]` is only for paths inside the LLM brain. A link to a memory file looks like a broken wiki link to every lint.
- **Tool pages record experience and pitfalls**, not the source's marketing copy.
- **Intent steers; it does not fabricate.** If `intent:` is empty, proceed neutrally.

## What this skill does not do

- It does not fetch URLs. `deep-ingest` fetches and saves the page first, and it handles pages that need a browser.
- It does not do bounded research on adjacent sources. That is `deep-ingest` (3 sources) or `research`.
- It does not change the wiki schema. If the source does not fit an existing page type, ask the author.
