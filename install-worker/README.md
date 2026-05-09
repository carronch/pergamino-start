# pergamino-install

Cloudflare Worker that serves the pergamino bootstrap script at
`https://pergamino.ai/install`.

## What it does

```
curl -fsSL pergamino.ai/install | bash
       │
       ▼
   Cloudflare edge
       │
       ▼  (cached 5 min)
   GitHub raw bootstrap.sh
       │
       ▼
   bash on the user's machine
```

The Worker fetches `bootstrap.sh` from the public GitHub URL, caches it
at the edge for 5 minutes, and returns it with `Content-Type:
text/x-shellscript`. If the upstream fetch fails, it returns a tiny
fallback script that tells the user to use the direct GitHub URL —
much friendlier than a raw HTTP error in the middle of `curl | bash`.

## Endpoints

| Path | Returns |
|---|---|
| `GET /install` | the bootstrap.sh script |
| `GET /install/` | same (trailing slash tolerated) |
| `GET /install/health` | `ok` (for uptime monitoring) |
| anything else | 404 |

## Config

`wrangler.toml` carries:

- The route binding `pergamino.ai/install*` on zone `pergamino.ai`.
- `BOOTSTRAP_URL` — the GitHub raw URL to fetch.
- `CACHE_TTL_SECONDS` — edge cache duration (default 300 = 5 min).

To point at a different repo (forks, testing branches), edit
`BOOTSTRAP_URL` in `wrangler.toml` and redeploy.

## Deploy

From this folder:

```sh
wrangler deploy
```

Wrangler uses the OAuth credentials from `wrangler login`. The route
binding requires `workers_routes:write` permission on the account
hosting the `pergamino.ai` zone.

## Test after deploy

```sh
# Health check
curl -fsSL https://pergamino.ai/install/health
# expected: ok

# Inspect the bootstrap script (don't pipe to bash yet)
curl -fsSL https://pergamino.ai/install | head -30
# expected: header comment + start of bootstrap.sh

# Full bootstrap (the user-facing one-liner)
curl -fsSL pergamino.ai/install | bash
```

## Cache invalidation

When the bootstrap.sh changes on GitHub, the edge cache holds the old
copy for up to `CACHE_TTL_SECONDS`. To force-refresh, either:

1. Redeploy the worker (clears the per-deployment cache), or
2. Hit the URL with a unique query string:
   `curl -fsSL "pergamino.ai/install?v=$(date +%s)" | bash`

Cache-busting via query string works because `cf.cacheEverything` keys
on the full URL.

## Cost

Free Cloudflare Worker plan covers up to 100,000 requests per day.
The pergamino install endpoint is unlikely to exceed that; even at
10 installs per minute (a moment of viral attention), it's ~14k/day.

If usage exceeds the free tier, the Workers Paid plan is $5/month for
10M requests.

## Operational notes

- **Don't put secrets here.** This worker reads a public URL and serves
  a public script. Anything in `wrangler.toml` `[vars]` is visible to
  anyone who runs `wrangler tail`.
- **Telemetry**: not implemented in v1. To add install counters,
  bind a KV namespace and increment on each request. Don't log
  IPs or user agents — running an install script is not consent for
  tracking.
- **OS-aware variants**: not needed in v1. The bootstrap.sh handles
  OS detection internally. If we ever want different scripts per
  platform, the worker can branch on `User-Agent` or a query param
  before fetching from GitHub.
