---
name: blast-radius
description: "Find what a change could break somewhere else before it ships, beyond the diff, and prove the one fact it is safe because of by running real code instead of writing it up. Main use: on a plan, before building, for work that touches money, sign-in or secrets. Use for 'blast radius of X', 'what could this break', 'map the risk before we build', or reviewing a small diff you do not trust."
disable-model-invocation: true
---

<!-- Upstream: github.com/cursor/plugins — pstack/skills/blast-radius/SKILL.md at commit
     78f46dacbafc71fd7d937bfc2c26da914f1bc09b (MIT, Copyright (c) 2026 Lauren Tan; see
     LICENSE-pstack). Everything below "# Blast radius" is upstream, verbatim. To update,
     re-copy it from a newer pinned commit; never hand-edit the upstream part. Local
     changes go only in the block directly below. -->

## Requires

- commands: `git`; `gh` is optional (to read pull-request history).

Check first: `command -v git`. If it prints nothing, stop and tell the author; do not work around it.

## Local adaptation (read this first — it wins wherever the upstream text below disagrees)

- **Main use: before building, on work that touches money, sign-in or secrets.** Run it on the
  *plan*, before any code is written. A wrong assumption found on the plan costs a changed plan
  instead of rewritten code. Read "the change" in the steps below as the planned change: the
  workblock card (in `"$PERGAMINO_LLM_BRAIN"/wiki/workblocks/`) or plan text, plus the code it will
  touch. Everything else stays — find the one fact the plan is safe because of, look where grep
  stops, be honest about each risk — except that proofs run against the *current* code. Hand the
  result back into the workblock card: the safety fact, and the level it reached, join the reference
  the work will be judged against; unproven facts and confirmed risks go under `## Known unknowns`;
  "Before you merge" becomes the check the build has to pass. It also works on a finished diff that
  you do not trust.
- **Always work in a throwaway clone** (`git clone --no-hardlinks . "$(mktemp -d)/repo"`, applying the
  change there if one exists) — nothing else checks that the repository was left alone.
- **Never print a secret.** When the plan touches credentials, work with names only (`git grep -l`,
  `grep -o 'NAME_[A-Z_]*'`), never the contents of `.env`, `.dev.vars`, token or credential files —
  including ones committed to the repository by mistake.
- `how`, `why`, `arena` and `unslop` are other pstack skills, not part of this kit. Instead of "`why`
  step 2" use `git log -p`, `git blame` and `gh pr view`; skip step 6's arena unless you have a
  second vendor's tool at hand (see `/review-pr`); write plainly.
- **Proof scripts and scratch files go in a fresh `mktemp -d` directory, never inside the
  repository** — including upstream step 5's "script or test". Paste each script in full with its
  output, so that the reader can check it before accepting "proven". Stop any process you start (dev
  server, watcher) before you finish.
- **Prove facts locally only.** No network, no remote bindings, no deploys, migrations, remote
  database commands, payments, emails, pushes, or calls to production services — this overrides
  upstream level 5 ("reproduced it in the running app") wherever the running app is production.
  Reading history with `gh pr view` is fine. If the one fact can only be proven against production,
  stop at level 3 of "How sure are you" and write **unproven**.

# Blast radius

Find what a change breaks somewhere else, before it ships. Use for "blast radius of X", "what could this break", or reviewing a small diff you don't trust yet.

Companion to `how` and `why`. `how` tells you what the code does. `why` tells you why it's shaped that way. Blast radius tells you what it breaks somewhere else.

Listing the callers is not the job. The agent can grep those in a second. The job is the breakage grep won't show you.

## Don't trust your own writeup

A blast-radius writeup that sounds right is worthless. It reads as convincing whether or not it's true. So don't hand back the writeup. Find the one or two facts the whole thing depends on and prove them by running code.

### How sure are you

For each fact the change's safety depends on, get it as far down this list as is cheap, and say where it stopped.

1. You said so. Worthless on its own.
2. You pointed at the line. A real `file:line`, or the library's own source.
3. You showed the bad case can't happen. You walked the failure step by step and it doesn't reach.
4. You ran it. A script or test that calls the real code and fails loud if you're wrong.
5. You reproduced it in the running app.

Step 4 is usually one small script that imports the same library the app ships and calls the exact function you're worried about.

## Steps

1. Read the change. The diff, the symbols it adds, changes, and deletes, and what it now does differently, including the part the diff doesn't spell out. Use `why` step 2 to pull the PR and commits.
2. Find the one fact it's safe because of. Most changes that look risky are safe because of a single fact, like "this call only drops already-dead cache entries and does nothing else". Find that fact. If it holds, most risky cases are cleared at once. Spend your time here, not on a long list of maybes.
3. Look where grep stops. Read the source of the library you call, and check its pinned version and any local patch. Work out when things run: microtasks, unmount and teardown, Solid versus React. Follow what a symbol search misses: the JSON an API returns, a DB column, a wire format, another language reading the same bytes, a feature flag, code three hops downstream.
4. Be honest about each risk. Give it a real chance of happening and a real cost if it does. Keep the risks you confirmed. List the ones you checked and cleared separately. Same rules as `why`. Cite a real `file:line`, a search that finds nothing is still an answer, and never make up a caller or an API.
5. Prove the one fact. Write a script or test that runs the real code, run it, and paste what happened.
6. For a big or wide change, run it as an `arena`. Ask several models the same question and merge the answers. Different models catch different real bugs.

## What to hand back

- **What it does.** What changed, including the part that isn't obvious.
- **The one fact it's safe because of.** State it, say which step you got it to, and show the proof. If you couldn't prove it, write unproven.
- **Risks.** Each names how it breaks, the `file:line`, how likely and how bad, and how to check. Paste the proof for the ones that matter.
- **Cleared.** What you checked and why it's fine.
- **Before you merge.** The cheapest test or repro that catches the real bug, including the script you wrote.

Write it through `unslop`, cite real code, and strip anything private before it goes anywhere public.

**Reply:** the writeup above, with the one safety fact either proven or marked unproven.
