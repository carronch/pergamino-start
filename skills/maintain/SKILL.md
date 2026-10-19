---
name: maintain
description: "Keep the LLM brain's wiki coherent: a 30-second orientation before an ingest, a 2-minute settling pass after it (re-read, back-links, index, emerging patterns), a pattern read when the author asks, and an on-demand maintenance sweep that writes a dated health report. Use when ingest calls it, when the author asks 'what's emerging?', 'what's the pattern?' or 'run a maintenance sweep', or after 10–20 ingests."
---

# Skill: Maintain the wiki

Maintain is the compound step of every cycle. After an ingest, after a query that surfaced
something, after a session of substantial work: pause, re-read what you wrote, and ask
*what pattern is emerging?*

Paths are relative to the LLM brain (`$PERGAMINO_LLM_BRAIN`). The Main brain is `$PERGAMINO_MAIN_BRAIN`.

| Mode | When | How it starts |
|------|------|---------------|
| 1. Pre-ingest | Before you process a new source | `ingest` calls it |
| 2. Post-ingest | After an ingest | `ingest` calls it |
| 3. Pattern read | The author asks "what's emerging?" | The author |
| 4. Sweep | On demand, a full health report | The author says "run a maintenance sweep" |

Every 10–20 ingests, offer a pattern read or a sweep: "I would like to do a maintain pass. Three minutes." Do not run it without the author's yes.

The brain does not maintain itself. The author and the agent maintain it together, during conversations.
A scheduled job can run deterministic checks, but a sweep's proposals still wait for the author.

---

## Mode 1 — Pre-ingest (30 seconds, automatic)

Before you process a new source, scan the context quickly:

```bash
# What changed recently?
tail -40 "$PERGAMINO_LLM_BRAIN/wiki/log.md"

# What did the last sessions leave open?
grep -rA2 "Open threads\|Open questions" "$PERGAMINO_LLM_BRAIN"/wiki/projects/*.md 2>/dev/null | tail -20
```

Read the headings of `wiki/_index.md` and glance at the concept or theme pages that the source is likely to touch.

Ask yourself:

- Is this new source related to the last few ingests? (If yes, extend
  existing pages and do not create new ones.)
- Did the last session leave open threads that this source might close?
- Which projects is it likely to touch? Skim those first.

Report in one line:

> *"The last 3 ingests touched [projects/X, tools/Y].
> This source continues the thread on [topic], so I will update
> [page] and not create a new one."*

Then proceed with the ingest. The point is *connection*, not deep analysis.

---

## Mode 2 — Post-ingest (2 minutes, automatic)

After an ingest, before you call it done:

1. **Re-read the pages you wrote.** Read them; do not skim. Does the TL;DR capture the source?
   Are the claims defensible and the citations real? Is there generic filler to remove?
   Do the additions to entity pages read coherently with what was already there?

2. **Verify the back-links.** For every tool, project or concept linked from the
   summary, confirm that the target page's Timeline has a matching entry that
   references the summary. Iron rule: an unlinked mention is a broken wiki.

3. **Rebuild the index.**
   ```bash
   bash "$PERGAMINO_HOME/scripts/rebuild-index.sh" "$PERGAMINO_LLM_BRAIN"
   ```
   It is deterministic and takes under a second. Do not skip it.

4. **Surface emerging patterns.**
   - The third source that mentions a concept with no concept page (the rule of three):
     > "This is the third source that mentions <topic>. Create `concepts/<slug>.md`?"
   - A theme with 5 or more sources: propose an update of its `## Current thesis`.
   - A new tension with another summary or with a Main brain belief: make sure that it is recorded, not buried.

5. **Note open threads.** Unresolved questions go on the relevant page,
   under "Open threads", so that `autoresearch` can pick them up later.

6. **Add a maintain note** of 1–2 lines to `wiki/log.md`, under the ingest entry:
   ```
     → maintain: cross-links verified; concept [[X]] now at 3 references — propose promotion next session.
   ```

---

## Mode 3 — Pattern read (on request, under 200 words)

When the author says "what's emerging?" or similar:

1. Read `wiki/log.md` for the period the author cares about (last week, last month).
2. Walk the most recently updated concept and theme pages.
3. Look for:
   - **Emerging concepts**: patterns in 3 or more recent ingests without a concept page.
   - **Drifting theses**: themes whose `## Current thesis` is older than the newest contradicting source.
   - **Cross-theme connections**: two themes that start to cite the same sources.
   - **Absent topics**: what the author seems to circle but has not written about.

Report in chat:

```
Maintain — past <period>:

Emerging:
- <pattern A>: now at N citations. Suggest concept page [[concepts/<slug>]].

Drifting:
- Theme [[themes/foo]]'s thesis has not changed since <date>; sources X, Y, Z suggest <revision>.

Cross-theme:
- [[themes/A]] and [[themes/B]] converge on <topic>. Worth a synthesis?

Quiet:
- Theme [[themes/Z]] has not been touched in <N> months. Archive or revive?
```

Wait for the author to choose what to act on.

---

## Mode 4 — Sweep (on demand, 15–30 minutes)

Starts when the author says "run a maintenance sweep". Run the deterministic
checks first, then the semantic work.

### Deterministic checks (run these first)

```bash
# Rebuild the index and the graph from the directory tree
bash "$PERGAMINO_HOME/scripts/rebuild-index.sh" "$PERGAMINO_LLM_BRAIN"
```

Then run `skills/lint/SKILL.md` for orphans, broken wikilinks and missing concept pages.
Capture the counts: they go into the report's health snapshot.

### Your job during a sweep

Write a report at `wiki/syntheses/maintain-YYYY-MM-DD.md`. Template:

```markdown
---
kind: synthesis
title: "Maintenance sweep — YYYY-MM-DD"
created: YYYY-MM-DD
tags: [maintenance]
---

# Maintenance sweep — YYYY-MM-DD

## Health snapshot
- Total pages: N
- Active projects: N
- Decisions (all time): N, superseded: N
- Orphans flagged by lint: N
- Broken wikilinks flagged by lint: N

## What compounded since the last sweep
- <projects that moved>
- <decisions recorded>
- <concepts that gained connections>
- <tools that gained experience notes>

## What's rotting
- <project pages with status: active but no Timeline entry in 30+ days>
- <tool pages with no "Your experience" content>
- <decisions 90+ days old worth revisiting>
- <architecture decision records whose context may have shifted>

## Contradictions flagged (not resolved)
- <page A says X. page B says Y. suggest: ___>
- <tool page says X. Main brain belief on the topic says Y. Truth wins — revise the tool page?>

## Stale decisions worth revisiting
- [[decisions/YYYY-MM-DD-slug]] — recorded N days ago. The context may have
  shifted because ___. Confirm, update or supersede?

## Tool pages thin on experience
- [[tools/...]] — used in 3+ projects but no "Your experience" section.
  Do you want to add observations now?

## Gaps worth researching (feed to autoresearch if approved)
- <open question from a project page>
- <tool mentioned across sources but no page yet>

## Beliefs possibly affected
- <Main brain file> — <what the sweep found>. Flag only; no proposal.

## Proposed actions (nothing applied without approval)
- [ ] Merge tools/a.md and tools/b.md (duplicate — same tool, different names)
- [ ] Promote syntheses/x.md into concepts/y.md (cited by 4 other pages)
- [ ] Archive projects/z.md (marked abandoned, no Timeline entries in 6 months)
- [ ] Supersede decisions/YYYY-MM-DD-a.md with a new decision record
```

Log:

```
## [YYYY-MM-DD] maintain | sweep
- report: wiki/syntheses/maintain-YYYY-MM-DD.md
- N issues flagged, 0 auto-fixed
```

---

## Principles

1. **Propose, do not apply.** Destructive changes (merge, archive, supersede)
   and new concept pages need the author's approval. Never rewrite a theme's
   `## Current thesis` without the author's nod.
2. **Truth is sacred.** Never propose edits to the Main brain from a sweep. Propose wiki
   revisions that align with the Main brain when they disagree, never the reverse.
3. **The maintenance reports are their own artifact.** Read in
   order, they tell the story of the brain. Keep them readable:
   no boilerplate padding.
4. **The second time is a pattern.** If the same fix appears in two
   consecutive sweeps, add a deterministic check to `skills/lint/SKILL.md`,
   so that lint catches it without semantic work.
5. **Less is more.** 50 well-connected, current, cited pages beat 500
   orphaned fragments. When in doubt, archive.
6. **Follow the brain's focus.** Prioritize what the author builds:
   active projects with recent Timeline entries, decision records that can be revisited,
   tools with real experience notes.
7. **Keep modes 1–3 short.** If a pass takes 10 or more minutes, you are doing analysis,
   not maintenance. Stop and ask the author what they want.

## What maintain is NOT

- **Not a rewrite of old pages to match the current style.** Style evolves. Old
  pages stay as they are unless they are factually wrong.
- **Not deletion of anything the author has not seen.** Archive (move to
  `wiki/<dir>/archive/`). Do not delete.
- **Not editorializing truth.** If a sweep surfaces reasons the author might
  want to update a belief, flag it under "Beliefs possibly affected" in
  the report and stop.
- **Not ingest** (see `ingest`), **not external research** (see `deep-ingest`, `research`), **not the full contradiction and schema check** (see `lint`).

## The point of maintain

Most knowledge bases die not from one bad decision but from *not noticing*. Notes accumulate. Concepts repeat. Themes drift. With a maintain rhythm, every ingest connects to what came before, every theme's thesis is current as of its last source, and every emerging pattern gets a name. The measure is not the volume of sources. It is the coherence of the catalog at any moment.
