# pergamino — client-brain onboarding kit

A two-vault knowledge system that interviews your leadership and turns
their answers into a queryable organizational brain. Plain Markdown all
the way down.

> *I will give you two scrolls. One for your own use, and one as the brain that gives your LLM context.*

## Two deployment shapes

This kit supports two shapes:

### Solo (single user, single machine)

For a solopreneur or a CEO running their own brain. Install and configure
in 30 minutes.

  1. `git clone https://github.com/{{ORG}}/pergamino-start ~/Pergamino`
  2. `cd ~/Pergamino && bash install.sh`
  3. Open `claude` (or `aider`/`gpt`/`gemini`) in this folder.
  4. Run `/pergamino-intake`. Answer the interview as the operator.
  5. The kit creates `~/Main{{SLUG}}Brain/` and `~/LLM{{SLUG}}Brain/`.
  6. Run `/interview-executive --person {{name}}` for any leader you
     want captured. Their answers populate the brain.

### Multi-user (5–50 person company)

Full client deployment with the heartbeat Worker, GitHub teams,
Cloudflare Access. See `heartbeat-worker/README.md` and the
deployment playbook for the provisioning flow. (The CLI
`pergamino-deploy` automates this; until built, follow the manual
steps in `heartbeat-worker/README.md`.)

## What's in the kit

- **11 skills** under `skills/`:
  - Ingestion: `ingest` · `deep-ingest`
  - Querying: `query`
  - Health: `lint` · `maintain`
  - Identity: `enrich`
  - Research: `research`
  - Discipline: `truth-aware` · `karpathy-discipline`
  - Setup: `pergamino-intake`
  - Capture: `interview-executive`
- **11 wiki templates** (business, project, decision, theme, thinker,
  concept, mental-model, summary, tool, venture, journal)
- **7 obsidian templates** (daily, dashboard, GTD-dashboard, inbox,
  project, solution, weekly-review)
- **6 AGENTS.md scope templates** for client-brain rules-of-the-house
  (company, customer-facing, principal, sales, operations, finance)
- **9 reviewer-agent prompts** for the heartbeat Worker (universal
  base + 7 scope-specific reviewers + cross-scope layer)
- **2 subagents** (reviewer, security) for code-review hygiene
- **The heartbeat Worker template** (per-client Cloudflare Worker)

The substrate is Markdown all the way down. No proprietary format, no
app, no SaaS.

## Architecture in one screen

```
~/Main{{SLUG}}Brain/                     ← PERGAMINO I — your truth zone
├── beliefs/                            (you write; the LLM only reads)
├── principles/
├── life-decisions/
└── leadership/                         ← /interview-executive populates this

~/LLM{{SLUG}}Brain/                      ← PERGAMINO II — librarian's brain
├── raw/                                (immutable sources)
├── wiki/                               (curated catalog the LLM keeps)
└── outputs/mainvault-pending/          ← the tray (proposals back to you)

[this kit's folder]                     ← the rules cascade
├── AGENTS.md                           ← rule of the house
├── CLAUDE.md                           ← schema
├── RESOLVER.md                         ← routing
├── skills/
├── wiki-templates/
├── obsidian-templates/
├── agents/                             ← code-review subagents
├── templates/
│   ├── agents-md-library/              ← per-scope rules of the house
│   ├── reviewer-agents/                ← per-scope PR reviewers
│   └── RESOLVER.md
└── heartbeat-worker/                   ← per-client CF Worker template
```

## Use

After install + `/pergamino-intake`:

```sh
cd ~/Pergamino
claude          # or 'gpt', 'gemini', 'aider', or any CLI LLM
```

Your LLM reads `CLAUDE.md` and `AGENTS.md` automatically and learns the
two-pergaminos discipline — that it can read the MainBrain but never
write there, that the LLMBrain is its catalog, that proposals back to
you go in the tray.

For your **first session**, paste the contents of
[`prompt-for-llm.md`](./prompt-for-llm.md) into your first message.
It bootstraps the librarian with starter context.

## Your first inscription

Open `~/Main{{SLUG}}Brain/beliefs/` and write `why-pergamino.md`. Three
sentences in your own voice. Why are you doing this?

That's the first thing your librarian will see. The brain starts there.

## Where to go next

- **Read the manual** at [pergamino.ai](https://pergamino.ai). It
  explains the architecture (the rules cascade, the two pergaminos,
  why markdown is the librarian's mother tongue).
- **Bring sources to the librarian.** Drop an article URL or a PDF
  into a chat with your LLM and ask it to *ingest* it. One source
  touches ten to fifteen pages in your wiki. The substrate compounds.
- **Capture leadership knowledge.** Run `/interview-executive --role ceo`
  (or `--role founder`, `cfo`, `cmo`, `sales`) to extract what your
  leaders carry in their heads.
- **Invite teammates.** Each teammate gets their own MainBrain or
  shares a scope of the company brain. The team can share an
  LLMBrain. Many scribes, one library.

## License

MIT. See [`LICENSE`](./LICENSE).

## Brand

Pergamino is named for **Pergamon** — the ancient Greek city whose
library held two hundred thousand scrolls and whose rivalry with
Alexandria perfected a more durable substrate when papyrus was cut
off. The library is gone. The word survives.

In an age of unlimited cheap AI-generated text, the act of choosing
what to keep is the work. Pergamino is the substrate where serious
thinkers compound their knowledge — built by humans, maintained by
AI, designed to outlast the conversations it captures.

— [pergamino.ai](https://pergamino.ai)
