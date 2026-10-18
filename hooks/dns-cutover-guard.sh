#!/usr/bin/env bash
# PreToolUse(Bash) guard: turn commands that touch nameservers or DNS records into an "ask".
# Rule: stage and verify the mail records (MX, SPF, DKIM, DMARC) at the destination before a
# nameserver change. A cutover that skips this step can stop a domain's email for days.
# Run it through run-guard.sh. Tests: hooks/hooks.test.sh.
set -euo pipefail

cmd=$(jq -r '.tool_input.command // ""')

# Patterns indicating nameserver or DNS-record manipulation
if grep -qE '\b(nameserver|ns1\.|ns2\.|set-nameservers|update-nameservers)\b' <<<"$cmd" \
   || grep -qE 'cloudflare.*(dns|zone|nameserver)' <<<"$cmd" \
   || grep -qE 'wrangler[[:space:]]+(dns|publish.*--routes)' <<<"$cmd" \
   || grep -qE 'gandi[[:space:]]+(livedns|dns)' <<<"$cmd" \
   || grep -qE 'aws[[:space:]]+route53[[:space:]]+(change-resource-record-sets|update-hosted-zone)' <<<"$cmd" \
   || grep -qE '"type"[[:space:]]*:[[:space:]]*"(NS|MX|SPF|DKIM|DMARC)"' <<<"$cmd" \
   || grep -qE 'curl.*api\.cloudflare\.com.*(zones|dns_records)' <<<"$cmd"; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: "This command touches nameservers or Domain Name System (DNS) records. Rule: never change nameservers or critical records before the mail records (MX, SPF, DKIM, DMARC) are staged at the destination and verified with dig. A cutover that skips this step can stop the email of the domain for days. Confirm with the author before you continue."
    }
  }'
fi
exit 0
