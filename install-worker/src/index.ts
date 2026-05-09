/**
 * pergamino-install — Cloudflare Worker
 *
 * Serves the bootstrap.sh installer at https://pergamino.ai/install.
 * Fetches the script from GitHub, caches at the edge, returns with the
 * right Content-Type so `curl -fsSL pergamino.ai/install | bash` works.
 *
 * Endpoints:
 *   GET /install         → bootstrap.sh (text/x-shellscript)
 *   GET /install/        → bootstrap.sh
 *   GET /install/health  → "ok" (uptime check)
 *   anything else        → 404
 */

interface Env {
  BOOTSTRAP_URL: string;
  CACHE_TTL_SECONDS: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";

    // Health check
    if (path === "/install/health") {
      return new Response("ok\n", {
        status: 200,
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      });
    }

    // Only /install is served
    if (path !== "/install") {
      return new Response("Not Found\n", {
        status: 404,
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      });
    }

    const cacheTtl = parseInt(env.CACHE_TTL_SECONDS, 10) || 300;

    // Fetch from GitHub with edge caching
    let upstream: Response;
    try {
      upstream = await fetch(env.BOOTSTRAP_URL, {
        cf: { cacheTtl, cacheEverything: true },
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return errorScript(`fetch failed: ${msg}`, 502, env.BOOTSTRAP_URL);
    }

    if (!upstream.ok) {
      return errorScript(`upstream ${upstream.status}`, 502, env.BOOTSTRAP_URL);
    }

    const body = await upstream.text();

    return new Response(body, {
      status: 200,
      headers: {
        "Content-Type": "text/x-shellscript; charset=utf-8",
        "Cache-Control": `public, max-age=${cacheTtl}`,
        "X-Pergamino-Source": "github",
      },
    });
  },
};

/**
 * When the upstream fetch fails, return a script that prints a clear
 * error to the user instead of a hostile HTTP error. This way
 * `curl … | bash` shows an actionable message in the terminal.
 */
function errorScript(reason: string, status: number, fallbackUrl: string): Response {
  const body =
    `#!/usr/bin/env bash\n` +
    `# Pergamino install endpoint hit an upstream error.\n` +
    `echo "[pergamino] install endpoint error: ${reason}" >&2\n` +
    `echo "[pergamino] try the direct URL instead:" >&2\n` +
    `echo "    curl -fsSL ${fallbackUrl} | bash" >&2\n` +
    `exit 1\n`;
  return new Response(body, {
    status,
    headers: {
      "Content-Type": "text/x-shellscript; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}
