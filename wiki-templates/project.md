---
kind: project
title: "{{title}}"
business: ""                 # slug of parent business, e.g. "{{ENTITY_EXAMPLE_1}}"
status: active | paused | shipped | abandoned
started: {{date}}
created: {{date}}
updated: {{date}}
stack: []
tags: []
---

# {{title}}

> One paragraph. What this project is, current status, what "done" would
> look like. If you read only this, you know whether to pick it up again
> today.

## State

- **Status:** active | paused | shipped | abandoned
- **What:** one-line description
- **Stage:** exploration | building | shipped | maintenance
- **Stack:** (Cloudflare Workers, Astro, D1, etc.)
- **Repo:** (link)
- **Deploy:** (URL if live)
- **Last meaningful work:** YYYY-MM-DD

## Current focus

What you're working on right now. Short, concrete. Update when it changes.

## Architecture

Key technical or strategic approach. Include a sketch (Mermaid or prose) of
how the pieces fit. Update when the architecture shifts, not on every
change.

## Key decisions

Link to ADRs in `wiki/decisions/` that shaped this project:

- [[decisions/YYYY-MM-DD-slug]] — one-line what it decided

If you find yourself re-explaining a choice in multiple places, it
probably deserves its own ADR.

## Tools in use

- [[tools/...]] — how it's used here
- [[tools/...]]

## Concepts it embodies

- [[concepts/...]]

## Open threads

Unresolved questions, blockers, decisions pending, things you owe the
project. Removed when resolved (move to Timeline with a resolution note).

## Related syntheses and sources

- [[syntheses/...]] — relevant analyses
- [[summaries/...]] — sources that informed decisions

---

## Timeline
_Append-only. Build log in reverse-chronological order. Every meaningful
session, decision, ship, or pivot goes here._

- **{{date}}** | Project page created.
