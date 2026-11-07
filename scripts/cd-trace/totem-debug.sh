#!/bin/bash
# totem-debug.sh — start Totem on the desktop with GStreamer debug logging, optionally playing a
# URI, for tracing audio-CD playback (issue X1). Run as root; Totem runs as the desktop user.
#
#   scripts/cd-trace/totem-debug.sh [<uri>] [<logfile>]
#
#   <uri>      e.g. "cdda://sr0/Track%201.wav" (gio list cdda://sr0/ shows the tracks);
#              without it Totem just opens, and a track opened later from the file manager goes
#              to this instance
#   <logfile>  default /tmp/cd-gaps-gst.log (the desktop user must be able to write it)
#
# Close any running Totem first: a second launch hands the URI to the running instance, which
# keeps its own (non-debug) environment.
set -uo pipefail
URI="${1:-}"
LOG="${2:-/tmp/cd-gaps-gst.log}"
CATS="3,giosrc:6,basesrc:5,wavparse:5,queue2:5,multiqueue:4,playsink:4,pulsesink:6,audiobasesink:5,audioringbuffer:5,audiosink:5"

if pgrep -x totem >/dev/null; then
    echo "totem is already running; close it first" >&2
    exit 2
fi

ENVV=(XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0
      DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
      GST_DEBUG_NO_COLOR=1 "GST_DEBUG_FILE=$LOG" "GST_DEBUG=$CATS")

runuser -u i -- env "${ENVV[@]}" totem &
echo "totem started (pid $!), GStreamer log: $LOG"
if [[ -n "$URI" ]]; then
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        runuser -u i -- env "${ENVV[@]}" gdbus introspect --session --dest org.gnome.Totem \
            --object-path /org/gnome/Totem >/dev/null 2>&1 && break
        read -r -t 1 < /dev/zero || true
    done
    runuser -u i -- env "${ENVV[@]}" totem "$URI"
    echo "opened $URI"
fi
