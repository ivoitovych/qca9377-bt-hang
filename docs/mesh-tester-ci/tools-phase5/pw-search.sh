#!/bin/bash
# pw-search.sh — read-only patchwork search for a patch by name words.
#   tmp/mesh-tester-ci/pw-search.sh <project> <query words...>
# Writes the raw JSON to tmp/mesh-tester-ci/logs/phase5/patchwork-<project>-<slug>.json
# and prints one line per hit: date  id  state  name. Exits 2 if the API is unreachable.
set -uo pipefail
PROJECT="${1:?project}"; shift
Q="$*"
SLUG="$(echo "$Q" | tr ' /' '--' | tr -cd 'A-Za-z0-9_-')"
OUT="/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/logs/phase5/patchwork-${PROJECT}-${SLUG}.json"
UA="qca9377-bt-hang/pw-search (curl)"
ENC="$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$Q")"
URL="https://patchwork.kernel.org/api/1.3/patches/?project=${PROJECT}&q=${ENC}&order=-date&per_page=50"
echo "URL: $URL"
if ! curl -fsSL -A "$UA" --max-time 60 "$URL" -o "$OUT"; then
	echo "cannot fetch $URL" >&2
	exit 2
fi
python3 - "$OUT" <<'PYEOF'
import json, sys
hits = json.load(open(sys.argv[1]))
print(f"hits: {len(hits)}")
for p in hits:
    print(f'{p["date"][:16]}  {p["id"]}  {p.get("state","?"):<14} {p["name"]}')
PYEOF
echo "saved: $OUT"
