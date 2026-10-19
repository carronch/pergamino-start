# Purpose: correct

## Why it exists

The author's corrections pile up as text that nothing enforces. A line in `lessons.md` or `AGENTS.md` fails silently when an agent skips it. This skill turns a mistake that happened twice into a check that fails, and proves the check on the real mistake.

## Motivating ideas

- "Turn repeated tasks into tooling" and "encode lessons in structure": a written lesson is the weakest kind of fix.
- Review findings repeat. In one count, about 3 of 8 review warnings were mechanical and could have been a script. A finding category seen in two pull requests becomes a rule, and a mechanical rule becomes a check.
- A check must be able to fail. Prove it on a real case, not on a made-up one.
- If the same question must always get the same answer, write the script.
- The `maintain` skill uses the same threshold for wiki fixes: the second time is a pattern.

## Would be retired when

A `/correct` run finds no mistake class that has happened twice for three months, or a scheduled job does the same mining and proposes the checks by itself.
