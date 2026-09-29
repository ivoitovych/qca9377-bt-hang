#!/bin/bash
# patchwork-checks.sh — what the BlueZ CI bot reported on OTHER recent series.
#
# The list's CI bot (bluez.test.bot) posts one check per test to patchwork, so
# a failing test's history is public data: if TestFunctional fails on unrelated
# series too, a failure on ours is the bot's, not the patch's. Read-only; writes
# the raw JSON under tmp/patchwork/ so the claim ships with its extraction.
#
#   scripts/patchwork-checks.sh [N]          the N most recent bluetooth patches (default 25)
#   scripts/patchwork-checks.sh --patch ID    the checks on one patch id
#   scripts/patchwork-checks.sh --failed-functional [N]
#       for every BlueZ patch among the N most recent whose TestFunctional check
#       failed: the bot's comment on patchwork, reduced to its "FAIL functional…"
#       lines — which test failed, not just that one did
#   scripts/patchwork-checks.sh --rate CONTEXT [N] [BEFORE]
#       over the N most recent patches (older than BEFORE, YYYY-MM-DD, if given)
#       that carry check CONTEXT (e.g. TestRunner_mesh-tester, run on kernel
#       patches only): each patch's state for it, then the fail/success totals —
#       is a failure the bot's standing one, and since when?
#
# Output, one line per patch:  <date> <patch-id> <check:state ...>  <name>
# lore.kernel.org blocks curl by user-agent; patchwork.kernel.org's API does not
# (docs/source-access.md). Exits 2 when the API cannot be reached.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API="https://patchwork.kernel.org/api/1.3"
OUT="$REPO/tmp/patchwork"
mkdir -p "$OUT"
UA="qca9377-bt-hang/patchwork-checks (curl)"

fetch() {                      # fetch <url> <file>; exit 2 on failure
	local url="$1" file="$2"
	if ! curl -fsSL -A "$UA" --max-time 60 "$url" -o "$file.tmp"; then
		echo "cannot fetch $url" >&2
		rm -f "$file.tmp"
		return 2
	fi
	mv "$file.tmp" "$file"
}

checks_line() {                # checks_line <patch-id> → "context:state ..."
	local id="$1"
	fetch "$API/patches/$id/checks/" "$OUT/checks-$id.json" || return 2
	python3 - "$OUT/checks-$id.json" <<'PYEOF'
import json, sys
seen = {}
for c in json.load(open(sys.argv[1])):
    seen[c["context"]] = c["state"]      # last state per context wins
print(" ".join(f"{k}:{v}" for k, v in sorted(seen.items())))
PYEOF
}

if [[ "${1:-}" == "--patch" ]]; then
	checks_line "${2:?patch id}"
	exit $?
fi

if [[ "${1:-}" == "--failed-functional" ]]; then
	N="${2:-25}"
	fetch "$API/patches/?project=bluetooth&order=-date&per_page=$N" "$OUT/patches.json" || exit 2
	python3 - "$OUT/patches.json" <<'PYEOF' > "$OUT/patches.tsv"
import json, sys
for p in json.load(open(sys.argv[1])):
    print(f'{p["date"][:16]}\t{p["id"]}\t{p["name"]}')
PYEOF
	while IFS=$'\t' read -r date id name; do
		line=$(checks_line "$id") || continue
		[[ "$line" == *"TestFunctional:fail"* ]] || continue
		echo "== $date  $id  $name"
		fetch "$API/patches/$id/comments/" "$OUT/comments-$id.json" || continue
		python3 - "$OUT/comments-$id.json" <<'PYEOF'
import json, re, sys
for c in json.load(open(sys.argv[1])):
    body = c.get("content", "")
    if "TestFunctional" not in body:
        continue
    print(f'   bot comment {c["date"][:16]} from {c["submitter"]["email"]}')
    for m in re.finditer(r"^FAIL (functional\.\S+): failed on (\w+) with \"([^:\n]+)", body, re.M):
        print(f'   FAIL {m.group(1)}  on {m.group(2)}  {m.group(3)}')
PYEOF
	done < "$OUT/patches.tsv"
	exit 0
fi

if [[ "${1:-}" == "--rate" ]]; then
	CTX="${2:?check context, e.g. TestRunner_mesh-tester}"
	N="${3:-100}"
	BEFORE="${4:+&before=$4}"
	fetch "$API/patches/?project=bluetooth&order=-date&per_page=$N$BEFORE" "$OUT/patches.json" || exit 2
	python3 - "$OUT/patches.json" <<'PYEOF' > "$OUT/patches.tsv"
import json, sys
for p in json.load(open(sys.argv[1])):
    print(f'{p["date"][:16]}\t{p["id"]}\t{p["name"]}')
PYEOF
	fail=0; ok=0; other=0
	while IFS=$'\t' read -r date id name; do
		line=$(checks_line "$id") || continue
		state=$(grep -oE "(^| )$CTX:[a-z]+" <<<"$line" | cut -d: -f2)
		[[ -n "$state" ]] || continue
		printf '%s  %s  %-8s  %s\n' "$date" "$id" "$state" "$name"
		case "$state" in fail) fail=$((fail + 1)) ;; success) ok=$((ok + 1)) ;; *) other=$((other + 1)) ;; esac
	done < "$OUT/patches.tsv"
	echo "$CTX over the $N most recent patches: fail $fail   success $ok   other $other"
	exit 0
fi

N="${1:-25}"
fetch "$API/patches/?project=bluetooth&order=-date&per_page=$N" "$OUT/patches.json" || exit 2
python3 - "$OUT/patches.json" <<'PYEOF' > "$OUT/patches.tsv"
import json, sys
for p in json.load(open(sys.argv[1])):
    print(f'{p["date"][:16]}\t{p["id"]}\t{p["name"]}')
PYEOF
while IFS=$'\t' read -r date id name; do
	line=$(checks_line "$id") || line="(checks unavailable)"
	printf '%s  %s  %s  %s\n' "$date" "$id" "${line:-(no checks)}" "$name"
done < "$OUT/patches.tsv"
