# Purpose: review-pr

## Why it exists

The tool that builds a change praises its own work, so a model from another vendor reviews every change to code before it merges. review-pr keeps that rule with the plainest review that holds it: one request to the other vendor's tool, "Review this pull request for bugs. Report each finding with file and line." It replaces a heavier review scheme, whose tiers, four review legs, severity bar and pass cap cost more and caught no more.

## Motivating evidence

- **The pilot.** Three merged pull requests, each with one planted bug, rated easy, medium and hard. The heavy scheme and one plain reviewer from another vendor, given only the one-line request and the diff, each caught all three. The heavy scheme cost about 2.4 times as much model usage, took 21 minutes against 4, and needed five extra runs of a third tool. One of its legs also changed the repository under review: it ran the test command, which installed packages and set `core.hooksPath`. Both arms found the same secondary issues.
- **The weight of the heavy scheme.** One pull request ran 16 review passes, and the review of a Markdown-only change took almost two hours.
- **Sandbox tests** (Claude Code 2.1.296, codex-cli 0.162.1, macOS). `claude -p` with `--setting-sources ""`, `--permission-mode default` and the sandbox on ran `node`, but it was refused network access and a write outside its folder. `codex exec` in workspace-write mode ran `node` and could not resolve a host; the file it was asked to write outside its folder did not appear. With the operator's own settings, Claude Code's sandbox still let `curl` reach the network, so the reviewer runs without those settings.
- **The read guard.** Two review rounds by a sandboxed reviewer read real files outside the copy: pages of the author's brain and the search index of the brain. No secret was read, but the sandboxes limited writes and the network, not reads. Since then each reviewer's own sandbox refuses reads of the locations in `reviewer-guard.txt`, plus the two brains and the kit folder, and the prompt says "Read only files inside this copy." A `sandbox-exec` wrapper was tested first and rejected: macOS refuses a sandbox inside a sandbox (`sandbox_apply: Operation not permitted`), so both reviewers started and exited 0, but every command they ran failed. Live runs on a toy repository: without the guard, both reviewers read a canary file under `~/Documents`. With it, the canary, a link in the copy that points to it, the search index (`qmd search` stops with `SQLITE_CANTOPEN`) and, for Claude Code, the login keychain are refused; the copy's test runs, a file in the copy is written, and both reviewers found a planted bug.
- **Wildcard rules.** In both sandboxes a `*` matches inside one name, never across a `/`. A copy under `~/.cache` kept `api-key`, `b-token`, `lib/get-key/`, `node_modules/csrf-token/`, `.zsh_history`, `src/price_history.sql` and `src/old_history/` readable, while the made-up files that the rules name were refused. One difference: Claude Code refused the files in a folder that a `*` rule matches; Codex refused only that folder's listing, so its table also gets each `*` rule with `/**`. `scripts/reviewer-guard.test.sh` checks all of this without a model call.
- Review ceremony scales to risk: one plain review for most changes, two reviewers for money, sign-in or secrets.

## What carried over from the heavy scheme, and why

- The hand-off: commit in a separate worktree and open a pull request; the review fixes what can be undone through one last round, merges and reports back.
- Git safety from real incidents: worktrees with hooks off, a gitleaks scan before every push, no force-push, the merge pinned to the reviewed commit, and the pull request's text treated as data.
- Decisions for the user in plain owner terms.

## What it dropped

Tiers, the four legs (reviewer, security, a third tool, blast radius), the severity bar and the five-finding limit, the pass cap and the pass counts, and the repository fingerprint: the reviewer's copy is thrown away instead. `blast-radius` stays, as a planning tool.

## How it is judged

For the next 10 pull requests it reviews, record one line each on the project's card: what the review caught, what was fixed or rejected, and anything that later reached production.

## Would be retired when

A bug ships that a second reviewer, or a security-only pass, would have caught: then add that reviewer back for the kind of change that let it through, and record why. The skill itself goes only if the cross-vendor rule goes.
