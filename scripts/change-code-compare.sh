#!/bin/bash
# change-code-compare.sh — is a change in one git tree the same code as a change in another, even
# on a different base (e.g. a series on Ubuntu's sources vs the same series on bluetooth-next)?
#
#   scripts/change-code-compare.sh <repo A> <from A> <to A> <repo B> <from B> <to B>
#
# Compares the two whole changes (from..to) three ways: the files touched; git patch-id --stable
# (git's fingerprint of a change's code; line numbers and hashes do not count); and the changed
# lines themselves (+/- lines, in order). Exit 0 if all three agree, 1 if not (the differing lines
# are printed). Read-only; scratch files in a mktemp directory, removed at the end.
set -u
RA=${1:?usage}; FA=${2:?usage}; TA=${3:?usage}; RB=${4:?usage}; FB=${5:?usage}; TB=${6:?usage}
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT
git -C "$RA" diff "$FA" "$TA" > "$T/a.diff" || exit 2
git -C "$RB" diff "$FB" "$TB" > "$T/b.diff" || exit 2
fa=$(git -C "$RA" diff --name-only "$FA" "$TA" | tr '\n' ' ')
fb=$(git -C "$RB" diff --name-only "$FB" "$TB" | tr '\n' ' ')
pa=$(git patch-id --stable < "$T/a.diff" | cut -c1-40)
pb=$(git patch-id --stable < "$T/b.diff" | cut -c1-40)
grep -E '^[-+]([^-+]|$)' "$T/a.diff" > "$T/a.lines"
grep -E '^[-+]([^-+]|$)' "$T/b.diff" > "$T/b.lines"
rc=0
echo "A: $FA..$TA in $RA"
echo "B: $FB..$TB in $RB"
if [[ "$fa" == "$fb" ]]; then echo "files: IDENTICAL ($fa)"; else echo "files: DIFFER: A $fa / B $fb"; rc=1; fi
if [[ -n "$pa" && "$pa" == "$pb" ]]; then echo "patch-id: IDENTICAL ${pa:0:16}"; else echo "patch-id: DIFFER ${pa:0:16} / ${pb:0:16}"; rc=1; fi
if diff "$T/a.lines" "$T/b.lines" > "$T/lines.diff"; then
	echo "changed lines: IDENTICAL ($(wc -l < "$T/a.lines") lines)"
else
	echo "changed lines: DIFFER"; cat "$T/lines.diff"; rc=1
fi
[[ $rc -eq 0 ]] && echo "RESULT: the same code change" || echo "RESULT: the changes DIFFER"
exit $rc
