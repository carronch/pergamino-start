# Search setup: qmd and the two collections

[qmd](https://github.com/tobi/qmd) is the search engine for the two brains. It runs on your computer as a command-line tool. It keeps one index on disk, in `~/.cache/qmd/`. Each brain is one **collection** in that index:

| Collection | Folder | Who writes there |
|---|---|---|
| `main` | `$PERGAMINO_MAIN_BRAIN` | the author only |
| `llm` | `$PERGAMINO_LLM_BRAIN` | the agent |

The kit's rules and skills use exactly these two names: `qmd search "<q>" -c main` and `qmd search "<q>" -c llm`.

## Requires

- Node.js or Bun, to install qmd.
- Disk space for a local embedding model (qmd downloads it at the first `qmd embed`).

Check: `command -v qmd`.

## Install

```bash
npm install -g @tobilu/qmd
# or
bun install -g @tobilu/qmd
```

A Bun install puts `qmd` in `~/.bun/bin`. Put that folder on your `PATH` if `command -v qmd` finds nothing.

## Register the two collections

Run these from the kit root, so `hooks/lib/paths.sh` can read `pergamino.local.env`:

```bash
eval "$(bash hooks/lib/paths.sh)"
qmd collection add "$PERGAMINO_MAIN_BRAIN" --name main --mask "**/*.md"
qmd collection add "$PERGAMINO_LLM_BRAIN"  --name llm  --mask "**/*.md"
qmd collection list
```

`qmd collection list` must show both collections, each with a file count.

## First index and embeddings

```bash
qmd update     # read new and changed files into the keyword (BM25) index
qmd embed      # make the vector embeddings with the local model
```

Run both again after a large operation (a bulk ingest, a setup interview).

On Claude Code, the Stop hook `hooks/post-session-index.sh` runs `qmd update` after each reply that changed a page, so keyword search sees the new pages at once. It does not run `qmd embed`: the model load is slow. Run `qmd embed` by hand, or from a scheduled job once a day.

## Search

`qmd query` is the default: it is hybrid (keywords, vectors and a rerank by a local model).

```bash
qmd query "how do we price the service"         # hybrid, both collections
qmd query "how do we price the service" -c llm  # one collection
qmd search "pricing" -c main                    # keywords only (fast, no model)
qmd vsearch "fair price for small clients" -c llm   # vectors only (intent-heavy questions)
```

Before you claim that something does not exist, search both collections: `qmd search "<name>" -c main` and `qmd search "<name>" -c llm`. Try aliases: with and without accents, the first name only, common spellings.

## Check that it works

```bash
qmd status            # the index and the health of each collection
qmd search "the" -c llm
```

If the search returns pages, the setup is done.

## Troubleshooting

- **No results after `qmd embed`:** check the folder of each collection with `qmd collection list`, and check that `.md` files exist there.
- **New files do not show up:** run `qmd update` (and `qmd embed` for vector search). qmd does not watch folders.
- **A collection has the wrong name:** `qmd collection rename <old> <new>` keeps the index; you do not need to embed again.
- **A brain moved to another folder:** `qmd collection remove <name>`, then add it again with the new path. Update `pergamino.local.env` too.
- **Slow first query:** the first `qmd query` loads the models. Later queries are faster.
