#!/bin/bash
# trial-close-now.sh — close the open trial by hand with main's closer,
# passively, and optionally open the next one.
#
#   scripts/trial-close-now.sh [--reopen]
#
# WHY (2026-10-18, the operator's request). Until main's tools are installed,
# the shutdown close of the installed 09-18 bt-trial decodes every capture
# before it writes the row, so a shutdown very likely loses a trial that saw a
# call. Closing by hand first leaves the shutdown nothing to lose.
#
# How, and why each choice:
#   * main's tools/bt-trial autostop, run from this checkout: the shutdown path,
#     PASSIVE (the verdict from the journal; no command to the controller), and
#     main's order (the row first). Nothing is installed.
#   * PATH puts main's tools/ and bin/ first, so the close's bt-state and
#     bt-mark are main's probe-free ones. The installed 09-18 bt-mark sends
#     HCI Read Local Name (hciconfig name) on every mark.
#   * BT_TRIAL_SCAN_BUDGET=600: no shutdown is waiting, so sco_sent and
#     usb_lost are counted rather than "?".
#   * The closer's own SCO decode is skipped (empty capture directories): it
#     uses COLUMNS, which btmon ignores, and can never keep a record (and it
#     would read 48 GB). sco-params.txt is then written by
#     scripts/trial-sco-decode.py at full width for the trial's window.
#   * --reopen: tools/bt-trial autostart <the same build>, as the boot unit does
#     (the unit sets BT_BUILD; the loaded E3 module carries no version suffix),
#     plus a step line saying the trial was opened by hand mid-boot.
#
# bt-mark and bt-state ask bluetoothd over D-Bus (`bluetoothctl devices
# Connected`); a bluetoothctl MGMT open can crash the capture's btmon 5.72
# (BT-4; 2026-10-18 16:59:10), costing about 1 s of trace. Nothing reaches the
# controller.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CUR=/run/bt-trial/current
[[ -r "$CUR" ]] || { echo "no open trial ($CUR)" >&2; exit 1; }
start=$(grep '^start=' "$CUR" | cut -d= -f2)
dir=$(grep '^dir=' "$CUR" | cut -d= -f2-)
build=$(grep '^build=' "$CUR" | cut -d= -f2-)
n=$(grep '^n=' "$CUR" | cut -d= -f2)
[[ "$start" =~ ^[0-9]+$ && -d "$dir" && -n "$build" ]] || { echo "$CUR is incomplete" >&2; exit 1; }
cp "$CUR" "$dir/current-at-close.txt" || exit 1
empty=$(mktemp -d "$HERE/tmp/trial-close-nocapture.XXXXXX") || exit 1
P="$HERE/tools:$HERE/bin:/usr/sbin:/usr/bin:/sbin:/bin"

echo "closing $build #$n (opened $(date -d "@$start" '+%Y-%m-%d %H:%M:%S'))"
t0=$(date +%s)
env -i PATH="$P" HOME="${HOME:-/root}" LANG=C.UTF-8 BT_TRIAL_SCAN_BUDGET=600 \
    BT_CAPTURE_DIR="$empty" BT_TRACE_DIR="$empty" \
    "$HERE/tools/bt-trial" autostop > "$dir/close-output.txt" 2>&1
rc=$?
end=$(date +%s)
echo "close: rc=$rc, $(( end - t0 )) s"
if [[ -e "$CUR" ]]; then
    echo "the trial is still open: see $dir/close-output.txt" >&2
    exit 1
fi
tail -n 1 "$HERE/evidence/trials/results.tsv"

t0=$(date +%s)
python3 -I "$HERE/scripts/trial-sco-decode.py" "$start" "$end" > "$dir/sco-params.txt" 2>&1
echo "sco decode: rc=$?, $(( $(date +%s) - t0 )) s"

if [[ "${1:-}" == --reopen ]]; then
    env -i PATH="$P" HOME="${HOME:-/root}" LANG=C.UTF-8 \
        "$HERE/tools/bt-trial" autostart "$build"
    echo "open: rc=$?"
    env -i PATH="$P" HOME="${HOME:-/root}" LANG=C.UTF-8 \
        "$HERE/tools/bt-trial" step "opened by hand mid-boot (scripts/trial-close-now.sh --reopen) after $build #$n was closed by hand; not aligned with the boot"
    cat "$CUR"
fi
