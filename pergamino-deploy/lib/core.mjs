// pergamino-deploy — core: logging, minimal YAML reader, intake, runner.
// Zero runtime dependencies. Node 18+ (built-in fetch).

import { readFileSync } from 'node:fs';

// ── logging (matches the kit's bash style) ───────────────────────────────
const tty = process.stdout.isTTY;
const c = (n) => (s) => (tty ? `\x1b[${n}m${s}\x1b[0m` : s);
const cyan = c(36), green = c(32), yellow = c(33), red = c(31), dim = c(2), bold = c(1);

export const log = {
  step: (s) => console.log(`\n${bold(cyan('▸ ' + s))}`),
  ok:   (s) => console.log(`  ${green('✓')}  ${s}`),
  warn: (s) => console.log(`  ${yellow('⚠')}  ${s}`),
  err:  (s) => console.error(`  ${red('✗')}  ${s}`),
  dry:  (s) => console.log(`  ${dim('·')}  ${dim('[dry-run] ' + s)}`),
  info: (s) => console.log(`     ${dim(s)}`),
};

// ── minimal YAML-subset parser ───────────────────────────────────────────
// Supports: comments, key: value, nested maps by 2-space indent, `- scalar`
// lists, and `- key: value` lists of one-level maps. Good enough for the
// intake schema; JSON is the escape hatch for anything richer.
function coerce(v) {
  if (v === '' || v === '~' || v === 'null') return null;
  if (v === 'true') return true;
  if (v === 'false') return false;
  if (/^-?\d+(\.\d+)?$/.test(v)) return Number(v);
  if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'")))
    return v.slice(1, -1);
  return v;
}

export function parseYaml(text) {
  const lines = text.split('\n')
    .map((l) => l.replace(/\t/g, '  '))
    .filter((l) => l.trim() !== '' && !l.trim().startsWith('#'))
    .map((l) => l.replace(/\s+#.*$/, '')); // strip trailing comments

  let i = 0;
  function parseBlock(indent) {
    // list?
    if (i < lines.length && lines[i].slice(indent).startsWith('- ')) {
      const arr = [];
      while (i < lines.length) {
        const cur = lines[i];
        const curIndent = cur.length - cur.trimStart().length;
        if (curIndent !== indent || !cur.slice(indent).startsWith('- ')) break;
        const rest = cur.slice(indent + 2);
        if (rest.includes(':')) {
          // one-level map item, possibly multi-key on following deeper lines
          i++;
          const obj = {};
          const [k, ...vp] = rest.split(':');
          obj[k.trim()] = coerce(vp.join(':').trim());
          while (i < lines.length) {
            const nl = lines[i];
            const nlIndent = nl.length - nl.trimStart().length;
            if (nlIndent <= indent) break;
            const [nk, ...nv] = nl.trim().split(':');
            obj[nk.trim()] = coerce(nv.join(':').trim());
            i++;
          }
          arr.push(obj);
        } else {
          arr.push(coerce(rest.trim()));
          i++;
        }
      }
      return arr;
    }
    // map
    const obj = {};
    while (i < lines.length) {
      const cur = lines[i];
      const curIndent = cur.length - cur.trimStart().length;
      if (curIndent < indent) break;
      if (curIndent > indent) { i++; continue; } // safety
      const [k, ...vp] = cur.trim().split(':');
      const val = vp.join(':').trim();
      if (val === '') {
        i++;
        obj[k.trim()] = parseBlock(indent + 2);
      } else {
        obj[k.trim()] = coerce(val);
        i++;
      }
    }
    return obj;
  }
  return parseBlock(0);
}

// ── intake load + validate ───────────────────────────────────────────────
export function loadIntake(path) {
  const raw = readFileSync(path, 'utf8');
  const data = path.endsWith('.json') ? JSON.parse(raw) : parseYaml(raw);
  const errors = [];
  const need = (p) => { if (!p.split('.').reduce((o, k) => o?.[k], data)) errors.push(p); };
  need('client.slug'); need('client.name'); need('roles'); need('repos.org');
  if (errors.length) {
    throw new Error(`intake is missing required fields: ${errors.join(', ')}`);
  }
  if (!/^[a-z0-9-]+$/.test(data.client.slug))
    throw new Error(`client.slug must be kebab-case: got "${data.client.slug}"`);
  return data;
}

// ── runner: apply then poll verify() until green ─────────────────────────
async function verifyWithRetry(step, ctx, { attempts = 5, baseMs = 800 } = {}) {
  let last = { ok: false, detail: 'not run' };
  for (let n = 1; n <= attempts; n++) {
    try {
      last = await step.verify(ctx);
    } catch (e) {
      last = { ok: false, detail: e.message };
    }
    if (last.ok) return last;
    if (n < attempts) {
      const wait = baseMs * n;
      log.info(`verify not green yet (${last.detail}) — retry ${n}/${attempts - 1} in ${wait}ms`);
      await new Promise((r) => setTimeout(r, wait));
    }
  }
  return last;
}

export async function runPlan(steps, ctx, { verifyOnly = false } = {}) {
  const report = [];
  for (const step of steps) {
    log.step(step.title + (step.serverDependent ? dim('  (server-dependent)') : ''));
    if (step.serverDependent && !ctx.allowServer) {
      log.warn('skipped — server host not decided. Re-run with --allow-server once wired.');
      report.push({ id: step.id, status: 'skipped' });
      continue;
    }
    try {
      if (!verifyOnly) {
        if (ctx.apply) await step.apply(ctx);
        else { ctx.log.dry(`would apply: ${step.id}`); await step.apply({ ...ctx, apply: false }); }
      }
      // Backoff polling only pays off right after a real apply (resources take
      // time to settle). In plan/verify we want a single status pass.
      const v = await verifyWithRetry(step, ctx, { attempts: ctx.apply ? 5 : 1 });
      if (v.ok) { log.ok(v.detail); report.push({ id: step.id, status: 'ok', detail: v.detail }); }
      else { log.err(v.detail); report.push({ id: step.id, status: 'failed', detail: v.detail }); }
    } catch (e) {
      log.err(e.message);
      report.push({ id: step.id, status: 'failed', detail: e.message });
    }
  }
  return report;
}

export function printReport(report, { json = false } = {}) {
  if (json) { console.log(JSON.stringify(report, null, 2)); return; }
  console.log(`\n${bold('── install report ──')}`);
  const mark = { ok: green('✓'), failed: red('✗'), skipped: yellow('—') };
  for (const r of report) console.log(`  ${mark[r.status] || '?'}  ${r.id}${r.detail ? dim('  ' + r.detail) : ''}`);
  const failed = report.filter((r) => r.status === 'failed').length;
  const skipped = report.filter((r) => r.status === 'skipped').length;
  console.log(failed
    ? `\n${red(bold(`✗ ${failed} step(s) not green — brain is NOT ready.`))}`
    : `\n${green(bold('✓ all green' + (skipped ? ` (${skipped} server step(s) deferred)` : '') + ' — brain ready.'))}`);
  return failed === 0;
}
