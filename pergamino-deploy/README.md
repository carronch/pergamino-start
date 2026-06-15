# pergamino-deploy

The provisioner that turns *"instalado por Daniel"* from days into ~1 hour.
One command reads an intake file and stands up a complete client brain —
repos, access, sync, billing — then **verifies every piece is green** before
declaring success.

> Design canon: the agent does **not** improvise each install. The heart is a
> **deterministic playbook** (these steps); the agent *orchestrates and verifies*
> it. Daniel's own loop/goal discipline applied to ops: *"don't stop until
> client N has their brain syncing, verified."* See the vault workblock
> `2026-06-15-pergamino-product-tiers`.

## Status (2026-06-15) — Sprint 1 scaffold

This is the **server-agnostic scaffold**. The host for the managed brain
(fly.io vs VPS) is deliberately undecided, so the steps that need it are
stubbed behind the step contract. Everything else is real and runnable in
`--dry-run` (the default).

| Step | Server-dependent? | Status |
|---|---|---|
| `intake` (read + validate) | no | ✅ implemented |
| `repos` (GitHub role repos by API) | no | ✅ implemented (dry-run + apply) |
| `cf-access` (CF Access policies + tokens) | no | ✅ implemented (dry-run + apply) |
| `stripe` (subscription + customer portal) | no | ✅ implemented (dry-run + apply) |
| `brain-seed` (seed Main/LLM brains from kit templates) | no | ✅ implemented |
| `couchdb` (per-client container) | **yes** | ⏳ stub — needs server decision |
| `tailscale` (tailnet enroll + ACLs) | **yes** | ⏳ stub — needs server decision |
| `verify` loop (poll until green) | no | ✅ implemented |

## Usage

```sh
# dry-run (default): prints the full plan + what each step WOULD do, runs verifiers
./bin/pergamino-deploy plan   --intake ./intake.example.yaml

# actually apply the server-agnostic steps (needs the relevant API tokens in env)
./bin/pergamino-deploy apply  --intake ./client.yaml

# include the server-dependent steps once the host is wired
./bin/pergamino-deploy apply  --intake ./client.yaml --allow-server

# just re-run the verifiers and print the install report
./bin/pergamino-deploy verify --intake ./client.yaml
```

Tokens are read from the environment (never the intake file):
`GITHUB_TOKEN`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `STRIPE_SECRET_KEY`.
A step with a missing token degrades to dry-run for that step and says so.

## The intake file

`/pergamino-intake` (the kit's interview skill) produces this. See
`intake.example.yaml` for the schema and the supported YAML subset. JSON is
also accepted (`--intake client.json`).

## Step contract

Every file in `steps/` default-exports:

```js
export default {
  id: 'repos',
  title: 'GitHub role repos',
  serverDependent: false,
  async apply(ctx) { /* idempotent; respects ctx.apply + ctx.env tokens */ },
  async verify(ctx) { return { ok: true, detail: 'all repos exist' } },
}
```

`ctx` = `{ intake, env, apply, allowServer, log }`. The runner applies each
step (or logs the intent in dry-run), then polls `verify()` with backoff until
it returns `{ ok: true }` or attempts are exhausted, then prints a one-screen
install report. Steps are ordered in `steps/index.mjs`.

## Adopting cf CLI conventions

Per the vault note `cf-cli-local-explorer`, the verb/flag surface mirrors
Cloudflare's `cf`: `plan`/`apply`/`verify` verbs, `--json` for machine output,
`--dry-run` default, explicit `--apply` to mutate. Keep new flags in that idiom
so agents read this CLI and `cf` natively.

## Requirements

Node 18+ (uses built-in `fetch`). Zero runtime dependencies — the YAML reader
is a small built-in subset parser (`lib/core.mjs`).
