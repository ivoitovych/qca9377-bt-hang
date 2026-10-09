#!/bin/bash
# pw-patch.sh — read-only: one patchwork patch's metadata and check states.
#   tmp/mesh-tester-ci/pw-patch.sh <patch-id>
# Saves ONLY metadata (no diff, no body) to logs/phase5/patchwork-patch-<id>.txt;
# prints the headers, the body and the diff to stdout for reading. Nothing from
# the diff is written to any file in this project.
set -uo pipefail
ID="${1:?patch id}"
API="https://patchwork.kernel.org/api/1.3"
LOG="/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/logs/phase5/patchwork-patch-${ID}.txt"
UA="qca9377-bt-hang/pw-patch (curl)"
TMP="$(mktemp)"
trap 'rm -f "$TMP" "$TMP.checks"' EXIT
curl -fsSL -A "$UA" --max-time 60 "$API/patches/$ID/" -o "$TMP" || { echo "cannot fetch patch $ID" >&2; exit 2; }
curl -fsSL -A "$UA" --max-time 60 "$API/patches/$ID/checks/" -o "$TMP.checks" || { echo "cannot fetch checks $ID" >&2; exit 2; }
python3 - "$TMP" "$TMP.checks" "$LOG" <<'PYEOF'
import json, sys
p = json.load(open(sys.argv[1]))
checks = json.load(open(sys.argv[2]))
seen = {}
for c in checks:
    seen[c["context"]] = (c["state"], c.get("date", "")[:16])
meta = []
meta.append(f'id:        {p["id"]}')
meta.append(f'name:      {p["name"]}')
meta.append(f'date:      {p["date"]}')
meta.append(f'state:     {p.get("state")}')
meta.append(f'submitter: {p["submitter"]["name"]}')
meta.append(f'msgid:     {p.get("msgid")}')
meta.append(f'series:    {[s["name"] for s in p.get("series", [])]}')
meta.append(f'delegate:  {p.get("delegate")}')
meta.append(f'archived:  {p.get("archived")}')
meta.append(f'checks:    ' + " ".join(f"{k}:{v[0]}" for k, v in sorted(seen.items())))
open(sys.argv[3], "w").write("\n".join(meta) + "\n")
print("\n".join(meta))
print("---- headers (stdout only) ----")
for k in ("From", "Date", "Subject", "Message-ID", "In-Reply-To"):
    v = p.get("headers", {}).get(k)
    if v:
        print(f"{k}: {v}")
print("---- content (stdout only) ----")
print(p.get("content", ""))
print("---- diff (stdout only, NOT saved) ----")
print(p.get("diff", ""))
PYEOF
echo "saved metadata: $LOG"
