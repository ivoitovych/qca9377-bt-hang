Correction to README.txt in this directory (written 2026-10-18; README.txt is kept as generated).

README.txt says "nothing was written to the journal". That is wrong for this run.
bt-state's `bluetoothctl devices Connected` opened a management socket at
16:59:10.415636, and the capture's btmon crashed on it (BT-4): bt-trace logged
"btmon exited (#14)" at 16:59:11 and restarted it, about 1 s of trace lost. The
first snapshot (snapshot-20261018T145529Z, no README) caused #13 at 16:56:11 the
same way, through boot-bt-summary.sh. Nothing was sent to the controller.

Evidence: in each crashed capture the last record is
"@ MGMT Open: bluetoothctl (privileged) version 1.23" (btmon -T --columns=200 -r on
/var/log/bt-health/trace/bt-20261018-145001.btsnoop and bt-20261018-165611.btsnoop);
docs/STATUS.md, the BT-4 row. scripts/trial-snapshot.sh says so since this correction.
