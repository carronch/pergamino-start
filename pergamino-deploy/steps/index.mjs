// Ordered playbook. The runner walks these top-to-bottom.
// Server-agnostic steps run anywhere; server-dependent steps are skipped
// unless --allow-server (and stay stubbed until the host is decided).
import repos from './repos.mjs';
import cfAccess from './cf-access.mjs';
import stripe from './stripe.mjs';
import brainSeed from './brain-seed.mjs';
import couchdb from './couchdb.mjs';
import tailscale from './tailscale.mjs';

export default [
  brainSeed,   // 1. stage the two-brain seed from kit templates
  repos,       // 2. GitHub role repos (folder-level access boundaries)
  cfAccess,    // 3. Cloudflare Access apps per role path (outside-in)
  couchdb,     // 4. per-client CouchDB container        (server-dependent)
  tailscale,   // 5. tailnet enroll + ACLs               (server-dependent)
  stripe,      // 6. billing: flat subscription + portal
];
