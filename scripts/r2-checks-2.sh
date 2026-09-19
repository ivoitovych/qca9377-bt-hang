#!/bin/bash
# r2-checks-2.sh — context lines for the R2 findings the first pass could not
# classify from a count alone. Read-only.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
h() { printf '\n── %s\n' "$1"; }
h "R2-06 which docs file still says 'then silence'";     grep -rn "then silence" docs | cut -c1-140
h "R2-09 README line 199";                                sed -n 199p README.md | cut -c1-160
h "R2-10 README first 8 lines";                           sed -n 1,8p README.md | cut -c1-120
h "R2-15 plan 're-derive' context";                       grep -n "re-derive" docs/investigation-plan.md | cut -c1-160
h "R2-17 HISTORY heading + next 3 lines";                 grep -n -A3 "^## Current state" HISTORY.md | cut -c1-140
h "R2-29 fix-proposal banner lines";                      grep -n -iE "superseded|revision" docs/fix-proposal.md | head -4 | cut -c1-140
h "R2-33 source-map bt-snapshot line";                    grep -n "bt-snapshot" docs/source-map.md | cut -c1-140
h "R2-34 source-map kernel table";                        grep -n -iE "7\.0\.0-|which kernel" docs/source-map.md docs/source-access.md | head -6 | cut -c1-120
h "R2-38 plan '13 of 34' and 'silence' context";          grep -n -E "13 of 34|silence" docs/investigation-plan.md | cut -c1-160
h "R2-39 plan BL status markers";                         grep -n -E "^### BL-0[0-9]" docs/investigation-plan.md | cut -c1-120
h "R2-49 watchdog header warning line";                   grep -n -iE "destroy|never arm|do not arm" bin/bt-hang-watchdog | head -3 | cut -c1-140
h "R2-52 bt-trace free_gb loop";                          grep -n -B1 -A3 "while.*free_gb" bin/bt-trace | cut -c1-140
h "R2-59 install.sh stamp block guard";                   grep -n -B6 "installed-at" install.sh | grep -E "if|TOOLS_ONLY|APPLY|STAMP" | cut -c1-120
h "R2-60 install.sh run() allowlist comment";             grep -n -B8 "install|rm|rmdir|mkdir) ;;" install.sh | grep -iE "nothing else|allowlist|only" | head -3 | cut -c1-140
h "R2-67 bt-archive AMBIGUOUS handling";                  grep -n -A4 "AMBIGUOUS" tools/bt-archive | cut -c1-120
h "R2-72 bt-postmortem 'too late' and alt lines";         grep -n -iE "too late|alt" tools/bt-postmortem | cut -c1-140
h "R2-76/78/94 probe and sco (re-check)";                 grep -c 'bsco\\b\|\\bSCO' tools/bt-status; grep -c -- '--probe' tools/bt-state tools/bt-diagnose tools/bt-status
h "R2-82 strings fallback";                               grep -n -E "command -v strings|strings " tools/bt-verify-kernel-mechanism | head -3 | cut -c1-120
h "R2-97 journal.sh -u handling";                         grep -n -E '\-u\b|unit-' tools/lib/journal.sh | head -6 | cut -c1-120
h "R2-114 exhibit index rows whose claim cell does not end a sentence"; awk -F'|' 'NR>3 && NF>4 {c=$3; gsub(/^ +| +$/,"",c); if (c !~ /[.!?)`*]$/) print NR": "substr(c,length(c)-40)}' evidence/exhibits/README.md | head -8
h "R2-120 reviews/README verify.sh scope statement";      grep -n "verify.sh" reviews/README.md | cut -c1-160
h "R2-16 HISTORY SUPERSEDED locations";                   grep -n "SUPERSEDED" HISTORY.md | cut -c1-100
h "R2-103 tests/README ~2 s line";                        grep -n "~2 s" tests/README.md | cut -c1-120
