# Card blocks — format and what each kind of work needs

Read this before step 6 of `SKILL.md`. It gives the block format and, for the common kinds of work, what a block must contain so that the next session can run the tasks without watching the video.

## The block

````markdown
## <Short title of the source> → <card or project> (<YYYY-MM-DD>)

> Source: [[wiki/summaries/<slug>]] · transcript `raw/transcripts/<file>` · <who, how long, the claim in one line>.
> Feeds: <the parts of the card's plan that this block changes>.

| Rule from the video (time) | <Target> today (source) | Change | Who | Done when |
|---|---|---|---|---|
| <the speaker's rule, short> (m:ss) | <fact> ([[wiki/…]]:line, `repo/file:line`, or "live check YYYY-MM-DD") | <the change> | session · #author | <a check anyone can run> |

**Tasks** (or "Tasks added to Phase N" when the card has phases)
- [ ] <concrete next action> — done when <check>
- [ ] <decision that only the author can make> #author

**Not adopted:** <rule> — <why it does not fit here>.
````

In a card in another language, write the same parts in that language, in the card's register.

### A blocked run

When the audio could not be read (a sign-in wall, no captions, a dead link), write a short block, so that the next session starts where this one stopped:

````markdown
## <Short title of the source> → <card or project> (<YYYY-MM-DD>) — blocked

> Blocked: <the reason, in one line, as the platform gave it>. Read so far: <title, description, thumbnails, on-screen text>.

- [ ] <the one action that unblocks it, for example "send a local copy of the video"> #author

| Rule from the video (time) | <Target> today (source) | Change | Who | Done when |
|---|---|---|---|---|
| <only rules visible in what was read; "time unknown" when there is none> | … | … | … | … |
````

Add no row for what the video might say. The re-run replaces this block with the full one.

## Rules for a good block

- **One row per rule, one rule per row.** Quote or tightly paraphrase the speaker, with the time. The summary holds the full quote; the block links to it.
- **"Today" is a cited fact, never a guess.** Search with `qmd` before you write that something is missing. A live check counts when it is read-only and dated.
- **"Done when" is a check:** a test that passes, a page that shows the right state, a number that the weekly review reads. Avoid "improve" and "consider".
- **Tasks are concrete next actions:** someone can start each one in 30 seconds. Write names in full: "Giving Tuesday", never "GT".
- **`#author` only on what the author alone can do:** decide, approve, pay, sign, publish. Untagged tasks are agent work.
- **"Not adopted" is part of the block.** A rule that does not fit, with the reason, stops the next session from proposing it again.
- **Do not copy the video into the card.** Link to the summary. The card keeps the plan and the dated timeline.

## What each kind of work needs

### Software

- Tasks sized as pull requests: the repository, the files, and the test or check that proves the change.
- Every code change ends with `/review-pr`. A change that touches money, sign-in or secrets runs `/blast-radius` on the plan first.
- Done when: the named test passes in continuous integration, or the review's findings are fixed.

### Content and media

- Content ideas or briefs: the hook in the first 2 seconds, the angle, the format, the channel and the language.
- If the project has a brand or style check (a grader script, a checklist), the draft runs it. A weekly review, if there is one, reads the result.
- Done when: a draft passes the check, or the weekly review reads the metric that the rule predicts.

### Advertising

- Briefs per gap: the person, the situation, the promise and the proof; one concept, one angle and one level of awareness (cold or warm).
- One tracked link per ad, and a read-only check of the landing page before any spend (the link opens the right page with the right options preselected, on a phone).
- Spend, budget steps, pause rules and approval are the author's (`#author`).
- Done when: the brief is approved, the landing check passes, or the weekly review reads the cost per result of that ad.

### Administration, tax and legal

- Procedures with their legal source: the tax authority, the social-security agency, the procurement portal. Cite the rule, not the video's paraphrase of it. When an official schema or form exists, a live check reads or parses it; it never sends a document.
- Checks reconcile against real records (invoices, bank statements).
- Agents never file, sign or pay. Digital signatures stay with the author (`#author`).
- Done when: a reconciliation run matches the records, or the author signs.

### Another kind of work

Read the card's plan. Map each rule to a part of the plan, then use the same block.

## Example rows (illustrative: an ad-buying talk → a donation project's card)

| Rule from the video (time) | The project today (source) | Change | Who | Done when |
|---|---|---|---|---|
| "test the funnel on your phone … before you spend a dollar" (7:08) | The campaign pages ignore `amount` and `frequency` in the link (live check; `CampaignPage.astro:546`) | The campaign page reuses the shared donation-preset code | session (pull request); merge #author | A read-only funnel check shows Monthly preselected on `/c/…?frequency=monthly` |
| Define a good result first (1:31–2:18) | Every donation fires one conversion, valued at the gift amount (analytics card, lines 15 and 28) | Monthly gifts send the amount × 10.4 (the expected months of giving) | session builds; publish #author | The tag manager preview shows value 374.4 for a $36 monthly test event |
| "five days before an ad gives you a solid read" (11:05) | Start planned for the second week of the month (card, Phase 2) | Launch on a Monday; first read on the Saturday after | #author | The next weekly review has a five-day read for each ad |
