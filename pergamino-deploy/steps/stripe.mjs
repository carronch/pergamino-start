// Billing — the flat $1k/mo per-company subscription (≤10 seats, AI bundled,
// no per-user, no commission) + optional one-time pilot + customer portal.
// Server-agnostic. Needs STRIPE_SECRET_KEY; degrades to dry-run without it.
// See vault: 2026-06-09-pergamino-llm-billing-architecture.

const API = 'https://api.stripe.com/v1';

async function stripe(key, method, path, params) {
  const body = params
    ? Object.entries(params).map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&')
    : undefined;
  const res = await fetch(API + path, {
    method,
    headers: { authorization: `Bearer ${key}`, 'content-type': 'application/x-www-form-urlencoded' },
    body,
  });
  return res.json();
}

const customerKey = (intake) => `pergamino:${intake.client.slug}`;

export default {
  id: 'stripe',
  title: 'Billing (flat subscription + portal)',
  serverDependent: false,

  async apply(ctx) {
    const { intake, env, apply, log } = ctx;
    const key = env.STRIPE_SECRET_KEY;
    const plan = intake.billing?.plan;
    if (!plan) { log.warn('no billing.plan in intake — skipping'); return; }
    if (!key || !apply) {
      log.dry(`would ensure customer "${intake.client.name}" + subscription to "${plan}"`);
      if (intake.billing?.pilot_one_time) log.dry('would create the one-time pilot invoice');
      if (intake.billing?.portal) log.dry('would generate a customer-portal link');
      return;
    }
    // find-or-create customer (idempotent via metadata lookup)
    const found = await stripe(key, 'GET', `/customers/search?query=${encodeURIComponent(`metadata['pergamino']:'${intake.client.slug}'`)}`);
    let customer = found.data?.[0];
    if (!customer) {
      customer = await stripe(key, 'POST', '/customers', {
        name: intake.client.name, 'metadata[pergamino]': intake.client.slug,
      });
      log.info(`created customer ${customer.id}`);
    } else log.info(`customer ${customer.id} already exists`);
    log.info(`subscription to plan "${plan}" — wire the price id, then create subscription`);
  },

  async verify(ctx) {
    const { intake, env } = ctx;
    const key = env.STRIPE_SECRET_KEY;
    if (!key) return { ok: true, detail: `(no STRIPE_SECRET_KEY) would bill ${customerKey(intake)} on "${intake.billing?.plan}"` };
    const found = await stripe(key, 'GET', `/customers/search?query=${encodeURIComponent(`metadata['pergamino']:'${intake.client.slug}'`)}`);
    const customer = found.data?.[0];
    if (!customer) return { ok: false, detail: 'stripe customer not found' };
    const subs = await stripe(key, 'GET', `/subscriptions?customer=${customer.id}&status=active`);
    return subs.data?.length
      ? { ok: true, detail: `active subscription for ${customer.id}` }
      : { ok: false, detail: `customer ${customer.id} has no active subscription` };
  },
};
