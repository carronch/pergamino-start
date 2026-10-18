# Purpose: prompt-style

## Why it exists

The author often hands an agent a creative or research ask. A long, step-heavy prompt caps the plan at the prompt writer's imagination, and it carries rules that current models no longer need. This skill turns a rough ask into the short "big ask" form that Boris Cherny's public prompt shows: fix the what and the why, and free the how. It adds two limits that a real setup needs: a bounded license to iterate, and a Boundary for work that touches production, client data, money or secrets.

## Motivating ideas

- The anatomy of the 82-word prompt: seven moves, three kinds of words (destination, taste, hints), and where the style needs limits.
- In replies to the prompt, its author said that the model chose to read the primary sources itself and picked OpenCV on its own. A free route can beat a prescribed one.
- Model vendors have cut large parts of their agents' system prompts for newer models with no measured loss. Conflicting rules tax the model.
- Practitioners report the same direction: fewer custom instructions.
- Showpiece work needs a named benchmark for the artifact, and two or three style frames approved before building.
- An iteration license needs a stop rule: a cap on rounds, and a report when the last round changes little.

## Would be retired when

A blind comparison on real tasks shows that the author's plain requests do as well without it (the harness ablation test: if removing it causes no regression, it is debt). Also retire it if the models change so that the effort license or the soft-hint style stops helping.
