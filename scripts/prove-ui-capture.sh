#!/bin/bash
# prove-ui-capture.sh — drive tools/bt-ui-capture end to end in a sandbox and
# assert what it does, without a session, a PipeWire, a kernel or a desktop.
#
#   scripts/prove-ui-capture.sh [path/to/bt-ui-capture]
#
# WHY A STANDALONE PROOF. tests/run-tests refuses while a trial is open, and on
# the investigation machine one is open by design; this tool was written there,
# for that machine, and acts on the operator's session. Its promises are the
# kind that are only worth anything if executed: `plan` changes nothing; every
# acting subcommand refuses without root; `start` records what it changes
# BEFORE changing it and `stop` puts exactly that back; a user file without the
# tool's marker is never overwritten or removed; a second `start` neither
# re-records the "before" values nor stacks units; the AT-SPI recorder keeps
# only the application under test and names the widget; monitor files rotate
# and stay bounded; `collect` publishes nothing that still holds an address.
#
# HOW IT STAYS HERMETIC. Every command the tool runs against the system is a
# stub on PATH (runuser passes through as the caller; systemd-run, systemctl,
# pw-metadata, loginctl, pgrep, busctl, dbus-monitor, gsettings, dpkg-query,
# chown record their arguments); every path is a seam into a temporary tree
# (BT_UI_BASE, BT_UI_HOME, BT_DYNDBG_CTL, BT_UI_APPDIR, BT_UI_CAPTURE_DIRS,
# BT_JOURNAL_FIXTURE). The AT-SPI check runs the real recorder against a
# PRIVATE dbus-daemon whose socket lives in the work directory, started here
# and stopped at exit, with a small emitter that names itself gnome-control-c.
# Nothing reaches the real buses, the user's home, the journal or /sys.
# Output: tmp/prove-ui-capture.*/ (ignored by git).
#
# Pass a modified copy of the tool as the argument to watch a check go red
# (house rule 1: a new check must be observed to fail).

set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TOOL_SRC="${1:-$ROOT/tools/bt-ui-capture}"
[[ -r "$TOOL_SRC" ]] || { echo "no tool at $TOOL_SRC" >&2; exit 2; }

mkdir -p "$ROOT/tmp"
T=$(mktemp -d "$ROOT/tmp/prove-ui-capture.XXXXXX") || exit 2
# Here-documents, sort and the sanitiser's mktemp all honour TMPDIR: keep every
# temporary file of this run inside the work directory.
mkdir -p "$T/tmpdir"; export TMPDIR="$T/tmpdir"
BUS_PID=""
cleanup() { [[ -n "$BUS_PID" ]] && kill "$BUS_PID" 2>/dev/null; return 0; }
trap cleanup EXIT

pass=0; fail=0
ok()    { echo "  ok    $1"; pass=$((pass + 1)); }
bad()   { echo "  FAIL  $1"; fail=$((fail + 1)); }
truth() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
count() { local n; n=$(grep -c -E -- "$1" "$2" 2>/dev/null || true); echo "${n:-0}"; }
eq()    { [[ "$1" == "$2" ]]; }

# ── the tool, its library and the sanitiser, copied together ─────────────
mkdir -p "$T/tools/lib" "$T/repo/scripts" "$T/repo/bin" "$T/stub" "$T/base" "$T/home" \
         "$T/apps" "$T/fixture" "$T/cap/capture" "$T/cap/trace" "$T/state" "$T/bus"
cp "$TOOL_SRC" "$T/tools/bt-ui-capture"
cp "$ROOT/tools/lib/journal.sh" "$T/tools/lib/"
cp "$ROOT/tools/sanitize-logs.sh" "$T/tools/"
cp "$ROOT/scripts/bt-ui-atspi.py" "$T/repo/scripts/"
printf '#!/bin/sh\nexit 0\n' > "$T/repo/scripts/bt-audio-policy.py"
chmod +x "$T/tools/bt-ui-capture" "$T/tools/sanitize-logs.sh" "$T/repo/scripts/bt-audio-policy.py"
TOOL="$T/tools/bt-ui-capture"
export PROVE_CALLS="$T/calls.log" PROVE_STATE="$T/state"
CALLS="$PROVE_CALLS"; STATE="$PROVE_STATE"
: > "$CALLS"
echo 2 > "$STATE/pw-level"

# ── stubs: each records its arguments; the acting ones keep a little state ─
mkstub() { cat > "$T/stub/$1"; chmod +x "$T/stub/$1"; }
mkstub runuser <<'EOF'
#!/bin/bash
echo "runuser $*" >> "$PROVE_CALLS"
while [[ $# -gt 0 && "$1" != "--" ]]; do shift; done
shift
exec "$@"
EOF
mkstub systemd-run <<'EOF'
#!/bin/bash
echo "systemd-run $*" >> "$PROVE_CALLS"
for a in "$@"; do case "$a" in --unit=*) touch "$PROVE_STATE/active-${a#--unit=}" ;; esac; done
EOF
mkstub systemctl <<'EOF'
#!/bin/bash
echo "systemctl $*" >> "$PROVE_CALLS"
case "$1" in
    is-active) [[ -e "$PROVE_STATE/active-${*: -1}" ]] ;;
    stop) rm -f "$PROVE_STATE/active-$2" ;;
    show) echo "{ path=/usr/libexec/bluetooth/bluetoothd ; argv[]=/usr/libexec/bluetooth/bluetoothd -d }" ;;
esac
EOF
mkstub pw-metadata <<'EOF'
#!/bin/bash
echo "pw-metadata $*" >> "$PROVE_CALLS"
if [[ $# -ge 5 ]]; then echo "$5" > "$PROVE_STATE/pw-level"; exit 0; fi
echo 'Found "settings" metadata 31'
printf "update: id:0 key:'log.level' value:'%s' type:''\n" "$(cat "$PROVE_STATE/pw-level")"
EOF
mkstub loginctl <<'EOF'
#!/bin/bash
echo "loginctl $*" >> "$PROVE_CALLS"
case "$1" in show-seat) echo 4 ;; show-session) echo prove-user ;; show-user) echo no ;; esac
EOF
mkstub chown <<'EOF'
#!/bin/bash
echo "chown $*" >> "$PROVE_CALLS"
EOF
mkstub busctl <<'EOF'
#!/bin/bash
printf 's "%s"\n' "$(cat "$PROVE_STATE/bus-address")"
EOF
mkstub dbus-monitor <<'EOF'
#!/bin/bash
echo "dbus-monitor $*" >> "$PROVE_CALLS"
EOF
mkstub pgrep <<'EOF'
#!/bin/bash
exit 1
EOF
mkstub gsettings <<'EOF'
#!/bin/bash
echo false
EOF
mkstub dpkg-query <<'EOF'
#!/bin/bash
echo "pipewire 1.0.5-test"
EOF
cat > "$T/repo/bin/bt-mark" <<'EOF'
#!/bin/bash
echo "bt-mark $*" >> "$PROVE_CALLS"
EOF
chmod +x "$T/repo/bin/bt-mark"

# A dynamic-debug control file in the kernel's own wording (lines copied from
# /sys/kernel/debug/dynamic_debug/control on 7.0.0-34, sites trimmed).
CTL="$T/control"
cat > "$CTL" <<'EOF'
net/bluetooth/sco.c:84 [bluetooth]sco_conn_free =_ "conn %p\n"
net/bluetooth/sco.c:164 [bluetooth]sco_sock_timeout =_ "sock %p state %d\n"
net/bluetooth/sco.c:224 [bluetooth]sco_conn_add =_ "hcon %p conn %p\n"
net/bluetooth/sco.c:238 [bluetooth]sco_chan_del =_ "sk %p, conn %p, err %d\n"
net/bluetooth/sco.c:263 [bluetooth]sco_conn_del =_ "hcon %p conn %p, err %d\n"
net/bluetooth/sco.c:286 [bluetooth]__sco_chan_add =_ "conn %p\n"
net/bluetooth/sco.c:327 [bluetooth]sco_connect =_ "%pMR -> %pMR\n"
net/bluetooth/sco.c:412 [bluetooth]sco_send_frame =_ "sk %p len %d\n"
net/bluetooth/sco.c:431 [bluetooth]sco_recv_frame =_ "sk %p len %u\n"
net/bluetooth/sco.c:527 [bluetooth]sco_sock_kill =_ "sk %p state %d\n"
net/bluetooth/sco.c:544 [bluetooth]__sco_sock_close =_ "sk %p state %d socket %p\n"
net/bluetooth/sco.c:676 [bluetooth]sco_sock_connect =_ "sk %p\n"
net/bluetooth/sco.c:837 [bluetooth]sco_sock_sendmsg =_ "sock %p, sk %p\n"
net/bluetooth/sco.c:876 [bluetooth]sco_conn_defer_accept =_ "conn %p\n"
net/bluetooth/sco.c:1334 [bluetooth]sco_sock_shutdown =_ "sock %p, sk %p\n"
net/bluetooth/sco.c:1364 [bluetooth]sco_sock_release =_ "sock %p, sk %p\n"
net/bluetooth/sco.c:1388 [bluetooth]sco_conn_ready =_ "conn %p\n"
net/bluetooth/sco.c:1449 [bluetooth]sco_connect_ind =_ "hdev %s, bdaddr %pMR\n"
net/bluetooth/sco.c:1476 [bluetooth]sco_connect_cfm =_ "hcon %p bdaddr %pMR status %u\n"
net/bluetooth/sco.c:1495 [bluetooth]sco_disconn_cfm =_ "hcon %p reason %d\n"
net/bluetooth/sco.c:1524 [bluetooth]sco_recv_scodata =_ "conn %p len %u\n"
net/bluetooth/hci_conn.c:546 [bluetooth]hci_sco_setup =p "hcon %p\n"
EOF
cp "$CTL" "$T/control.orig"

printf '[Desktop Entry]\nName=Sound\nExec=gnome-control-center sound\nType=Application\n' > "$T/apps/gnome-sound-panel.desktop"
printf '[Desktop Entry]\nName=Bluetooth\nExec=gnome-control-center bluetooth\nType=Application\n' > "$T/apps/gnome-bluetooth-panel.desktop"
printf '[Desktop Entry]\nName=Settings\nExec=gnome-control-center\nType=Application\n' > "$T/apps/org.gnome.Settings.desktop"

export PATH="$T/stub:$PATH"
export BT_UI_BASE="$T/base" BT_UI_HOME="$T/home" BT_UI_UID=4242 BT_UI_REPO="$T/repo" \
       BT_DYNDBG_CTL="$CTL" BT_UI_APPDIR="$T/apps" BT_UI_CAPTURE_DIRS="$T/cap/capture $T/cap/trace" \
       BT_JOURNAL_FIXTURE="$T/fixture" BT_UI_EUID=0 BT_UI_MARK="$T/repo/bin/bt-mark"
unset BT_UI_USER

tree() { find "$T/base" "$T/home" -printf '%p %s\n' 2>/dev/null | sort; }
mutations() { count '^(systemd-run|systemctl stop|chown|bt-mark)|pw-metadata -n settings 0 ' "$CALLS"; }
APPS="$T/home/.local/share/applications"
DBUSSVC="$T/home/.local/share/dbus-1/services/org.gnome.Settings.service"

echo "── plan changes nothing"
before=$(tree)
out=$("$TOOL" plan 2>&1); rc=$?
first=$("$TOOL" 2>&1 | head -1)
truth "plan exits 0" eq "$rc" 0
truth "plan made no acting call (systemd-run, systemctl stop, chown, pw-metadata set, bt-mark)" eq "$(mutations)" 0
truth "plan left the session and home trees as they were" eq "$(tree)" "$before"
truth "plan left the dynamic-debug control untouched" cmp -s "$CTL" "$T/control.orig"
n=$(grep -c -e "would write 'module bluetooth func sco_connect +p'" -e "would run: systemd-run" <<<"$out" || true)
# one dynamic-debug line shown here + three monitors + the recorder
truth "plan names what start would change" eq "$n" 5
truth "plan is the default with no argument" eq "${first%% —*}" "bt-ui-capture plan"

echo "── every acting subcommand refuses without root"
for sub in start stop stage-restart unstage collect _monitor; do
    : > "$CALLS"
    o=$(BT_UI_EUID=1000 "$TOOL" "$sub" 2>&1); r=$?
    said=0; [[ "$o" == *"must run as root"* ]] && said=1
    truth "$sub refuses (exit 1, says root)" eq "$r/$said" "1/1"
    truth "$sub made no call before refusing" eq "$(wc -c < "$CALLS")" 0
done

echo "── start records, then changes; a foreign file is left alone"
printf '[Desktop Entry]\nName=Mine\nExec=my-own-launcher\n' > "$T/foreign.desktop"
mkdir -p "$APPS"
cp "$T/foreign.desktop" "$APPS/gnome-bluetooth-panel.desktop"
: > "$CALLS"
"$TOOL" start > "$T/start1.out" 2>&1; rc=$?
S=$(cat "$T/base/current" 2>/dev/null)
M="$S/manifest.txt"
truth "start exits 0" eq "$rc" 0
truth "start wrote the session pointer" test -n "$S" -a -d "$S"
truth "start recorded the PipeWire level it found (2)" eq "$(count '^pw_level_before=2$' "$M")" 1
truth "start set the PipeWire daemon level to 3" eq "$(cat "$STATE/pw-level")" 3
truth "start recorded all 16 sco.c functions as off before enabling" eq "$(count '^dyndbg_before\..*=_$' "$M")" 16
truth "start enabled the 16 connection-level sco.c functions" eq "$(count '^module bluetooth func .* \+p$' "$CTL")" 16
truth "start enabled no per-packet sco.c function" eq "$(count 'func (sco_send_frame|sco_recv_frame|sco_recv_scodata|sco_sock_sendmsg) ' "$CTL")" 0
truth "start wrote the sound-panel override with its marker" eq "$(count '^# bt-ui-capture' "$APPS/gnome-sound-panel.desktop")" 1
truth "start's override runs Settings with the debug domains" \
    eq "$(count '^Exec=env "G_MESSAGES_DEBUG=cc-sound-panel Gvc" gnome-control-center sound$' "$APPS/gnome-sound-panel.desktop")" 1
truth "start wrote the D-Bus activation override" eq "$(count '^Exec=/usr/bin/env "G_MESSAGES_DEBUG=' "$DBUSSVC")" 1
truth "start left a foreign launcher untouched" cmp -s "$T/foreign.desktop" "$APPS/gnome-bluetooth-panel.desktop"
truth "start launched exactly the three monitors" eq "$(count '^systemd-run .*--unit=bt-ui-(atspi|sysbus|sessbus) ' "$CALLS")" 3
truth "start started the recorder because it was not running" eq "$(count '^systemd-run .*--unit=bt-audio-policy ' "$CALLS")" 1
truth "start marked the journal" eq "$(count '^bt-mark ui-capture START' "$CALLS")" 1
truth "start copied the AT-SPI recorder into the session" test -r "$S/bin/bt-ui-atspi.py"

echo "── a second start is idempotent"
: > "$CALLS"
"$TOOL" start > "$T/start2.out" 2>&1; rc=$?
truth "second start exits 0 and reuses the session" eq "$rc:$(cat "$T/base/current")" "0:$S"
truth "second start did not re-record the before level" eq "$(count '^pw_level_before=' "$M")" 1
truth "second start launched no unit" eq "$(count '^systemd-run ' "$CALLS")" 0
truth "second start did not set the level again" eq "$(count 'pw-metadata -n settings 0 ' "$CALLS")" 0

echo "── stage-restart writes, unstage removes, a foreign drop-in stays"
PWD_DIR="$T/home/.config/systemd/user/pipewire.service.d"
mkdir -p "$PWD_DIR"
printf '[Service]\nEnvironment=FOO=1\n' > "$T/foreign.conf"
cp "$T/foreign.conf" "$PWD_DIR/90-bt-ui-capture.conf"
: > "$CALLS"
"$TOOL" stage-restart > "$T/stage.out" 2>&1; rc=$?
WPD="$T/home/.config/systemd/user/wireplumber.service.d/90-bt-ui-capture.conf"
PPD="$T/home/.config/systemd/user/pipewire-pulse.service.d/90-bt-ui-capture.conf"
truth "stage-restart exits 0" eq "$rc" 0
truth "stage-restart wrote WIREPLUMBER_DEBUG with the native HFP topic" eq "$(count '^Environment="WIREPLUMBER_DEBUG=D:.*spa\.bluez5\.native' "$WPD")" 1
truth "stage-restart wrote PIPEWIRE_DEBUG for pipewire-pulse at info" eq "$(count '^Environment="PIPEWIRE_DEBUG=mod\.protocol-pulse\*:3"$' "$PPD")" 1
truth "stage-restart left the per-cycle sink.sco topic out" eq "$(count 'sink\.sco' "$WPD")" 0
truth "stage-restart did not overwrite a foreign drop-in" cmp -s "$T/foreign.conf" "$PWD_DIR/90-bt-ui-capture.conf"
truth "stage-restart restarted and reloaded nothing" eq "$(count '^systemctl (restart|daemon-reload|--user)' "$CALLS")" 0
"$TOOL" unstage > "$T/unstage.out" 2>&1
truth "unstage removed its drop-ins" eq "$([[ -e "$WPD" || -e "$PPD" ]] && echo present || echo gone)" gone
truth "unstage kept the foreign drop-in" cmp -s "$T/foreign.conf" "$PWD_DIR/90-bt-ui-capture.conf"

echo "── the AT-SPI recorder, against a private bus"
if command -v dbus-daemon >/dev/null 2>&1 && python3 -c 'import gi' 2>/dev/null; then
    cat > "$T/bus.conf" <<EOF
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>accessibility</type>
  <listen>unix:dir=$T/bus</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow user="*"/>
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
EOF
    busout=$(dbus-daemon --config-file="$T/bus.conf" --fork --print-address=1 --print-pid=1 2>/dev/null)
    addr=$(sed -n 1p <<<"$busout"); BUS_PID=$(sed -n 2p <<<"$busout")
    printf '%s' "$addr" > "$STATE/bus-address"
    cat > "$T/emitter.py" <<'PYEOF'
import ctypes, sys
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib
# Name this process like the application under test (PR_SET_NAME = 15).
ctypes.CDLL(None).prctl(15, sys.argv[3].encode(), 0, 0, 0)
addr, n = sys.argv[1], int(sys.argv[2])
conn = Gio.DBusConnection.new_for_address_sync(
    addr, Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT |
    Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION, None, None)
xml = ('<node><interface name="org.a11y.atspi.Accessible">'
       '<method name="GetRoleName"><arg type="s" direction="out"/></method>'
       '<property name="Name" type="s" access="read"/>'
       '<property name="Parent" type="(so)" access="read"/></interface></node>')
iface = Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0]
def method(c, sender, path, i, m, params, inv):
    inv.return_value(GLib.Variant("(s)", ("panel" if path.endswith("row") else "filler",)))
def getprop(c, sender, path, i, prop):
    if prop == "Name":
        return GLib.Variant("s", "Configuration" if path.endswith("row") else "Output")
    return GLib.Variant("(so)", (c.get_unique_name(), "/t/group"))
for p in ("/t/row", "/t/group"):
    conn.register_object(p, iface, method, getprop, None)
loop = GLib.MainLoop()
state = {"i": 0}
def tick():
    i = state["i"]; state["i"] += 1
    if i >= n:
        GLib.timeout_add(500, loop.quit)
        return False
    conn.emit_signal(None, "/t/row", "org.a11y.atspi.Event.Object", "StateChanged",
                     GLib.Variant("(siiva{sv})", (sys.argv[4], i % 2, 0, GLib.Variant("s", "0"), {})))
    conn.emit_signal(None, "/t/row", "org.a11y.atspi.Event.Object", "BoundsChanged",
                     GLib.Variant("(siiva{sv})", ("", 0, 0, GLib.Variant("s", "0"), {})))
    return True
GLib.timeout_add(20, tick)
loop.run()
PYEOF
    MON_DIR="$T/mon"; mkdir -p "$MON_DIR/bin"; cp "$ROOT/scripts/bt-ui-atspi.py" "$MON_DIR/bin/"
    BT_UI_USER=prove-user BT_UI_MAX_BYTES=4000 BT_UI_KEEP=2 "$TOOL" _monitor atspi "$MON_DIR" &
    MON=$!
    for _ in $(seq 1 50); do
        [[ "$(count 'bt-ui-atspi start' "$MON_DIR/atspi.log")" -gt 0 ]] && break
        sleep 0.1
    done
    # The application first, then a bystander process emitting a state the
    # application never does: run LAST so that, were it recorded, rotation
    # could not have discarded the evidence.
    python3 "$T/emitter.py" "$addr" 120 gnome-control-c showing
    python3 "$T/emitter.py" "$addr" 5 bystander focused
    sleep 1
    pkill -f "$MON_DIR/bin/bt-ui-atspi.py" 2>/dev/null
    wait "$MON" 2>/dev/null
    cat "$MON_DIR"/atspi.log* > "$T/atspi.all" 2>/dev/null
    nfiles=$(find "$MON_DIR" -maxdepth 1 -name 'atspi.log*' | wc -l)
    big=$(find "$MON_DIR" -maxdepth 1 -name 'atspi.log*' -size +8k | wc -l)
    truth "recorder named the widget and its parent" \
        eq "$(count "object:state-changed:showing v1=1 role=panel name='Configuration' parent='Output'" "$T/atspi.all")" \
           "$(count 'object:state-changed:showing v1=1 ' "$T/atspi.all")"
    truth "recorder recorded the application's events" test "$(count 'object:state-changed:showing' "$T/atspi.all")" -gt 0
    truth "recorder dropped the bystander process's events" eq "$(count 'state-changed:focused' "$T/atspi.all")" 0
    truth "recorder did not record BoundsChanged" eq "$(count 'BoundsChanged|bounds-changed' "$T/atspi.all")" 0
    truth "monitor rotated and kept at most KEEP+1 files" test "$nfiles" -ge 2 -a "$nfiles" -le 3
    truth "no monitor file grew far past the cap" eq "$big" 0
    kill "$BUS_PID" 2>/dev/null; BUS_PID=""
else
    bad "AT-SPI check needs dbus-daemon and python3-gi (not proven here)"
fi

echo "── stop puts back exactly what start recorded"
: > "$CALLS"
"$TOOL" stop > "$T/stop.out" 2>&1; rc=$?
truth "stop exits 0" eq "$rc" 0
truth "stop stopped the three monitors" eq "$(count '^systemctl stop bt-ui-(atspi|sysbus|sessbus)$' "$CALLS")" 3
truth "stop restored the PipeWire level recorded at start" eq "$(cat "$STATE/pw-level")" 2
truth "stop switched the 16 sco.c functions off again" eq "$(count '^module bluetooth func .* -p$' "$CTL")" 16
truth "stop stopped the recorder because start had started it" eq "$(count '^systemctl stop bt-audio-policy$' "$CALLS")" 1
truth "stop removed its overrides" eq "$([[ -e "$APPS/gnome-sound-panel.desktop" || -e "$DBUSSVC" ]] && echo present || echo gone)" gone
truth "stop kept the foreign launcher" cmp -s "$T/foreign.desktop" "$APPS/gnome-bluetooth-panel.desktop"
truth "stop cleared the pointer" test ! -e "$T/base/current"
truth "stop recorded the state" eq "$(awk -F= '/^state=/ { v = $2 } END { print v }' "$M")" stopped

echo "── collect: the window, the captures, published copies without addresses"
cat > "$T/fixture/default.log" <<'EOF'
2026-10-05T01:00:01.000000+0200 n kernel: Bluetooth: sco_connect() 00:11:22:33:44:55 -> DE:AD:BE:EF:00:01
2026-10-05T01:00:02.000000+0200 n wireplumber[3292]: RFCOMM << AT+BCS=2
2026-10-05T01:00:03.000000+0200 n wireplumber[3292]: bluez_output.00_11_22_33_44_55.1 transport acquired
EOF
touch -d '2026-10-05 00:59:00' "$T/cap/trace/bt-20261005-000000.btsnoop"
touch -d '2026-10-05 01:30:00' "$T/cap/trace/bt-20261005-005900.btsnoop"
touch -d '2026-10-04 20:00:00' "$T/cap/trace/bt-20261004-180000.btsnoop"
touch -d '2026-10-05 03:00:00' "$T/cap/capture/hci-20261005-020000.btsnoop"
"$TOOL" collect --since '2026-10-05 01:00:00' --until '2026-10-05 01:45:00' > "$T/collect.out" 2>&1; rc=$?
C=$(find "$S" -maxdepth 1 -type d -name 'collect-*' | head -1)
truth "collect exits 0 and writes a collect directory" test "$rc" -eq 0 -a -d "$C"
truth "collect kept the raw timeline" eq "$(count 'AT\+BCS=2' "$C/raw/timeline.log")" 1
truth "collect listed the capture that runs into the window" eq "$(count 'bt-20261005-005900' "$C/raw/captures.txt")" 1
truth "collect left out the captures before and after the window" eq "$(count 'bt-20261004-180000|hci-20261005-020000|bt-20261005-000000' "$C/raw/captures.txt")" 0
truth "collect published a sanitised timeline" test -s "$C/published/timeline.log"
cat "$C"/published/* > "$T/published.all" 2>/dev/null
all_macs=$(grep -oiE '[0-9a-f]{2}([:_-][0-9a-f]{2}){5}' "$T/published.all" | wc -l)
placeholders=$(grep -oiE 'AA:BB:CC:00:00:[0-9]{2}' "$T/published.all" | wc -l)
truth "no published file still holds an address (every one is a placeholder)" eq "$all_macs" "$placeholders"
truth "the raw timeline did hold addresses (the check above can fail)" test "$(count '00:11:22:33:44:55' "$C/raw/timeline.log")" -gt 0

echo
echo "prove-ui-capture: $pass passed, $fail failed  (work dir $T)"
(( fail == 0 ))
