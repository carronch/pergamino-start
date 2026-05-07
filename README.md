# Pergamino — Starter Kit

> *I will give you two scrolls. One for your own use, and one as the brain that gives your LLM context. Open this folder in the CLI to start your day's work, and your knowledge — and your teammates' knowledge — compounds with every session.*

This is the bootstrap kit for [pergamino.ai](https://pergamino.ai) — a brain system you run on your own machine, in plain markdown, with any LLM you choose as your librarian.

## What you get

- **Two pergaminos.** Two folders — `~/MainVault/` (the author's brain — *only you* write here) and `~/LLMVault/` (the librarian's brain — your LLM tends this).
- **A rules folder.** `AGENTS.md`, `CLAUDE.md`, and `RESOLVER.md` — three plain markdown files your LLM reads at the start of every session.
- **Five essential skills.** `ingest`, `deep-ingest`, `query`, `lint`, `maintain` — small instruction manuals your librarian follows.
- **One install command.** Three lines, ten seconds.

The substrate is markdown all the way down. No proprietary format, no app, no SaaS. Open the folder in any text editor in 2026, in 2046, or in 2126 — it still works.

## Install

```sh
git clone https://github.com/carronch/pergamino-start ~/Pergamino
cd ~/Pergamino
./install.sh
```

That's the whole setup. The script creates `~/MainVault/` and `~/LLMVault/` with starter folders, leaves the rules in this directory where your LLM will read them, and prints next steps.

## Use

After install, start your LLM from inside this folder:

```sh
cd ~/Pergamino
claude          # or 'gpt', 'gemini', 'aider', or any CLI LLM
```

Your LLM reads `CLAUDE.md` and `AGENTS.md` automatically and learns the two-pergaminos discipline — that it can read MainVault but never write there, that LLMVault is its catalog, that proposals back to you go in the tray.

For your **first session**, paste the contents of [`prompt-for-llm.md`](./prompt-for-llm.md) into your first message. It bootstraps the librarian with starter context.

## Your first inscription

Open `~/MainVault/beliefs/` and write `why-pergamino.md`. Three sentences in your own voice. Why are you doing this?

That's the first thing your librarian will see. The brain starts there.

## Where to go next

- **Read the manual** at [pergamino.ai](https://pergamino.ai). It explains the architecture (the rules cascade, the two pergaminos, why markdown is the librarian's mother tongue).
- **Bring sources to the librarian.** Drop an article URL or a PDF into a chat with your LLM and ask it to *ingest* it. One source touches ten to fifteen pages in your wiki. The substrate compounds.
- **Invite teammates.** Each teammate gets their own MainVault. The team can share an LLMVault. Ten scribes, one library.

## Layout

```
pergamino-start/
├── README.md              # this file
├── install.sh             # the install script
├── prompt-for-llm.md      # paste this into your first LLM session
├── AGENTS.md              # the rule of the house
├── CLAUDE.md              # the schema (how the catalog is organized)
├── RESOLVER.md            # the routing (where new files go)
├── skills/
│   ├── ingest/SKILL.md          # process a new source
│   ├── deep-ingest/SKILL.md     # research-augmented ingest
│   ├── query/SKILL.md           # search and synthesize from the vault
│   ├── lint/SKILL.md            # health-check the wiki
│   └── maintain/SKILL.md        # the Compound step — keep the substrate clean
└── templates/              # starter files copied into your vaults during install
```

After install, your home directory has two new folders:

```
~/MainVault/             # PERGAMINO I — the author's brain
├── beliefs/
├── principles/
├── life-decisions/
└── heartbeats/

~/LLMVault/              # PERGAMINO II — the librarian's brain
├── raw/
│   ├── articles/
│   ├── papers/
│   └── web/
├── wiki/
│   ├── concepts/
│   ├── themes/
│   ├── projects/
│   ├── summaries/
│   ├── _index.md
│   └── log.md
└── outputs/
    └── mainvault-pending/   # the tray — proposals from librarian to author
```

## License

MIT. See [`LICENSE`](./LICENSE).

## Brand

Pergamino is named for **Pergamon** — the ancient Greek city whose library held two hundred thousand scrolls and whose rivalry with Alexandria perfected a more durable substrate when papyrus was cut off. The library is gone. The word survives.

In an age of unlimited cheap AI-generated text, the act of choosing what to keep is the work. Pergamino is the substrate where serious thinkers compound their knowledge — built by humans, maintained by AI, designed to outlast the conversations it captures.

— [pergamino.ai](https://pergamino.ai)
