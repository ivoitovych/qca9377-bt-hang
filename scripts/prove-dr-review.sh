#!/bin/bash
# Standalone proofs for the five tooling fixes from the 2026-09-19 comprehensive
# review (DR-05 capture rotation, DR-06 sanitiser manifest, DR-07 passive
# autostop + tracked abort, DR-08 uninstall .disabled, DR-09 usbstate by VID:PID),
# runnable while an open trial keeps tests/run-tests closed. Mirrors the suite's
# fixtures; writes only under mktemp and tmp/.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$REPO" || exit 2
P=0; F=0
ok()  { printf '  PASS  %s\n' "$1"; P=$((P+1)); }
bad() { printf '  FAIL  %s\n' "$1"; F=$((F+1)); }

echo "── DR-09 bt-usbstate"
US=$(mktemp -d); mkdir -p "$US/1-2/power" "$US/2-4"
echo 13d3 > "$US/1-2/idVendor"; echo 3503 > "$US/1-2/idProduct"; echo auto > "$US/1-2/power/control"
echo 8087 > "$US/2-4/idVendor"; echo 0a2b > "$US/2-4/idProduct"
o=$(BT_SYSFS_USB="$US" tools/bt-usbstate 2>&1); rc=$?
(( rc == 0 )) && [[ "$o" == *"1-2 at"* ]] && ok "found at 1-2 (rc=$rc)" || bad "not found at 1-2 (rc=$rc): $(head -1 <<<"$o")"
o=$(BT_SYSFS_USB="$US/2-4" tools/bt-usbstate 2>&1); rc=$?
(( rc == 0 )) && [[ "$o" == *"no device 13d3:3503"* ]] && ok "absence by VID:PID" || bad "absence (rc=$rc): $(head -1 <<<"$o")"
o=$(BT_SYSFS_USB="$US" BT_USB_PATH=9-9 tools/bt-usbstate 2>&1); rc=$?
(( rc == 2 )) && [[ "$o" == *"configured path"* ]] && ok "bad BT_USB_PATH is rc 2" || bad "bad path (rc=$rc)"
mkdir -p "$US/3-1"; echo 13d3 > "$US/3-1/idVendor"; echo 3503 > "$US/3-1/idProduct"
BT_SYSFS_USB="$US" tools/bt-usbstate >/dev/null 2>&1; (( $? == 2 )) && ok "two matches refused" || bad "two matches not refused"
rm -rf "$US"

echo "── DR-06 bt-incident sanitiser outcome"
INCS=$(mktemp -d); mkdir -p "$INCS/repo" "$INCS/bin"
printf '#!/bin/sh\nexit 1\n' > "$INCS/bin/fail"; printf '#!/bin/sh\nexit 0\n' > "$INCS/bin/pass"; chmod +x "$INCS/bin/"*
BT_EVIDENCE_REPO="$INCS/repo" BT_SANITIZER="$INCS/bin/fail" tools/bt-incident dr06-fail --since '5 minutes ago' >/dev/null 2>&1; rc=$?
# sessions/ also holds a `latest` symlink to the newest session: match the dated dir only
man=$(cat "$INCS"/repo/evidence/sessions/2*/MANIFEST.txt 2>/dev/null | grep sanitised)
(( rc != 0 )) && [[ "$man" == sanitised=FAILED:* ]] && ok "failing sanitiser → rc=$rc, $man" || bad "failing sanitiser: rc=$rc, $man"
rm -rf "$INCS/repo"; mkdir -p "$INCS/repo"
BT_EVIDENCE_REPO="$INCS/repo" BT_SANITIZER="$INCS/bin/pass" tools/bt-incident dr06-ok --since '5 minutes ago' >/dev/null 2>&1; rc=$?
man=$(cat "$INCS"/repo/evidence/sessions/2*/MANIFEST.txt 2>/dev/null | grep sanitised)
(( rc == 0 )) && [[ "$man" == "sanitised=yes" ]] && ok "passing sanitiser → rc=0, $man" || bad "passing sanitiser: rc=$rc, $man"
rm -rf "$INCS"

echo "── DR-08 uninstall .disabled"
SS=$(mktemp -d); mkdir -p "$SS/bin"
for s in systemctl udevadm modprobe; do printf '#!/bin/sh\nexit 0\n' > "$SS/bin/$s"; chmod +x "$SS/bin/$s"; done
SRDIS=$(mktemp -d); mkdir -p "$SRDIS/etc/modprobe.d" "$SRDIS/etc/udev/rules.d"
: > "$SRDIS/etc/modprobe.d/btusb-qca9377.conf.disabled"
: > "$SRDIS/etc/udev/rules.d/50-bluetooth-no-autosuspend.rules.disabled"
: > "$SRDIS/etc/udev/rules.d/51-bluetooth-health-snapshot.rules.disabled"
o=$(env PATH="$SS/bin:$PATH" BT_DESTDIR="$SRDIS" ./uninstall.sh --apply 2>&1); rc=$?
left=$(find "$SRDIS/etc" -name '*.disabled' | wc -l)
(( rc == 0 && left == 0 )) && [[ "$o" == *"UNINSTALL COMPLETE"* ]] && ok "all three .disabled removed, COMPLETE (rc=$rc)" || bad "left=$left rc=$rc"
rm -rf "$SRDIS" "$SS"

echo "── DR-07 bt-trial: passive autostop, tracked abort"
TL=$(mktemp -d); mkdir -p "$TL/bin" "$TL/state" "$TL/sysfs/3-3/power" "$TL/sysfs/3-3/3-3:1.0/bluetooth/hci0" "$TL/evidence/trials"
echo 13d3 > "$TL/sysfs/3-3/idVendor"; echo 3503 > "$TL/sysfs/3-3/idProduct"; echo on > "$TL/sysfs/3-3/power/control"
printf '#!/bin/sh\necho "$*" >> %s/hciconfig-calls\n[ -e %s/dead ] && exit 1\nexit 0\n' "$TL" "$TL" > "$TL/bin/hciconfig"
printf '#!/bin/sh\nexit 3\n' > "$TL/bin/systemctl"
printf '#!/bin/sh\necho "up 1 hour"\n' > "$TL/bin/uptime"
printf '#!/bin/sh\nexit 0\n' > "$TL/bin/bt-incident"
ln -sf "$REPO/bin/bt-mark" "$TL/bin/bt-mark"; ln -sf "$REPO/tools/bt-state" "$TL/bin/bt-state"   # the checkout's, not the installed
: > "$TL/kjournal"
printf '#!/bin/sh\ncase "$*" in *"-b -1"*) exit 0 ;; *bt-health-snapshot*) exit 0 ;; *"-u bt-trace"*) exit 0 ;; *"-u bt-hang-watchdog"*) exit 0 ;; esac\ncat %s/kjournal\nexit 0\n' "$TL" > "$TL/bin/journalctl"
chmod +x "$TL/bin"/*
tl() { PATH="$TL/bin:$PATH" BT_REPO="$TL" BT_EVIDENCE_REPO="$TL" BT_STATE="$TL/state" BT_SYSFS_USB="$TL/sysfs" tools/bt-trial "$@" 2>&1; }
res() { tail -1 "$TL/evidence/trials/results.tsv" 2>/dev/null | cut -f9; }
# start/autostart probe on purpose; the spy is reset after autostart so only autostop counts
tl autostart stock >/dev/null; rm -f "$TL/hciconfig-calls"; tl autostop >/dev/null
[[ "$(res)" == ended_unprobed && ! -e "$TL/hciconfig-calls" ]] && ok "no timeout → ended_unprobed, 0 HCI commands" || bad "passive ok: result=$(res) calls=$(cat "$TL/hciconfig-calls" 2>/dev/null | wc -l)"
printf 'Bluetooth: hci0: command 0x0406 tx timeout\n' > "$TL/kjournal"
tl autostart stock >/dev/null; touch "$TL/dead"; rm -f "$TL/hciconfig-calls"; tl autostop >/dev/null
[[ "$(res)" == failed && ! -e "$TL/hciconfig-calls" ]] && ok "timeout → failed, 0 HCI commands" || bad "passive hang: result=$(res) calls=$(cat "$TL/hciconfig-calls" 2>/dev/null | wc -l)"
: > "$TL/kjournal"
tl autostart stock >/dev/null; rm -f "$TL/hciconfig-calls"; BT_TRIAL_PROBE=1 tl autostop >/dev/null
[[ "$(res)" == failed && -s "$TL/hciconfig-calls" ]] && ok "BT_TRIAL_PROBE=1 probes (dead → failed)" || bad "probe mode: result=$(res)"
rm -f "$TL/dead" "$TL/hciconfig-calls"
git -C "$TL" init -q; tl autostart stock >/dev/null
d=$(grep '^dir=' "$TL/state/current" | cut -d= -f2-); printf 'kept\n' > "$d/evidence.log"
git -C "$TL" -c user.name=test -c user.email=test@example.com add "$d/evidence.log"
o=$(tl abort --discard); rc=$?
(( rc == 1 )) && [[ "$o" == *REFUSED* && -d "$d" && -e "$TL/state/current" ]] && ok "abort --discard refused with tracked file (rc=$rc)" || bad "tracked abort: rc=$rc $o"
git -C "$TL" rm -q --cached "$d/evidence.log"; o=$(tl abort --discard); rc=$?
(( rc == 0 )) && [[ ! -d "$d" ]] && ok "abort --discard deletes once untracked" || bad "untracked abort rc=$rc"
rm -rf "$TL"

echo "── DR-05 bt-capture rotation + AF_BLUETOOTH"
BCR=$(mktemp -d); mkdir -p "$BCR/cap"
out=$(cd "$BCR" && python3 - "$REPO/bin/bt-capture" "$BCR" <<'PYEOF'
import importlib.util, importlib.machinery, io, os, socket, struct, sys
path, tmp = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_loader("btcap", importlib.machinery.SourceFileLoader("btcap", path))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
frame = struct.pack("<I", 10) + struct.pack("<HHH", 2, 0, 4) + b"\x01\x28\x04\x11"
frames = os.path.join(tmp, "frames.bin")
with open(frames, "wb") as f:
    for _ in range(45000): f.write(frame)
answers = [True, False]; calls = []
def fake_prune(d, keep, gb):
    calls.append(1); return answers.pop(0) if answers else False
m.prune = fake_prune
os.environ["BT_CAPTURE_SOURCE"] = frames; os.environ["BT_CAPTURE_DIR"] = os.path.join(tmp, "cap")
sys.argv = ["bt-capture", "--max-mb", "1", "--min-free-gb", "0", "--duration", "5"]
log = io.StringIO(); m.log = lambda s: log.write(s + "\n")
rc = m.main()
files = [f for f in os.listdir(os.path.join(tmp, "cap")) if f.endswith(".btsnoop")]
print(("PASS" if (rc == 1 and len(files) == 1 and "floor not restored" in log.getvalue() and len(calls) == 2) else "FAIL")
      + f" rotation: rc={rc} files={len(files)} prune_calls={len(calls)}")
os.environ.pop("BT_CAPTURE_SOURCE")
saved = getattr(socket, "AF_BLUETOOTH", None)
if saved is not None: delattr(socket, "AF_BLUETOOTH")
try:
    m.open_monitor(); print("FAIL no-socket: opened something")
except OSError as e:
    print("PASS no-socket: OSError", e.errno)
except Exception as e:
    print("FAIL no-socket:", type(e).__name__)
finally:
    if saved is not None: socket.AF_BLUETOOTH = saved
PYEOF
)
echo "$out" | sed 's/^/  /'
grep -q "PASS rotation" <<<"$out" && P=$((P+1)) || F=$((F+1))
grep -q "PASS no-socket" <<<"$out" && P=$((P+1)) || F=$((F+1))
rm -rf "$BCR"
printf '\n  %s passed, %s failed\n' "$P" "$F"; (( F == 0 ))
