#!/bin/sh
# Read-only snapshot of the laptop's relevant state, kept as evidence of the starting point.
# Uses only: dpkg-query, /proc, file hashes, journalctl reads.  Changes nothing.
top=/root/exp/agent-work/laptop-headset-session-20261111
out=$top/logs/host-state-readonly.txt
"$top/scripts/log.sh" START read-host-state
{
  echo "# read-only snapshot taken $(date -u +%Y-%m-%dT%H:%M:%SZ) by scripts/read-host-state.sh"
  python3 -I "$top/kit/bin/session-state.py"
  echo
  echo "== dpkg --verify (empty = every file of the packages is as shipped)"
  dpkg --verify bluez libbluetooth3 bluez-obexd
  echo "[exit $?]"
  echo
  echo "== effective bluetooth.service drop-in names"
  ls /etc/systemd/system/bluetooth.service.d
  echo
  echo "== HCI recorders (newest files)"
  ls -t /var/log/bt-health/capture | head -2
  ls -t /var/log/bt-health/trace | head -2
} > "$out" 2>&1
"$top/scripts/log.sh" END read-host-state
