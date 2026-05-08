/**
 * pergamino-heartbeat — Cloudflare Worker
 *
 * One Worker per client. Provisioned by `pergamino-deploy new <slug>`.
 *
 * Responsibilities:
 *   1. Cron(reviewer-digest)   — pre-analyze pending GitHub PRs, send WhatsApp digest to reviewers.
 *   2. Cron(user-nudge)        — scan workspace for promote-worthy items, send per-user nudge.
 *   3. Cron(customer-bot-weekly) — review customer-facing knowledge gaps, propose FAQ updates as PRs.
 *   4. Webhook(/whatsapp-reply) — handle BULK APPROVE / approve N / reject N / ASK X messages.
 *   5. Webhook(/whatsapp-customer) — Meta Cloud API webhook for inbound customer messages (concierge).
 *   6. Webhook(/github)        — GitHub PR events (e.g., reviewer-AI runs on every PR open, not just digest time).
 *
 * Cost model: client's Anthropic API key. Each PR = ~$0.005 (Haiku) to ~$0.05 (Sonnet).
 * 12-person client at 50 PRs/week = ~$6/month. Negligible.
 */

// ============================================================================
// Types
// ============================================================================

interface Env {
  PERGAMINO_KV: KVNamespace;
  PERGAMINO_DB: D1Database;

  // secrets
  ANTHROPIC_API_KEY: string;
  GITHUB_TOKEN: string;
  WHATSAPP_TOKEN: string;
  WHATSAPP_PHONE_ID: string;
  WHATSAPP_VERIFY_TOKEN: string;
  REVIEWER_AGENTS_REPO: string;

  // vars
  CLIENT_SLUG: string;
  CLIENT_DISPLAY: string;
  CLIENT_TZ: string;
  BRAIN_CANON_REPO: string;
  REVIEWER_DIGEST_RECIPIENTS: string;
  USER_NUDGE_RECIPIENTS: string;
  CUSTOMER_FACING_ENABLED: string;
  LLM_MODEL_DEFAULT: string;
  LLM_MODEL_CHEAP: string;
}

interface PRSummary {
  number: number;
  title: string;
  author: string;
  authorScope: string;
  targetPaths: string[];
  targetScopes: string[];
  isCrossScope: boolean;
  diff: string;
  body: string;
}

interface ReviewVerdict {
  prNumber: number;
  verdict: "approve" | "needs-eyes" | "reject";
  confidence: "high" | "medium" | "low";
  reasoning: string;
  flags: string[];
  crossScope: { sourceScope: string; targetScope: string; suggestedReviewer: string } | null;
  suggestedReviewer: string;
}

// ============================================================================
// Entry point
// ============================================================================

export default {
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    const cron = event.cron;
    console.log(`[heartbeat] cron fired: ${cron}`);

    // Map cron pattern → handler. Patterns set in wrangler.toml.
    if (cron === "30 14 * * 1-5") {
      await runReviewerDigest(env);
    } else if (cron === "0 0 * * 2-6") {
      await runUserNudge(env);
    } else if (cron === "0 3 * * 1") {
      await runCustomerBotWeekly(env);
    }
  },

  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === "/whatsapp-reply") return handleWhatsAppReply(req, env);
    if (url.pathname === "/whatsapp-customer") return handleWhatsAppCustomer(req, env);
    if (url.pathname === "/github") return handleGitHubWebhook(req, env);
    if (url.pathname === "/health") return new Response("ok");
    return new Response("not found", { status: 404 });
  },
};

// ============================================================================
// Reviewer digest (cron, weekday 8:30am local)
// ============================================================================

async function runReviewerDigest(env: Env): Promise<void> {
  // 1. Fetch open PRs from brain-canon
  const prs = await fetchOpenPRs(env);
  if (prs.length === 0) return;

  // 2. For each PR, run the appropriate reviewer-agent
  const verdicts: ReviewVerdict[] = [];
  for (const pr of prs) {
    const verdict = await reviewPR(pr, env);
    verdicts.push(verdict);
    // Persist to D1 for the dashboard
    await env.PERGAMINO_DB.prepare(
      `INSERT INTO pr_reviews (pr_number, verdict, confidence, reasoning, flags, ts)
       VALUES (?, ?, ?, ?, ?, ?)`
    )
      .bind(verdict.prNumber, verdict.verdict, verdict.confidence, verdict.reasoning, JSON.stringify(verdict.flags), Date.now())
      .run();
  }

  // 3. Compose the digest
  const recipients = env.REVIEWER_DIGEST_RECIPIENTS.split(",").map((s) => s.trim());
  const digestBody = composeDigest(verdicts, env);

  // 4. Deliver via WhatsApp to each recipient
  for (const recipient of recipients) {
    const phone = await resolvePhoneFromEmail(recipient, env);
    if (phone) await sendWhatsApp(phone, digestBody, env);
  }

  // 5. Cache pending-approval map for the BULK APPROVE webhook
  const pendingMap = verdicts
    .filter((v) => v.verdict === "approve")
    .reduce((acc, v) => ({ ...acc, [v.prNumber]: true }), {} as Record<number, boolean>);
  await env.PERGAMINO_KV.put("pending-bulk-approve", JSON.stringify(pendingMap), { expirationTtl: 86400 });
}

// ============================================================================
// Per-PR review (calls Claude with the right reviewer-agent prompt)
// ============================================================================

async function reviewPR(pr: PRSummary, env: Env): Promise<ReviewVerdict> {
  // 1. Determine which scope-specific reviewer applies (path-based)
  const targetScope = pr.targetScopes[0] ?? "company";
  const reviewerFile = `${targetScope}-reviewer.md`;

  // 2. Load reviewer-agent prompts (base + scope-specific) from the reviewer-agents repo
  const baseReviewer = await fetchReviewerAgent("_base-reviewer.md", env);
  const scopeReviewer = await fetchReviewerAgent(reviewerFile, env);
  const scopeAgentsMd = await fetchCanonFile(`${targetScope}/AGENTS.md`, env);

  // 3. If cross-scope, also load the cross-scope reviewer
  let crossReviewer = "";
  if (pr.isCrossScope) {
    crossReviewer = await fetchReviewerAgent("cross-scope-reviewer.md", env);
  }

  // 4. Compose system prompt
  const systemPrompt = [baseReviewer, scopeReviewer, crossReviewer, `## Target scope's AGENTS.md\n\n${scopeAgentsMd}`].join("\n\n---\n\n");

  // 5. User message: the PR
  const userMsg = `# PR #${pr.number} — ${pr.title}\n\n## Description\n\n${pr.body}\n\n## Diff\n\n${pr.diff}`;

  // 6. Call Claude. Use Sonnet for high-stakes scopes, Haiku for routine.
  const model = ["customer-facing", "finance"].includes(targetScope) ? env.LLM_MODEL_DEFAULT : env.LLM_MODEL_CHEAP;
  const response = await callClaude(systemPrompt, userMsg, model, env);

  // 7. Parse the structured Markdown output into a verdict
  return parseVerdict(response, pr);
}

async function callClaude(systemPrompt: string, userMsg: string, model: string, env: Env): Promise<string> {
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model,
      max_tokens: 2048,
      system: systemPrompt,
      messages: [{ role: "user", content: userMsg }],
    }),
  });
  if (!r.ok) throw new Error(`Anthropic API: ${r.status} ${await r.text()}`);
  const data: any = await r.json();
  return data.content[0].text;
}

// Parse the reviewer-agent's structured Markdown output (per _base-reviewer.md schema)
function parseVerdict(text: string, pr: PRSummary): ReviewVerdict {
  const verdictMatch = text.match(/## Verdict\s*\n+\s*([✅⚠️🚫])/);
  const confidenceMatch = text.match(/## Confidence\s*\n+\s*(high|medium|low)/);
  const reasoningMatch = text.match(/## Reasoning\s*\n+([^#]+?)(?=\n##|$)/s);
  const flagsBlock = text.match(/## Flags\s*\n+([^#]+?)(?=\n##|$)/s);
  const reviewerMatch = text.match(/## Suggested reviewer\s*\n+([^\n#]+)/);

  const emojiToVerdict: Record<string, ReviewVerdict["verdict"]> = {
    "✅": "approve",
    "⚠️": "needs-eyes",
    "🚫": "reject",
  };
  const verdict = emojiToVerdict[verdictMatch?.[1] ?? "⚠️"] ?? "needs-eyes";

  const flags = (flagsBlock?.[1] ?? "")
    .split("\n")
    .map((line) => line.replace(/^\s*-\s*/, "").trim())
    .filter((line) => line && line !== "(none)");

  return {
    prNumber: pr.number,
    verdict,
    confidence: (confidenceMatch?.[1] ?? "medium") as any,
    reasoning: reasoningMatch?.[1]?.trim() ?? "",
    flags,
    crossScope: null, // populated if cross-scope-reviewer ran; parser TBD
    suggestedReviewer: reviewerMatch?.[1]?.trim() ?? "self",
  };
}

// ============================================================================
// Compose the WhatsApp digest message from verdicts
// ============================================================================

function composeDigest(verdicts: ReviewVerdict[], env: Env): string {
  const ok = verdicts.filter((v) => v.verdict === "approve");
  const warn = verdicts.filter((v) => v.verdict === "needs-eyes");
  const reject = verdicts.filter((v) => v.verdict === "reject");

  const dayName = new Date().toLocaleDateString("en-US", { weekday: "long" });

  let body = `🌅 ${env.CLIENT_DISPLAY} — ${dayName} review\n${verdicts.length} item${verdicts.length === 1 ? "" : "s"} waiting (~${Math.ceil(verdicts.length * 2)} min total)\n\n`;

  if (ok.length > 0) {
    body += `*Within-scope (recommend approve):*\n`;
    ok.forEach((v) => {
      body += `  ✅ #${v.prNumber} — ${v.reasoning.split(".")[0]}\n`;
    });
    body += "\n";
  }
  if (warn.length > 0) {
    body += `*Needs your eyes:*\n`;
    warn.forEach((v) => {
      body += `  ⚠ #${v.prNumber} — ${v.reasoning.split(".")[0]}\n`;
      if (v.flags.length > 0) {
        body += `      ${v.flags.slice(0, 2).join("; ")}\n`;
      }
    });
    body += "\n";
  }
  if (reject.length > 0) {
    body += `*Recommend reject:*\n`;
    reject.forEach((v) => {
      body += `  🚫 #${v.prNumber} — ${v.reasoning.split(".")[0]}\n`;
    });
    body += "\n";
  }

  body += `→ Reply *BULK APPROVE* to merge all ✅ items now.\n`;
  body += `→ Reply *N APPROVE* / *N REJECT* / *N ASK* for individual items.\n`;
  body += `→ Reply *SNOOZE* to push to tomorrow.\n`;
  return body;
}

// ============================================================================
// Webhook: WhatsApp replies (BULK APPROVE etc.)
// ============================================================================

async function handleWhatsAppReply(req: Request, env: Env): Promise<Response> {
  // Meta Cloud API webhook verification (GET) + POST events
  if (req.method === "GET") {
    const url = new URL(req.url);
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");
    if (mode === "subscribe" && token === env.WHATSAPP_VERIFY_TOKEN) {
      return new Response(challenge ?? "", { status: 200 });
    }
    return new Response("forbidden", { status: 403 });
  }

  const body: any = await req.json();
  const message = body?.entry?.[0]?.changes?.[0]?.value?.messages?.[0];
  if (!message) return new Response("no message", { status: 200 });

  const fromPhone = message.from;
  const text = (message.text?.body ?? "").trim();

  // Resolve phone → user identity (lookup in PERGAMINO_KV: phone -> email mapping)
  const userEmail = await env.PERGAMINO_KV.get(`phone:${fromPhone}`);
  if (!userEmail) {
    await sendWhatsApp(fromPhone, "Your phone is not registered with this brain. Contact your administrator.", env);
    return new Response("unknown sender", { status: 200 });
  }

  // Parse the command
  if (/^BULK APPROVE$/i.test(text) || /^APROBAR TODOS$/i.test(text)) {
    const pendingJson = await env.PERGAMINO_KV.get("pending-bulk-approve");
    const pending = pendingJson ? JSON.parse(pendingJson) : {};
    const prNumbers = Object.keys(pending).map(Number);
    for (const n of prNumbers) {
      await mergePR(n, env, `Bulk approved by ${userEmail}`);
    }
    await sendWhatsApp(fromPhone, `${prNumbers.length} item${prNumbers.length === 1 ? "" : "s"} merged ✓\nThank you.`, env);
    await env.PERGAMINO_KV.delete("pending-bulk-approve");
  } else if (/^(\d+)\s+APPROVE$/i.test(text)) {
    const n = parseInt(text.match(/^(\d+)/)![1]);
    await mergePR(n, env, `Approved via WhatsApp by ${userEmail}`);
    await sendWhatsApp(fromPhone, `#${n} merged ✓`, env);
  } else if (/^(\d+)\s+REJECT(?:\s+(.+))?$/i.test(text)) {
    const m = text.match(/^(\d+)\s+REJECT(?:\s+(.+))?$/i)!;
    const n = parseInt(m[1]);
    const reason = m[2] ?? "Rejected via WhatsApp";
    await closePR(n, env, reason);
    await sendWhatsApp(fromPhone, `#${n} closed.`, env);
  } else if (/^SNOOZE$/i.test(text)) {
    await sendWhatsApp(fromPhone, `Snoozed. Will retry tomorrow morning.`, env);
  } else {
    // Unknown command — log; don't reply (avoid bot-noise)
    console.log(`[heartbeat] unknown reply from ${userEmail}: ${text}`);
  }

  return new Response("ok", { status: 200 });
}

// ============================================================================
// Webhook: customer-facing concierge (inbound from real customers)
// ============================================================================

async function handleWhatsAppCustomer(req: Request, env: Env): Promise<Response> {
  if (env.CUSTOMER_FACING_ENABLED !== "true") {
    return new Response("customer-facing disabled for this client", { status: 200 });
  }

  if (req.method === "GET") {
    // verification
    const url = new URL(req.url);
    return new Response(url.searchParams.get("hub.challenge") ?? "", { status: 200 });
  }

  const body: any = await req.json();
  const message = body?.entry?.[0]?.changes?.[0]?.value?.messages?.[0];
  if (!message) return new Response("no message", { status: 200 });

  const fromPhone = message.from;
  const text = message.text?.body ?? "";

  // Load conversation history (last 20 turns)
  const history = await loadConversation(fromPhone, env);

  // Load customer-facing context
  const customerAgents = await fetchCanonFile("customer-facing/AGENTS.md", env);
  const customerCanon = await fetchCanonDir("customer-facing/", env); // FAQ + policies + pricing-public

  // Compose system prompt
  const systemPrompt = `${customerAgents}\n\n## Available canon\n\n${customerCanon}`;

  // Build messages history
  const messages = history.concat([{ role: "user", content: text }]);

  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: env.LLM_MODEL_DEFAULT,
      max_tokens: 1024,
      system: systemPrompt,
      messages,
    }),
  });

  const data: any = await response.json();
  const reply = data.content[0].text;

  // Send reply
  await sendWhatsApp(fromPhone, reply, env);

  // Save conversation turn
  await saveConversation(fromPhone, [
    { role: "user", content: text },
    { role: "assistant", content: reply },
  ], env);

  // Detect escalation marker (per customer-facing/AGENTS.md, the bot tags conversations)
  if (reply.toLowerCase().includes("connect you with our team") || reply.toLowerCase().includes("conectarte con")) {
    await env.PERGAMINO_DB.prepare(
      `INSERT INTO escalations (phone, last_message, ts) VALUES (?, ?, ?)`
    ).bind(fromPhone, text, Date.now()).run();
    // Notify ops head via separate channel
  }

  // Knowledge-gap detection: if reply included "I don't have that information"
  if (reply.toLowerCase().includes("don't have that information") || reply.toLowerCase().includes("no tengo esa información")) {
    await env.PERGAMINO_DB.prepare(
      `INSERT INTO knowledge_gaps (question, ts) VALUES (?, ?)`
    ).bind(text, Date.now()).run();
  }

  return new Response("ok", { status: 200 });
}

// ============================================================================
// Cron: user-nudge (end-of-day; scan workspace for promote-worthy items)
// ============================================================================

async function runUserNudge(env: Env): Promise<void> {
  // 1. List authorized users (from GitHub team membership)
  const users = await listTeamMembers(env);

  // 2. For each user, scan their workspace for un-promoted items
  //    (LiveSync DB query — items in working/ created today, not yet PR'd)
  for (const user of users) {
    const items = await scanWorkspaceForPromotionCandidates(user, env);
    if (items.length === 0) continue;

    const phone = await resolvePhoneFromEmail(user.email, env);
    if (!phone) continue;

    const msg = `📝 ${user.name}, ${items.length} item${items.length === 1 ? "" : "s"} worth promoting from today's work:\n\n` +
      items.slice(0, 5).map((it: any) => `  • ${it.title}`).join("\n") +
      `\n\nRun \`pergamino promote\` or open ${env.CLIENT_SLUG}.pergamino.app/promote to review.\nReply *SKIP* to dismiss.`;
    await sendWhatsApp(phone, msg, env);
  }
}

// ============================================================================
// Cron: customer-bot weekly review (knowledge gaps → FAQ proposals)
// ============================================================================

async function runCustomerBotWeekly(env: Env): Promise<void> {
  if (env.CUSTOMER_FACING_ENABLED !== "true") return;

  // 1. Fetch knowledge_gaps from D1 over the past week
  const result = await env.PERGAMINO_DB.prepare(
    `SELECT question, COUNT(*) as count FROM knowledge_gaps
     WHERE ts > ? GROUP BY question ORDER BY count DESC LIMIT 20`
  ).bind(Date.now() - 7 * 86400 * 1000).all();

  if (!result.results.length) return;

  // 2. Cluster questions (LLM call: "group these questions by topic")
  const clusterPrompt = `Below are customer questions our concierge couldn't answer this week. Cluster them by topic. For each cluster of 3+ questions, propose a FAQ entry.\n\n` +
    (result.results as any[]).map((r) => `(${r.count}×) ${r.question}`).join("\n");
  const proposals = await callClaude(
    "You are the customer-facing knowledge-gap analyzer. Output structured Markdown with a 'Proposed FAQ entries' section.",
    clusterPrompt,
    env.LLM_MODEL_DEFAULT,
    env
  );

  // 3. For each proposed FAQ entry, open a PR against customer-facing/faq.md
  //    (principal + operator review per CODEOWNERS)
  await openFAQProposalPR(proposals, env);

  // 4. Notify principal + operator
  for (const recipient of env.REVIEWER_DIGEST_RECIPIENTS.split(",")) {
    const phone = await resolvePhoneFromEmail(recipient.trim(), env);
    if (phone) {
      await sendWhatsApp(phone, `📚 Weekly knowledge-gap proposals from the concierge ready for review.\nOpen: ${env.CLIENT_SLUG}.pergamino.app/review`, env);
    }
  }
}

// ============================================================================
// GitHub PR webhook (real-time review when PR opens — optional)
// ============================================================================

async function handleGitHubWebhook(req: Request, env: Env): Promise<Response> {
  const event = req.headers.get("x-github-event");
  if (event !== "pull_request") return new Response("ok", { status: 200 });
  const body: any = await req.json();
  if (body.action !== "opened" && body.action !== "synchronize") return new Response("ok", { status: 200 });

  const pr = await prSummaryFromGitHubPayload(body, env);
  const verdict = await reviewPR(pr, env);

  // Post the verdict as a PR comment (so it's visible in the GitHub UI)
  await postPRComment(pr.number, formatVerdictAsComment(verdict), env);

  return new Response("ok", { status: 200 });
}

// ============================================================================
// Helpers (stubs — full implementations live in separate modules)
// ============================================================================

async function fetchOpenPRs(env: Env): Promise<PRSummary[]> {
  // GET /repos/:owner/:repo/pulls?state=open
  const r = await fetch(`https://api.github.com/repos/${env.BRAIN_CANON_REPO}/pulls?state=open`, {
    headers: { authorization: `Bearer ${env.GITHUB_TOKEN}`, accept: "application/vnd.github+json" },
  });
  const prs: any[] = await r.json();
  // For each PR, fetch the diff and extract scope info
  return Promise.all(prs.map((pr) => prSummaryFromGitHub(pr, env)));
}

async function prSummaryFromGitHub(pr: any, env: Env): Promise<PRSummary> {
  // Fetch diff
  const diffResp = await fetch(pr.diff_url, { headers: { authorization: `Bearer ${env.GITHUB_TOKEN}` } });
  const diff = await diffResp.text();
  // Extract target paths/scopes from diff
  const targetPaths = Array.from(new Set(diff.match(/^[+-]{3} [ab]\/(.+)$/gm)?.map((m) => m.replace(/^[+-]{3} [ab]\//, "")) ?? []));
  const targetScopes = Array.from(new Set(targetPaths.map((p) => p.split("/")[0])));
  const authorScope = await env.PERGAMINO_KV.get(`user-scope:${pr.user.login}`) ?? "company";
  return {
    number: pr.number,
    title: pr.title,
    author: pr.user.login,
    authorScope,
    targetPaths,
    targetScopes,
    isCrossScope: targetScopes.some((s) => s !== authorScope),
    diff,
    body: pr.body ?? "",
  };
}

async function fetchReviewerAgent(filename: string, env: Env): Promise<string> {
  const r = await fetch(`https://api.github.com/repos/${env.REVIEWER_AGENTS_REPO}/contents/${filename}`, {
    headers: { authorization: `Bearer ${env.GITHUB_TOKEN}`, accept: "application/vnd.github.raw" },
  });
  return r.text();
}

async function fetchCanonFile(path: string, env: Env): Promise<string> {
  const r = await fetch(`https://api.github.com/repos/${env.BRAIN_CANON_REPO}/contents/${path}`, {
    headers: { authorization: `Bearer ${env.GITHUB_TOKEN}`, accept: "application/vnd.github.raw" },
  });
  if (!r.ok) return "";
  return r.text();
}

async function fetchCanonDir(path: string, env: Env): Promise<string> {
  // Recursive fetch of all .md files; concatenate. For production: cache aggressively.
  // Simplified: list contents, fetch each, join.
  const r = await fetch(`https://api.github.com/repos/${env.BRAIN_CANON_REPO}/contents/${path}`, {
    headers: { authorization: `Bearer ${env.GITHUB_TOKEN}`, accept: "application/vnd.github+json" },
  });
  const items: any[] = await r.json();
  const mdFiles = items.filter((i) => i.type === "file" && i.name.endsWith(".md"));
  const contents = await Promise.all(mdFiles.map((f) => fetchCanonFile(`${path}${f.name}`, env)));
  return contents.join("\n\n---\n\n");
}

async function sendWhatsApp(to: string, body: string, env: Env): Promise<void> {
  await fetch(`https://graph.facebook.com/v20.0/${env.WHATSAPP_PHONE_ID}/messages`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.WHATSAPP_TOKEN}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      to,
      type: "text",
      text: { body },
    }),
  });
}

async function resolvePhoneFromEmail(email: string, env: Env): Promise<string | null> {
  return env.PERGAMINO_KV.get(`email-phone:${email}`);
}

async function mergePR(prNumber: number, env: Env, msg: string): Promise<void> {
  await fetch(`https://api.github.com/repos/${env.BRAIN_CANON_REPO}/pulls/${prNumber}/merge`, {
    method: "PUT",
    headers: { authorization: `Bearer ${env.GITHUB_TOKEN}`, accept: "application/vnd.github+json" },
    body: JSON.stringify({ commit_title: msg, merge_method: "squash" }),
  });
}

async function closePR(prNumber: number, env: Env, reason: string): Promise<void> {
  await postPRComment(prNumber, `**Closed via WhatsApp:** ${reason}`, env);
  await fetch(`https://api.github.com/repos/${env.BRAIN_CANON_REPO}/pulls/${prNumber}`, {
    method: "PATCH",
    headers: { authorization: `Bearer ${env.GITHUB_TOKEN}` },
    body: JSON.stringify({ state: "closed" }),
  });
}

async function postPRComment(prNumber: number, body: string, env: Env): Promise<void> {
  await fetch(`https://api.github.com/repos/${env.BRAIN_CANON_REPO}/issues/${prNumber}/comments`, {
    method: "POST",
    headers: { authorization: `Bearer ${env.GITHUB_TOKEN}`, accept: "application/vnd.github+json" },
    body: JSON.stringify({ body }),
  });
}

async function loadConversation(phone: string, env: Env): Promise<Array<{ role: string; content: string }>> {
  const json = await env.PERGAMINO_KV.get(`convo:${phone}`);
  return json ? JSON.parse(json) : [];
}

async function saveConversation(phone: string, newTurns: Array<{ role: string; content: string }>, env: Env): Promise<void> {
  const existing = await loadConversation(phone, env);
  const updated = [...existing, ...newTurns].slice(-40); // keep last 20 turns each side
  await env.PERGAMINO_KV.put(`convo:${phone}`, JSON.stringify(updated), { expirationTtl: 30 * 86400 });
}

async function listTeamMembers(env: Env): Promise<Array<{ email: string; name: string; scope: string }>> {
  // GET /orgs/:org/teams/:team_slug/members; combined across all teams
  // Simplified placeholder
  return [];
}

async function scanWorkspaceForPromotionCandidates(user: { email: string; scope: string }, env: Env): Promise<any[]> {
  // Query LiveSync/CouchDB for files in working/ created today, not in any PR yet
  return [];
}

async function openFAQProposalPR(proposals: string, env: Env): Promise<void> {
  // Create a branch, commit a knowledge-gap-proposals.md file, open a PR
  // Stub for v0; full implementation in separate module
}

async function prSummaryFromGitHubPayload(body: any, env: Env): Promise<PRSummary> {
  return prSummaryFromGitHub(body.pull_request, env);
}

function formatVerdictAsComment(v: ReviewVerdict): string {
  return `## 🤖 Reviewer agent verdict

**Verdict:** ${v.verdict === "approve" ? "✅" : v.verdict === "needs-eyes" ? "⚠️" : "🚫"} ${v.verdict}
**Confidence:** ${v.confidence}

**Reasoning:** ${v.reasoning}

${v.flags.length > 0 ? `**Flags:**\n${v.flags.map((f) => `- ${f}`).join("\n")}` : ""}

**Suggested reviewer:** ${v.suggestedReviewer}

---
*This is a pre-analysis. The human reviewer ratifies or overrides.*`;
}
