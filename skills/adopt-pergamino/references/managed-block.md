# The managed block

`adopt-pergamino` adds this block to a target's rule file (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`, `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`). For Cursor, it goes in `.cursor/rules/pergamino.mdc` with the frontmatter `alwaysApply: true`.

Fill `<KIT>`, `<MAIN>` and `<LLM>` with the absolute paths that `bash "$PERGAMINO_HOME/hooks/lib/paths.sh"` prints on this machine. The block is in the user's own file, so local paths are fine there. Keep the markers exactly as written: the next run finds them and replaces only the text between them. List only the skills that the plan installs in this target, and drop a line whose skill the plan does not install (for example the `/review-pr` line).

```markdown
<!-- pergamino:begin — managed by adopt-pergamino; edit outside these markers -->
## Pergamino

- Two brains. The Main brain (`<MAIN>`) holds the author's own notes: read it, cite it, never write in it. The LLM brain (`<LLM>`) is the agent's curated layer.
- Before you say that something exists or does not exist, search both brains: `qmd search "<query>" -c main` and `qmd search "<query>" -c llm`.
- A proposed change to the Main brain goes to the tray, a folder under `<LLM>/outputs/` that `<KIT>/AGENTS.md` names ("The tray"), for the author to promote.
- Each project has one card in `<LLM>/wiki/workblocks/`. A session that advances the work updates the card's `status:` and `status_note:` and adds a dated timeline entry before it ends.
- Every change to code goes through `/review-pr`: a model from another vendor reviews it before it merges.
- Skills from the kit: <the installed skills, one word each, for example /review-pr, /blast-radius, /triage-cards, /video-to-card, /correct, /retro, /teach>.
- The kit's full rules: `<KIT>/AGENTS.md`.
<!-- pergamino:end -->
```
