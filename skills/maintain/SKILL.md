# Skill: Maintain — the Compound step

Maintain is the librarian's fourth step in every cycle. After every ingest, every query that surfaced something, every session of substantial work — pause and re-read what you wrote. Ask: *what pattern is emerging?*

This is the equivalent of the **Compound step** in Every's compound-engineering loop, applied to a knowledge vault rather than a codebase.

## When to invoke

- **Mode 1: Pre-ingest orientation.** Before starting an ingest, glance at `wiki/log.md` recent entries and active concept/theme pages. 30 seconds. The point is to know what's been touched recently so the new ingest connects rather than duplicates.
- **Mode 2: Post-ingest settling.** After an ingest finishes, re-read what you wrote. Verify cross-links, flag emerging patterns, propose new concepts or syntheses if warranted.
- **Mode 3: Author asks.** *"What's the pattern?"*, *"What's emerging?"*, *"Read the last week and tell me what you see."* — these are explicit invitations to a maintain pass.
- **Mode 4: Periodic.** Once every 10–20 ingests, even unprompted. Surface to the author: *"I'd like to do a maintain pass. Three minutes."*

## Mode 1: Pre-ingest orientation

Before starting an ingest:

1. Read the last 3 entries in `wiki/log.md`.
2. Read the headings of `_index.md`.
3. Glance at any concept or theme pages your incoming source is likely to touch.

Tell the author one line: *"Last 3 ingests touched [X, Y, Z]. The incoming source connects to [[concepts/foo]] — I'll extend that page rather than create a new one."*

Then proceed with ingest. Total time: 30 seconds. The point is *connection*, not deep analysis.

## Mode 2: Post-ingest settling

After an ingest finishes:

1. Re-read the new summary you wrote. Does the TL;DR actually capture the source? If not, fix it.
2. Walk the cross-references. Every wiki-link in the summary — does it resolve to a real page? Did you remember to update those pages' `backlinks:`?
3. Re-read the entity pages you updated. Do the additions read coherently with what was already there, or did you tack something on awkwardly?
4. Check for emerging patterns:
   - Has this concept been referenced in 3+ summaries now? If so, it might warrant promotion from a passing mention to a full concept page (the **rule of three**).
   - Has this theme accumulated 5+ sources? Time to update its `## Current thesis`.
   - Did the new source create a tension with another summary or a Main{{SLUG}}Brain belief? Make sure that tension is captured, not buried.
5. Append a 1–2 line maintain note to `wiki/log.md` *under* the ingest entry:

```
## [YYYY-MM-DD] ingest | Source title
- summary: ...
- (existing ingest entry)

  → maintain: cross-links verified; concept [[X]] now at 3 references — propose promotion in next session.
```

Total time: 1–2 minutes. Most of the value comes from *forcing yourself to look back.*

## Mode 3: Author asks

When the author says *"what's emerging?"* or similar, do a deeper pass:

1. Read `wiki/log.md` for the period the author cares about (last week, last month).
2. Walk the most-recently-updated concept and theme pages.
3. Look for:
   - **Emerging concepts** — patterns that show up across 3+ recent ingests but don't yet have a concept page.
   - **Drifting theses** — themes whose `## Current thesis` is older than the most recent contradicting source. Time to propose an update.
   - **Cross-theme connections** — when two themes start citing the same sources, that's signal. Worth surfacing.
   - **Absent topics** — what hasn't been written about that the author seems to be circling?

Report in chat. Under 200 words:

```
Maintain — past <period>:

Emerging:
- <pattern A>: now at N citations. Suggest concept page [[concepts/<slug>]].
- <pattern B>: ...

Drifting:
- Theme [[themes/foo]]'s thesis hasn't been updated since <date>; recent sources X, Y, Z suggest <revision>.

Cross-theme:
- [[themes/A]] and [[themes/B]] are converging on <topic>. Worth a synthesis?

Quiet:
- Theme [[themes/Z]] hasn't been touched in <X> months. Archive or revive?
```

Wait for the author to choose what to act on.

## Mode 4: Periodic (unprompted)

After every 10–20 ingests, surface a maintain offer to the author. Don't run it without permission — but do *flag* that it might be due.

## Rules

- **Never auto-promote a concept to a page** without the author's nod. Surface, propose, wait.
- **Never auto-rewrite a theme's `## Current thesis`** without the author's nod. Propose the change in chat; let the author bless it before editing.
- **Never delete or archive on the author's behalf.** Lint and maintain surface candidates; the author acts.
- **Maintain is short.** If you find yourself spending 10+ minutes, you're doing analysis, not maintenance. Stop and ask the author what they want.

## What this skill does NOT do

- It doesn't ingest new sources. (See `ingest`.)
- It doesn't run external research. (See `deep-ingest`.)
- It doesn't do schema or contradiction-checking. (See `lint`.)
- It doesn't write to Main{{SLUG}}Brain. Stage proposals in the tray.

## The point of maintain

Most knowledge bases die not from a single bad decision but from *not noticing*. Notes accumulate. Concepts repeat. Themes drift. Without a maintain rhythm, the substrate becomes a mound. With one, it stays *alive* — every ingest connects to what came before, every theme's thesis is current as of the last source, every emerging pattern gets a name.

The author's compound is not the volume of sources ingested. It is the *coherence* of the catalog at any moment. Maintain is what produces that coherence.
