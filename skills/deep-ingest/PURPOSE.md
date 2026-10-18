# Purpose: deep-ingest

## Why it exists

One URL or capture should become LLM brain knowledge in one bounded pass: fetched, filed to `raw/`, summarized, theme-resolved and lightly researched. It must not turn into an unbounded research loop or bypass the author's judgment on themes. deep-ingest is the composition layer: it owns capture-file dispatch (shapes, dead-letters, duplicate checks, filename and URL safety) and delegates everything else to `ingest` and `research`.

## Motivating evidence

- The anchor pattern is the "LLM wiki": sources are compiled once into a persistent wiki. This chain implements it for web sources.
- Capture tools (a web clipper, a mobile app, a bookmark sync) write into `inbox/` and `Clippings/`. The `_processed/` and `_dead-letter/` folders keep an audit trail, so a capture is never deleted.
- The hard caps (3 research sources, 15 files, never auto-create a theme) keep the run bounded and keep the author in charge of the wiki's structure.
- The untrusted-content and URL-safety rules encode the threat model of clipped web pages: the title, the filename and the body are written by strangers.
- Consolidating experience into the wiki before acting on it is the ordering that research on agent skill libraries supports.
- The capture handling moved to `references/captures.md`, which loads only for a capture file. A shorter SKILL.md costs less context on every URL run. "Process inbox" lists the files and proceeds: the run is small and reversible. The theme, thesis, Main brain, 15-file and research-cap gates stay.
- A page that needs a browser goes to a host with a browser tool. The skill does not drive a browser itself.

## Would be retired when

Ingestion goes fully unattended (for example a nightly job with staged trust), and the human gates that this skill protects move into that system's approval layer.
