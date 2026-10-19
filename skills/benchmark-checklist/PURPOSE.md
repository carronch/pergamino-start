# Purpose: benchmark-checklist

## Why it exists

A setup that uses agents measures often: agent arms, search speed, cost per run, vendor claims. A number reported from one run, an untuned side or a misread counter can mislead a decision. This skill vets a number before anyone acts on it.

## Motivating ideas

- A benchmark with two runs per cell and one task type has limits. Name them in the report.
- A first diagnosis of a slow search can be wrong. Profiling finds the real limiter.
- A live token counter can understate a session's cost several times over. Use the cost the tool reports at the end.
- Evaluation practice: fixed tasks, repeated trials, pass^k, paired per-task comparisons.
- A vendor's price or speed claim can be checked against the published price table and hardware limits.

## Would be retired when

The benchmark harnesses print error counts, run counts, ranges and limiters by themselves, so that a person or an agent can no longer report a bare number from them.
