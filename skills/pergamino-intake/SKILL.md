# Skill: pergamino-intake

> First-principles interview that produces a per-client scope plan. Run this before `pergamino-deploy new` provisions any infrastructure.

## When to invoke

Trigger phrases (Daniel runs this):
- "Run the pergamino intake for `<client>`"
- "Set up a new pergamino client" (you ask for the slug, then run intake)
- "Plan the brain structure for `<client>`"

## Why this skill exists

Every client has a different shape. Hospitality has `sales / operations / finance / customer-facing`. Real-estate has `agents/<each> / transactions / legal`. A solopreneur has `self / clients/<each> / business`. **Don't hard-code one structure.** The intake produces a YAML scope plan that drives provisioning.

Output: `~/Documents/GitHub/pergamino-deployments/<client-slug>/intake.yaml` (or wherever Daniel keeps client deployment configs).

## The interview — 8 questions

You (the LLM running this skill) ask Daniel and the client's principal in sequence. Don't batch. Each answer informs the next question. Adapt phrasing per client.

### Q1 — Unit of analysis

> *Roughly how many people will use the brain? Just you? Two-to-four cofounders? A small team of 5–25? Mid-size 25–100?*

Map their answer:
- 1 → `unit: solopreneur`
- 2–4 → `unit: partnership`
- 5–25 → `unit: small`
- 26–100 → `unit: mid`
- 100+ → `unit: enterprise` — pause, this is outside pergamino's current SKU; flag for Daniel

### Q2 — Vertical

> *What does the company actually do? Pick the closest:*
> *— Hospitality (lodge, hotel, restaurant)*
> *— Real estate (residential, commercial, brokerage)*
> *— Marketing/creative agency*
> *— Retail (physical or e-com)*
> *— SaaS or software product*
> *— Professional services (consulting, legal, accounting)*
> *— Other (describe in your own words)*

If "Other" — capture a 1-sentence description and treat as a new vertical. The variable reviewer-agents will need fresh tuning.

### Q3 — Customer-facing reality

> *How does this business interact with its customers? Three rough shapes:*
> *(a) High-volume B2C — constant inbound stream of inquiries, mostly repeat questions*
> *(b) Few B2B clients — named relationships, complex back-and-forth, lower volume*
> *(c) Internal-only — no external customer surface; this brain is for the team's own work*

Map to:
- (a) → `customer-facing: high-volume-b2c` — concierge bot is in scope
- (b) → `customer-facing: low-volume-b2b` — customer-facing scope exists but no automated bot
- (c) → `customer-facing: none` — no customer-facing scope at all

### Q4 — Decision shape

> *Who actually decides things in this company day-to-day?*
> *(a) Single principal — one founder/CEO who calls most shots*
> *(b) Co-founders — 2–3 equal decision-makers*
> *(c) Principal + dept heads — CEO with operations / finance / sales heads*
> *(d) Multiple equal partners — partnership of 4+ peers*

This determines:
- Who's the "principal scope" (named `ceo/`, `founder/`, `owner/`, or `partners/<each>/`)
- Who reviews cross-scope PRs (single CEO vs co-founder co-sign vs dept-specific routing)
- Whether `<principal>/` is one folder or split per partner

### Q5 — Current breakage

> *What's currently painful that you want pergamino to fix? Be specific. "Knowledge management" doesn't count — what concretely breaks today?*

Capture verbatim. This is the **success metric** — the 90-day review benchmark Daniel will reference. Examples that count:
- "Our finance head spends 4 hours/week answering the same questions"
- "Customer service inbox has 200 unanswered messages"
- "When someone leaves, all their context goes with them"
- "Three different versions of the playbook exist; nobody knows which is canon"

If the answer is vague, push back: *"Can you give me a specific example from last week?"*

### Q6 — Compliance posture

> *Any regulated data here? Medical (HIPAA), financial (PCI/SOX), legal-privilege, EU-data (GDPR), other?*

Map to:
- None → `compliance: standard`
- Medical → `compliance: hipaa` — pause; pergamino's SOC 2 story is not yet there
- Financial card data → `compliance: pci` — same caution
- Legal privilege → `compliance: legal` — append-only paths get tighter; no LLM training exposure
- GDPR (EU users) → `compliance: gdpr` — data-residency questions matter

### Q7 — Tech-comfort spectrum

> *On a scale of who-uses-what:*
> *(a) Mostly comfortable with terminal / git / CLI tools*
> *(b) Comfortable with web apps, not terminal*
> *(c) WhatsApp / phone-first; terminal is a foreign country*
> *(d) Mixed — some of each*

Map to:
- (a) → `tech-comfort: cli-native` — Claude Code in folder is the daily UX
- (b) → `tech-comfort: web` — the web chat fallback is the primary UX; terminal optional for power users
- (c) → `tech-comfort: messaging` — WhatsApp-only access; even web chat is secondary
- (d) → `tech-comfort: mixed` — both surfaces; let users self-select

### Q8 — Knowledge-work distribution

> *Who in the company actually creates knowledge that others need to read?*
> *(a) Concentrated — a few people (CEO + heads) write; everyone else reads*
> *(b) Collaborative — most employees write knowledge*
> *(c) Project-shaped — knowledge lives per-engagement (each client/project is its own world)*
> *(d) Solo — only you*

Determines:
- Promotion volume (concentrated = fewer PRs; collaborative = more)
- Whether per-project sub-scopes exist (`projects/<each-engagement>/`)
- Heartbeat cadence (more writers = daily nudges; fewer = weekly)

## Output: the scope plan

After all 8 answers, you generate the scope plan as YAML. Show it to Daniel + the client principal. They review and tweak. Then save to disk.

```yaml
# Generated by pergamino-intake on <date>
# Reviewed by: <daniel + principal-name>

client: <slug>
client_display: <Display Name>
intake_date: <YYYY-MM-DD>

unit: <solopreneur | partnership | small | mid>
vertical: <hospitality | real-estate | agency | retail | saas | professional-services | other>
vertical_note: <only if other; 1-sentence description>

customer_facing: <high-volume-b2c | low-volume-b2b | none>
decision_shape: <single-principal | co-founders | principal-plus-heads | multiple-partners>
breakage:
  - <verbatim from Q5; the success metric>
compliance: <standard | hipaa | pci | legal | gdpr | combination>
tech_comfort: <cli-native | web | messaging | mixed>
knowledge_distribution: <concentrated | collaborative | project-shaped | solo>

# === Scopes (the folder structure) ===
scopes:
  universal:
    - company             # always
    - <principal-name>    # named per client (ceo / founder / owner / partners-<X>)
    # customer-facing only if Q3 != "none"
    # - customer-facing
  variable:               # filled per vertical + decision_shape
    - <scope-1>
    - <scope-2>
    # ...

# === Reviewers (CODEOWNERS routing) ===
reviewers:
  company: <list>
  customer-facing: <list>
  <each variable scope>: <list>
  <principal scope>: self  # always self for the principal

# === Append-only paths ===
append_only:
  - <list of paths per vertical's risk profile>

# === Heartbeat schedule ===
heartbeat:
  user_nudge: <time> local, <weekday-pattern>, <channel>
  reviewer_digest: <time> local, <weekday-pattern>, <channel>
  customer_bot_weekly: <time + day>  # only if customer-facing != "none"
  timezone: <IANA timezone>
  default_channel: <whatsapp | email | web-only>

# === Surfaces ===
surfaces:
  cli: <true if tech_comfort includes cli>
  web_chat: <true if tech_comfort includes web or messaging>
  whatsapp_internal: <true if tech_comfort includes messaging or vertical = hospitality>
  whatsapp_concierge: <true if customer_facing == "high-volume-b2c">

# === First cohort (the 90-min onboarding) ===
first_cohort:
  - email: <ceo-email>
    role: principal
    name: <name>
  - email: <head-email>
    role: <head-of-X>
    name: <name>
  # 2–3 more

# === Success metric ===
success_metric: |
  <Daniel + principal write this together>
  At 90 days, success looks like: <verbatim, specific, measurable>
```

## Mappings — vertical to scope template

The intake skill consults this table when proposing the `scopes.variable` list:

| vertical | typical variable scopes |
|---|---|
| hospitality | sales · operations · finance |
| real-estate | agents/<each> · transactions · legal |
| agency | clients/<each> · team · ops · finance |
| retail | products · sales · operations · finance |
| saas | product · engineering · go-to-market · finance |
| professional-services | clients/<each> · business · learning |
| solopreneur | self · business · clients/<each> |
| other | <ask the principal directly> |

Override per the decision_shape:
- `multiple-partners` → instead of single `<principal>/`, create `partners/<name>/` per partner; everyone has read on company
- `solopreneur` → most variable scopes collapse; `self/` becomes the working brain; canon is sparse

## Mappings — vertical to append-only paths

| vertical | append-only paths |
|---|---|
| hospitality | finance/reports · finance/audit-trail.md · operations/incidents · customer-facing/policies · decisions |
| real-estate | transactions/closed · finance/reports · legal/contracts · decisions |
| agency | clients/<each>/contracts · finance/reports · decisions |
| retail | finance/reports · operations/incidents · decisions |
| saas | finance/reports · product/decisions · operations/incidents · security/audits |
| professional-services | clients/<each>/contracts · finance/reports · decisions |
| solopreneur | business/contracts · business/finance/reports · decisions |

## Common patterns to detect (and act on)

- **"It's me + my assistant"** → solopreneur with one helper; treat as solopreneur but add `assistant/` as a variable scope.
- **"We're three cofounders, but really I run product, she runs ops, and he handles sales"** → decision_shape is principal-plus-heads disguised as co-founders; treat as latter.
- **"We don't really have departments"** → small/partnership unit, no variable scopes; everything goes in company/.
- **"Half our team is on WhatsApp, half on Slack"** → tech-comfort mixed; surfaces include both; don't force-pick.

## What this skill does NOT do

- Does not provision infrastructure. That's `pergamino-deploy new` reading the YAML this skill produces.
- Does not write the AGENTS.md library. Templates exist; per-scope tuning happens after intake based on the YAML.
- Does not interview employees individually. Only the principal + Daniel. Other employees onboard via the rollout, not the intake.

## After the interview

Save the YAML. Then:

```sh
pergamino-deploy new <client-slug> --intake-yaml <path>
```

The deploy CLI reads the scope plan and provisions:
1. GitHub `brain-canon` repo with the scope folders + CODEOWNERS from the YAML
2. CouchDB on fly.io for LiveSync
3. Tailscale tailnet
4. Cloudflare Tunnel + Access with policies matching the scope routing
5. Heartbeat Worker (deployed to client's Cloudflare account) with cron triggers from the YAML
6. AGENTS.md library customized per scope
7. The Pergamino launcher (Mac .app / Windows .exe / Linux .desktop) for users
8. The first-cohort onboarding emails

## Reference

- Sister skill: `setup-interview` (Daniel's personal vault setup; this skill is its client-facing twin)
- Output consumed by: `pergamino-deploy` CLI (sketch in `wiki/syntheses/pergamino-deployment-playbook.md`)
- Reviewer-agent library that gets customized: `wiki/syntheses/pergamino-reviewer-agents/`
