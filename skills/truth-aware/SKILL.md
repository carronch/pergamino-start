# Skill: Truth-aware behavior

The MainBrain is the author's ground truth — beliefs, principles, life-decisions,
people. This skill is how you honor it.

## The core rule

The MainBrain (`~/Main{{SLUG}}Brain/`) contains the author's authoritative voice.
You **never** write to it. You **always** consult it.

## When reading

Every query skill invocation should span both vaults — MainBrain and LLMBrain
hits surface together. If you want to scope to the MainBrain only, search there
explicitly:

```bash
grep -rl "<query>" ~/Main{{SLUG}}Brain/
```

If the MainBrain has a relevant hit, surface it prominently in your response. Format:

```
> **Your position (Main{{SLUG}}Brain/<file>.md):** <quote or close paraphrase>
```

## When the wiki contradicts the MainBrain

The MainBrain wins. Explicitly:

1. Answer using the MainBrain.
2. Note the wiki says something different.
3. Do not edit either file in response to this.
4. Flag it for the next lint pass.

Example:

> You asked about {{ENTITY_EXAMPLE_1}}'s legal structure.
>
> **Your position (Main{{SLUG}}Brain/people/{{ENTITY_EXAMPLE_1}}.md):** "[paraphrase]"
>
> Note: `wiki/tools/{{ENTITY_EXAMPLE_1}}.md` says something different,
> citing [Source: ...]. Flagging for lint.

## When a source contradicts the MainBrain

On ingest, if a source contains claims that contradict the MainBrain, do NOT
update the MainBrain. Add a section to the summary page:

```
## Tension with your beliefs
This source claims X. Your MainBrain `beliefs/<file>.md#topic` holds Y.
Not updating the MainBrain. Flagging for your review.
```

Then stop. Never nudge the author to change the MainBrain. Never propose MainBrain edits.

## Refusing writes

If the author says "update my beliefs file" or "add this to the MainBrain", refuse:

> I can't write to the MainBrain — that's the zone you own. Here's what I'd write
> if I could:
>
> ```
> <proposed content>
> ```
>
> Two options:
> 1. Copy-paste into the target file yourself.
> 2. Have me stage it in `~/LLM{{SLUG}}Brain/outputs/mainvault-pending/`
>    with a `<!-- target: <path> -->` marker, then promote it manually
>    when you're ready (or via `pergamino promote` if the kit's
>    promotion CLI is available).

This isn't a technical limitation. It's the architecture. The friction is the
feature — it keeps the MainBrain human-curated.

## What the MainBrain is for (and isn't)

The MainBrain is:
- Beliefs you've thought about and committed to
- Life-level decisions with reasoning
- Principles you operate by
- Your honest read on people
- Heartbeat check-ins

The MainBrain is not:
- A task list
- Raw facts about the world (those go in LLMBrain `wiki/`)
- Contact info, addresses, phone numbers (those go in wiki entity pages)

If the author asks you to help clarify a belief before they commit it to the
MainBrain, that's fine — do it in chat or in a scratch file in `wiki/syntheses/`.
The final committed version, they write themselves (or promotes via the queue).
