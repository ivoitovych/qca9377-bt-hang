#!/bin/bash
# verify.sh — run every check in the action register and print pass/fail.
#
#   reviews/verify.sh            all items
#   reviews/verify.sh UT-10      one item
#
# WHY THIS EXISTS. The register in README.md gives each recommendation a
# command that decides whether it has been done. The first draft of that table
# shipped four commands that did not work: one pointed `run-tests --section` at
# a source comment rather than a printed heading, one asserted that `python3`
# had left run-tests when three legitimate uses remain, and two quoted counts
# that were simply wrong — 109 journalctl "call sites" that were really every
# mention of the word including comments, and a line count off by 138.
#
# A register of unrun commands is documentation, and this repository's whole
# argument is that documentation drifts and executable checks do not. So the
# register is executable. Running it is how the numbers in README.md are kept
# honest, and how a reader who does not trust them settles it in one command.
#
# Read-only. Exit 0 if every item is in its recorded state, 1 otherwise.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

WANT="${1:-}"
pass=0; fail=0; skip=0

G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; O=$'\033[0m'
[[ -t 1 ]] || { G=""; R=""; Y=""; O=""; }

# check <id> <expected-state> <description> ; body decides via return status
check() {
    local id="$1" state="$2" desc="$3"; shift 3
    if [[ -n "$WANT" && "$WANT" != "$id" ]]; then return 0; fi
    if [[ "$state" == open || "$state" == blocked ]]; then
        printf '%s○ %-6s %s%s  (%s)\n' "$Y" "$id" "$desc" "$O" "$state"
        skip=$((skip + 1)); return 0
    fi
    if "$@" >/dev/null 2>&1; then
        printf '%s✓ %-6s %s%s\n' "$G" "$id" "$desc" "$O"; pass=$((pass + 1))
    else
        printf '%s✗ %-6s %s%s  <- recorded as %s, but the check fails\n' \
               "$R" "$id" "$desc" "$O" "$state"; fail=$((fail + 1))
    fi
}

# Counted, never `| grep -q`: under pipefail a matching grep -q pipeline exits
# non-zero, which is the inversion tests/run-tests forbids repo-wide.
has() { local n; n=$(grep -c "$2" "$1" 2>/dev/null); [[ "${n:-0}" -gt 0 ]]; }
hasnt() { local n; n=$(grep -c "$2" "$1" 2>/dev/null); [[ "${n:-0}" -eq 0 ]]; }

echo "action register — reviews/2026-08-13T1214Z-unit-testing-assessment.md"
echo "──────────────────────────────────────────────────────────────────────"

check UT-01 done "systemd-analyze guarded in repo-validate" \
      has devtools/repo-validate 'command -v systemd-analyze'
check UT-02 done "tests/ and devtools documented in the READMEs" \
      has README.md 'devtools/coverage'
check UT-03 done "tests/README.md exists" test -r tests/README.md
check UT-04 done "CI workflow present" test -r .github/workflows/checks.yml
check UT-05 done "awk fixture harness runs cases" \
      bash -c 'n=$(tests/run-tests --section "awk libraries" 2>&1 | grep -c "✓"); [ "${n:-0}" -ge 5 ]'
check UT-06 done "trial-summary.awk has fixtures" \
      bash -c '[ "$(ls tests/fixtures/trial-summary/*.in 2>/dev/null | wc -l)" -ge 5 ]'
check UT-07 done "fixtures for trial-sco-table.awk and stage2.awk" \
      bash -c '[ -d tests/fixtures/trial-sco-table ] && [ -d tests/fixtures/stage2 ]'
check UT-08 done "journal seam library present" test -r tools/lib/journal.sh
check UT-09 done "seam invariant asserted by the suite" \
      bash -c 'tests/run-tests --section "whole tools" 2>&1 | grep -c "journal seam" >/dev/null'
check UT-11 done "phase.awk extracted, Python extractor gone" \
      bash -c 'test -r tools/lib/phase.awk && ! grep -q "re.search" tests/run-tests'
check UT-12 open "tests/run-tests split into per-area files" true
check UT-13 blocked "repo-scan added to CI (needs a publish-safety decision)" true

# UT-10 is a ratio, not a yes/no: report it rather than pass/fail it.
if [[ -z "$WANT" || "$WANT" == UT-10 ]]; then
    conv=$(grep -rl 'source "$LIBDIR/journal.sh"' tools bin 2>/dev/null | grep -vc 'lib/journal.sh')
    remaining=$(grep -rn '[^_a-z]journalctl ' tools bin 2>/dev/null \
                | grep -v 'lib/journal.sh' | grep -v ':[0-9]*:[[:space:]]*#' | wc -l)
    rfiles=$(grep -rn '[^_a-z]journalctl ' tools bin 2>/dev/null \
             | grep -v 'lib/journal.sh' | grep -v ':[0-9]*:[[:space:]]*#' \
             | cut -d: -f1 | sort -u | wc -l)
    printf '%s◐ %-6s %s%s\n' "$Y" "UT-10" "journal seam adoption" "$O"
    printf '         converted: %s tool(s)\n' "$conv"
    printf '         remaining: %s direct journalctl call site(s) in %s file(s)\n' "$remaining" "$rfiles"
    printf '         baseline at 6c0491c: 75 sites in 21 files\n'
fi

echo
printf 'coverage: '
devtools/coverage --quiet 2>/dev/null | grep TOTAL || echo "(coverage tool failed)"
echo "  baseline 13.1% (503/3846) at report time; 18.3% (713/3898) at d016249"

echo
if (( fail )); then
    printf '%s%d item(s) are NOT in their recorded state — the register is stale%s\n' "$R" "$fail" "$O"
    exit 1
fi
printf '%s%d verified%s, %d still open or blocked\n' "$G" "$pass" "$O" "$skip"
