<!-- Routing rules — where new files go.
     For the rule of the house, see AGENTS.md.
     For the catalog schema, see CLAUDE.md. -->

# Pergamino — Routing

When you receive a new artifact (a URL, a file path, a piece of text), this file tells you **where it goes**. Read alongside `AGENTS.md` and `CLAUDE.md` at the start of every session.

## The decision tree

```
                    ┌─────────────────────────────┐
                    │   What did the author       │
                    │   just hand me?             │
                    └─────────────────────────────┘
                                  │
            ┌─────────────────────┼─────────────────────┐
            │                     │                     │
            ▼                     ▼                     ▼
       A. A URL              B. A local file       C. A text snippet
            │                     │                     │
            ▼                     ▼                     ▼
       step 1 below          step 2 below          step 3 below
```

## A. URL routing

A URL the author wants ingested:

```
~/LLMVault/raw/web/<YYYY-MM-DD>-<slug>.md
```

The slug derives from the URL path (so the same URL always produces the same slug). Frontmatter:

```yaml
---
type: raw
source_url: "<url>"
source_type: article
processed: false
fetched: <YYYY-MM-DD>
---
```

If the URL points at a PDF, route to `~/LLMVault/raw/papers/` instead with `source_type: paper`.

## B. Local file routing

The author hands you a file path. Decide by extension and content:

| Extension / shape | Goes to | `source_type` |
|---|---|---|
| `.pdf` (academic, journal article) | `raw/papers/<slug>.pdf` | paper |
| `.pdf` (book) | `raw/books/<slug>.pdf` | book |
| Markdown article (clean text body) | `raw/articles/<slug>.md` | article |
| Email export | `raw/correspondence/<YYYY-MM-DD>-<slug>.md` | correspondence |
| Voice memo / audio transcript | `raw/transcripts/<YYYY-MM-DD>-<slug>.md` | transcript |
| Code repository (you're studying it as an artifact) | `raw/code/<slug>.md` (a *summary* of the repo, not the code) | code |
| Image (diagram, photo) | `raw/media/<slug>.<ext>` + a `.md` description alongside | media |
| Anything you can't classify | Ask the author. Don't guess into a wrong folder. |

## C. Text snippet (no URL, no file)

The author writes you a paragraph or pastes some text. Two routings:

- **If it's a captured fact, observation, or thought** → `raw/notes/<YYYY-MM-DD>-<slug>.md` with `source_type: note`. Then ingest the note.
- **If it's an instruction to you** (e.g., "remind me to..." or "make a note that...") → don't file it as a source. Update `~/LLMVault/wiki/log.md` and act on the instruction.

## After routing — what triggers ingest?

A file landing in `raw/` does NOT auto-ingest. The author triggers ingest explicitly with the `ingest` skill. Until ingest is invoked, the file sits in `raw/` with `processed: false`.

Why not auto-ingest? Because the author may file something for later, or as background context, without wanting the catalog updated right now. Default-on auto-ingest causes catalog noise. Be patient.

## Special folders that aren't sources

These folders are **not** ingest targets — they live in LLMVault but they're not sources to summarize:

- `~/LLMVault/wiki/` — the curated catalog (you write here, but you don't *ingest* it)
- `~/LLMVault/outputs/` — staged proposals back to the author
- `~/LLMVault/.cache/` — anything you generate as scratch space (cleared by `lint`)

If the author hands you a file in any of these folders and asks to "ingest" it, pause and ask — they probably meant something else.

## Tray (proposals back to MainVault)

If your ingest produces a finding that should update a MainVault belief or principle, stage a proposal:

```
~/LLMVault/outputs/mainvault-pending/<slug>.md
```

with the first line:

```html
<!-- target: beliefs/<filename>.md -->
```

(or `<!-- target: principles/<filename>.md -->`, etc., depending on which MainVault folder it should land in)

The author promotes the file via a script or by hand. You never copy it yourself.

## Slug rules

A slug is a stable, lowercase-hyphenated identifier. **Same input → same slug**, always.

For URLs:
- `https://every.to/guides/compound-engineering` → `compound-engineering`
- `https://gist.github.com/foo/abc123/file.md` → `foo-abc123-file` (or just `abc123` if titled meaningfully)
- Strip `www.`, query strings, anchor tags before deriving.

For files:
- Take the file's basename without extension.
- Lowercase, replace spaces and underscores with hyphens.
- Truncate at 60 characters.

For text snippets:
- Use the date prefix (`YYYY-MM-DD-`) plus a 3–6 word summary the author confirms.

## When in doubt

Ask. Better to pause and confirm a routing than to misfile something the author later can't find.

---

*— pergamino.ai*
