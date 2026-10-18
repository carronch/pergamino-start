# Purpose: retro

## Why it exists

Without it, no skill looks back at past sessions. The only look-back is `lessons.md`, which loads in full at every session start. `retro` reads one session and proposes changes to the agent's environment (navigation pointers, automated checks, reviewer standards, a leaner `AGENTS.md`, cheaper tooling), most severe first. It proposes; it changes nothing by itself.

## Source

A verbatim copy of `skills/engineering/retro/` from github.com/mattpocock/skills at commit `49dd158d1076134a641b33efb035946536778336` (2026-10-09), under the MIT License (`LICENSE-mattpocock`). To update it, copy the folder again at a newer commit and record the commit here. Do not edit `SKILL.md` in place. The one local change is the frontmatter `description:`, which adds trigger phrases so that agents discover the skill; keep it when you copy again. `retro` calls `writing-for-agents` first, so that skill came from the same commit.

## How its proposals land in a Pergamino setup

- An automated check goes in the repository, through `/review-pr`.
- A reviewer standard: `/review-pr` sends one plain request and reads no `CODING_STANDARDS.md`. Propose the standard on the project's card in `"$PERGAMINO_LLM_BRAIN"/wiki/workblocks/`, and the author decides where it lives.
- A line for `AGENTS.md` or for memory is never a small change, so the author decides. A lesson for one project goes to that project's card, under `## Lessons`. A lesson for every session goes to `"$PERGAMINO_LLM_BRAIN"/lessons.md`.

## Known costs

- It loads `writing-for-agents` (about 11 KB) first.
- Upstream users report noisy candidates. Expect to drop some of them.

## Would be retired when

Four weekly runs in a row yield no proposal that the author accepts.
