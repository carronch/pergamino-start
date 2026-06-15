// Brain seed — stage the two-pergamino structure (MainBrain + LLMBrain) from
// the kit's templates, with {{SLUG}} substituted. Server-agnostic: writes a
// staging tree under ./.pergamino/<slug>/ that the server step later ships.

import { mkdirSync, existsSync, writeFileSync, readdirSync, copyFileSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const KIT = join(HERE, '..', '..');               // pergamino-start/

const MAIN_DIRS = ['beliefs', 'principles', 'life-decisions', 'leadership'];
const LLM_DIRS = ['raw', 'wiki', 'outputs/mainvault-pending'];

function stageRoot(intake) { return join(process.cwd(), '.pergamino', intake.client.slug); }
function mainDir(intake) { return join(stageRoot(intake), `Main${intake.client.slug}Brain`); }
function llmDir(intake) { return join(stageRoot(intake), `LLM${intake.client.slug}Brain`); }

export default {
  id: 'brain-seed',
  title: 'Two-brain seed (from kit templates)',
  serverDependent: false,

  async apply(ctx) {
    const { intake, apply, log } = ctx;
    const root = stageRoot(intake);
    if (!apply) { log.dry(`would stage Main/LLM brains at ${root}`); return; }

    for (const d of MAIN_DIRS) mkdirSync(join(mainDir(intake), d), { recursive: true });
    for (const d of LLM_DIRS) mkdirSync(join(llmDir(intake), d), { recursive: true });

    // seed the per-role rules-of-the-house from templates/<seed_from>
    const seedFrom = join(KIT, 'templates', intake.repos?.seed_from || 'agents-md-library');
    if (existsSync(seedFrom)) {
      const dest = join(llmDir(intake), 'agents-md-library');
      mkdirSync(dest, { recursive: true });
      for (const f of readdirSync(seedFrom)) {
        const src = join(seedFrom, f);
        if (statSync(src).isFile()) copyFileSync(src, join(dest, f));
      }
      log.info(`seeded rules-of-the-house from templates/${intake.repos?.seed_from || 'agents-md-library'}`);
    } else {
      log.warn(`seed templates not found at ${seedFrom}`);
    }

    // first inscription stub
    const why = join(mainDir(intake), 'beliefs', 'why-pergamino.md');
    if (!existsSync(why)) {
      writeFileSync(why, `# why-pergamino\n\n_(${intake.client.name}: three sentences in your own voice. Why are you doing this?)_\n`);
    }
    log.info(`staged at ${root}`);
  },

  async verify(ctx) {
    const { intake } = ctx;
    const ok = existsSync(mainDir(intake)) && existsSync(llmDir(intake));
    return ok
      ? { ok: true, detail: `two-brain seed staged for ${intake.client.slug}` }
      : { ok: false, detail: 'brain seed not staged yet (run apply)' };
  },
};
