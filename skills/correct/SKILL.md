---
name: correct
description: "Find the mistakes agents keep repeating in a repository or in the author's agent setup, and make each one impossible. Try architecture first, then types, then a lint, hook or continuous-integration check whose error names the fix, then a test, and write rules last. Prove each check fails on a real past mistake. Use when the author types /correct, or says 'agents keep doing X', 'make this mistake impossible' or 'turn this lesson into a check'."
disable-model-invocation: true
---

# Correct

Adapted from pstack's `correct` skill (Lauren Tan, MIT licence; `cursor/plugins`, commit `9d76bca`). This copy names where the author's corrections are recorded and which checks can enforce a rule in a Pergamino setup.

The author keeps correcting agents for the same mistakes. Change the repository, or the setup, so the next agent cannot make them.

Assume every contributor is an agent that sees only the files it opened, copies the nearest example, and takes the shortest path that compiles. Design the repository so that a change that looks right from one file is right for the whole repository.

## Find the mistake classes

Read these, in this order:

1. `tasks/lessons.md` in the repository, if it has one, and `"$PERGAMINO_LLM_BRAIN"/lessons.md` for setup mistakes. Each entry is a correction the author made.
2. Review findings: pull-request comments from earlier reviews (`gh pr view <n> --comments`), especially the findings that the author accepted.
3. Recent commits, reverts and fix commits (`git log --since=60.days --oneline`, `git log -i --grep=fix --grep=revert`).
4. The agent instruction files (`AGENTS.md`, `CLAUDE.md`, `.claude/` rule files, `.cursor/rules/`) and code comments that explain a workaround.

Group the mistakes into classes. A class counts once it has happened twice ("the second time is a pattern").

## Fix each class at the highest level that works

1. **Eliminate it with architecture.** Give each piece of state one owner and each task one supported way. Hide internals so that the wrong import fails. Replace hand-synced lists with one source of truth. Delete old ways and dead code that an agent would copy.
2. **Enforce it with types**, so that the bad state cannot be written.
3. **Enforce it with a check whose error names the fix.** The options: a lint script with its own test, a step in the repository's continuous-integration (CI) workflow, a hook in `"$PERGAMINO_HOME"/hooks/`, or a deny rule in the agent's settings file (for Claude Code, `~/.claude/settings.json` or the project's `.claude/settings.json`). If the pattern is already common, fail only when a change adds more.
4. **Test the behavior.** Fix or delete any test that would still pass if every function it calls returned nothing.
5. **Write docs or agent rules last, only for judgment calls.** Nothing fails when an agent skips them. Here that means a line in `AGENTS.md` or in `"$PERGAMINO_LLM_BRAIN"/lessons.md`.

## Fix and prove

Fix the most frequent classes now, one commit each. Prove each new check fails on a real past mistake: run it on the commit that had the mistake and keep the failing output, then run it on the fix and keep the passing output. Run the same command locally and in CI. An exception goes on the offending line, with a reason, an expiry date and the author's approval.

Code and script changes go through the repository's review (`/review-pr`). A change to a skill, a rule file or a hook goes in a pull request that the author reads and merges.

## Keep the rule table

Keep a short table in the repository's agent instruction file that pairs each rule with what enforces it. When the author corrects you, fix the mistake and add the rule. If the rule was already there and nothing enforces it, that is a repeat: fix it at the highest level in the same change. Drop a rule once its mistake cannot happen.

**Reply:** each class with its evidence (file and line, or commit), the level you picked, and why a higher level did not work.
