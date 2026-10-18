# Capture files: dispatch, shapes, duplicates and the move

Read this before you handle a file from `inbox/` or `Clippings/` in the LLM brain (`$PERGAMINO_LLM_BRAIN`). SKILL.md § Untrusted content applies to every line here.

**Dead-letter** means: move the file to `<recorded-source-folder>/_dead-letter/<basename>`, then stop with a one-line note in chat.

## Dispatch

Do these in order.

1. **Record the source folder**: the file's actual parent directory at dispatch time. Every later move uses it, not the folder that the shape implies. (A Shape A note that the author moved into `Clippings/` dead-letters to `Clippings/_dead-letter/`.)
2. **Check the filename** (SKILL.md § Untrusted content) before any frontmatter logic. Web page titles become filenames, so an adversary can control them. Dead-letter a refused name. From here on, use `basename "$file"` semantics: every `mv` or `Write` destination is `<recorded-source-folder>/{_processed,_dead-letter}/.../<basename>`, and its real path must stay under `<recorded-source-folder>/_processed/` or `<recorded-source-folder>/_dead-letter/`.
3. **Find the shape** from the frontmatter, not the folder: the author may move files.
   - `type: capture` → Shape A.
   - `tags` includes `clippings`, and a top-level `source:` holds a URL string → Shape B.
   - Both markers → Shape A: `type:` is the explicit signal, and `tags` can travel with a hand-edited file.
   - Neither → malformed: dead-letter it.
4. **Check each URL's scheme** (SKILL.md § Untrusted content) before any fetch, slug derivation or search: every `urls:` entry in Shape A, and `source:` in Shape B. The routes below drop a failed URL or dead-letter the file.
5. **Route the file** by its shape (§ Shape A, § Shape B).
6. **Check for a duplicate** (§ Duplicates) when the file carries a URL. Only then continue at SKILL.md step 1 or 2.

## Shape A: `inbox/` capture

From a custom capture template, a mobile notes app or a bookmark sync.

```yaml
---
type: capture
source: web-clipper | mobile | bookmark-sync
captured: <ISO 8601>
urls: [<zero or more>]
---
<body>
```

- **Malformed** (no frontmatter, zero bytes, or a required key missing) → dead-letter.
- **`urls: []`, a text-only note** → save the body to `raw/notes/<YYYY-MM-DD>-<slug>.md` with `type: raw`, `source_type: note`, `processed: false`. Go to SKILL.md step 3 with that file. Skip step 5 and § Duplicates: there is nothing to research and no URL to compare. After step 8, move the capture (§ Move).
- **`urls: [<one>]`** → a failed scheme check dead-letters the file with reason `unsafe-url-scheme`. Otherwise the URL is the input to step 1. Carry the capture body forward for step 3.
- **`urls: [<first>, <rest...>]`** → drop each URL that fails the scheme check, and say in chat which you dropped. If none survive, dead-letter with reason `all-urls-unsafe-scheme`. Otherwise this run uses the first surviving URL. For each other surviving URL, write a new capture file to `<recorded-source-folder>/` (the same frontmatter, one URL, no body), so that a later run picks it up.

## Shape B: `Clippings/` file (Obsidian Web Clipper default)

```yaml
---
title: "<page title>"
source: "<url>"
author: <maybe>
published: <maybe>
created: <YYYY-MM-DD>
description: <maybe>
intent: <maybe>
tags:
  - "clippings"
---
<rendered article body>
```

- **Malformed** (no frontmatter, or no `source:` URL) → dead-letter.
- **Unsafe `source:` scheme** → dead-letter with reason `unsafe-url-scheme`.
- **A valid `source:` and a body** → the body is already-rendered article content, so skip step 1 (no fetch, no JavaScript-shell check). In step 2, write `raw/web/<YYYY-MM-DD>-<slug>.md` in the URL-input shape: `source_url` from `source:`, the H1 from `title:`, the body verbatim, `source_type: article`, and `fetched:` from `created:` (today if absent).
- **`intent:`** is the author's answer to the Web Clipper's clip-time prompt: why they save the page and what they want done with it. It is the author's framing, not the source's content. Never invent one. Without it, proceed neutrally. With a value, copy it verbatim into the raw file's frontmatter under the same key, where `ingest` step 0 reads it. When it is absent or empty, omit the key: no `intent: ""`, no `intent: null`.

## Duplicates

For every capture that carries a URL:

1. Take the URL that this run will fetch: the first surviving URL in Shape A (after the scheme check, so not always `urls[0]`), or `source:` in Shape B. Derive the slug from it, never from `title:`: titles vary across captures of one URL and would defeat the check.
2. Look in `raw/web/` for a file whose frontmatter `source_url` equals that URL. This content scan is the authoritative check. The URL is attacker-controlled and may hold shell metacharacters (`` $() ``, backticks, `;`), so it stays out of every command string (SKILL.md § Untrusted content):
   - **Preferred:** list the directory in code (Python, Node or a `Read`-tool listing), read each `*.md` file's frontmatter, and compare `source_url` to the URL by string equality. The code reads the URL from the capture file or from a scratch file, never from a literal that you type. No shell interpolation, no regular expression.
   - **With `grep`:** write the line `source_url: "<url>"` to a scratch file with the `Write` tool, so that no shell parses the URL. Match that line as a fixed string (`--fixed-strings`, so that `.` is no wildcard):
     ```bash
     grep -rlF --include='*.md' -f <scratch-file> "$PERGAMINO_LLM_BRAIN/raw/web/"
     ```
     If you build the command in code, pass the URL as a separate argument-list element.
3. **On a hit**, skip the fetch and the research, log `deep-ingest | <url> | skipped: already ingested`, and move the capture (§ Move). The run ends there.

## Move

On every successful path from a capture file, this is the last action before the report (SKILL.md step 9). If the month directory does not exist, create it. Check that the resolved destination is still under `<recorded-source-folder>/_processed/`, then move:

```
<recorded-source-folder>/<basename>
  → <recorded-source-folder>/_processed/<YYYY-MM>/<basename>
```
