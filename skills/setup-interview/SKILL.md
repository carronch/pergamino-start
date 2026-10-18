---
name: setup-interview
description: "First-run interview for one person (solo use): ask the author about their businesses, clients, projects, tools, vendors, ventures, research themes, thinkers and boundaries, then customize RESOLVER.md and write one stub page per item into the LLM brain. Use once after install, after a big portfolio change, or when the author says 'set up my brain', 'personalize the vault' or types /setup-interview. For a company deployment use pergamino-intake instead."
---

# Skill: Setup interview — personalize the LLM brain on first run

Run this once, after `install.sh` creates the empty LLM brain. The goal is to turn
a generic kit into the author's own brain: ask about their work, and write their
portfolio into the LLM brain (`$PERGAMINO_LLM_BRAIN`).

This is **not** the soul audit. See "Related skills" at the bottom for the
difference.

## When to invoke

- The first setup, after the install created the empty tree.
- After a significant change (a new business, a portfolio shift, leaving a
  role). Re-runs are cheap: it is an interview, not a migration.
- The author types `/setup-interview` or asks for it.

Do **not** run it automatically during the install. Creating the brain
can repeat safely; the interview cannot. Wait for the author to invoke it.

## Prerequisites

- The LLM brain exists with the tree from the install.
- `RESOLVER.md` is present in the LLM brain (`"$PERGAMINO_LLM_BRAIN/RESOLVER.md"`).
  If it is missing, copy `"$PERGAMINO_HOME/templates/RESOLVER.md"` there first.
- Nothing else is required.

## Steps

### 1. Orient the author

One paragraph, in the author's language:

> "We will spend 10–15 minutes customizing this brain for how *you*
> work. I will ask about your businesses, clients, projects and what you
> research. Then I will write one short page for each thing you mention, so
> that next time you name a client I will know who it is without asking
> again. This is the structure layer only. The deeper 'who are you'
> interview (soul-audit) comes later and writes to a different place."

Wait for a go-ahead before you start.

### 2. Ask about Operating

Ask each question. Listen. Capture aliases when the author mentions them.

**Businesses** (entities they operate: legal status, accounting, operations):
> "Which businesses do you operate right now? For each one, tell me the
> name, whether it is active or paused, and one sentence about what it
> does. If you are not sure whether something is a business or a venture,
> say so. I will help you decide."

If nothing is operational: skip to Clients.

**Clients** (if they run a services business):
> "Who are your current clients? Name, status, and what you do for them."

If they do not run services: skip.

**Projects** (work that ships, inside a business or for a client):
> "What are you building or delivering right now? For each, which business
> or client is it for?"

**Tools** (external software they work inside every week):
> "Which software do you rely on? I do not need a full list: only
> the 3–5 things you would miss most if they disappeared."

**Vendors** (paid services and dependencies):
> "Whom do you pay monthly or yearly? Cloud, infrastructure, subscriptions:
> only the ones that matter."

### 3. Ask about Exploring

**Ventures** (business ideas not yet committed):
> "Are there ideas you are turning over without a commitment? Things you
> would like to build, a business you have considered, a partnership
> you are evaluating?"

For each venture, capture the commit-or-kill criteria:
> "What would make you commit to this? What would make you kill it?"

### 4. Ask about Research

**Themes** (long-running threads):
> "What are you deepening your understanding of right now? Topics you return
> to, books you stack, people whose work you track? For each, tell me if
> it is **work** (feeds your businesses), **interest** (pure curiosity)
> or **teaching** (producing output for others)."

**Thinkers** (intellectual influences):
> "Whose thinking do you return to? Not contacts: people whose published
> work shapes how you see things."

Thinker pages also seat the `convene-the-board` panel, so ask which 3–8 thinkers the author would want on an advisory panel.

### 5. Ask about Boundaries

> "What should the agent **not** touch without asking?"
> "What should the agent **never** bring up unless you ask for it?"

Common answers: finances, health, family names, specific clients by name
in summaries. Write these into `personal/access-notes.md` in the LLM brain.

### 6. Customize RESOLVER.md

Based on the answers, edit `RESOLVER.md` in the LLM brain:

- **Remove categories the author does not need.** A researcher might not have
  `businesses/` or `clients/`. A business owner without services might
  not have `clients/`. A student might not have any operating section.
- **Rename if the author's language differs.** A lawyer's "clients" might be
  "matters". A designer's "projects" might be "engagements". The taxonomy
  is scaffolding, not a cage.
- **Point at the canonical slug list** in `personal/my-portfolio.md` (step 7).

Present the proposed edits as a diff. Wait for approval before you write.

### 7. Write the portfolio and the stub pages

First write `personal/my-portfolio.md`: one section per kind, one row per item
(slug, name, aliases, status, one line). Agents consult this file before they
invent a name.

Then, for each item, create a stub wiki page through `skills/enrich/SKILL.md`, with
the matching template from `"$PERGAMINO_HOME/wiki-templates/"`:

- Business → `wiki/businesses/<slug>.md` from `business.md`
- Client → `wiki/clients/<slug>.md` from `business.md`, with `kind: client`
- Project → `wiki/projects/<slug>.md` from `project.md`
- Venture → `wiki/ventures/<slug>.md` from `venture.md`
- Tool → `wiki/tools/<slug>.md` from `tool.md`
- Vendor → `wiki/vendors/<slug>.md` from `tool.md`, with `kind: vendor`
- Theme → `wiki/themes/<slug>.md` from `theme.md`
- Thinker → `wiki/thinkers/<slug>.md` from `thinker.md`

Each stub gets:
- Frontmatter filled from the interview.
- A one-paragraph compiled-truth section based on what the author said.
- A timeline entry: `- YYYY-MM-DD: [source: the author, setup-interview] Captured during setup-interview.`

Do **not** add detail beyond what the author said. A 30-word page is better than
a plausible fiction.

For each active project, offer a work card: `wiki/workblocks/YYYY-MM-DD-<slug>.md`
from `"$PERGAMINO_HOME/templates/workblock.md"`. One card per project.

### 8. Rebuild the index

```bash
bash "$PERGAMINO_HOME/scripts/rebuild-index.sh" "$PERGAMINO_LLM_BRAIN"
```

Append one entry to `wiki/log.md`:

```
## [YYYY-MM-DD] setup-interview
- pages written: N (businesses N, clients N, projects N, ...)
- RESOLVER.md: <categories removed or renamed>
- boundaries: personal/access-notes.md
```

### 9. Report back

Show the author:
- How many pages you wrote, by kind.
- The updated `RESOLVER.md` tree.
- What they may want to cover in a soul audit later.

Keep the report under 15 lines. They just spent 15 minutes talking to you.
They do not want a wall of text now.

## Rules

- **Never invent content.** Every fact in every stub page comes from
  what the author said, verbatim or closely paraphrased. No filler.
- **Never write to the Main brain.** Only `soul-audit` writes there, and only
  when the author invokes it.
- **Ask again rather than guess.** If a slug is ambiguous (is
  it a project slug or the business slug?), ask.
- **Do not skip the boundaries.** Step 5 is easy to skip and expensive later.
- **Stop if the author is tired.** 10–15 minutes is the target; 25 or more is
  too long. Offer to resume another day, and save what you captured so far.
- **More than 15 pages:** state the count and the list before you write them.

## Related skills

- **`soul-audit`**: writes to the Main brain (principles, beliefs, life-level
  decisions, the author's reads on people, a heartbeat). It runs after
  setup-interview, not before. A different brain, different permissions,
  a different frequency (yearly and monthly, compared with once).
- **`pergamino-intake`**: the interview for a **company deployment**. It
  produces a scope plan for a team's brains before provisioning. Use it, not this
  skill, when the brain serves a company rather than one person.
- **`skills/enrich/`**: called by `ingest` when it creates or updates wiki
  pages. This skill also produces wiki pages through it, but in bulk, from a
  structured interview, not from an ingested source.
- **`skills/research/`**: deepens themes *after* setup. This skill
  only names them.

The agent never assumes the author's portfolio. It asks.
