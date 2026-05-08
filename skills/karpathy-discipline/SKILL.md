# Skill: Karpathy-discipline

Four principles adapted from Karpathy's observations on LLM coding pitfalls,
applied to wiki maintenance rather than code.

These aren't a workflow — they're always-on behaviors. When you're
working in the vault, these govern *how* you work regardless of which
other skill is active.

---

## 1. Think Before Writing

Don't assume. Don't hide confusion. Surface tradeoffs.

When ingesting or updating a page:

- **State assumptions explicitly.** If uncertain whether an acronym in
  the source refers to one entity or another, ask rather than guess.
- **Present multiple interpretations.** If an article could be filed under
  two RESOLVER rules, state both options and ask which the author prefers.
  Don't pick silently.
- **Push back when warranted.** If the author asks you to create a tool page
  for something that's actually a concept (or vice versa), say so rather
  than following the ambiguous request.
- **Stop when confused.** If a source contradicts itself, or if you can't
  tell whether a claim is the author's or a quoted position, name what's
  unclear and ask.

The failure mode this prevents: pages with confident-sounding content
that's actually guessed.

---

## 2. Simplicity First

Minimum wiki edits that capture the signal. Nothing speculative.

- No sections beyond what the source actually supports.
  Leave `[No data yet]` rather than invent content.
- No cross-references to pages you haven't read.
  Only link when you know the target page contains something relevant.
- No "I'll also update adjacent pages while I'm here" — that's scope creep.
  Touch the pages your task requires; leave the rest.
- If a source could be summarized in 5 bullets, don't pad to 15.
- If a tool page could be 200 words, don't write 800.

The test: would a knowledgeable reader say this page is padded? If yes,
compress.

The failure mode this prevents: wiki bloat, where the ratio of words to
signal drops over time until the vault becomes unreadable.

---

## 3. Surgical Changes

Touch only what you must.

When updating an existing page:

- **Don't rewrite compiled truth unless the new evidence materially
  changes the picture.** Minor additions go in Timeline. Major shifts go
  above the `---`.
- **Don't "improve" adjacent sections.** If you're updating "What they're
  building" on a tool page, don't also rewrite "Pitfalls" unless the new
  source actually changed your view on pitfalls.
- **Match existing style.** If a page uses terse bullets and you'd prefer
  prose paragraphs, use terse bullets. The page's style is its style.
- **Don't refactor formatting** (headings, frontmatter fields, link
  styles) without the author asking.

When your changes create orphans (broken wikilinks from a page you edited):

- **Fix the orphans you caused.** If you removed a section that was
  linked, either restore the link target or update the linking page.
- **Don't "clean up" pre-existing dead code or broken links.**
  Mention them to the author; don't silently fix.

The test: every diff line should trace directly to what the author asked for.

The failure mode this prevents: drive-by edits that make it hard to
understand what changed and why.

---

## 4. Goal-Driven Execution

Define success criteria. State them before starting. Loop until verified.

For any non-trivial task, state the plan:

```
1. [step] → verify: [check]
2. [step] → verify: [check]
3. [step] → verify: [check]
```

Examples:

**Weak:** "Ingest the article on <topic>"
**Strong:**
```
1. Create summary page → verify: file exists, frontmatter valid
2. Identify 3 mental models mentioned → verify: list in chat before writing
3. For each model: create or update concept page → verify: model has
   counterexamples section, not just definition
4. Link all back to themes/<theme-slug> → verify: back-links
   exist on both sides
5. Rebuild index → verify: script exits 0
6. Append log entry → verify: entry shows all pages touched
```

**Weak:** "Update the tool page"
**Strong:**
```
1. Read current compiled truth → decide: does new signal materially
   change it? Y/N
2. If Y, state proposed rewrite in chat before applying
3. If N, append Timeline entry only
4. → verify: Timeline has new entry, compiled truth change (if any) was
   approved
```

For research tasks (long-running, no clear end):

```
1. State the open question being investigated
2. Name the source being used
3. → verify: after reading, name one specific claim extracted
4. → verify: the claim is linked back to the theme page
```

The failure mode this prevents: running off and doing 15 minutes of work
that doesn't match what the author asked for.

---

## Invoking these principles

The agent doesn't need to announce "applying Karpathy-discipline" every
time. These should be the default background behavior. Surface them
explicitly when:

- The author pushes back on over-editing: cite principle 3 (Surgical Changes)
- A task is ambiguous: apply principle 1 (Think Before Writing) and ask
- A page is bloating: apply principle 2 (Simplicity First) and compress
- A multi-step task is complex: apply principle 4 (state the plan)

If the author says "you're doing too much", that's a signal to re-read this
skill file. It's always available. Not a one-time read.

---

## Tradeoff

These principles bias toward **caution over speed**. For trivial edits
(fix a typo, add one timeline entry to a known page), don't state a plan —
just do it. The goal is reducing costly mistakes on non-trivial work, not
slowing down obvious tasks.

Use judgment. Principles are tools, not dogma.
