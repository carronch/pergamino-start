// GitHub role repos — one private repo per role = folder-level access boundary.
// Server-agnostic. Needs GITHUB_TOKEN; degrades to dry-run without it.

const API = 'https://api.github.com';

function repoNames(intake) {
  const { slug } = intake.client;
  return intake.roles.map((role) => ({ role, name: `${slug}-${role}` }));
}

async function gh(token, method, path, body) {
  const res = await fetch(API + path, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      accept: 'application/vnd.github+json',
      'x-github-api-version': '2022-11-28',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return res;
}

export default {
  id: 'repos',
  title: 'GitHub role repos',
  serverDependent: false,

  async apply(ctx) {
    const { intake, env, apply, log } = ctx;
    const token = env.GITHUB_TOKEN;
    const org = intake.repos.org;
    const visibility = intake.repos.visibility || 'private';
    for (const { role, name } of repoNames(intake)) {
      if (!token) { log.dry(`would ensure ${org}/${name} (${visibility})`); continue; }
      if (!apply) { log.dry(`would ensure ${org}/${name} (${visibility})`); continue; }
      const exists = (await gh(token, 'GET', `/repos/${org}/${name}`)).ok;
      if (exists) { log.info(`${org}/${name} already exists`); continue; }
      const res = await gh(token, 'POST', `/orgs/${org}/repos`, {
        name, private: visibility !== 'public',
        description: `pergamino brain — ${intake.client.name} / ${role}`,
        auto_init: true,
      });
      if (!res.ok) throw new Error(`create ${name} failed: ${res.status} ${await res.text()}`);
      log.info(`created ${org}/${name}`);
    }
  },

  async verify(ctx) {
    const { intake, env } = ctx;
    const token = env.GITHUB_TOKEN;
    const names = repoNames(intake);
    if (!token) return { ok: true, detail: `(no GITHUB_TOKEN) would manage ${names.length} repos under ${intake.repos.org}` };
    const missing = [];
    for (const { name } of names) {
      if (!(await gh(token, 'GET', `/repos/${intake.repos.org}/${name}`)).ok) missing.push(name);
    }
    return missing.length
      ? { ok: false, detail: `missing repos: ${missing.join(', ')}` }
      : { ok: true, detail: `${names.length} role repos present under ${intake.repos.org}` };
  },
};
