---
type: reviewer-agents-readme
purpose: Operational guide for the pergamino reviewer-agent layer
created: 2026-05-07
updated: 2026-05-07
tags: [pergamino, reviewer-agents, productization, deployment]
---

# Pergamino reviewer agents

This folder contains the reviewer-agent prompts that pergamino's heartbeat invokes against pending pull requests in `brain-canon`. Each file is a system prompt — concatenated with `_base-reviewer.md` and sent to Claude (or whichever LLM the client uses) to pre-analyze a PR before the human reviewer sees it.

## Why this layer exists

The reviewer-agent layer is the **demo moment** of pergamino. Without it, a CEO opens GitHub, faces an unsorted PR queue, and spends 30+ minutes context-switching. With it, the CEO opens WhatsApp at 8:30am, sees a structured digest with verdicts and reasoning, and resolves the day's review in 12 minutes — including bulk-approve from WhatsApp.

The reviewer-agent does **not** have authority to merge PRs. It only **proposes a verdict and reasoning** that the human reviewer (CEO, dept head, or pergamino implementer) ratifies or overrides.

## Architecture: universal core + variable shell

Each reviewer is composed at runtime as:

```
[ _base-reviewer.md content ]
    +
[ <scope>-reviewer.md content ]
    =
    final system prompt sent to Claude
```

`_base-reviewer.md` carries the 80% that's true for every scope: output format, factual-grounding, tone-match, scope-creep, append-only enforcement, prompt-injection defense, PR-quality basics, cross-scope detection. Inherit. Don't repeat in scope-specific files.

`<scope>-reviewer.md` adds the 20% that's specific to the scope: voice details, scope-specific risk flags, file-path rules, industry-specific concerns.

## Universality classification

| File | Universality | Notes |
|---|---|---|
| `_base-reviewer.md` | universal | Inherited by all. Don't override. |
| `company-reviewer.md` | universal | Every client has a `company/` scope. |
| `customer-facing-reviewer.md` | universal | Strictest. Most clients have a customer-facing surface. |
| `principal-reviewer.md` | universal | Audit-only mode for CEO/founder/owner self-approve. |
| `cross-scope-reviewer.md` | universal | Runs ON TOP of source-scope reviewer when PR crosses scopes. |
| `sales-reviewer.md` | variable (hospitality, Mawamba template) | Tune per vertical. |
| `operations-reviewer.md` | variable (hospitality, Mawamba template) | Tune per vertical. |
| `finance-reviewer.md` | variable (mostly transferable, strict everywhere) | Most clients have finance; rules transfer well. |

## Output format (uniform across all reviewers)

Every reviewer produces structured Markdown the heartbeat-Worker can parse:

```markdown
## Verdict
[✅ recommend approve | ⚠️ needs human eyes | 🚫 should reject]

## Confidence
[high | medium | low]

## Reasoning
<2–4 sentence plain-language explanation>

## Flags
- [flag-type]: <description with file path>
- [flag-type]: <description>

## Cross-scope
<empty if not cross-scope; otherwise: target scope, suggested co-reviewer>

## Suggested reviewer
<role or person, per the client's CODEOWNERS>
```

The pergamino heartbeat parses these fields and composes the WhatsApp digest. Verdict emoji becomes the digest line; reasoning becomes the "why escalated" detail; flags become the "needs your eyes" bullet list.

## Runtime model

The pergamino reviewer-Worker, deployed per-client, runs on a Cloudflare Cron Trigger (08:30 local time, weekdays). For each open PR in `brain-canon`:

1. Fetch PR diff + description + commit metadata via GitHub API.
2. Identify the target scope (path-based; e.g., PR touching `sales/playbook.md` → sales scope).
3. Load the appropriate scope-specific reviewer-agent file + `_base-reviewer.md` + the target scope's `AGENTS.md`.
4. If cross-scope detected, also load `cross-scope-reviewer.md`.
5. Compose the system prompt; send the diff + description as user message; call Claude API.
6. Parse the structured output; persist to PR's review status; aggregate into the daily digest.

Per-PR cost: ~$0.005 with Claude Haiku, ~$0.05 with Claude Sonnet. **Sonnet recommended for the customer-facing and finance scopes** (high-stakes); Haiku is fine for routine within-scope.

## Adding a new vertical's variable reviewer

When a non-hospitality client onboards (e.g., a marketing agency), the variable reviewers need vertical-specific tuning:

1. Copy the existing file as `<scope>-reviewer-<vertical>.md` (e.g., `sales-reviewer-saas.md`).
2. Update frontmatter `vertical:` and `client-template:`.
3. Adjust the scope-specific checks for the new vertical's voice, regulatory concerns, common failure modes.
4. Test against 3–5 sample PRs (real or synthetic) before deployment.
5. Register in the client's `pergamino-deploy` config: `reviewer-agents.sales: sales-reviewer-saas.md`.

The library accumulates over time. Goal: by deployment 5, ~80% of new clients reuse an existing vertical template with minor tuning.

## First-3-weeks calibration

For each new client deployment, the operator acts as co-reviewer alongside the AI for the first 3 weeks. The pergamino dashboard tracks AI-verdict vs human-final-decision agreement; misses and false positives surface as tuning opportunities for the scope-specific reviewer prompts. After 3 weeks of calibration, the AI is reliable enough that the CEO can delegate to it confidently. Bake into the engagement structure and price.

## Files in this folder

- `README.md` — this file
- `_base-reviewer.md` — universal base prompt (inherited by all scope-specific reviewers)
- `company-reviewer.md` — universal: company-wide canon scope
- `customer-facing-reviewer.md` — universal: outbound-to-customers scope (strictest)
- `principal-reviewer.md` — universal: CEO/founder/owner private scope (audit-only)
- `cross-scope-reviewer.md` — universal: runs on top of source-scope when a PR crosses scopes
- `sales-reviewer.md` — Mawamba-template (hospitality vertical)
- `operations-reviewer.md` — Mawamba-template (hospitality vertical)
- `finance-reviewer.md` — variable (transferable, strictest)

## Companion documents

- [[wiki/syntheses/pergamino-deployment-playbook]] — the broader deployment context.
- [[wiki/projects/pergamino-ai]] — the productization project.
- [[wiki/themes/founder-tooling]] — primary theme.
