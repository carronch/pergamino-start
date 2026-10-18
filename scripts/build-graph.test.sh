#!/usr/bin/env bash
# Test harness for scripts/build-graph.py and scripts/graph-hop.py. Builds a made-up LLM brain in a temporary
# folder, so it never reads or writes the real brains. Covers links a lint once reported as unresolved by
# mistake (check 2): memory cards linked by name, a frontmatter path with a trailing period, frontmatter paths
# that name a folder. Real broken links must stay reported.
#
# Usage: bash scripts/build-graph.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BUILDER="${BUILDER:-$HERE/build-graph.py}"
HOP="${HOP:-$HERE/graph-hop.py}"
fails=0
check() { if [[ "$2" == 0 ]]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

tmp="$(mktemp -d)" && [ -d "$tmp" ] || { echo "mktemp failed" >&2; exit 1; }; trap 'rm -rf "$tmp"' EXIT
V="$tmp/LLMBrain"; W="$V/wiki"
mkdir -p "$W/workblocks" "$W/clients/acme-textiles" "$W/meetings" "$W/research" "$V/memory"
page() {  # page <file> <frontmatter lines> [body]
  printf -- '---\n%s\n---\n%s\n' "$2" "${3:-}" > "$1"
}

for m in shell-wrapper search-speed-note north-star-direction; do
  page "$V/memory/$m.md" "name: $m"$'\ntype: project'
done
page "$W/todo.md" "type: todo" \
  "See [[shell-wrapper]] and [[search-speed-note.md]]. Gone: [[no-such-memory-card]]."
page "$W/workblocks/2030-01-07-errand-app.md" "type: workblock" "North: [[north-star-direction]]."
page "$W/workblocks/2030-01-14-laptop-pending-for-author.md" "type: workblock"
page "$W/workblocks/2030-01-03-setup-review.md" \
  "type: workblock"$'\n'"status_note: \"handed to wiki/workblocks/2030-01-14-laptop-pending-for-author.\""
page "$W/clients/acme-textiles/systems.md" "type: client"
page "$W/workblocks/2030-01-01-acme-textiles-discovery.md" \
  "type: workblock"$'\n'"status_note: \"notes in wiki/clients/acme-textiles (systems page)\""
page "$W/workblocks/2030-01-02-meeting-ingest.md" \
  "type: workblock"$'\n'"status_note: \"one wiki/meetings note per call; old one in wiki/tools/gone-tool.\""
page "$W/research/2030-01-05-profile.md" \
  "type: research"$'\n'"raw_data: wiki/research/2030-01-05-profile-autocomplete.csv" \
  "Raw data: [[wiki/research/2030-01-05-profile-autocomplete.csv]]"

out="$(python3 "$BUILDER" "$V" 2>&1)"; rc=$?
[[ $rc == 0 ]]; check "the builder runs on the test vault" $?
[[ $rc == 0 ]] || echo "$out"
G="$W/_graph.json"
q() { python3 -c 'import json,sys; g=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$G" "$1" 2>/dev/null; }

unres="$(q '",".join(sorted(g["unresolved"]))')"
want="no-such-memory-card,wiki/research/2030-01-05-profile-autocomplete.csv,wiki/tools/gone-tool"
[[ "$unres" == "$want" ]]; check "only the real broken links stay unresolved (got: $unres)" $?
for m in shell-wrapper search-speed-note north-star-direction; do
  [[ "$(q "'$m' in g['unresolved']")" == False ]]; check "memory card $m linked by name resolves" $?
done
[[ "$(q 'any(k.startswith("memory/") for k in g["nodes"])')" == False ]]; check "memory cards are not graph nodes" $?
[[ "$(q '"wiki/workblocks/2030-01-14-laptop-pending-for-author" in g["backlinks"]')" == True ]]
check "a frontmatter path with a trailing period links to its card" $?
[[ "$(q '"wiki/clients/acme-textiles" in g["unresolved"] or "wiki/meetings" in g["unresolved"]')" == False ]]
check "frontmatter paths that name a folder are not links" $?
[[ "$(q '"wiki/tools/gone-tool" in g["unresolved"] and "wiki/tools/gone-tool." not in g["unresolved"]')" == True ]]
check "a broken frontmatter path is reported without its trailing period" $?

# A period inside an explicit [[...]] link stays: only bare paths lose it.
V2="$tmp/v2/LLMBrain"; mkdir -p "$V2/wiki/concepts" "$V2/wiki/workblocks" "$V2/memory"
page "$V2/wiki/concepts/widget.md" "type: concept"
page "$V2/wiki/workblocks/2030-01-15-widget-card.md" "type: workblock"$'\n'"related: \"[[wiki/concepts/widget.md.]]\""
python3 "$BUILDER" "$V2" >/dev/null 2>&1; check "the builder runs on the second test vault" $?
[[ "$(python3 -c 'import json,sys; g=json.load(open(sys.argv[1])); print("wiki/concepts/widget" in g["backlinks"])' "$V2/wiki/_graph.json" 2>/dev/null)" == False ]]
check "a period inside an explicit [[...]] link is kept (no false backlink)" $?

# The LLM brain from the environment, and graph-hop.py over the built graph.
out="$(PERGAMINO_LLM_BRAIN="$V2" python3 "$BUILDER" 2>&1)"; check "the builder takes the LLM brain from PERGAMINO_LLM_BRAIN" $?
out="$(env -u PERGAMINO_LLM_BRAIN python3 "$BUILDER" 2>&1)"; [[ $? != 0 && "$out" == *"no LLM brain"* ]]
check "with no argument and no PERGAMINO_LLM_BRAIN, the builder stops with a message" $?
out="$(PERGAMINO_LLM_BRAIN="$V" python3 "$HOP" 2030-01-03-setup-review 2>&1)"
[[ "$out" == *"seed: wiki/workblocks/2030-01-03-setup-review"* && "$out" == *"wiki/workblocks/2030-01-14-laptop-pending-for-author"* ]]
check "graph-hop.py lists a seed's 1-hop neighbors" $?

echo
if [[ $fails -eq 0 ]]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
exit $(( fails > 0 ? 1 : 0 ))
