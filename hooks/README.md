# hooks — the kit's Claude Code hooks

Claude Code runs these scripts on its lifecycle events. The kit wires them in `.claude/settings.json`, so they run when the author starts Claude Code in the kit root (`cd ~/Pergamino && claude`). Each script reads the event as JSON on stdin. Exit 2 blocks the action (the message on stderr goes back to the agent); exit 0 lets it through.

Every hook finds the brains through `lib/paths.sh`: `PERGAMINO_HOME`, `PERGAMINO_MAIN_BRAIN` and `PERGAMINO_LLM_BRAIN` from the environment, else from `pergamino.local.env` in the kit root (parsed, never run). A hook that needs the LLM brain does nothing when that path is not set.

Each guard runs through `run-guard.sh`, the fail-closed wrapper: when a guard cannot run or fails, the wrapper blocks the tool call instead of letting it through unguarded.

On Codex CLI and Cursor these hooks do not run from this file. There, the "Guards" section of `AGENTS.md` is the guard.

| Hook | Event | What it does | How to turn it off |
|---|---|---|---|
| `session-context.sh` | SessionStart (every source) | Prints the three resolved paths, then `AGENTS.local.md` from the kit root under `=== Your rules (AGENTS.local.md) ===`, then `<LLM brain>/lessons.md` under `=== Lessons (lessons.md) ===`. Each file is silent when absent and cut at 20,000 bytes. Writes the three paths to `CLAUDE_ENV_FILE`, so shell commands can use `"$PERGAMINO_LLM_BRAIN"`. | Remove its entry from `SessionStart` in `.claude/settings.json`. |
| `inbox-greet.sh` | SessionStart (`startup\|clear`) | Lists the pending captures in `<LLM brain>/inbox/` and `Clippings/`: file name and first body line, cleaned of control, invisible and look-alike characters, inside an envelope whose closing tag carries a random code. Never fetches a URL. Hands each capture to `taint-mark.sh`. | Remove its entry from the `startup\|clear` group. |
| `surface-reminders.sh` | SessionStart (`startup\|clear`) | Lists each reminder in `<LLM brain>/reminders/*.md` whose `due:` date is today or earlier: date, title, path. Flags a reminder without a usable date. Never shows a body. To dismiss a reminder, delete its file. | Remove its entry from the `startup\|clear` group. |
| `recent-workblocks.sh` | SessionStart (`startup\|clear`) | Lists the 5 most recently changed cards in `<LLM brain>/wiki/workblocks/`. | Remove its entry from the `startup\|clear` group. |
| `stale-projects.sh` | SessionStart (`startup\|clear`) | Names each card tagged `rollup` with no dated movement (on the card or on a card it links) for 7 days or more. | Remove its entry, or set `STALE_DAYS` to a larger number. |
| `context-nudge.sh` | UserPromptSubmit | Above 500,000 tokens of context, then every 150,000 more, asks the agent to save the session state to its card and to suggest a manual `/compact` at the next natural break. Never compacts and never blocks. | Remove its entry, or raise `CONTEXT_NUDGE_AT` (and `CONTEXT_NUDGE_STEP`). |
| `block-sensitive.sh` | PreToolUse (`Bash\|Shell`; `Edit\|Write\|Read\|MultiEdit\|Grep`), through `run-guard.sh` | Blocks reads and writes of secret files: `.env` and `.env.*`, `.dev.vars*`, `*.env`, credential and key files, `*.p12`, `*.pfx`, and anything under `~/.ssh`, `~/.gnupg`, `~/.aws/credentials`, `~/.config/op`, `~/.config/gh/hosts.yml`, `~/.codex/auth.json`, `~/.config/gcloud/credentials.db`; `.git/` for file tools. Scans shell commands for those names and for files they write. Blocks searches that would open a secret. Allows tracked `.example` templates, files of 1Password references only, and `pergamino.local.env` while it holds only `PERGAMINO_*` path lines. Fails closed. Known gaps are listed at the top of the script. | Do not turn it off. To protect another token folder, add it in the three places the script names, with a test. |
| `destructive-guard.sh` | PreToolUse (`Bash\|Shell`), through `run-guard.sh` | Blocks `rm -rf` on `/` or the home folder, fork bombs, a download piped into a shell, `dd` to a device, `chmod -R 777` on home or root, a force-push to `main`, `master`, `production`, `prod` or `release`, and a hard `git reset`. | Remove its entry from the `Bash\|Shell` group. |
| `dns-cutover-guard.sh` | PreToolUse (`Bash\|Shell`), through `run-guard.sh` | Turns a command that changes nameservers or DNS records into an "ask": stage and verify the mail records (MX, SPF, DKIM, DMARC) with `dig` before a cutover. | Remove its entry from the `Bash\|Shell` group. |
| `block-lockfile-edits.sh` | PreToolUse (`Edit\|Write\|MultiEdit`), through `run-guard.sh` | Blocks hand edits of lock files (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `Cargo.lock`, `poetry.lock`, `uv.lock`, `bun.lock*` and others), also inside a Codex patch. | Remove its entry. |
| `taint-guard.sh` | PreToolUse (`Bash\|Shell`), through `run-guard.sh` | Only while the session is tainted (see `taint-mark.sh`): blocks network egress with a payload, piping into a network client, credential reads, pushes and deploys, reaching into the Main brain, and `curl \| bash`. Ingestion is never blocked. | Remove its entry. To clear a taint for one session: `rm ~/.claude/state/taint-<session_id>`. |
| `scan-injection.sh` | PostToolUse (`Read\|WebFetch\|Grep`) | Warns when a tool result matches a prompt-injection pattern (instruction override, fake system delimiters, role-play, invisible characters, long base64 blobs, prompt extraction, hidden comments). Never blocks. | Remove its entry. |
| `taint-mark.sh` | PostToolUse (`Read\|WebFetch\|Grep`) | Marks the session as tainted (`~/.claude/state/taint-<session_id>`) when content from `inbox/`, `Clippings/`, `raw/web/` or any WebFetch matches an injection pattern. Text in `wiki/` never marks. | Remove its entry (`taint-guard.sh` then never fires). |
| `wiki-lint.sh` | PreToolUse (`Bash\|Shell`), PostToolUse (`Edit\|Write\|MultiEdit\|Bash`), PostToolUseFailure (`Bash`) | Checks the frontmatter of each page in `<LLM brain>/wiki/` that a call writes: it opens on line 1, closes by line 80, and has `kind`, `type` or `title` in its first 40 lines. Blocks `[[wikilinks]]` to memory notes. For a shell command, lints the pages that changed while it ran. Keeps the session's list of changed cards for `workblock-status-guard.sh`. | Remove its three entries. |
| `workblock-status-guard.sh` | Stop | Blocks the stop once when the session changed a card in `<LLM brain>/wiki/workblocks/` (not `archive/`) without a timeline entry dated from the day of the change through today. | Remove its entry from `Stop`. |
| `post-session-index.sh` | Stop | When a page changed since its last run, rebuilds `wiki/_index.md` and `wiki/_graph.json` (`scripts/rebuild-index.sh`) and runs `qmd update`, in a background job under a lock. Never blocks. | Remove its entry from `Stop`. |
| `audit.sh` | PostToolUse (`*`), optional | Appends one JSON line per tool call to `~/.claude/audit/YYYY-MM-DD.jsonl` (owner-only, kept 30 days): metadata and the tool input, never the output, strings cut at 300 characters, common secret formats redacted. Never blocks. | Off by default. To turn it on, add `{"matcher": "*", "hooks": [{"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR\"/hooks/audit.sh", "timeout": 5}]}` to `PostToolUse`. |
| `run-guard.sh` | — (wraps each guard) | Runs a guard with bash. Passes its exit 0 (allow) and 2 (block) through; turns every other exit, also a missing guard file, into a block. | Do not remove it while a guard runs through it. |

Settings of your own go in `.claude/settings.local.json`, which Claude Code merges with this file and which git does not track. Then `git pull` never conflicts with them.

## Tests

Every test runs only in temporary folders, with a made-up home, kit root and brains:

```bash
bash hooks/hooks.test.sh                    # block-sensitive, lock files, destructive, DNS, run-guard, audit
bash hooks/context-nudge.test.sh
bash hooks/session-start.test.sh            # lib/paths.sh, session-context, recent-workblocks, stale-projects
bash hooks/inbox-greet.test.sh
bash hooks/surface-reminders.test.sh
bash hooks/taint.test.sh                    # scan-injection, taint-mark, taint-guard
bash hooks/wiki-lint.test.sh
bash hooks/workblock-status-guard.test.sh
bash hooks/post-session-index.test.sh
```

`HOOK_SHELL=/bin/bash` runs the hooks under macOS's bash 3.2.

## Requires

`bash`, `jq`, `perl` and `python3` (for the index scripts). Check: `command -v jq perl python3`.
