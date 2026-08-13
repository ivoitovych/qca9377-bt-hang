#!/bin/bash
# sanitize-logs.sh — strip identifying data from kernel/bluetoothd logs before
# publishing them.
#
#   ./tools/sanitize-logs.sh <input.log> [output.log]
#
# Safe to use in place: ./tools/sanitize-logs.sh kernel.log kernel.log
# (output is built in a temp file and renamed only after verification passes).
#
# Replaces, deterministically (the same input always maps to the same
# placeholder, so cross-references within the log stay readable):
#
#   MAC addresses / BSSIDs  -> AA:BB:CC:00:00:NN   (colon, underscore OR dash separated)
#   UUIDs                   -> <UUID-NN>
#   IPv4 addresses          -> <IPV4-NN>           (0.0.0.0 / 127.0.0.1 kept)
#
# WHY THIS MATTERS: a Wi-Fi access point BSSID is indexed by public geolocation
# databases (WiGLE, Google, Apple). Publishing one can reveal the physical
# location of the machine. Kernel logs contain them by default — see the
# "authenticate with <BSSID>" lines emitted by mac80211.
#
# IMPLEMENTATION NOTES
#   * Each pass builds its output incrementally rather than rewriting `line` in
#     place. A naive in-place loop never terminates, because a replacement such
#     as AA:BB:CC:00:00:01 itself matches the MAC pattern and the scanner
#     rediscovers its own output forever.
#   * The MAC pattern uses {5,} so a longer hex run (e.g. an 8-group EUI-64)
#     is consumed whole. Matching exactly 6 groups would replace the first six
#     and leave the tail (":66:77") behind in the output.
#   * Verification checks colon AND dash AND underscore forms plus IPv4, so a
#     form the substituter misses cannot produce a false all-clear.
#   * UNDERSCORE was added on 2026-08-12 after 20 unsanitised addresses reached
#     a public commit. BlueZ names its D-Bus objects and PipeWire its audio
#     nodes with the address underscore-separated:
#         /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF
#         bluez_output.AA_BB_CC_DD_EE_FF.1
#     Enabling `bluetoothd -d` made those paths the dominant form in the logs,
#     so a separator this tool had never handled suddenly carried most of the
#     addresses. The colon form in the same files was scrubbed correctly, and
#     verification passed, because verification only tested the forms the
#     substituter already knew — the identical failure this comment block was
#     originally written to warn about. Adding a log source can change which
#     representations appear; the pattern must cover the format, not the habit.

set -euo pipefail

# -i takes any number of files and sanitises each in place.
#
# WHY THIS MODE EXISTS. Without it, cleaning several files means a shell loop
# (`for f in ...; do sanitize "$f" "$f"; done`). A loop puts a variable in the
# argument position, and a variable argument cannot be statically analysed — so
# the call matches no permission rule and prompts every single time, however
# many rules are configured. Accepting a file list keeps the invocation a
# literal command. Batch behaviour belongs in the tool, not in the caller's
# shell.
if [[ "${1:-}" == "-i" ]]; then
    shift
    [[ $# -gt 0 ]] || { echo "usage: sanitize-logs.sh -i <file> [file...]" >&2; exit 1; }
    rc=0
    for f in "$@"; do
        if [[ -r "$f" ]]; then
            "$0" "$f" "$f" || rc=1
        else
            echo "cannot read $f" >&2; rc=1
        fi
    done
    exit "$rc"
fi

IN="${1:?usage: sanitize-logs.sh <input.log> [output.log]  |  -i <file> [file...]}"
OUT="${2:-${IN%.log}.sanitized.log}"

[[ -r "$IN" ]] || { echo "cannot read $IN" >&2; exit 1; }

# The patterns rely on ERE interval expressions ({n}, {n,}). Some awk builds
# (older mawk) silently treat them as literals, which would pass everything
# through untouched while still reporting success. Refuse to run on those.
if ! echo "00:11:22:33:44:55:66:77" \
     | awk '{exit !(match($0, /[0-9a-fA-F]{2}([:_-][0-9a-fA-F]{2}){5,}/) && RLENGTH == 23)}'; then
    echo "FAIL: this awk does not support ERE interval expressions correctly." >&2
    echo "      Install gawk (or mawk >= 1.3.4) and retry." >&2
    exit 1
fi

# Build into a temp file so in-place use cannot truncate the input, and so a
# failed verification never leaves a half-sanitised file behind.
TMP=$(mktemp "${TMPDIR:-/tmp}/sanitize-logs.XXXXXX")
trap 'rm -f "$TMP"' EXIT

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

    # --- pass 1: UUIDs (before MACs: they contain hex runs) ----------------
    out = ""
    while (match(line, /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/)) {
        raw  = substr(line, RSTART, RLENGTH)
        out  = out substr(line, 1, RSTART-1) pseudo("uuid", tolower(raw), U)
        line = substr(line, RSTART + RLENGTH)
    }
    line = out line

    # --- pass 2: MAC addresses / BSSIDs, colon, underscore or dash separated ----------
    out = ""
    while (match(line, /[0-9a-fA-F]{2}([:_-][0-9a-fA-F]{2}){5,}/)) {
        raw  = substr(line, RSTART, RLENGTH)
        # ALL separator forms alias to one key. Colon (kernel), underscore
        # (BlueZ D-Bus paths, PipeWire node names) and dash spellings of the
        # same address must receive the SAME placeholder, or the documented
        # cross-reference property breaks exactly at the kernel<->bluetoothd
        # boundary a maintainer follows in a merged timeline. Underscore was
        # missing here even after the underscore LEAK was fixed: the
        # substitution learned the form, the aliasing did not.
        key  = tolower(raw); gsub(/[_-]/, ":", key)
        out  = out substr(line, 1, RSTART-1) pseudo("mac", key, M)
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
' "$IN" > "$TMP"

# --- verification ----------------------------------------------------------
fail=0

leftover=$(grep -oEi '[0-9a-f]{2}([:_-][0-9a-f]{2}){5,}' "$TMP" 2>/dev/null \
           | grep -vi '^aa:bb:cc:00:00:[0-9][0-9]$' | sort -u || true)
if [[ -n "$leftover" ]]; then
    echo "FAIL: unsanitised MAC-like strings remain:" >&2
    printf '  %s\n' $leftover >&2
    fail=1
fi

uuids=$(grep -oEi '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$TMP" 2>/dev/null | sort -u || true)
if [[ -n "$uuids" ]]; then
    echo "FAIL: raw UUIDs remain:" >&2
    printf '  %s\n' $uuids >&2
    fail=1
fi

ips=$(grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$TMP" 2>/dev/null \
      | grep -vE '^(0\.0\.0\.0|127\.0\.0\.1)$' | sort -u || true)
if [[ -n "$ips" ]]; then
    echo "FAIL: raw IPv4 addresses remain:" >&2
    printf '  %s\n' $ips >&2
    fail=1
fi

if (( fail )); then
    echo "output NOT written — $IN left untouched" >&2
    exit 1
fi

# Verification passed: publish the result. mv is atomic within a filesystem;
# fall back to a copy when TMPDIR is on a different one.
mv -f "$TMP" "$OUT" 2>/dev/null || { cp -f "$TMP" "$OUT"; rm -f "$TMP"; }
trap - EXIT

echo "wrote $OUT"
echo "verified: no MACs, BSSIDs, UUIDs or IPv4 addresses remain"
