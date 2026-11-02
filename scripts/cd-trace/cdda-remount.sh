#!/bin/bash
# cdda-remount.sh — unmount and mount the audio CD in the desktop user's session, so that gvfs
# starts a fresh gvfsd-cdda (e.g. after a test binary was installed). Run as root; Totem should
# be closed first. Prints the new backend's pid and the checksum of the binary it runs.
set -uo pipefail
ENVV=(XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus)
runuser -u i -- env "${ENVV[@]}" gio mount -u cdda://sr0/ || true
for _ in 1 2 3 4 5; do
    pgrep -x gvfsd-cdda >/dev/null || break
    read -r -t 1 < /dev/zero || true
done
runuser -u i -- env "${ENVV[@]}" gio mount cdda://sr0/
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pid="$(pgrep -x gvfsd-cdda | head -n 1)"
    [[ -n "$pid" ]] && break
    read -r -t 1 < /dev/zero || true
done
[[ -n "${pid:-}" ]] || { echo "no gvfsd-cdda after mount" >&2; exit 1; }
echo "gvfsd-cdda pid $pid"
sha256sum "/proc/$pid/exe"
