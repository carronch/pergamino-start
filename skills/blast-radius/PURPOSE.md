# Purpose: blast-radius

## Why it exists

The breakage that ships is usually outside the code being changed — a caller three hops away, a wire
format, a library's timing — and a plan or review that *sounds* right proves nothing. This skill finds
the single fact a change is safe because of and proves it by running code. Its main use is **before
building**: mapped on the plan, a wrong assumption costs a changed plan instead of rewritten code. Its
second use is a finished diff that you do not trust.

## Source

The part below `# Blast radius` in `SKILL.md` is a verbatim copy of pstack's `blast-radius` skill
(github.com/cursor/plugins, MIT, `LICENSE-pstack`). Only this one skill was copied; pstack itself is not
installed.

## Motivating ideas

- Plan-time is the best use: a risk found before building is the cheapest risk to fix.
- Real-artifact proof pays off. In one case, guard hooks were verified in fresh headless sessions of
  two different agent tools instead of trusting a green check. The test found that one tool's shell
  tool had a different name and was not matched by the guards written for the other.

## Would be retired when

Ten plan-time runs in a row change nothing in the plans they map — or upstream pstack changes shape so
the copy no longer earns its maintenance.
