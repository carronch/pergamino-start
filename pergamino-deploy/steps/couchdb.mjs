// CouchDB — one container per client on the operator's managed server (the sync
// substrate for the LLM brain via LiveSync). SERVER-DEPENDENT: blocked on the host
// decision (fly.io vs VPS). The runner skips
// this unless --allow-server. Contract is in place so wiring is a one-file job.
//
// TODO when host is decided:
//   - fly.io:  `flyctl apps create pergamino-<slug>` + a couchdb image + volume
//   - VPS:     `docker run -d --name couch-<slug> -v ... couchdb:3 ...`
//   then create one DB per role (sync.couchdb.db_per_role) + a replication user.

export default {
  id: 'couchdb',
  title: 'CouchDB per-client container',
  serverDependent: true,

  async apply(ctx) {
    const host = ctx.intake.sync?.couchdb?.host;
    if (!host || host === 'TBD') {
      throw new Error('couchdb host not set (sync.couchdb.host=TBD) — decide fly.io vs VPS first');
    }
    throw new Error(`couchdb provisioner not implemented for host "${host}" — pending Sprint-1 server decision`);
  },

  async verify(ctx) {
    const host = ctx.intake.sync?.couchdb?.host;
    return { ok: false, detail: `couchdb not provisioned (host=${host ?? 'unset'}) — pending server decision` };
  },
};
