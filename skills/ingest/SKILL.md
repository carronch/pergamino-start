# Skill: Ingest a new source

Run this when the author hands you a file in `~/LLM{{SLUG}}Brain/raw/` or asks you to "ingest" something.

## Triggers

- *"Ingest this article"*
- *"Process this paper"*
- *"Read [URL] and add it to the wiki"*
- A new file appears in `~/LLM{{SLUG}}Brain/raw/` with `processed: false` and the author asks you to handle it.

## Steps

### 1. Read the source in full

Don't skim. You're the one compiling it. If it's a URL, fetch the full page (not just a snippet). If it's a PDF, read all pages.

If the source is mostly noise (a JS-rendered shell with no actual content; a PDF that's mostly images you can't read), stop and tell the author. A bad summary is worse than no summary.

### 2. Brief discussion

Before writing, tell the author in 3–5 sentences:
- What the source is.
- The 1–3 ideas that matter most.
- Where you plan to file the summary, and which existing pages you expect to update.

Wait for a go-ahead or a redirect. The author may want a different theme assignment, or may want you to skip ingestion entirely if it's the wrong shape.

### 3. Pre-ingest orientation

Quickly read:
- The last 3–5 entries of `~/LLM{{SLUG}}Brain/wiki/log.md` — to know what's been touched recently.
- The `_index.md` section headings relevant to this source's topic.
- Any concept or theme pages your summary might cite.

This is a 30-second pass. You're orienting, not researching.

### 4. Create the summary page

Write `~/LLM{{SLUG}}Brain/wiki/summaries/<slug>.md`. The slug matches the source file's slug (so `raw/web/2026-05-06-foo.md` produces `summaries/foo.md`).

Use the structure in `CLAUDE.md` (`type: summary` page schema): TL;DR, key claims, tools/concepts/projects mentioned, connections to existing context, tension with truth (if any), open threads, timeline.

Every factual claim cites the source: `[Source: raw/<path>/<slug>]`.

### 5. Extract entities

Scan the source for:
- **Concepts** (frameworks, mental models, patterns)
- **Themes** (long-running topics — does this source extend an existing one?)
- **Projects** (work the author is doing that this bears on)
- **Tools** (software, libraries, services)
- **Thinkers** (people whose ideas the author tracks)

Make a list before touching any other file. This is your checklist for steps 6 and 7.

### 6. For each entity, update or create the page

For **existing** entity pages: add a citation to the new summary, update relevant sections, append to the timeline.

For **new** entity pages: write the page following the schema in `CLAUDE.md`. Apply the **rule of three** — don't promote a one-off mention to a concept page unless it's been referenced in at least 3 sources or the author asks.

### 7. Check against Main{{SLUG}}Brain

Search Main{{SLUG}}Brain for any belief, principle, or life-decision that this source bears on. If Main{{SLUG}}Brain has a position, mention it in the summary's `## Connections` section: *"This aligns with `Main{{SLUG}}Brain: beliefs/<slug>.md`"* or *"This contradicts `Main{{SLUG}}Brain: beliefs/<slug>.md` — see Tension with truth."*

If a contradiction is meaningful enough to warrant updating the author's belief, **stage a proposal** at `~/LLM{{SLUG}}Brain/outputs/mainvault-pending/<slug>.md` with a `<!-- target: beliefs/<filename>.md -->` marker.

**Never edit Main{{SLUG}}Brain directly.** Stage and let the author decide.

### 8. Update the index and log

- Add the new summary to `~/LLM{{SLUG}}Brain/wiki/_index.md` under the appropriate section.
- Append to `~/LLM{{SLUG}}Brain/wiki/log.md`:

```
## [YYYY-MM-DD] ingest | <source title>
- summary: wiki/summaries/<slug>.md
- entities touched: <one-line list of pages updated>
- Main{{SLUG}}Brain check: <aligns | tension staged | no relevant content>
```

One self-contained entry. Append-only.

### 9. Mark the source processed

Update the raw file's frontmatter from `processed: false` to `processed: true`. This prevents re-ingestion.

### 10. Post-ingest settling

Re-read what you wrote. Verify:
- All wiki-links resolve to actual files.
- The summary's `## Tension with truth` section, if used, is honest and specific.
- The log entry captures everything the author should see.

Then report to the author in chat. Under 10 lines:
- What was filed.
- What was back-linked.
- What contradictions or open questions emerged.

## Rules

- **One source, one ingest.** Don't batch unless the author explicitly asks.
- **15 file threshold.** A healthy ingest touches 10–15 pages. If you'd touch more than 15, pause and ask the author. You're either being over-eager or the source warrants a synthesis (which the author writes).
- **Never write to `raw/`** — sources are immutable.
- **Never write to Main{{SLUG}}Brain** — stage proposals in the tray.
- **Citations on every factual claim.**
- **Default to no auto-ingest.** A file landing in `raw/` does not get processed until the author says so.

## What this skill does not do

- It does not fetch URLs that need a browser (heavy JS-rendered pages). For those, the author runs the deep-ingest skill from a browser-capable agent or pastes the rendered text into `raw/notes/` first.
- It does not do bounded research (looking up adjacent sources). For that, see `skills/deep-ingest/`.
- It does not modify the wiki schema. If the source doesn't fit existing page types, ask the author.
