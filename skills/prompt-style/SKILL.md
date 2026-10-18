---
name: prompt-style
description: Rewrite a rough idea, or a long step-by-step prompt, as one short first-person "big ask" prompt: the deliverable, a purpose that decides what to keep, plain quality words, a bounded license to iterate, soft flourishes, named taste benchmarks and hedged technique hints. Use when the author says "prompt style", "big ask", "write this as a prompt", "make this prompt like Boris's", or hands over a rough creative or research request for an agent. For a deploy, a deletion, real client data, money or secrets it writes a trimmed prompt plus a "before you run this" list.
---

# Skill: Prompt style — the big ask

Rewrite a request as one short paragraph in the author's voice. State the destination and the taste. Leave the route to the model.

The pattern comes from Boris Cherny's 82-word prompt for an interactive Acquired Home Depot companion. The prompt is public (a post by Boris Cherny on X); the Example section at the end of this file takes it apart. The reason for the skill is in `PURPOSE.md` next to this file.

## Trigger phrases

- "Prompt style: `<rough idea>`"
- "Write this as a prompt" / "big ask"
- "Make this prompt like Boris's" / "bring this prompt to that style"

## Two modes

Pick the mode by what the prompt would make an agent do.

- **Creation work.** Building or editing files, and making explainers, artifacts, designs, prototypes, research write-ups and showpieces. Use all eight moves. A page that only explains or describes is creation work, even when its subject is accounting or money. When the subject is accounting, money, clients or secrets, add a Boundary that keeps real data out. Real data means records of real people or clients, real amounts, accounts and credentials. Public facts are fine.
- **Risky work.** Deploying, publishing, deleting, or touching real data, accounts or secrets. Use the trimmed form: moves 2, 3 and 8 only. No effort license, flourishes or hints. Do not add "entire", "every" or "all" to a destructive action. Drop time-pressure words such as "tonight" and "quick". Never guess a target: write a `<placeholder>` in the prompt and ask about it in the list below. Add a **Before you run this** list under the prompt:
  1. The exact targets: which site, branches, accounts or files. One question for each missing target.
  2. The rollback: how each step can be undone, or a plain statement that it cannot be.
  3. The checks that still apply: `"$PERGAMINO_HOME"/skills/review-pr/SKILL.md` and `"$PERGAMINO_HOME"/skills/blast-radius/SKILL.md`.

Do not use this skill for a pipeline that needs a fixed output shape. Write a spec or use structured output.

## Inputs

- A rough idea in chat, or an existing prompt to convert.
- The language the author will send it in. Write the prompt in that language, in the author's own register and form of address. Write the lists under the prompt in the language the author wrote to you in.

## The eight moves

Use the moves in order. Skip a move only when it has nothing to say.

1. **Why I care.** One sentence of context or enthusiasm that the author gave. Point to the source by name or link. Do not paste a source the model can find. Paste it only when the model cannot find it, such as a private file. Skip this move when the author gave no context. Never invent enthusiasm or a reason.
2. **The deliverable and its scope.** "I want you to make X that does Y." One output type, with the content that defines it, for example "a pricing page that shows three plans". Add a scope word ("entire", "every") only when the source is large, because it blocks a lazy summary. Name the depth only if the author did: "in depth", "short", "a one-page version".
3. **The purpose, as a selection rule.** What the piece must communicate, and to whom. This tells the model what to keep and what to drop.
4. **How good, in plain words.** Quality words only ("beautiful", "fun", "easy to follow"). Use the author's and add none. When the author gave none, derive two from the purpose and list them under "added". Do not say how to reach them.
5. **The effort license, bounded.** Default wording: "Take the time you need and iterate until you would be proud to show it, for at most three rounds. If round three changes little, stop and tell me what is missing." Use the open wording ("Use lots of tokens and iterate till you're proud of it") only when the author says to go big. When taste decides what "proud" means, say it, for example "proud enough to publish".
6. **Flourishes and benchmarks, softly.** Use only the flourishes and exemplars that the author gave. Never invent either. Start each flourish with "maybe". A named exemplar is always soft ("maybe", "vibes"), even when the author wrote "make it feel like X". Add "but better" when the author wants to beat it. When the author gave no exemplar and taste decides the result, offer up to two candidates after the prompt, marked as the author's call, and say that they are from memory. Offer only public works or public figures as candidates, never a private person.
7. **Technique hints, softly.** "I think you can use X for Y." Use a hint when the author knows a tool or a route that the model may not assume. A check the author asked for ("test on Chrome") becomes a hint: "I think you can check it in Chrome." Never turn a hint into a requirement.
8. **Boundary and musts, in plain words.** Every explicit must or must-not that the author gave about the whole result: a length, viewport widths, a load time, "works offline", "bilingual", a banned tool. List them plainly: "It must: …. It must not: …." There is no cap, and do not drop one. Add what must not happen. For destructive steps, add the gate "stop and ask me before each one". When a project is in play, read its `tasks/lessons.md` if one exists, and the `## Lessons` section of its card in `"$PERGAMINO_LLM_BRAIN"/wiki/workblocks/`, and carry in only the corrections that bear on this task. Do not write a pointer to the file.

Two optional lines:

- **Evidence line**, for research deliverables and for any page that states facts: "Say what you read, and mark what you could not check."
- **Showpiece line**: "Show me two or three style frames before you build." Add it when the result is a finished piece for people outside the author's team (donors, customers, the public), or when the author calls it a showpiece. Otherwise leave it out.

## Steps

1. Read the input. Mark the deliverable, the purpose, the source, the quality words, the benchmarks, the technique hints and the musts. Pick the mode.
2. If you cannot guess the deliverable or the purpose, ask one question. Otherwise draft at once. In risky work, a missing target is a placeholder, not a question before the draft.
3. Sort the requirements. Do this for any input with several requirements, whether a long prompt or a list of musts. Put each statement in one place:
   - **What it is and what it is for** (the deliverable, a depth word such as "short", the content that defines it, the purpose): the paragraph.
   - **A quality** ("beautiful", "fun", "easy to follow"): move 4.
   - **A must about the whole result** (a word count, viewport widths, a load time, a banned tool, "works offline", "bilingual", "brand colors"): move 8.
   - **A build choice** (steps, structure, technology and versions, file layout, sizes of parts, fonts, color codes, role lines): drop it and list it under "dropped", so that the author can restore any that matter. A technology the author named stays only as a soft hint, and only when it unlocks something the model may not assume.
   - **How to check the result** ("test on Chrome"): a soft hint.
4. Draft one paragraph in the author's voice. Aim for 120 words or fewer, before move 8 and the optional lines. Fix spelling. Keep the casual, first-person tone.
5. Run the checks below. Fix any failure.
6. Output the prompt in one code block that is ready to paste. Put move 8 and the optional lines inside the block, after the paragraph. Under the block, add three short lists: kept, softened or dropped, and added. In "added", list any input the work needs that the author did not give, such as a palette, prices or a source file. Do not invent them. Add the benchmark candidates if you offered any. In risky work, add the **Before you run this** list.

## Checks

- One paragraph, first person, 120 words or fewer (move 8 and the optional lines excluded).
- The paragraph holds the deliverable, the purpose and the quality words. Every other explicit must is in move 8.
- The purpose is stated as a selection rule.
- No steps, role line, technology, layout, font or color code in the paragraph.
- Every benchmark and flourish in the prompt came from the author. Candidates appear only after the prompt.
- The effort license is present and bounded, or open on request. Risky work has none.
- Risky work has move 8 and the **Before you run this** list. No target is guessed.
- The language and the voice match the author's.

## Rules

- Keep the author's names and exemplars. Drop the author's build choices, and list them.
- Do not add steps to look thorough. A step you add caps the plan at your own imagination.
- Do not hide a real rule in a soft phrase. A real rule goes in move 8, in plain words.
- Never let the purpose widen the work. When the purpose does not justify an action the author named, keep the action and say so under "added".
- Do not invent rules, context, flourishes or inputs for the author. Anything you add goes under "added" so that the author can strike it.
- This skill writes the prompt. It does not run it. Run the prompt only when the author asks.
- When the author asks why the style works, point to the Example and to `PURPOSE.md`, and name its limits: one example from one author, and the result was not opened.

## Example

Boris Cherny's prompt is the model case. Its moves: (1) "The latest acquired Home Depot episode is really amazing." (2) "make an artifact that narrates the entire episode". (3) "communicating the nugggets of business wisdom throughout the episode". (4) "beautiful and interactive … really good". (5) "use lots of tokens and iterate till you're proud of it", the open wording. (6) "Maybe add watercolor illustrations … New Yorker or nytimes data viz vibes but better". (7) "I think you can use OpenCV for water color images". It has no move 8, because the task makes a page and touches nothing else.
