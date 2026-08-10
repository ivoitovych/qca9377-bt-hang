#!/bin/bash
# bt-timeline — merge every Bluetooth-relevant log stream into one chronology.
#
#   bt-timeline                    # this boot
#   bt-timeline -30m               # last 30 minutes
#   bt-timeline "2026-08-10 06:00" # since a timestamp
#   bt-timeline -1h --raw          # no colour, for pasting into a bug report
#   bt-timeline --all              # include bluetoothd endpoint-registration noise
#
# Merges, tagged by source:
#   MARK    your bt-mark annotations  — what you were doing
#   KERN    kernel hci/usb/btusb events
#   BLUED   bluetoothd (profiles, AVDTP, connections)
#   WDOG    bt-hang-watchdog decisions and actions
#   TRACE   HCI capture rotation events
#
# Reconstructing a stall means correlating all five. Reading them separately
# loses the ordering that explains the mechanism.

set -uo pipefail

RAW=0
ALL=0
SINCE=""
for a in "$@"; do
    case "$a" in
        --raw) RAW=1 ;;
        --all) ALL=1 ;;   # include bluetoothd endpoint-registration noise
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) SINCE="$a" ;;
    esac
done

if (( RAW )); then
    C_MARK=""; C_KERN=""; C_BLUE=""; C_WDOG=""; C_TRC=""; C_HOT=""; C_OFF=""
else
    C_MARK=$'\033[1;35m'; C_KERN=$'\033[36m'; C_BLUE=$'\033[34m'
    C_WDOG=$'\033[1;33m'; C_TRC=$'\033[90m'; C_HOT=$'\033[1;31m'; C_OFF=$'\033[0m'
fi

# journalctl accepts "-30m" style only via --since; default to this boot.
if [[ -n "$SINCE" ]]; then
    SEL=(--since "$SINCE")
else
    SEL=(-b 0)
fi

TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT

# Each stream is collected separately with epoch timestamps, tagged, then merged
# by sort. Doing it in one journalctl call would work, but separate calls let
# each stream be filtered on its own terms (the kernel one needs it badly).
grab() { # tag, extra journalctl args...
    local tag="$1"; shift
    journalctl "${SEL[@]}" -o short-unix --no-pager "$@" 2>/dev/null \
      | awk -v t="$tag" '{ ts=$1; $1=""; sub(/^ /,""); printf "%s\t%s\t%s\n", ts, t, $0 }'
}

# Kernel: filter to what is relevant, or the timeline drowns in unrelated boot noise.
grab KERN -k | grep -iE "hci|btusb|bluetooth|usb [0-9]+-[0-9]|xhci" >> "$TMP" || true
# bluetoothd's A2DP endpoint registrations are ~50% of its output and carry no
# diagnostic value here; they drown the AVDTP/connection events that matter.
if (( ALL )); then
    grab BLUED -u bluetooth >> "$TMP" || true
else
    grab BLUED -u bluetooth | grep -vE "Endpoint (registered|unregistered)" >> "$TMP" || true
fi
grab WDOG  -u bt-hang-watchdog                                      >> "$TMP" || true
grab TRACE -u bt-trace                                              >> "$TMP" || true
grab MARK  -t bt-mark                                               >> "$TMP" || true

if [[ ! -s "$TMP" ]]; then
    echo "no events in range"; exit 0
fi

echo "BLUETOOTH TIMELINE — ${SINCE:-current boot}"
echo "─────────────────────────────────────────────────────────────────────────"

sort -n -k1,1 "$TMP" | while IFS=$'\t' read -r ts tag msg; do
    when=$(date -d "@${ts%.*}" '+%H:%M:%S' 2>/dev/null || echo "$ts")
    # Strip the "host process[pid]:" prefix journalctl leaves on userspace lines.
    msg=${msg#*: }
    case "$tag" in
        MARK)  col="$C_MARK" ;;
        WDOG)  col="$C_WDOG" ;;
        KERN)  col="$C_KERN" ;;
        BLUED) col="$C_BLUE" ;;
        *)     col="$C_TRC"  ;;
    esac
    # Highlight the signatures that matter, whatever stream they came from.
    if [[ "$msg" == *"tx timeout"* || "$msg" == *"RECOVERED"* || "$msg" == *"FATAL"* \
       || "$msg" == *"RECOVERY FAILED"* || "$msg" == *"intervening"* \
       || "$msg" == *"not accepting address"* || "$msg" == *"Connection timed out"* ]]; then
        col="$C_HOT"
    fi
    printf '%s  %s%-5s %s%s\n' "$when" "$col" "$tag" "$msg" "$C_OFF"
done

echo "─────────────────────────────────────────────────────────────────────────"
printf 'events: %s   (MARK=%s KERN=%s BLUED=%s WDOG=%s)\n' \
    "$(wc -l < "$TMP")" \
    "$(grep -c $'\tMARK\t'  "$TMP" || true)" \
    "$(grep -c $'\tKERN\t'  "$TMP" || true)" \
    "$(grep -c $'\tBLUED\t' "$TMP" || true)" \
    "$(grep -c $'\tWDOG\t'  "$TMP" || true)"
