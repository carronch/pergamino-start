# Skill: Deep-ingest a URL

A more thorough ingest with bounded adjacent research. Run this when the author pastes a URL and asks to *"deep-ingest"*, *"ingest and research"*, or *"deep research"*.

This skill **composes** the `ingest` skill. It does not duplicate ingest's logic — it adds a research pass on top.

## Triggers

- *"Deep-ingest this: <URL>"*
- *"Ingest and research <URL>"*
- *"Do deep research on <URL>"*

## Steps

### 1. Fetch the source

If you have a web fetch tool, use it. Quick sanity check: if the response is mostly `<script>` tags or a "Loading…" placeholder (under ~500 chars of body content), stop and tell the author the page is JS-rendered. Don't produce a garbled summary from a JS shell.

Save the fetched content to `~/LLMVault/raw/web/<YYYY-MM-DD>-<slug>.md` (per the routing in `RESOLVER.md`).

### 2. Run the ingest skill

Hand off to `skills/ingest/SKILL.md` on the new raw file. When ingest finishes, you have a summary at `wiki/summaries/<slug>.md` plus whatever entity pages got touched.

**Do not duplicate ingest's logic.**

### 3. Theme resolution

Decide where this source belongs thematically. Three outcomes:

- **High-confidence match** on an existing theme → extend that theme page.
- **Uncertain** → propose the candidate in chat: *"This looks like it extends `[[themes/<slug>]]`. Confirm or redirect."* Wait for the author.
- **No existing theme covers this** → propose a new theme: *"No existing theme covers this. Propose new theme `<slug>` in cluster <work | interest | teaching>. OK?"* **Never auto-create a theme.**

### 4. Bounded research pass — max 3 adjacent sources

This is the part that distinguishes deep-ingest from regular ingest. Identify up to 3 adjacent sources worth pulling in:

- An upstream ancestor (the original idea this source builds on).
- A canonical alternative or counter-position.
- A worked example or case study.

For each:
- Fetch and save to `~/LLMVault/raw/autoresearch/<YYYY-MM-DD>/<slug>.md`.
- Run the `ingest` skill on each.
- Cross-link the new summaries back to the theme page from step 3.

**Hard cap: 3 sources.** No recursion. The research is bounded by design.

If the theme already has 10+ sources consumed, **skip this step** — the theme is mature; adding more breadth here is noise. Tell the author you skipped and why.

### 5. Synthesize into the theme page

Update the theme page (per the schema in `CLAUDE.md`):

- `## Current thesis` — if the theme already had one, **propose** an update in chat. Don't overwrite.
- `## Open questions` — append 1–3 new questions surfaced by the new sources.
- `## Key claims` — each with `[Source: [[summaries/<slug>]]]`.
- `## Sources consumed` — one line per ingested source, with takeaway.
- Append a timeline entry: `- **YYYY-MM-DD** | deep-ingest | <source title>. [Source: raw/web/<slug>]`

### 6. MainVault theme-level check

In addition to the per-source MainVault check ingest already did, run a theme-level check: search MainVault for the theme's keywords. If the author has a belief or principle on this topic, **prepend** it to the theme page's `## Current thesis` block as the starting position, citing the MainVault file.

### 7. Log

Append to `~/LLMVault/wiki/log.md`:

```
## [YYYY-MM-DD] deep-ingest | <source title>
- url: <url>
- summary: wiki/summaries/<slug>.md
- theme: wiki/themes/<theme-slug>.md (new | extended)
- research sources: N
```

### 8. Report

In chat, under 10 lines:
- What was fetched.
- Theme assignment (new or extended; which).
- Research sources pulled (count and one-liners).
- Open questions surfaced.
- Any MainVault tension staged.

## Rules

- **One URL, one deep-ingest.** Don't batch.
- **Max 3 adjacent sources.** Hard cap. No exceptions, no recursion.
- **15-file threshold still applies.** If the full chain (ingest + research) would touch more than 15 files, stop and ask. Usually narrowing the research pass to 1–2 sources is the answer.
- **Never auto-create a theme.** Always confirm.
- **Never write to MainVault.** Stage proposals in the tray.
- **Never skip the JS-shell check** — a silently garbled summary is worse than no summary.

## What this skill does NOT do

- A full multi-day research loop (that's a different skill — and probably a question for the author, not a default behavior).
- Following links recursively beyond the bounded 3-source pass.
- Editing MainVault directly under any circumstances.
