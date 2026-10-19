---
type: workblock
title: "{{title}}"
slug: {{slug}}
date: {{date}}                 # the day the card was created; the file name starts with it
updated: {{date}}              # bump it on every change to status: or status_note:
tags: [workblock]
status: active                 # active | waiting-for | someday-maybe | done (the kanban lane)
status_note: "{{one or two sentences, about 300 characters: where the card stands and what comes next. Current state only; history goes to the Timeline.}}"
---

<!--
How to use this card (delete this comment when you fill the card in):

- File it at wiki/workblocks/YYYY-MM-DD-<slug>.md in the LLM brain. One card per project or plan;
  new work inside a project goes on its existing card.
- Lanes are the status: field, with Getting Things Done names. Move a card by editing status:
  (and updated:). Prose goes in status_note:, never in status:.
    active         work in progress
    waiting-for    blocked on someone or something outside this session
    someday-maybe  a finished plan that is not executing yet
    done           finished; the card stays as the record
- status_note: holds the current state only, about 300 characters. Every session that reads the
  card or the kanban loads it, so keep it short. History goes to the Timeline.
- Next actions are checkbox items. Tag an item #author only if the author alone can do it
  (decide, sign, pay, call, go somewhere). Every untagged item is agent work.
- Write each item as a concrete next physical action that the author could start in 30 seconds
  ("Find the latest invoice in email", not "Pay the invoice"). Write names in full, with no
  project-internal abbreviations: cards are read cold, weeks later, on a phone.
- A session that advances the card updates it in the same session: status:, status_note:, and a
  dated Timeline entry (newest first). Check boxes as items complete; do not delete items.
- The card holds the plan and the timeline. Facts about how a system works live on their wiki
  page; link to that page instead of restating it.
-->

# {{title}}

> One or two lines: what this project or plan is, and why it matters. Link the pages that hold
> its facts: [[wiki/projects/<slug>]], [[wiki/businesses/<slug>]].

## Goal

What "done" looks like, in one to three sentences. Make it checkable.

## Plan

1. Step one.
2. Step two.
3. Step three.

## Next actions

- [ ] A concrete next physical action for an agent.
- [ ] A concrete next physical action that only the author can take. #author

## Decisions and constraints

Settled choices and steering instructions from the author that must outlive the session.

- YYYY-MM-DD: <decision or instruction>. <one line on why>.

## Lessons

Corrections that belong to this project only. Rules for every session go to `lessons.md` in the LLM brain.

<!-- timeline -->
## Timeline

- {{date}}: [source:<chat | file | meeting>] Card created. <one line of context>.
