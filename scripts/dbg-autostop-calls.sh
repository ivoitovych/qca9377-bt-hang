#!/bin/bash
# Which caller still reaches hciconfig on the passive autostop path? Same
# harness as prove-dr-review.sh, but the spy records its parent's command line.
set -uo pipefail
REPO=/root/exp/qca9377-bt-hang; cd "$REPO" || exit 2
TL=$(mktemp -d); mkdir -p "$TL/bin" "$TL/state" "$TL/sysfs/3-3/power" "$TL/sysfs/3-3/3-3:1.0/bluetooth/hci0" "$TL/evidence/trials"
echo 13d3 > "$TL/sysfs/3-3/idVendor"; echo 3503 > "$TL/sysfs/3-3/idProduct"; echo on > "$TL/sysfs/3-3/power/control"
cat > "$TL/bin/hciconfig" <<EOF
#!/bin/sh
{ echo "args: \$*"; echo "parent: \$(tr '\\0' ' ' < /proc/\$PPID/cmdline)"; echo "grandparent: \$(tr '\\0' ' ' < /proc/\$(awk '{print \$4}' /proc/\$PPID/stat)/cmdline)"; echo; } >> $TL/hciconfig-calls
exit 0
EOF
printf '#!/bin/sh\nexit 3\n' > "$TL/bin/systemctl"
printf '#!/bin/sh\necho "up 1 hour"\n' > "$TL/bin/uptime"
printf '#!/bin/sh\nexit 0\n' > "$TL/bin/bt-incident"
: > "$TL/kjournal"
printf '#!/bin/sh\ncase "$*" in *"-b -1"*) exit 0 ;; *bt-health-snapshot*) exit 0 ;; *"-u bt-trace"*) exit 0 ;; *"-u bt-hang-watchdog"*) exit 0 ;; esac\ncat %s/kjournal\nexit 0\n' "$TL" > "$TL/bin/journalctl"
chmod +x "$TL/bin"/*
tl() { PATH="$TL/bin:$PATH" BT_REPO="$TL" BT_EVIDENCE_REPO="$TL" BT_STATE="$TL/state" BT_SYSFS_USB="$TL/sysfs" tools/bt-trial "$@" 2>&1; }
tl autostart stock >/dev/null; rm -f "$TL/hciconfig-calls"
tl autostop
echo "── calls recorded during autostop:"; cat "$TL/hciconfig-calls" 2>/dev/null || echo "(none)"
rm -rf "$TL"
