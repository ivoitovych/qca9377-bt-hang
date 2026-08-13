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

# AWK CAPABILITY GATE. The patterns rely on ERE interval expressions applied to
# GROUPS — `(...){5,}`, `(...){3}`. Not every awk implements them, and the ways
# they fail are not symmetric:
#
#   * gawk           correct.
#   * mawk 1.3.4     BROKEN, two different ways, neither of them an error:
#                      - `[0-9a-fA-F]{2}(...){5,}` aborts the regex compiler
#                        outright ("REcompile() - panic: values still on machine
#                        stack"), which at least fails loudly;
#                      - an interval on a group is otherwise treated as `+`, so
#                        `(X){3}` matches ONE repetition. `11:22` — two hex
#                        pairs, not an address — matches the MAC pattern and
#                        would be REPLACED, and `([0-9]{1,3}\.){3}[0-9]{1,3}`
#                        matches `01.1`, so a placeholder written by pass 2
#                        gets partly overwritten by pass 3.
#
# The second mode is the dangerous one, and it is why this gate is not a
# positive test. A probe that only asks "does a real MAC match?" is answered
# correctly BY ACCIDENT on mawk: `(X){5,}` degraded to `(X)+` still matches a
# full address, greedily, at the right length. The engine looks fine and is not.
#
# So each pattern is probed BOTH ways: a string that must match at an exact
# length, and a string that must NOT match at all. That is the same lesson the
# header block records about verification — "verification only tested the forms
# the substituter already knew" — applied to the engine instead of the input.
#
# Do NOT try to make these patterns mawk-safe by expanding the inner intervals.
# That was attempted: it stops the panic, so the tool appears to work, while
# `(group){n}` stays degraded and the over-matching above is live. Refusing to
# run is the correct outcome on an engine that cannot express the patterns.
MAC_RE='/[0-9a-fA-F]{2}([:_-][0-9a-fA-F]{2}){5,}/'
UUID_RE='/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/'
IPV4_RE='/([0-9]{1,3}\.){3}[0-9]{1,3}/'

# must_match <input> <exact RLENGTH> <pattern> ; must_miss <input> <pattern>
must_match() { echo "$1" | awk -v w="$2" "{exit !(match(\$0, $3) && RLENGTH == w)}" 2>/dev/null; }
must_miss()  { echo "$1" | awk               "{exit  (match(\$0, $2) != 0)}"        2>/dev/null; }

awk_ok=1
must_match "00:11:22:33:44:55:66:77" 23 "$MAC_RE"                  || awk_ok=0
must_miss  "11:22"                       "$MAC_RE"                 || awk_ok=0
must_miss  "aa:bb:cc"                    "$MAC_RE"                 || awk_ok=0
must_match "00000000-0000-0000-0000-000000000000" 36 "$UUID_RE"    || awk_ok=0
must_match "255.255.255.255" 15 "$IPV4_RE"                         || awk_ok=0
must_miss  "01.1"                        "$IPV4_RE"                || awk_ok=0

if (( ! awk_ok )); then
    echo "FAIL: this awk mishandles ERE intervals on groups; refusing to run." >&2
    echo "      Redaction would be wrong in BOTH directions — short hex runs" >&2
    echo "      replaced as if they were addresses, and real addresses only" >&2
    echo "      partly replaced. Neither is visible in the output." >&2
    echo "      Install gawk and re-run:  sudo apt install gawk" >&2
    echo "      (mawk 1.3.4 is NOT sufficient, despite earlier advice here.)" >&2
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
        key  = tolower(raw); gsub(/-/, ":", key)   # dash and colon forms alias
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
