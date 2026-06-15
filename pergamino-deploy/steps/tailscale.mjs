// Tailscale — tailnet-per-client (locked decision). Enroll the client's
// devices with auth keys + push an ACL stanza scoping access by role.
// SERVER-DEPENDENT: the tailnet is operated alongside the managed server, so
// it waits on the same host decision. Runner skips unless --allow-server.
//
// TODO when wired (all by Tailscale API, token in env TS_API_KEY):
//   - POST /api/v2/tailnet/<tailnet>/keys        → reusable, ephemeral auth key
//   - POST /api/v2/tailnet/<tailnet>/acl         → role->tag grants
//   - hand the auth key to the device self-enroll script in bootstrap.sh

export default {
  id: 'tailscale',
  title: 'Tailnet enroll + ACLs',
  serverDependent: true,

  async apply(ctx) {
    const tailnet = ctx.intake.sync?.tailscale?.tailnet;
    if (!tailnet) throw new Error('sync.tailscale.tailnet not set in intake');
    throw new Error(`tailscale provisioner not implemented — pending server decision (tailnet "${tailnet}")`);
  },

  async verify(ctx) {
    const tailnet = ctx.intake.sync?.tailscale?.tailnet;
    return { ok: false, detail: `tailnet "${tailnet ?? 'unset'}" not provisioned — pending server decision` };
  },
};
