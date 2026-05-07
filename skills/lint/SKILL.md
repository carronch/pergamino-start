# Skill: Lint the wiki

Run this when the author asks for a health-check, says *"clean up the wiki"*, *"what's stale?"*, or *"run lint."* Periodic linting (every 20–30 ingests, or weekly for active vaults) keeps the catalog from drifting into noise.

## What lint checks

### 1. Contradictions

Walk through theme pages and concept pages. For each `## Current thesis` or `## Key claims` block, check whether any other page makes a contradicting claim.

When you find contradictions:
- If both claims cite different sources, that's normal disagreement — note it on the page as *"Sources differ; see X vs. Y."*
- If both claims cite the same source, one of them is wrong. Flag for the author to review.
- If one of the claims contradicts a MainVault belief, **stage a proposal** in `outputs/mainvault-pending/` describing the discrepancy. The author decides which is right.

### 2. Orphans

Find pages that:
- Are not linked to from any other page (`backlinks: []` and not in `_index.md`).
- Were created more than 30 days ago.
- Have not been edited since creation.

These are usually one-off ingest summaries that never got cross-referenced. Two outcomes:
- If the page contains a useful fact or claim, propose cross-links to existing concept/theme pages.
- If the page is genuinely a dead end, propose archival to `wiki/archive/<slug>.md`. Do not delete.

### 3. Stale claims

For each page with frontmatter `confidence: forming` or `confidence: low` AND `updated:` more than 6 months old: flag for author review. The author's confidence may have changed; the page should be updated or the confidence acknowledged.

For pages that cite sources marked `processed: false` (i.e., the source was filed but never ingested): note which sources are outstanding.

### 4. Missing cross-references

For each summary page, check whether the concepts/themes/projects it references all link *back* to the summary in their respective pages. Cross-links are bidirectional in the schema; lint catches asymmetries.

### 5. Schema drift

For each page in `wiki/`:
- Verify frontmatter matches the schema in `CLAUDE.md` (correct `type`, required fields, valid `confidence` values).
- Verify the page's section structure matches its `type` (e.g., a `summary` page should have TL;DR + Key claims sections).

Flag pages that have drifted. Don't auto-fix without the author's nod — schema drift is sometimes intentional.

### 6. The index

After lint, regenerate `wiki/_index.md` from current state:
- One section per page type (Concepts, Themes, Projects, Summaries, Syntheses, Tools, Thinkers).
- Each entry links to the page with a 1-line description.
- Sort within each section by `updated:` descending (most recent first).

If the author has a deterministic index regenerator (a shell script), prefer running that over hand-editing.

### 7. Tray hygiene

Walk `outputs/mainvault-pending/`:
- For each staged proposal, check if it's been there more than 7 days. If so, surface to the author: *"This proposal has been waiting since <date>. Promote, archive, or revise?"*
- For each proposal that's been **archived** (resolved) but not deleted, clean it up.

## Output

A single lint report in chat, structured as:

```
## Lint report — YYYY-MM-DD

### Critical (blockers)
- <items requiring author decision before more ingests>

### Important (should fix soon)
- <items>

### Nice-to-fix
- <items>

### Stats
- Pages: N concepts, N themes, N summaries, ...
- Orphans: N
- Stale (>6mo): N
- Tray pending: N
```

Don't auto-fix anything in the **Critical** category — surface and wait. **Important** and **Nice-to-fix** items can be auto-fixed only if the fix is mechanical (regenerating an index, restoring a missing backlink). Anything that requires judgment goes to the author.

## Rules

- **Lint is read-mostly.** Its job is to surface, not to act.
- **Never delete pages.** Archive, propose archival, but don't delete. The author keeps the substrate's git history; deletion is a manual choice.
- **Never edit MainVault.** Stage proposals.
- **Don't lint during an ingest.** They're separate operations. Linting mid-ingest causes noise.

## After lint

Append to `wiki/log.md`:

```
## [YYYY-MM-DD] lint
- pages scanned: N
- critical: N · important: N · nice-to-fix: N
- author actions queued: <one-line>
```

## What this skill does not do

- It does not run automated cleanup that requires judgment. Human-in-the-loop on contradictions, archival, MainVault staging.
- It does not run on a schedule. It runs when the author invokes it.
