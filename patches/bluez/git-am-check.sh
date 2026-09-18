#!/bin/bash
# git-am-check.sh — prove the two patches apply to a BlueZ tree the way a
#                   maintainer will apply them: `git am`, each alone, both
#                   together, in either order, plus BlueZ's format rules.
#
#   patches/bluez/git-am-check.sh <path-to-bluez-checkout> [<commit>]
#
# <commit> defaults to the checkout's HEAD. Everything happens in a throwaway
# worktree under mktemp; the checkout itself is not modified.
#
# WHY THIS IS A TRACKED FILE. patches/bluez/README.md quoted this script's
# six PASS lines as the verification of the patches, and the script was not
# in the repository — a transcript of a command nobody else could run, which
# is the exact thing evidence/exhibits/ exists to prevent (front-door review
# 2026-09-17T2251Z, FD-13). The rules checked are BlueZ's own, read from
# HACKING at c73fa2f9a: no Signed-off-by, subject <= 50, body <= 72 with
# quoted tool output exempt.
#
# ⚠️ A shallow clone cannot see the 2020 commits the patches cite in prose;
# that does not affect `git am`, but any history question needs
# `git fetch --unshallow` first (see the README).
#
# Exit 0 when every check passes, 1 otherwise. Read-only on the checkout.

set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TREE="${1:?usage: git-am-check.sh <path-to-bluez-checkout> [<commit>]}"
BASE="${2:-HEAD}"

[[ -d "$TREE/.git" || -f "$TREE/.git" ]] || { echo "not a git checkout: $TREE" >&2; exit 2; }
mapfile -t PATCHES < <(ls "$HERE"/0*.patch 2>/dev/null | sort)
(( ${#PATCHES[@]} == 2 )) || { echo "expected exactly two 0*.patch files in $HERE, found ${#PATCHES[@]}" >&2; exit 2; }

BASE_SHA=$(git -C "$TREE" rev-parse --verify --quiet "$BASE^{commit}") \
    || { echo "cannot resolve $BASE in $TREE" >&2; exit 2; }
SHORT="${BASE_SHA:0:9}"

W=$(mktemp -d) || exit 2
cleanup() { git -C "$TREE" worktree remove --force "$W/wt" >/dev/null 2>&1; rm -rf "$W"; }
trap cleanup EXIT

pass=0; fail=0
ok()  { printf '  PASS  %s\n' "$*"; pass=$((pass + 1)); }
bad() { printf '  FAIL  %s\n' "$*"; fail=$((fail + 1)); }

fresh() {   # reset the worktree to the base commit
    git -C "$TREE" worktree remove --force "$W/wt" >/dev/null 2>&1
    git -C "$TREE" worktree add -q --detach "$W/wt" "$BASE_SHA" >/dev/null 2>&1
}

apply_set() {   # <label> <patch>... — git am the given patches in order
    local label="$1"; shift
    fresh
    if git -C "$W/wt" am -q "$@" >"$W/am.log" 2>&1; then
        local n; n=$(git -C "$W/wt" rev-list --count "$BASE_SHA..HEAD")
        (( n == $# )) && ok "$label — git am clean, $n commit(s) on top of $SHORT" \
                      || bad "$label — git am produced $n commit(s), expected $#"
        # A stray `---` in a message body silently truncates everything after
        # it; check the last body line of each applied commit is the last
        # line the patch file carried.
        local i=1 p
        for p in "$@"; do
            local want got
            want=$(sed -n '1,/^---$/p' "$p" | sed '$d' | grep -v '^$' | tail -1)
            got=$(git -C "$W/wt" log -1 --format=%B "HEAD~$(( $# - i ))" | grep -v '^$' | tail -1)
            [[ "$want" == "$got" ]] || bad "$label — body of $(basename "$p") truncated at git am ('$got')"
            i=$((i + 1))
        done
    else
        bad "$label — git am FAILED:"; sed 's/^/          /' "$W/am.log"
    fi
}

echo "git-am-check — $(basename "$TREE") at $SHORT"
apply_set "$(basename "${PATCHES[0]}" | cut -c1-4) alone" "${PATCHES[0]}"
apply_set "$(basename "${PATCHES[1]}" | cut -c1-4) alone" "${PATCHES[1]}"
apply_set "0001 then 0002" "${PATCHES[0]}" "${PATCHES[1]}"
apply_set "0002 then 0001 (order-independent)" "${PATCHES[1]}" "${PATCHES[0]}"

# ── BlueZ's format rules, read from HACKING ─────────────────────────────
n_sob=$(grep -c '^Signed-off-by:' "${PATCHES[@]}" | awk -F: '{s+=$2} END{print s+0}')
(( n_sob == 0 )) && ok "no Signed-off-by in either patch" \
                 || bad "$n_sob Signed-off-by line(s) — BlueZ HACKING calls that an error"

subj_note=""; long=0
for p in "${PATCHES[@]}"; do
    s=$(grep -m1 '^Subject:' "$p" | sed -E 's/^Subject: \[PATCH[^]]*\] //')
    subj_note="$subj_note subject ${#s} chars ·"
    (( ${#s} <= 50 )) || bad "subject over 50 characters in $(basename "$p"): ${#s}"
    # Body lines between the headers and `---`, excluding quoted tool output
    # (indented by two or more spaces or a tab, exempt per HACKING §5).
    while IFS= read -r line; do
        [[ "$line" =~ ^([[:space:]]{2,}|$'\t') ]] && continue
        # Trailers (Fixes:, Link:, …) are never wrapped — a wrapped trailer stops
        # being a trailer — and BlueZ's own Fixes: lines run past 80 columns.
        # The first run of this file against the real tree flagged 0001's Fixes:
        # at 75 and reported FAIL on a patch that was fine (2026-09-18).
        [[ "$line" =~ ^[A-Z][A-Za-z-]+:\  ]] && continue
        (( ${#line} > 72 )) && { long=$((long + 1)); echo "        >72: $line"; }
    done < <(sed -n '/^$/,/^---$/p' "$p" | sed '$d')
done
(( long == 0 )) && ok "${subj_note# } no body line over 72" \
                || bad "$long body line(s) over 72 columns (quoted output exempt)"

echo
if (( fail )); then echo "FAILED: $fail check(s)"; exit 1; fi
echo "all $pass checks passed"
