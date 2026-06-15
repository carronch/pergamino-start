// Cloudflare Access — one self-hosted Access application per role path,
// gating the reading layer (Quartz). Server-agnostic (CF is API-only).
// Needs CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID; degrades without them.

const API = 'https://api.cloudflare.com/client/v4';

async function cf(token, method, path, body) {
  const res = await fetch(API + path, {
    method,
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  return res.json();
}

function appsFor(intake) {
  const domain = intake.cloudflare?.access_domain;
  const paths = intake.cloudflare?.paths || [];
  return paths.map((p) => ({ path: p, name: `${intake.client.slug}${p}`, domain }));
}

export default {
  id: 'cf-access',
  title: 'Cloudflare Access (role paths)',
  serverDependent: false,

  async apply(ctx) {
    const { intake, env, apply, log } = ctx;
    const token = env.CLOUDFLARE_API_TOKEN;
    const account = env.CLOUDFLARE_ACCOUNT_ID;
    const apps = appsFor(intake);
    if (!apps.length) { log.warn('no cloudflare.paths in intake — nothing to gate'); return; }
    for (const a of apps) {
      if (!token || !account || !apply) { log.dry(`would create Access app for ${a.domain}${a.path}`); continue; }
      const out = await cf(token, 'POST', `/accounts/${account}/access/apps`, {
        name: a.name, domain: `${a.domain}${a.path}`, type: 'self_hosted',
        session_duration: '24h',
      });
      if (!out.success) throw new Error(`Access app ${a.name} failed: ${JSON.stringify(out.errors)}`);
      log.info(`created Access app ${a.name}`);
    }
  },

  async verify(ctx) {
    const { intake, env } = ctx;
    const token = env.CLOUDFLARE_API_TOKEN;
    const account = env.CLOUDFLARE_ACCOUNT_ID;
    const apps = appsFor(intake);
    if (!token || !account)
      return { ok: true, detail: `(no CF token/account) would gate ${apps.length} role path(s)` };
    const out = await cf(token, 'GET', `/accounts/${account}/access/apps`);
    const have = new Set((out.result || []).map((r) => r.domain));
    const missing = apps.filter((a) => !have.has(`${a.domain}${a.path}`)).map((a) => a.path);
    return missing.length
      ? { ok: false, detail: `Access apps missing for: ${missing.join(', ')}` }
      : { ok: true, detail: `${apps.length} Access app(s) present` };
  },
};
