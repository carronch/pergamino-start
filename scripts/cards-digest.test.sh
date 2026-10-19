#!/usr/bin/env bash
# Test harness for cards-digest.py, the read-only card digest that /triage-cards reads.
# Runs only in a temporary folder with made-up cards; it never reads a real brain.
#
# Before trusting it as evidence, mutation-test it: point DIGEST= at a copy with one rule
# removed (skipping done cards, skipping README.md, the future-date filter, the #author
# split, the canonical-lane check, the oldest-first sort, the upkeep filter, the dated-heading
# match, the updated:/file-name fallback, the continuation join, the stop at the next list
# line, the skipped portfolio sections, the .md and bare-name links, the date-prefix forms,
# the whole last date of entries, the fence filter and each of its rules, the folder check,
# done in any case, the "No change" forms, the north heading on line 1, no portfolio links
# above the first section, the skip word at the start of a heading, the --today check, the
# brain argument and PERGAMINO_LLM_BRAIN, the north: frontmatter, --author-name) and confirm a
# line turns red.
#
# Usage: bash scripts/cards-digest.test.sh   (run it with bash: zsh does not split words the same way)
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DIGEST="${DIGEST:-$HERE/cards-digest.py}"
fails=0
check() { if [[ "$2" == 0 ]]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir "$T/north"

cat > "$T/2026-01-01-old.md" <<'EOF'
---
title: "Old card"
status: active
status_note: "waiting on a reply"
---
# Old card
- [ ] Call the bank. #author
- [ ] Draft the summary.
- [x] Done item.
## Timeline
- 2026-09-01: first entry
- **2026-09-10** | second entry
EOF
cat > "$T/2026-02-01-planned.md" <<'EOF'
---
title: 'Planned card'
status: planned
---
- [ ] Agent step one.
- 2026-10-12: recent entry
- 2027-01-01: a future date that must not count
EOF
cat > "$T/2026-03-01-done.md" <<'EOF'
---
title: "Done card"
status: done
---
- 2026-10-01: closed
EOF
cat > "$T/2026-04-01-nodates.md" <<'EOF'
---
title: "No dates"
status: someday-maybe
---
Nothing dated here.
EOF
cat > "$T/undated-notes.md" <<'EOF'
---
title: "No date anywhere"
status: active
---
Nothing dated here, not even the file name.
EOF
cat > "$T/2026-05-01-upkeep.md" <<'EOF'
---
title: "Upkeep only lately"
status: active
---
- [ ] Ask the author about the price.
- [ ] Wire the form, then ask
      the author for the key. #author
  - [ ] Nested step for the agent.
- [ ] Parent step for the agent.
  - [ ] Nested step for the author. #author
- [ ] Agent step with a note.
  - a plain note line that mentions #author
- [x] Shipped part one.
- [X] Shipped part two.

## Timeline
- 2026-09-01: [source: session] real work
- 2026-10-10: [source:lint] Frontmatter completed so the vault lint passes; no other change.
- 2026-10-11: [source: lint 2026-10-11] Back-link: discussed in [[wiki/summaries/x]].
- 2026-10-12: [source: workblock-status-guard; this session ran past midnight] No change since the 2026-10-11 entry.
- 2026-10-12: [source: triage-cards, outputs/triage/2026-10-12.md] Park: idle.
- 2026-10-12: [source:vault-navigation audit] Paths updated.
- 2026-10-12: [source:sweep link fixes, author-approved] Dangling wikilinks rewritten.
- 2026-10-12: No change today.
- **2026-10-12** | No change today.
- 2026-10-12 (lint): [source: lint] Frontmatter completed.
EOF
cat > "$T/2026-06-01-heading.md" <<'EOF'
---
title: "Dated heading"
status: waiting-for
updated: 2026-10-05
---
## Status check 2026-09-20
Some text.
- 2026-08-01: [source: session] older entry
EOF
cat > "$T/2026-07-01-updated.md" <<'EOF'
---
title: "Only updated"
status: someday-maybe
updated: 2026-09-30
created: 2026-07-01
---
No dated lines.
EOF
printf -- '---\ntitle: "Readme"\nstatus: active\n---\n' > "$T/README.md"
printf -- '---\ntitle: "Linked with .md"\nstatus: someday-maybe\n---\n' > "$T/2026-08-01-mdlink.md"
printf -- '---\ntitle: "Linked by bare name"\nstatus: someday-maybe\n---\n' > "$T/2026-08-02-bare.md"

cat > "$T/north/north.md" <<'EOF'
---
title: "North"
---
## North cards — parts and homes
| Area | Part | Home |
|---|---|---|
| Admin | Form | [[wiki/workblocks/2026-05-01-upkeep]] |
| Admin | Bank | [[wiki/workblocks/2026-08-01-mdlink.md]] |
## Later section
[[wiki/workblocks/2026-01-01-old]]
EOF
cat > "$T/north/portfolio.md" <<'EOF'
# Portfolio
## Operating businesses
- Planned: [[wiki/workblocks/2026-02-01-planned|the planned card]]
- Bare: [[2026-08-02-bare|Bare]]
## Closed or paused
- [[wiki/workblocks/2026-06-01-heading]]
## Archived (for reference)
- [[wiki/workblocks/2026-07-01-updated]]
EOF
N=(--north-card "$T/north/north.md" --portfolio "$T/north/portfolio.md")

out="$(python3 -I "$DIGEST" --dir "$T" --today 2026-10-13 --format json "${N[@]}")"
check "exit code 0" $?
q() { printf '%s' "$out" | python3 -I -c "import json,sys; d={c['card']:c for c in json.load(sys.stdin)}; print($1)"; }

[[ "$(q 'len(d)')" == 9 ]]; check "lists the 9 open cards (done card and README skipped)" $?
[[ "$(q "'2026-03-01-done' in d")" == False ]]; check "skips the done card" $?
[[ "$(q "'README' in d")" == False ]]; check "skips README.md" $?
[[ "$(q "d['2026-01-01-old']['last']")" == 2026-09-10 ]]; check "newest dated entry, bold form included" $?
[[ "$(q "d['2026-01-01-old']['idle_days']")" == 33 ]]; check "idle days from --today" $?
[[ "$(q "d['2026-01-01-old']['open_author']")" == 1 ]]; check "counts open #author items" $?
[[ "$(q "d['2026-01-01-old']['open_agent']")" == 1 ]]; check "counts open agent items, not checked ones" $?
[[ "$(q "d['2026-01-01-old']['status_note']")" == "waiting on a reply" ]]; check "reads the status_note without quotes" $?
[[ "$(q "d['2026-02-01-planned']['last']")" == 2026-10-12 ]]; check "ignores future dates" $?
[[ "$(q "d['2026-02-01-planned']['canonical']")" == False ]]; check "flags a lane the kanban does not have" $?
[[ "$(q "d['2026-02-01-planned']['title']")" == "Planned card" ]]; check "reads a single-quoted title" $?

[[ "$(q "d['2026-05-01-upkeep']['last']")" == 2026-09-01 ]]; check "lint, guard, triage, audit, link-fix and No change lines are not movement" $?
[[ "$(q "d['2026-06-01-heading']['last']")" == 2026-09-20 ]]; check "a dated heading counts as movement" $?
[[ "$(q "d['2026-06-01-heading']['updated']")" == 2026-10-05 ]]; check "reports updated:" $?
[[ "$(q "d['2026-07-01-updated']['last'], d['2026-07-01-updated']['last_from']")" == "2026-09-30 updated" ]]; check "no real entry falls back to updated:" $?
[[ "$(q "d['2026-04-01-nodates']['last'], d['2026-04-01-nodates']['last_from']")" == "2026-04-01 file name" ]]; check "then to the file name date" $?
[[ "$(q "d['undated-notes']['idle_days']")" == None ]]; check "no date anywhere gives no idle days" $?

[[ "$(q "d['2026-05-01-upkeep']['open_author']")" == 2 ]]; check "a #author tag on a continuation line counts, and a nested tagged box counts once" $?
[[ "$(q "d['2026-05-01-upkeep']['open_agent']")" == 4 ]]; check "a nested box is its own item, and an item stops at the next list line" $?
[[ "$(q "d['2026-05-01-upkeep']['checked']")" == 2 ]]; check "counts checked boxes, x and X" $?
[[ "$(q "d['2026-05-01-upkeep']['open_names_author']")" == 1 ]]; check "counts untagged open items that name the author" $?

[[ "$(q "d['2026-05-01-upkeep']['north']")" == True ]]; check "the north table links a card onto the north" $?
[[ "$(q "d['2026-01-01-old']['north']")" == False ]]; check "a link after the north table does not count" $?
[[ "$(q "d['2026-02-01-planned']['north']")" == True ]]; check "a portfolio link with an alias counts" $?
[[ "$(q "d['2026-06-01-heading']['north'], d['2026-07-01-updated']['north']")" == "False False" ]]; check "closed and archived sections of the portfolio do not count" $?
[[ "$(q "d['2026-08-01-mdlink']['north'], d['2026-08-02-bare']['north']")" == "True True" ]]; check "a link with .md and a link by bare name both count" $?

first="$(printf '%s' "$out" | python3 -I -c "import json,sys; print(json.load(sys.stdin)[0]['card'])")"
[[ "$first" == undated-notes ]]; check "sorts cards with no date first" $?
second="$(printf '%s' "$out" | python3 -I -c "import json,sys; print(json.load(sys.stdin)[1]['card'])")"
[[ "$second" == 2026-04-01-nodates ]]; check "then the most idle card" $?

md="$(python3 -I "$DIGEST" --dir "$T" --today 2026-10-13 --format md "${N[@]}")"
printf '%s\n' "$md" | grep -qF "planned [not a kanban lane] · north"; check "markdown output marks the lane and the north" $?
printf '%s\n' "$md" | grep -qF -- "- open: #author Call the bank. #author"; check "markdown output lists open items" $?
printf '%s\n' "$md" | grep -qF -- "- not a lane: planned: 1"; check "markdown summary counts a lane that is not a kanban lane" $?
printf '%s\n' "$md" | grep -qF -- "- active: 3"; check "markdown summary counts the lanes" $?
printf '%s\n' "$md" | grep -qF "no real entry; updated 2026-09-30"; check "markdown output says where a fallback date comes from" $?

err="$(python3 -I "$DIGEST" --dir "$T" --today 2026-10-13 --format json --north-card "$T/north/none.md" 2>&1 >/dev/null)"
printf '%s\n' "$err" | grep -qF "north card not found"; check "warns when the named north card is missing" $?
md2="$(python3 -I "$DIGEST" --dir "$T" --today 2026-10-13 --format md --north-card "$T/north/none.md")"
printf '%s\n' "$md2" | grep -qF "WARNING, north set"; check "markdown output carries the warning" $?
err0="$(python3 -I "$DIGEST" --dir "$T" --today 2026-10-13 --format md 2>&1)"
printf '%s\n' "$err0" | grep -qF "WARNING, north set"; [[ $? -ne 0 ]]; check "no warning when no north card was named and DIR/north.md does not exist" $?

# Same-day entries and fenced examples, in a folder of their own so the counts above stay.
X="$T/cases"; mkdir "$X"
# Four entries on one day, oldest first: the default limit of 3 must not cut that day.
cat > "$X/2026-09-01-sameday.md" <<'EOF'
---
title: "Four entries on one day"
status: active
---
## Timeline
- 2026-10-01: [source: session] Work started.
- 2026-10-12: [source: session] Price drafted.
- 2026-10-12: [source: session] Price checked.
- 2026-10-12: [source: session] Draft sent to the author.
- 2026-10-12: [source: session] The author approved the final price.
EOF
# Fences: an indented one inside an item, one at the margin that holds a line with an info
# string, a tilde one, four backticks around three, inline code at the start of a line, and a
# stray fence that never closes.
cat > "$X/2026-09-02-fenced.md" <<'EOF'
---
title: "Fenced examples"
status: active
---
- [ ] Run the check:
  ```bash
  - [ ] an example box inside the item #author
  ```
  then send the log to the author. #author
- [ ] Margin item.
```text
- [ ] Example box. #author
- 2026-10-12: example entry
```bash
## Example heading 2026-10-12
```
  indented text after a margin fence #author
~~~
- [x] Tilde example.
~~~
````md
```
- [ ] Inner example. #author
```
- 2026-10-11: still inside the outer fence
````
```inline``` code at the start of a line opens no fence.
- [ ] Real agent step.
```
- [ ] After a stray fence that never closes.

## Timeline
- 2026-08-01: [source: session] real work
EOF
cases="$(python3 -I "$DIGEST" --dir "$X" --today 2026-10-13 --format json "${N[@]}")"
qc() { printf '%s' "$cases" | python3 -I -c "import json,sys; d={c['card']:c for c in json.load(sys.stdin)}; print($1)"; }
[[ "$(qc "[e.split('] ', 1)[1] for e in d['2026-09-01-sameday']['newest_entries']]")" == "['Price drafted.', 'Price checked.', 'Draft sent to the author.', 'The author approved the final price.']" ]]; check "keeps every entry of the last date shown, in the card's order, and cuts older dates" $?
[[ "$(qc "d['2026-09-02-fenced']['last']")" == 2026-08-01 ]]; check "dated lines and headings in a fence are not movement" $?
[[ "$(qc "d['2026-09-02-fenced']['open_author'], d['2026-09-02-fenced']['open_agent'], d['2026-09-02-fenced']['checked']")" == "1 3 0" ]]; check "boxes in a fence are not items, and a fence that never closes hides nothing" $?
[[ "$(qc "d['2026-09-02-fenced']['first_open_items'][0]")" == "#author Run the check: then send the log to the author. #author" ]]; check "an indented fence leaves its item whole" $?

# Edge cases from an earlier review round. The cards for the first three sit in a folder of their own.
R="$T/round3"; mkdir "$R"
printf -- '---\ntitle: "Done, capital D"\nstatus: Done\n---\n- 2026-10-01: closed\n' > "$R/2026-09-03-done-capital.md"
printf -- '---\ntitle: "Done, in quotes with spaces"\nstatus: " done "\n---\n- 2026-10-01: closed\n' > "$R/2026-09-04-done-spaces.md"
printf -- '---\ntitle: "No status line"\n---\n- 2026-10-01: an entry\n' > "$R/2026-09-05-no-status.md"
# A real line that starts with "No change", then the upkeep forms that the cards use.
cat > "$R/2026-09-06-no-change.md" <<'EOF'
---
title: "Lines that start with No change"
status: active
---
## Timeline
- 2026-09-01: [source: session] real work
- 2026-10-11: [source: session] No change needed; work continues.
- 2026-10-12: [source: session] No change to this card today; the day went to another card.
- 2026-10-12: [source: session] No change in state; the link was made past midnight.
- 2026-10-12: [source: session] No change to the plan or status. Still waiting on the author.
- 2026-10-12: [source: SEO agent session] **No change** since the 2026-10-09 entry: the site is not live yet.
- 2026-10-12: [source: session] No changes.
EOF
# The north heading on the file's first line, then the heading text only in the middle of a line.
printf -- '## North cards\n| Admin | Form | [[wiki/workblocks/2026-09-06-no-change]] |\n## Later section\n[[wiki/workblocks/2026-09-05-no-status]]\n' > "$T/north/first-line.md"
printf -- 'Notes: ## North cards [[wiki/workblocks/2026-09-06-no-change]]\n' > "$T/north/mid-line.md"
r3="$(python3 -I "$DIGEST" --dir "$R" --today 2026-10-13 --format json "${N[@]}")"
qr() { printf '%s' "$r3" | python3 -I -c "import json,sys; d={c['card']:c for c in json.load(sys.stdin)}; print($1)"; }
[[ "$(qr "sorted(d), repr(d['2026-09-05-no-status']['status'])")" == "['2026-09-05-no-status', '2026-09-06-no-change'] ''" ]]; check "a done status in any case or with spaces is closed, and a card with no status: stays, with an empty status" $?
[[ "$(qr "d['2026-09-06-no-change']['last']")" == 2026-10-11 ]]; check 'a real line that starts with "No change" is movement, and the upkeep forms of "No change" are not' $?
nq() { python3 -I "$DIGEST" --dir "$R" --today 2026-10-13 --format json --north-card "$T/north/$1" --portfolio "$T/north/portfolio.md" 2>/dev/null | python3 -I -c "import json,sys; d={c['card']:c for c in json.load(sys.stdin)}; print(d['2026-09-06-no-change']['north'], d['2026-09-05-no-status']['north'])"; }
[[ "$(nq first-line.md) / $(nq mid-line.md)" == "True False / False False" ]]; check "the north heading counts on the file's first line, and not in the middle of a line" $?
# A portfolio with links above its first section, and headings that hold a skip word in other
# places. The north card does not exist, so only the portfolio puts a card on the north.
cat > "$T/north/portfolio-r3.md" <<'EOF'
# Portfolio
Links above the first section: [[wiki/workblocks/2026-01-01-old]]
- [[2026-04-01-nodates]]
## Clients (paying or active)
- [[2026-08-02-bare]]
## Operating businesses (closed-loop)
- [[wiki/workblocks/2026-02-01-planned]]
## Closed-loop recycling
- [[wiki/workblocks/2026-08-01-mdlink]]
## Closed or paused
- [[wiki/workblocks/2026-06-01-heading]]
## ARCHIVED projects
- [[wiki/workblocks/2026-07-01-updated]]
## Paused, for later
- [[wiki/workblocks/2026-05-01-upkeep]]
EOF
pq() { python3 -I "$DIGEST" --dir "$T" --today 2026-10-13 --format json --north-card "$T/north/none.md" --portfolio "$T/north/portfolio-r3.md" 2>/dev/null | python3 -I -c "import json,sys; d={c['card']:c for c in json.load(sys.stdin)}; print(*[d[n]['north'] for n in sys.argv[1:]])" "$@"; }
[[ "$(pq 2026-01-01-old 2026-04-01-nodates 2026-08-02-bare)" == "False False True" ]]; check "portfolio links above the first section do not count" $?
[[ "$(pq 2026-02-01-planned 2026-08-01-mdlink 2026-06-01-heading 2026-07-01-updated 2026-05-01-upkeep)" == "True True False False False" ]]; check "a portfolio section is skipped only when its heading starts with closed, paused or archived as a whole word" $?
terr="$(python3 -I "$DIGEST" --dir "$T" --today 2026-13-45 "${N[@]}" 2>&1 >/dev/null)"; trc=$?
[[ $trc -eq 2 && -n "$terr" && "$terr" != *$'\n'* && "$terr" == *--today* && "$terr" != *Traceback* ]]; check "a bad --today fails with one line and exit 2, not a traceback" $?

miss="$T/no-such-folder"
mout="$(python3 -I "$DIGEST" --dir "$miss" --today 2026-10-13 --format md "${N[@]}" 2>/dev/null)"; mrc=$?
merr="$(python3 -I "$DIGEST" --dir "$miss" --today 2026-10-13 --format json "${N[@]}" 2>&1 >/dev/null)"; jrc=$?
[[ $mrc -ne 0 && $jrc -ne 0 && "$mout" != *"Open cards"* && "$merr" == *"$miss"* ]]; check "a missing card folder fails with a message, not an empty queue" $?
python3 -I "$DIGEST" --dir "$T/2026-01-01-old.md" --today 2026-10-13 "${N[@]}" >/dev/null 2>&1
[[ $? -ne 0 ]]; check "a file given as the card folder fails too" $?

B="$T/many"; mkdir "$B"
for i in $(seq 1 400); do printf -- '---\ntitle: "Card %s"\nstatus: active\n---\n- [ ] Step %s for the agent, long enough to fill the pipe quickly.\n- 2026-10-01: entry\n' "$i" "$i" > "$B/2026-09-01-c$i.md"; done
err="$( { python3 -I "$DIGEST" --dir "$B" --today 2026-10-13 --format md | head -1 >/dev/null; } 2>&1 )"
[[ -z "$err" ]]; check "ends quietly when the reader closes the pipe early" $?
rm -rf "$B"

# The brain folder as the first argument, or from PERGAMINO_LLM_BRAIN; neither gives exit 2.
BR="$T/brain"; mkdir -p "$BR/wiki/workblocks"
printf -- '---\ntitle: "In the brain"\nstatus: active\n---\n- [ ] Ask Ana. #author\n- [ ] Send Ana the draft.\n- 2026-10-01: entry\n' > "$BR/wiki/workblocks/2026-09-07-brain.md"
printf -- '---\ntitle: "Marked north"\nstatus: someday-maybe\nnorth: true\n---\n' > "$BR/wiki/workblocks/2026-09-08-marked.md"
printf -- '---\ntitle: "The north card"\nstatus: active\n---\n## North cards\n- [[2026-09-07-brain]]\n' > "$BR/wiki/workblocks/north.md"
ba="$(env -u PERGAMINO_LLM_BRAIN python3 -I "$DIGEST" "$BR" --today 2026-10-13 --format json | python3 -I -c "import json,sys; print(sorted(c['card'] for c in json.load(sys.stdin)))")"
[[ "$ba" == "['2026-09-07-brain', '2026-09-08-marked', 'north']" ]]; check "reads BRAIN/wiki/workblocks when the brain is the first argument" $?
be="$(PERGAMINO_LLM_BRAIN="$BR" python3 -I "$DIGEST" --today 2026-10-13 --format json | python3 -I -c "import json,sys; print(len(json.load(sys.stdin)))")"
[[ "$be" == 3 ]]; check "reads the brain from PERGAMINO_LLM_BRAIN" $?
bn="$(env -u PERGAMINO_LLM_BRAIN python3 -I "$DIGEST" "$BR" --today 2026-10-13 --format json 2>/dev/null | python3 -I -c "import json,sys; d={c['card']:c for c in json.load(sys.stdin)}; print(d['north']['north'], d['2026-09-07-brain']['north'], d['2026-09-08-marked']['north'])")"
[[ "$bn" == "True True True" ]]; check "the default north card DIR/north.md and a north: true card put cards on the north" $?
bnm="$(env -u PERGAMINO_LLM_BRAIN python3 -I "$DIGEST" "$BR" --today 2026-10-13 --format json --author-name Ana | python3 -I -c "import json,sys; d={c['card']:c for c in json.load(sys.stdin)}; print(d['2026-09-07-brain']['open_author'], d['2026-09-07-brain']['open_names_author'])")"
[[ "$bnm" == "1 1" ]]; check "--author-name counts an untagged item that names the author" $?
nerr="$(env -u PERGAMINO_LLM_BRAIN python3 -I "$DIGEST" --today 2026-10-13 2>&1 >/dev/null)"; nrc=$?
[[ $nrc -eq 2 && "$nerr" == *PERGAMINO_LLM_BRAIN* ]]; check "no brain, no PERGAMINO_LLM_BRAIN and no --dir fails with exit 2 and a message" $?
printf -- '---\ntitle: "Tag lookalike"\nstatus: active\n---\n- [ ] Check the #authority claim.\n' > "$R/2026-09-09-lookalike.md"
la="$(python3 -I "$DIGEST" --dir "$R" --today 2026-10-13 --format json | python3 -I -c "import json,sys; d={c['card']:c for c in json.load(sys.stdin)}; print(d['2026-09-09-lookalike']['open_author'], d['2026-09-09-lookalike']['open_agent'])")"
[[ "$la" == "0 1" ]]; check "a longer word that starts with #author is not the tag" $?

before="$(cd "$T" && find . -type f -exec shasum {} + | sort | shasum)"
python3 -I "$DIGEST" --dir "$T" --today 2026-10-13 "${N[@]}" >/dev/null
after="$(cd "$T" && find . -type f -exec shasum {} + | sort | shasum)"
[[ "$before" == "$after" ]]; check "changes no file" $?

echo
if [[ $fails -eq 0 ]]; then echo "all checks passed"; else echo "$fails check(s) failed"; exit 1; fi
