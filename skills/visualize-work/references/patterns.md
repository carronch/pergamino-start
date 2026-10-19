# Patterns for explaining work

Read the section matching the selected medium, plus "Prose and source boundaries", which applies to every medium. These are defaults to adapt to the reader, not compulsory UI features or node counts.

## Structure and code maps

Prompt shape: “Map [scope] so I can understand [question]. Read the current source, show the primary path and boundaries, and make supporting file/line evidence inspectable. Mark unresolved calls.”

Use stable component identifiers and named edge meanings. Distinguish an import, a possible call, an observed execution and a proposed integration. Take an observed execution from existing logs, traces or test output. Run the project's code only when the task allows it. Pin source-backed maps to the examined revision or clearly identify a dirty working tree. Start at an entry point or reader-relevant action, then follow only the relationships the source supports. Group lower-level detail; choose readable hierarchy over an all-files hairball.

Selection can reveal evidence; path highlighting traverses the authored graph. Keep the selected node name and a text description accessible. If source browsing is unavailable, leave a readable evidence locator and say what was not inspected. Archify's structured-source/validation pattern is a useful reference when it is already available; invoking this skill does not install it.

Validation: node/edge identifiers resolve; paths follow actual directed edges; labels do not collide; source links point at the examined files. Verify each important relation against code/docs rather than treating graph validity as factual validity.

## Workflow, state and change review

Prompt shape: “Show who acts, what changes and where work can wait or fail. For the proposed change, align current and proposed views and keep the difference explicit.”

Workflow explains responsibility; sequence explains exchanges over time; lifecycle explains allowed states and events. Pick the one that answers the question. Separate the agent's proposal from human approval and real execution when the actual/proposed system makes that distinction. Include rejection, stale input, retry or cancellation when it matters. Show asynchronous boundaries without inventing durations.

Before/after views use aligned names and geometry. Added or proposed relationships need explicit labels; unchanged structures keep their meaning. Dependency reach can help review, but the visualization does not prove blast radius or merge safety.

Validation: walk one primary path and an important alternate path. Ensure terminal outcomes and loops agree with the evidence. Simulation scenarios should be deterministic and visibly synthetic/proposed; local scenario controls should have no live side effects.

## Results and explorable models

Prompt shape: “Show the actual result, why it changed and what decision follows. Let me vary [meaningful assumption] if that answers a question; expose the formula, source data and uncertainty.”

Use observed data with quantities/units, an appropriate baseline and an honest scale. Clearly separate measurements, forecasts and illustrative values. Interpretation explains the mechanism; next action follows the supported result and existing goal. Avoid manufacturing an action where the data only supports an open question.

Interaction is useful when changing an input has a meaningful consequence. Keep a readable baseline, the model and assumptions available; guide the reader with a concrete example. It is insufficient to drop them into an unexplained simulator. Do not make confidence look numerical without a defensible method.

Validation: compute values in code; check a baseline and relevant boundary case against the formula/data. Interactions update all affected views consistently. Test labels, legends and units at phone width; color has a text/shape equivalent. Show estimation or model limitations without turning the visual into a disclaimer wall.

## Narrative and video

Prompt shape: “Storyboard this mechanism with a claim, visual action and narration beat per scene. Use motion only where it explains order, transformation or timing. Keep source and captions editable.”

A storyboard can be the complete requested deliverable. For rendered video, use an available code or native workflow. Manim can suit geometric/scientific scenes; an existing Remotion project can suit interface motion. Neither is mandatory. A narrated animation should follow the argument, not merely animate slide decoration. A viewer may need a still summary to inspect the final structure.

Verify narration/visual synchronization, readable labels and representative rendered frames, plus the full short output when feasible. Check numbers and captions against the evidence. Voiceover plugins, speech APIs and licenses have their own actual prerequisites; no entitlement or paid service is presumed.

## Prose and source boundaries

Short, concrete labels and focused captions help the visual stay legible. Explain an unfamiliar term when it first matters, preserving precise domain names. Use Simplified Technical English for technical labels and explanations: short sentences, active voice, one topic per sentence. Preserve exact terms and the requested editorial voice. Do not claim full dictionary compliance from a style prompt.

The main public sources for these patterns are:

- Karpathy's artifact suggestions;
- the inspected Alice map video, shared by `@_overment` (its creator is not identified);
- Nizam's finance concept and Rico's explicit states;
- Poteto's goal-restatement prompt;
- Archify's pinned README;
- Bret Victor's original essay and the official Manim documentation.

Local design/engineering recommendations are synthesis, not source-proven comprehension gains.
