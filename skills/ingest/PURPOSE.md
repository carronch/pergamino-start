# Purpose: ingest

## Why it exists

Each new source in `raw/` should be compiled into the wiki once, by one procedure: a summary page, every entity it names resolved through `enrich`, a check against the Main brain, fresh indexes and a log entry. `deep-ingest`, `research` and `autoresearch` call it for each source that they file.

## Motivating evidence

- The anchor pattern is Andrej Karpathy's "LLM wiki": sources are compiled once into a persistent wiki, and the wiki compounds.
- Memory references are plain text because one lint pass found that most broken links in a wiki came from memory slugs written as `[[wikilinks]]` by ingest runs.
- Step 8b refreshes the search index because "search before you claim" fails on pages that the index has not seen. A stale index leads to duplicate pages.
- Step 0 reads the clip-time `intent:` field because the author's reason for saving a source is the best guide to what the ingest should produce.
- Step 2 briefs the author and proceeds. An earlier version waited for a go-ahead before every summary, even for one bookmark. A small, reversible write in the LLM brain is done first and reported after.

## Would be retired when

Another route compiles every new `raw/` file with the same checks (for example an unattended nightly research job), and removing this skill causes no regression.
