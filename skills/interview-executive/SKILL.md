# Skill: interview-executive

> Role-specific question bank that the operator runs with one leader at a time. Populates the company's MainBrain with leadership knowledge: how this person thinks, what they decide, what's in their head that nobody else has written down.

## When to invoke

Trigger phrases:
- *"Run interview-executive for {{name}}"*
- *"/interview-executive --person {{person-slug}}"*
- *"/interview-executive --role ceo"*

Run this skill **after** `pergamino-intake` has produced the scope plan and the kit has provisioned the brain. The intake interviewed the operator and the principal as a duo about company shape; this skill goes deeper, one leader at a time, role by role.

## Why this skill exists

Every company has knowledge concentrated in a few heads. When that knowledge stays unwritten, it leaves with the person, fragments under pressure, or quietly contradicts itself across departments. This skill is the deliberate extraction pass: a role-specific question bank that surfaces what the leader carries, captures it in their voice, and files it where the rest of the kit can use it.

## Inputs

The skill takes one of two arguments:

- `--person {person-slug}` — interview a specific named leader. Loads `~/Main{{SLUG}}Brain/leadership/{person-slug}.md` to discover their role.
- `--role {role}` — interview a role generically (when the leader hasn't been added to the roster yet). Saves to a temp draft until the operator confirms the person.

Supported roles: `ceo`, `founder`, `cfo`, `cmo`, `sales`. (More roles are added by writing additional banks under `roles/`.)

## Interview flow

1. **Load the leader's file.**
   - With `--person`: read `~/Main{{SLUG}}Brain/leadership/{person-slug}.md`. Extract the `role:` field from frontmatter. If the file doesn't exist, the operator should add the person to the roster first (a one-line entry per leader, written by the operator during onboarding).
   - With `--role`: skip the file load; ask the operator for the person's name and slug at the start, then create `~/Main{{SLUG}}Brain/leadership/{person-slug}.md` with the role frontmatter set.

2. **Load the question bank.** Read `roles/{role}.md`. The frontmatter declares the section list; the body has the questions per section.

3. **Confirm scope with the leader.** Tell them: "I'll ask you N questions across M sections. Estimated time: X minutes. We can pause anytime; nothing is committed until the end of the session." Get their go-ahead.

4. **Run the questions one at a time.** For each question:
   a. **Show the question** in plain language, the leader's primary language. If the leader's `language:` frontmatter says `{{LANG_SECONDARY}}`, ask in that language and capture the answer in the same language.
   b. **Wait for the answer.** Don't push. Don't summarize back into corporate-speak. The leader's words are the artifact.
   c. **Append to the leader's file** under the matching `## <section-name>` heading. Format the answer as the leader said it; light-touch grammar fixes only.
   d. **Apply tags.** If the question carries `tag: disclosure_tier`, also append the answer to `~/Main{{SLUG}}Brain/policies/{person-slug}-disclosure.md` under the matching tier section. If the question carries `tag: decision`, also append to `~/Main{{SLUG}}Brain/leadership/{person-slug}-decisions.md`.

5. **After the last question**, summarize for the leader:
   - "We captured N answers across M sections."
   - "Disclosure-tier answers: K (filed to `policies/{person-slug}-disclosure.md`)."
   - "Decision-tagged answers: J (filed to `leadership/{person-slug}-decisions.md`)."
   - "Anything you want to revise before this is final?"

6. **Offer to ingest.** Once the leader confirms, ask: *"Ready to ingest this into the LLMBrain index? That cross-links your file from relevant theme/concept pages so the rest of the kit can cite you."* On yes, hand off to the `ingest` skill on the leader's file.

7. **Log the session.** Append to `~/LLM{{SLUG}}Brain/wiki/log.md`:

   ```
   ## [YYYY-MM-DD HH:MM] interview-executive | {{name}} ({{role}})
   - sections covered: <list>
   - questions answered: N / total M
   - disclosure-tier entries: K
   - decision entries: J
   - leader file: ~/Main{{SLUG}}Brain/leadership/{person-slug}.md
   ```

## Output shape

After a complete CEO interview for a leader named "Alex Smith" (slug: `alex-smith`):

```
~/Main{{SLUG}}Brain/
├── leadership/
│   ├── alex-smith.md                  ← all answers organized by section
│   └── alex-smith-decisions.md        ← decision-tagged answers (subset)
└── policies/
    └── alex-smith-disclosure.md       ← disclosure-tier-tagged answers (subset)
```

The leader's main file (`leadership/{person-slug}.md`) is the canonical
record. The decisions and disclosure files are derived views, useful
because they're addressable individually (e.g., the customer-facing
reviewer-agent reads from `policies/{person-slug}-disclosure.md` to
know what this leader has authorized for public mention).

## Question-bank structure

Every file in `roles/` follows this shape:

```markdown
---
role: ceo | founder | cfo | cmo | sales
sections:
  - <section-1>
  - <section-2>
  - ...
---

## Section: <section-name>

1. "<Question text>" — tag: <none | disclosure_tier | decision>
2. "<Question text>"
...
```

Tags are optional. A question without a tag goes only into the leader's
main file. A question tagged `disclosure_tier` requires the leader to
specify a tier in their answer (`internal`, `internal-leadership`,
`board-only`, `public`); the runtime files the answer to the disclosure
file under the matching tier. A question tagged `decision` files the
answer to the decisions file in addition to the main file.

## Hard rules

- **Never edit the leader's file mid-session.** Append-only as the
  interview proceeds. Edits happen at step 5 if the leader requests them.
- **Never paraphrase the leader.** Their voice is the artifact. Light
  grammar-fix only.
- **Never auto-promote the file from the MainBrain.** This is a MainBrain
  artifact; it's hand-curated, never machine-promoted.
- **Never run more than one role bank in a session.** Founders can also
  hold CEO/CFO hats; that's fine, but interview those roles separately
  on separate days.
- **Always offer pause.** Some questions are heavy (`what kills us`,
  `succession`). The leader can stop and resume; the runtime persists
  partial state.

## What this skill does NOT do

- It does not interview multiple leaders in one session. One session,
  one leader.
- It does not infer answers. A skipped question stays empty in the file
  with `[unanswered: <reason>]` so it can be revisited.
- It does not push answers into other employees' brains. Leadership
  knowledge stays in `~/Main{{SLUG}}Brain/leadership/` until the
  leader explicitly approves a quote or excerpt for a different scope.
- It does not write to `~/LLM{{SLUG}}Brain/` directly other than the
  log entry; the `ingest` skill handles cross-linking.

## Reference

- Sister skill: `pergamino-intake` (interview the operator + principal
  about company shape; runs once before this skill).
- Related role pages: `wiki-templates/thinker.md` (similar shape for
  intellectual influences, but external; this skill targets internal
  leaders).
- The MainBrain layout: `~/Main{{SLUG}}Brain/leadership/`,
  `~/Main{{SLUG}}Brain/policies/`.

This skill turns a one-hour conversation into a structured, citable,
durable record. Done well, it's the most leverage a leader's time
buys in pergamino's first month.
