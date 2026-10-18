---
name: truth-aware
description: "Always-on rules for the Main brain, the author's ground truth: consult it on every answer, never write to it, let it win over the wiki, record tensions instead of resolving them, and route any proposed change through the tray. Use whenever an answer, an ingest or a request touches the author's beliefs, principles, life-decisions or people, and when the author says 'update my beliefs file' or 'add this to my Main brain'."
---

# Skill: Truth-aware behavior

The Main brain is the author's ground truth: beliefs, principles, life-decisions,
people. This skill is how you honor it.

## The core rule

The Main brain (`$PERGAMINO_MAIN_BRAIN`) holds the author's authoritative voice.
You **never** write to it. You **always** consult it.

The one exception is the `soul-audit` skill: when the author invokes it by name, it writes to the Main brain for the length of that audit only.

## When reading

Every query: `qmd query "<query>"` spans both collections,
so Main brain hits surface automatically. To search the Main brain
only, use `qmd search "<query>" -c main`. Without `qmd`:

```bash
grep -rli "<query>" "$PERGAMINO_MAIN_BRAIN/"
```

If the Main brain has a relevant hit, show it prominently in your response. Format:

```
> **Your position (Main brain: <file>.md):** <quote or close paraphrase>
```

## When the wiki contradicts the Main brain

The Main brain wins. Explicitly:

1. Answer from the Main brain.
2. Note that the wiki says something different.
3. Do not edit either file in response.
4. Flag it for the next lint pass.

Example:

> You asked about the legal structure of `<business>`.
>
> **Your position (Main brain: people/<partner>.md):** "[paraphrase]"
>
> Note: `wiki/businesses/<business>.md` says something different,
> citing [Source: ...]. Flagging it for lint.

## When a source contradicts the Main brain

On ingest, if a source makes claims that contradict the Main brain, do NOT
update the Main brain. Add a section to the summary page:

```
## Tension with your beliefs
This source claims X. Your Main brain `beliefs/<file>.md#topic` holds Y.
Not updating the Main brain. Flagging it for your review.
```

Then stop. Never nudge the author to change the Main brain. The only route for a change is a staged
proposal in the tray, and only when `skills/query/SKILL.md` § Mandatory check says one applies.
Once it is staged, do not mention it again.

## Refusing writes

If the author says "update my beliefs file" or "add this to my Main brain", refuse:

> I do not write to the Main brain: that is the part you own. Here is what I would write
> if I could:
>
> ```
> <proposed content>
> ```
>
> Two options:
> 1. Copy and paste it into the target file yourself.
> 2. Have me stage it in `outputs/mainvault-pending/` in the LLM brain,
>    with a `<!-- target: <path> -->` marker as its first line. Then run
>    `"$PERGAMINO_HOME/scripts/promote-to-mainvault.sh"` when you are ready to promote it.
>
> If you want a guided interview that writes the Main brain directly, invoke `soul-audit`.

This is not a technical limitation. It is the architecture. The friction is the
feature: it keeps the Main brain curated by a human.

## What the Main brain is for (and is not)

The Main brain holds:
- Beliefs the author has thought about and committed to
- Life-level decisions with their reasoning
- Principles the author operates by
- The author's honest read on people
- Heartbeat check-ins

The Main brain does not hold:
- A task list (tasks go on cards in `wiki/workblocks/`)
- Raw facts about the world (those go in the LLM brain's `wiki/`)
- Contact details, addresses, phone numbers (those go in wiki entity pages)

If the author asks you to help clarify a belief before they commit it to the
Main brain, do it in chat or in a scratch file in `wiki/syntheses/`.
The author writes the final version (or promotes it through the tray).
