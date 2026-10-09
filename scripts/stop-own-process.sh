#!/bin/bash
# stop-own-process.sh — stop processes this project started (QEMU guests,
# builds, test runs), and nothing else.
#
#   scripts/stop-own-process.sh <pid>...
#
# A PID is signalled (TERM) only if its command line names the project
# directory and it is not one of the host's Bluetooth or audio processes.
# Anything else is refused and named. The family laptop's Bluetooth stack
# is touched only by the operator.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
[ $# -ge 1 ] || { echo "usage: $0 <pid>..." >&2; exit 2; }
rc=0
for pid in "$@"; do
    case "$pid" in ''|*[!0-9]*) echo "refused $pid: not a PID" >&2; rc=1; continue ;; esac
    if [ ! -r "/proc/$pid/cmdline" ]; then
        echo "gone    $pid"
        continue
    fi
    cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline")
    comm=$(cat "/proc/$pid/comm")
    case "$comm" in
        bluetoothd|pipewire*|wireplumber|obexd|btmon|pulseaudio)
            echo "refused $pid: host Bluetooth/audio process ($comm)" >&2; rc=1; continue ;;
    esac
    case "$cmd" in
        *"$REPO"*) ;;
        *) echo "refused $pid: not started from the project: ${cmd:0:120}" >&2; rc=1; continue ;;
    esac
    if kill -TERM "$pid"; then
        echo "stopped $pid: ${cmd:0:120}"
    else
        rc=1
    fi
done
exit "$rc"
