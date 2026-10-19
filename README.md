# pergamino — a two-brain setup for your AI agent

A knowledge system that your agent keeps for you, in plain Markdown. One brain is yours: beliefs, principles, decisions. The other brain is the agent's: sources, a curated wiki, and one card per project. The agent reads yours and writes only its own. It works with Claude Code, Codex CLI, Cursor and other command-line agents.

> *I will give you two scrolls. One for your own use, and one as the brain that gives your LLM context.*

## What you get

- **Rules the agent follows** (`AGENTS.md`): search before claiming, cite every claim, compiled truth above a dated timeline, one home per fact, a card per project, and corrections that become rules.
- **Skills** (`skills/`): bring sources in, ask the brain, keep it healthy, deepen a theme, review code with a second model, turn repeated mistakes into checks.
- **Guards** (`hooks/`, Claude Code): block secret files, refuse destructive shell commands, stage DNS changes, treat captured web text as untrusted, and remind the agent to update its cards.
- **Scripts** (`scripts/`): rebuild the wiki index, promote a proposal into your brain, digest the cards, map the links.

Everything is Markdown and shell. No app, no service, no account.

## Install

```sh
curl -fsSL pergamino.ai/install | bash
```

This checks for `git`, clones the kit to `~/Pergamino`, runs `install.sh`, and installs Claude Code if no agent is present. Choose another agent with `PERGAMINO_LLM=aider | gemini | none`.

Or by hand:

```sh
git clone https://github.com/carronch/pergamino-start ~/Pergamino
cd ~/Pergamino && bash install.sh
```

`install.sh` asks where the two brains live (defaults: `~/MainBrain` and `~/LLMBrain`; an older install's `~/Main<Name>Brain` folders are found automatically). It writes the answer to `pergamino.local.env`, creates the folders, registers the two search collections (`main` and `llm`) if [qmd](docs/search-setup.md) is installed, and links the skills for every host. Run it as often as you like: it creates only what is missing.

Then:

```sh
cd ~/Pergamino
claude            # or codex, cursor-agent, gemini, aider
```

| You are | First command |
|---|---|
| One person, starting fresh | `/setup-interview` |
| A company of 5–50 people | `/pergamino-intake`, then `/interview-executive` for each leader |
| Someone who already has an agent setup | `/adopt-pergamino` — it merges the kit into your own rules files, skills and hooks without losing yours |

## Update

```sh
git -C ~/Pergamino pull && bash ~/Pergamino/install.sh
```

The kit never edits its own tracked files for you, so `git pull` always works. Your settings live outside them:

| File | Holds | Committed |
|---|---|---|
| `pergamino.local.env` | The paths of your two brains | No |
| `AGENTS.local.md` | Your own rules: language, tone, tools. They win over `AGENTS.md` on preferences | No |
| `.claude/settings.local.json` | Your own Claude Code settings and hook changes | No |

## Architecture

```
~/Pergamino/                     ← the kit: rules, skills, hooks, scripts (git clone)
├── AGENTS.md                    ← rule of the house; CLAUDE.md links here
├── SCHEMA.md                    ← page types and frontmatter
├── RESOLVER.md                  ← where each new file goes
├── skills/                      ← .claude/skills and .agents/skills link here
├── hooks/  scripts/  agents/  templates/  wiki-templates/  obsidian-templates/

<Main brain>/                    ← PERGAMINO I — yours (the agent only reads)
├── beliefs/  principles/  life-decisions/  people/  heartbeats/

<LLM brain>/                     ← PERGAMINO II — the librarian's
├── inbox/  Clippings/           ← captures, untrusted until you confirm
├── raw/                         ← immutable sources
├── wiki/                        ← summaries, concepts, themes, thinkers, tools, projects
│   └── workblocks/              ← one card per project: status, plan, dated timeline
├── reminders/  lessons.md
└── outputs/mainvault-pending/   ← the tray: proposals back to you
```

The two brains talk through one tray. When the agent has something for your brain, it stages a file in `outputs/mainvault-pending/` with a `<!-- target: … -->` first line. You decide, then run `scripts/promote-to-mainvault.sh` or copy it by hand.

Open both brains in [Obsidian](https://obsidian.md) if you like: graph view, mobile capture, and the Web Clipper into `Clippings/`. The system works without it.

## Skills

| Group | Skills |
|---|---|
| Bring sources in | `ingest`, `deep-ingest` (a URL plus a short research pass), `video-to-card`, `ingest-meeting` |
| Ask the brain | `query`, `convene-the-board` (a panel of the thinkers in your wiki), `teach` |
| Keep it healthy | `lint`, `maintain`, `enrich`, `triage-cards` |
| Deepen | `research`, `autoresearch` |
| Always on | `truth-aware`, `karpathy-discipline` |
| Set up | `setup-interview`, `pergamino-intake`, `interview-executive`, `soul-audit`, `adopt-pergamino` |
| Work and code | `review-pr`, `blast-radius`, `benchmark-checklist`, `retro`, `correct`, `visualize-work`, `prompt-style`, `writing-for-agents` |

Each skill is `skills/<name>/SKILL.md`. Read one before you run it; the "Requires" list names the tools it needs.

## Guards

On Claude Code, `.claude/settings.json` wires the hooks in `hooks/`. On other hosts, the same rules are prose in `AGENTS.md`. `hooks/README.md` lists each hook, its event, and how to turn it off in `.claude/settings.local.json`. The tests run with `bash hooks/<name>.test.sh` and touch only temporary folders.

## For a company

The kit also supports a 5–50 person deployment: one brain per scope (company, principal, sales, operations, finance, customer-facing), reviewer prompts for each scope, and a heartbeat Worker. See `templates/agents-md-library/`, `templates/reviewer-agents/`, `heartbeat-worker/README.md` and `pergamino-deploy/` (it reads the `/pergamino-intake` output and provisions repositories, access, sync and billing; the server steps wait for a hosting choice).

## Build it yourself instead

The repository also carries paste-and-go build specifications. Paste one as the first message to an agent on a fresh machine; it interviews you and builds a two-vault system phase by phase, without the kit. The kit is the maintained path; these are the earlier design.

- [`brain-setup-prompt-en.md`](./brain-setup-prompt-en.md) — English
- [`brain-setup-prompt-es.md`](./brain-setup-prompt-es.md) — Español (voseo)
- [`brain-setup-prompt-team-newsroom-es.md`](./brain-setup-prompt-team-newsroom-es.md) — Team Edition for a shared newsroom brain (one vault, git-driven sync, a hard block on `fuentes-confidenciales/`)

## Your first inscription

Open your Main brain's `beliefs/` folder and write `why-pergamino.md`: three sentences in your own voice. Why are you doing this? That is the first thing your librarian will read.

## License

**Pergamino License v1.0** — see [`LICENSE`](./LICENSE).

- **Personal use:** free for individuals running their own brain.
- **Commercial use:** USD $100 per User per year. A "User" is anyone with access to a brain provisioned with this kit, or who receives its outputs as part of their work.
- **30-day free evaluation** for prospective commercial deployments.
- Commercial licensing inquiries: `licensing@pergamino.ai`.

## Brand

Pergamino is named for **Pergamon**, the ancient Greek city whose library held two hundred thousand scrolls and whose rivalry with Alexandria perfected a more durable substrate when papyrus was cut off. The library is gone. The word survives.

In an age of unlimited cheap AI-generated text, the act of choosing what to keep is the work. Pergamino is the substrate where serious thinkers compound their knowledge: built by humans, maintained by AI, designed to outlast the conversations it captures.

— [pergamino.ai](https://pergamino.ai)
