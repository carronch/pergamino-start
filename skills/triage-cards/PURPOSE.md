# Purpose: triage-cards

## Why it exists

The author's cards pile up faster than the author can decide them, and each small decision waits for the author. A triage reads every open card, takes the calls that can be undone, and leaves the author one short table of the calls that are the author's own.

## Motivating ideas

- A real snapshot of one brain, before the first triage: close to 100 open cards, about a third of them idle for 60 days, a third with no open item at all, many status notes over 600 characters, and more than 140 open items tagged for the author. Nobody can decide that by hand.
- The first dry run found 15 faults in the earlier version of this skill, and this version fixes them: "Keep going" hid Park and Retire, Done needed facts outside the card, the lane fix had no `waiting-for`, lint and guard lines counted as movement, a tag on a later line of an item was missed, and items had no calls.
- "You are babysitting the agent too much": an agent can take every call that is small and can be undone, then report.
- An operation that touches more than 15 files needs the author's go first. Hence the dry run.

## Standing calls for a weekly run

None yet. The author adds a call here after approving it in two dry-run reports in a row. Until then, a weekly run writes a report only.

## How it is judged

For each report: how many rows the author approved as written, how many the author changed, and how many open `#author` items remain afterwards. Record the three numbers at the top of the next report.

## Would be retired when

Four weekly reports in a row hold no decision, or the author stops reading them.
