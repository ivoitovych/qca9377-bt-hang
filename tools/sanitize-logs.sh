#!/bin/bash
# sanitize-logs.sh — strip identifying data from kernel/bluetoothd logs before
# publishing them.
#
#   ./tools/sanitize-logs.sh <input.log> [output.log]
#
# Replaces, deterministically (the same input always maps to the same
# placeholder, so cross-references within the log stay readable):
#
#   MAC addresses / BSSIDs  -> AA:BB:CC:00:00:NN
#   UUIDs                   -> <UUID-NN>
#   IPv4 addresses          -> <IPV4-NN>
#
# WHY THIS MATTERS: a Wi-Fi access point BSSID is indexed by public geolocation
# databases (WiGLE, Google, Apple). Publishing one can reveal the physical
# location of the machine. Kernel logs contain them by default — see the
# "authenticate with <BSSID>" lines emitted by mac80211.
#
# IMPLEMENTATION NOTE: each pass builds its output incrementally rather than
# rewriting `line` in place. A naive in-place loop never terminates, because a
# replacement such as AA:BB:CC:00:00:01 itself matches the MAC pattern and the
# scanner rediscovers its own output forever.

set -euo pipefail

IN="${1:?usage: sanitize-logs.sh <input.log> [output.log]}"
OUT="${2:-${IN%.log}.sanitized.log}"

[[ -r "$IN" ]] || { echo "cannot read $IN" >&2; exit 1; }

awk '
function pseudo(kind, key, arr,   n) {
    if (key in arr) return arr[key]
    n = ++cnt[kind]
    if      (kind == "mac")  arr[key] = sprintf("AA:BB:CC:00:00:%02d", n)
    else if (kind == "uuid") arr[key] = sprintf("<UUID-%02d>", n)
    else if (kind == "ip")   arr[key] = sprintf("<IPV4-%02d>", n)
    return arr[key]
}
{
    line = $0

    # --- pass 1: UUIDs -----------------------------------------------------
    out = ""
    while (match(line, /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/)) {
        raw = substr(line, RSTART, RLENGTH)
        out  = out substr(line, 1, RSTART-1) pseudo("uuid", tolower(raw), U)
        line = substr(line, RSTART + RLENGTH)
    }
    line = out line

    # --- pass 2: MAC addresses / BSSIDs ------------------------------------
    out = ""
    while (match(line, /[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]/)) {
        raw = substr(line, RSTART, RLENGTH)
        out  = out substr(line, 1, RSTART-1) pseudo("mac", tolower(raw), M)
        line = substr(line, RSTART + RLENGTH)
    }
    line = out line

    # --- pass 3: IPv4 ------------------------------------------------------
    out = ""
    while (match(line, /([0-9]{1,3}\.){3}[0-9]{1,3}/)) {
        raw = substr(line, RSTART, RLENGTH)
        if (raw == "0.0.0.0" || raw == "127.0.0.1")
            out = out substr(line, 1, RSTART + RLENGTH - 1)
        else
            out = out substr(line, 1, RSTART-1) pseudo("ip", raw, P)
        line = substr(line, RSTART + RLENGTH)
    }
    print out line
}
' "$IN" > "$OUT"

echo "wrote $OUT"

# --- verification ----------------------------------------------------------
leftover=$(grep -oEi '([0-9a-f]{2}:){5}[0-9a-f]{2}' "$OUT" 2>/dev/null \
           | grep -vi '^aa:bb:cc' | sort -u || true)
if [[ -n "$leftover" ]]; then
    echo "FAIL: unsanitised MAC-like strings remain:" >&2
    printf '  %s\n' $leftover >&2
    exit 1
fi

uuids=$(grep -oEi '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$OUT" 2>/dev/null | sort -u || true)
if [[ -n "$uuids" ]]; then
    echo "FAIL: raw UUIDs remain:" >&2
    printf '  %s\n' $uuids >&2
    exit 1
fi

echo "verified: no MACs, BSSIDs or UUIDs remain"
