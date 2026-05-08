---
kind: business
title: "{{title}}"
aliases: []
legal_entity: ""
status: active | paused | closed
stage: pre-launch | operating | maturing | winding-down
started: YYYY-MM-DD
created: {{date}}
updated: {{date}}
tags: []
---

# {{title}}

> One paragraph. What this business is, its current state, why it
> matters. If you read only this, you know whether it needs your
> attention today.

## State

- **Legal entity:** (S.A. name, or "not yet incorporated")
- **Status:** active | paused | closed
- **Stage:** pre-launch | operating | maturing | winding-down
- **Model:** (how it makes money, in one line)
- **Key metric:** (the one number that tells you it's healthy)
- **Last meaningful update:** YYYY-MM-DD

## What it is

What the business does, who it serves, how it makes money. Keep to a
paragraph or two. Link to concept pages for the underlying business
models if relevant.

## Operations

How it runs day-to-day. Key workflows, recurring tasks, seasonality,
cadences. Don't re-document tools already linked below — describe
*what happens*, not what runs it.

## Stack

Tools this business depends on:

- [[tools/...]] — how it's used
- [[tools/...]]

## Key properties / products / services

Concrete assets: specific storage units, properties, SKUs, services.
Not exhaustive inventory — just what you'd want to recall fast.

## Active projects

Projects tagged to this business (queried via Dataview in Obsidian):

```dataview
LIST
FROM "wiki/projects"
WHERE business = this.file.name
AND status = "active"
```

Or hand-list them if not using Dataview:

- [[projects/...]]
- [[projects/...]]

## Open decisions

- [[decisions/YYYY-MM-DD-...]]

## Relevant research themes

Research threads that bear on this business:

- [[themes/...]]

## Accounting & legal notes

Not full books. A pointer to wherever the real accounting lives, plus
anything you need to remember: fiscal year, tax structure, key legal
obligations, standing agreements.

## Key people

Names only, with a note that real context lives in truth:

- Partner/employee/vendor name — role. _See Main{{SLUG}}Brain `people/` for
  actual read._

## Open threads

Operational items pending. Removed when resolved (move to Timeline).

---

## Timeline
_Milestones, pivots, major operational events. Append-only._

- **{{date}}** | Business page created.
