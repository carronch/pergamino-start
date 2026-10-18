# Purpose: visualize-work

## Why it exists

AI can make ongoing work easier to understand through reusable visualization patterns. The skill chooses a representation from the reader's question, keeps actual-work claims grounded, and checks the rendered explanation instead of equating visual polish with understanding.

## Motivating ideas

- Custom prose, diagram, interactive and video artifacts can serve as aids to understanding (Andrej Karpathy's artifact suggestions).
- A navigable code map is useful only when its edges come from inspected source.
- A results view works best as a hierarchy: number, then explanation, then action.
- Explicit interface states and a restated goal keep a visual on the reader's question.
- Structured source plus validation (the Archify pattern) gives a map that can be checked, without claims of runtime safety.
- Bret Victor's explorable explanations: a guided explanation, with the assumptions behind each interaction open to inspection.
- A style rule drifts unless the actual rendered output is checked.
- Replaying recorded run logs through a pure reducer, step by step, can show what a log read line by line and the code alone do not. In one trial, a replay showed that an agent wrote every file through its shell tool and never through the guarded file-edit tool.

## Would be retired when

An existing visualization workflow reliably makes the same choices without these instructions: it preserves evidence and status distinctions and validates the output. The skill is also retired when repeated real use shows that it adds friction without improving the author's understanding. Initial fixture checks and a synthetic example do not establish a measured comprehension benefit.
