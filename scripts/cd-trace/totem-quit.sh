#!/bin/bash
# totem-quit.sh — ask the desktop user's Totem to quit (its own "quit" action over D-Bus), and
# wait up to 10 s for it to exit. Run as root. Used before totem-debug.sh (issue X1).
set -uo pipefail
ENVV=(XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus)
if ! pgrep -x totem >/dev/null; then
    echo "totem is not running"
    exit 0
fi
runuser -u i -- env "${ENVV[@]}" gdbus call --session --dest org.gnome.Totem \
    --object-path /org/gnome/Totem --method org.gtk.Actions.Activate quit '[]' '{}' >/dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x totem >/dev/null || { echo "totem quit"; exit 0; }
    read -r -t 1 < /dev/zero || true
done
echo "totem still running after 10 s" >&2
exit 1
