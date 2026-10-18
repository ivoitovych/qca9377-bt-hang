#!/bin/bash
# trial-snapshot.sh — the open trial's record as of now, without closing it.
#
#   scripts/trial-snapshot.sh      writes <trial dir>/snapshot-<UTC stamp>/
#
# Nothing is sent to the controller, no unit is started or stopped, the open
# trial stays open and evidence/trials/results.tsv is not touched. Not quite
# read-only: bt-state and boot-bt-summary.sh ask bluetoothd over D-Bus
# (`bluetoothctl devices`), and a bluetoothctl MGMT open can crash the
# capture's btmon 5.72 (BT-4), which bt-trace logs and restarts within 1 s
# (2026-10-18: 16:56:11 and 16:59:10, during this script's first two runs).
#
# WHY (2026-10-18). Until main's tools are installed, the shutdown close of the
# installed 09-18 bt-trial decodes every capture before it writes the row, and
# systemd stops it at 90 s: the next shutdown very likely loses the open
# trial's row. The trial's state file lives in /run and goes with the boot.
# This keeps both, and the evidence the row summarises, before that happens.
#
# What it writes:
#   current.txt          /run/bt-trial/current, verbatim: start, build, number,
#                        the treatment and tool revision at open
#   row.tsv              the results row main's closer computes now, header
#                        included: tools/bt-trial autostop (the shutdown path,
#                        passive) run in a sandbox under tmp/: its own copy of
#                        the state, a scratch results file, the descriptive
#                        budget raised from 20 s to 600 s (no shutdown is
#                        waiting, so sco_sent and usb_lost are counted, not "?"),
#                        no capture directories (sco-params.txt below does that
#                        decode right), and a PATH without /usr/local/bin, so the
#                        installed bt-state, bt-mark and bt-incident cannot run
#                        (the installed 09-18 bt-mark sends HCI Read Local Name on
#                        every mark; main's bt-state runs separately below)
#   close-output.txt     what that close printed
#   state-now.txt        tools/bt-state, what the close writes as state-after.txt:
#                        probe-free by default (sysfs, the journal, and
#                        `bluetoothctl devices Connected` over D-Bus)
#   boot-bt-summary.txt  scripts/boot-bt-summary.sh <boot id>: the build loaded,
#                        the firmware lines, every error-level hci0 line and the
#                        SCO ledger with its totals (the BT-1 evidence)
#   sco-params.txt       scripts/trial-sco-decode.py <start>: the window's SCO
#                        requests at full width, both capture paths
#   README.txt           what this is, when, and how to use it if the row is lost
#   SHA256SUMS
#
# The snapshot covers the trial from its start to the snapshot time. After a
# shutdown that lost the row, the rest of the boot is in the journal of boot -1
# (scripts/boot-bt-summary.sh -1 for the ledger).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CUR="${BT_TRIAL_CURRENT:-/run/bt-trial/current}"
[[ -r "$CUR" ]] || { echo "no open trial ($CUR)" >&2; exit 1; }
start=$(grep '^start=' "$CUR" | cut -d= -f2)
dir=$(grep '^dir=' "$CUR" | cut -d= -f2-)
[[ "$start" =~ ^[0-9]+$ && -d "$dir" ]] || { echo "$CUR names no start or no directory" >&2; exit 1; }

stamp=$(date -u +%Y%m%dT%H%M%SZ)
out="$dir/snapshot-$stamp"
mkdir "$out" || exit 1
cp "$CUR" "$out/current.txt" || exit 1
echo "snapshot: $out"

# The sandbox the closer runs in. Kept after the run (it is small); the
# closer's own sco-params.txt there is the skipped decode, not evidence.
sb=$(mktemp -d "$HERE/tmp/trial-snapshot-$stamp.XXXXXX") || exit 1
mkdir -p "$sb/repo/evidence/trials" "$sb/state" "$sb/trialdir" "$sb/nocapture"
# measurement_rev reads `git rev-parse HEAD` in the repository: a gitfile
# lends it this checkout's, and nothing else of git is used.
printf 'gitdir: %s\n' "$(git -C "$HERE" rev-parse --absolute-git-dir)" > "$sb/repo/.git"
: > "$sb/repo/install.sh"
sed "s|^dir=.*|dir=$sb/trialdir|" "$CUR" > "$sb/state/current"

t0=$(date +%s)
env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME="${HOME:-/root}" LANG=C.UTF-8 \
    BT_REPO="$sb/repo" BT_STATE="$sb/state" BT_TRIAL_SCAN_BUDGET=600 \
    BT_CAPTURE_DIR="$sb/nocapture" BT_TRACE_DIR="$sb/nocapture" \
    "$HERE/tools/bt-trial" autostop > "$out/close-output.txt" 2>&1
rc=$?
echo "close: rc=$rc, $(( $(date +%s) - t0 )) s"
if [[ -s "$sb/repo/evidence/trials/results.tsv" ]]; then
    cp "$sb/repo/evidence/trials/results.tsv" "$out/row.tsv"
else
    echo "close wrote no row; see $out/close-output.txt" >&2
fi

t0=$(date +%s)
"$HERE/tools/bt-state" > "$out/state-now.txt" 2>&1
echo "state: rc=$?, $(( $(date +%s) - t0 )) s"

boot=$(journalctl --list-boots --no-pager 2>/dev/null | awk '$1 == "0" { print $2 }')
t0=$(date +%s)
"$HERE/scripts/boot-bt-summary.sh" "${boot:-0}" > "$out/boot-bt-summary.txt" 2>&1
echo "boot summary (${boot:-0}): rc=$?, $(( $(date +%s) - t0 )) s"

t0=$(date +%s)
python3 -I "$HERE/scripts/trial-sco-decode.py" "$start" > "$out/sco-params.txt" 2>&1
echo "sco decode: rc=$?, $(( $(date +%s) - t0 )) s"

build=$(grep '^build=' "$CUR" | cut -d= -f2-)
n=$(grep '^n=' "$CUR" | cut -d= -f2)
cat > "$out/README.txt" <<EOF
Snapshot of the open trial $build #$n, taken $stamp by scripts/trial-snapshot.sh
(checkout $(git -C "$HERE" rev-parse --short HEAD), boot ${boot:-?}). The trial was left open.

It covers the trial from its start ($(date -d "@$start" '+%Y-%m-%d %H:%M:%S %z')) to the
snapshot. row.tsv is the row main's closer computes at that moment (passive,
600 s budget); the real close at shutdown writes its own row to
evidence/trials/results.tsv if it gets that far.

If the shutdown close writes no row: this row is the trial's record up to the
snapshot, and the rest of the boot is in the journal of boot ${boot:-?}
(scripts/boot-bt-summary.sh ${boot:-<boot id>} for its SCO ledger, timeouts and
error lines). Add a row to results.tsv only by a reviewed commit that says
where it came from; never edit this snapshot.

Nothing was sent to the controller and no unit was touched. bt-state and the
boot summary ask bluetoothd over D-Bus (bluetoothctl), and a bluetoothctl MGMT
open can crash the capture's btmon (BT-4): check `journalctl -u bt-trace` for a
"btmon exited" during the snapshot.
EOF
( cd "$out" && sha256sum README.txt current.txt row.tsv close-output.txt state-now.txt boot-bt-summary.txt sco-params.txt > SHA256SUMS 2>/dev/null )
echo "done: $out"
