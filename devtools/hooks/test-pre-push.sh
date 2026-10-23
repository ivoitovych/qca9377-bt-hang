#!/bin/bash
# test-pre-push.sh — tests for devtools/hooks/pre-push. Calls the hook directly with git's stdin
# lines; NOTHING IS PUSHED. The leaking commit is built with hash-object/mktree/commit-tree, so it
# exists only as a loose object (no branch, no index, no work tree touched).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
H="$ROOT/devtools/hooks/pre-push"
# Built at run time: written out, the address and the ssh user@host would trip the scan of this
# file itself (as they did on 2026-10-23).
SSH="git""@""github.com"
MAC=$(printf '%s:%s:%s:%s:%s:%s' 12 34 56 78 9a bc)
PUB="$SSH:ivoitovych/qca9377-bt-hang.git"
PRIV="$SSH:ivoitovych/qca9377-bt-hang-private.git"
ZERO=0000000000000000000000000000000000000000
cd "$ROOT" || exit 2
HEAD_SHA=$(git rev-parse HEAD)
blob=$(printf 'test address %s\n' "$MAC" | git hash-object -w --stdin)
tree=$( { git ls-tree HEAD; printf '100644 blob %s\tpre-push-test-leak.txt\n' "$blob"; } | git mktree)
leak=$(git commit-tree "$tree" -p HEAD -m "pre-push test: a leaking commit (never pushed)")
pass=0 fail=0
expect() { # <name> <want-rc> <regex> <remote> <url> <stdin>
	local out rc
	out=$(printf '%s\n' "$6" | "$H" "$4" "$5" 2>&1); rc=$?
	if [[ $rc -eq $2 ]] && grep -qE "$3" <<<"$out"; then pass=$((pass + 1)); echo "PASS $1 (rc=$rc)"
	else fail=$((fail + 1)); echo "FAIL $1 (rc=$rc, want $2, /$3/)"; sed -e 's/^/     /' <<<"$out" | tail -n 6; fi
}
# A refusal must be the scanner's finding, not an error: the address is named in the output.
LEAK_RE="real MAC/BSSID found"
expect leak-public 1 "$LEAK_RE" origin "$PUB" "refs/heads/main $leak refs/heads/main $HEAD_SHA"
expect leak-new-branch 1 "$LEAK_RE" origin "$PUB" "refs/heads/t $leak refs/heads/t $ZERO"
expect leak-unknown-tip 1 "$LEAK_RE" origin "$PUB" "refs/heads/main $leak refs/heads/main 1111111111111111111111111111111111111111"
expect https-public 1 "$LEAK_RE" origin "https://github.com/ivoitovych/qca9377-bt-hang.git" "refs/heads/main $leak refs/heads/main $HEAD_SHA"
expect leak-private 0 "not the public repository" private "$PRIV" "refs/heads/main $leak refs/heads/main $HEAD_SHA"
expect clean-public 0 "publish scan clean for 1" origin "$PUB" "refs/heads/main $HEAD_SHA refs/heads/main $HEAD_SHA"
expect delete-public 0 "publish scan clean for 0" origin "$PUB" "(delete) $ZERO refs/heads/t $HEAD_SHA"
# Two refs, one leaking: the whole push is refused.
expect mixed-refs 1 "$LEAK_RE" origin "$PUB" "refs/heads/main $HEAD_SHA refs/heads/main $HEAD_SHA
refs/heads/t $leak refs/heads/t $ZERO"
echo "passed $pass, failed $fail"
(( fail == 0 ))
