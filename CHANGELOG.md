# Changelog

## 0.2.0 — 2026-10-17

The kit now carries the full setup, not only the brain skills.

- **Rules.** `AGENTS.md` is the one rules file; `CLAUDE.md` links to it, so Claude Code reads the same rules as Codex CLI and Cursor. The catalog schema moved to `SCHEMA.md`. New rules: search before claiming, compiled truth above a dated timeline, cite every claim, one home per fact, a card per project, corrections become lessons, guards that hold on every host.
- **Your settings stay yours.** Brain paths live in `pergamino.local.env`, your own rules in `AGENTS.local.md`, your Claude Code changes in `.claude/settings.local.json`. None is committed, so `git pull` always updates the kit. The `{{SLUG}}` placeholders in the solo path are gone.
- **Skills.** Updated: `ingest`, `deep-ingest`, `enrich`, `research`, `query`, `lint`, `maintain`, `truth-aware`, `karpathy-discipline`. New: `autoresearch`, `ingest-meeting`, `setup-interview`, `soul-audit`, `convene-the-board`, `video-to-card`, `triage-cards`, `teach`, `review-pr`, `blast-radius`, `benchmark-checklist`, `retro`, `correct`, `visualize-work`, `prompt-style`, `writing-for-agents`, `adopt-pergamino` (merge the kit into a setup you already have). Skills are linked for Claude Code (`.claude/skills`) and Codex (`.agents/skills`).
- **Hooks** (Claude Code, wired in `.claude/settings.json`): secret-file block, destructive-command guard, lock-file guard, DNS staging guard, prompt-injection scan and taint guard, page frontmatter lint, card-update check at stop, index rebuild at stop, session-start listing of captures, reminders, recent cards, stale projects, your rules and lessons. Each has a test; see `hooks/README.md`.
- **Scripts.** `rebuild-index.sh` (index and link graph), `promote-to-mainvault.sh`, `build-graph.py`, `graph-hop.py`, `cards-digest.py`.
- **Install.** `install.sh` asks for the two brain paths (it finds an older `~/Main<Name>Brain`), creates the folders, registers the `main` and `llm` search collections, lets Claude Code work in both brains, and is safe to run again.

## 0.1.0 — 2026-05-07

First kit: two brains, eleven skills, company deployment templates.
