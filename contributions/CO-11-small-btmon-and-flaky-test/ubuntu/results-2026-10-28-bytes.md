# CO-11 btmon SRU — byte-for-byte comparison, stock 5.8 vs rebuilt 5.9 (2026-10-28)

Answers the outside reviews (`reviews-2026-10-28.md` items 1 and 2): the earlier run compared
line counts only. This one keeps every output and compares stdout with `cmp`.

Command (host): `/root/exp/qca9377-bt-hang/tmp/co11-btmon/run-test2.sh` — a throw-away
`ubuntu:24.04` container, no devices, running `tmp/co11-btmon/inner-test2.sh`: stock
`bluez 5.72-0ubuntu5.8` from the archive, then the rebuilt `5.72-0ubuntu5.9` .deb; both
captures (`tmp/co11-btmon/caps/`, written by `tests/btmon/real/mkcap.py`) at each width,
`TZ=UTC btmon [--columns=N] -T -r <capture>`. Outputs kept in `tmp/co11-btmon/cmp2/`.

btmon sha256: stock `0744f98cb0e5173fb9995fe68f4bb38ab633d4ccf90c9d504b677762ac59e5ab`,
rebuilt `58d92e1a666531eb26c34fbbffd50ec8bc0639c64c44f6ef1a0a8a8f769b95eb`.

```
=== comparison (exit codes stock/rebuilt; cmp of stdout)
priv-open cols=10: exit 134/0, stdout 0/128 bytes, DIFFERENT
priv-open cols=40: exit 134/0, stdout 0/149 bytes, DIFFERENT
priv-open cols=60: exit 134/0, stdout 0/147 bytes, DIFFERENT
priv-open cols=79: exit 134/0, stdout 0/185 bytes, DIFFERENT
priv-open cols=80: exit 134/0, stdout 0/187 bytes, DIFFERENT
priv-open cols=81: exit 0/0, stdout 190/189 bytes, DIFFERENT
priv-open cols=82: exit 0/0, stdout 191/191 bytes, DIFFERENT
priv-open cols=100: exit 0/0, stdout 227/227 bytes, identical
priv-open cols=200: exit 0/0, stdout 427/427 bytes, identical
priv-open cols=3000: exit 134/0, stdout 0/6027 bytes, DIFFERENT
priv-open cols=5000: exit 134/0, stdout 0/10027 bytes, DIFFERENT
priv-open cols=piped: exit 134/0, stdout 0/187 bytes, DIFFERENT
lines cols=10: exit 134/0, stdout 0/1482 bytes, DIFFERENT
lines cols=40: exit 134/0, stdout 0/1561 bytes, DIFFERENT
lines cols=60: exit 134/0, stdout 0/1543 bytes, DIFFERENT
lines cols=79: exit 0/0, stdout 1676/1676 bytes, identical
lines cols=80: exit 0/0, stdout 1683/1683 bytes, identical
lines cols=81: exit 0/0, stdout 1690/1690 bytes, identical
lines cols=82: exit 0/0, stdout 1697/1697 bytes, identical
lines cols=100: exit 0/0, stdout 1823/1823 bytes, identical
lines cols=200: exit 0/0, stdout 2523/2523 bytes, identical
lines cols=3000: exit 134/0, stdout 0/22123 bytes, DIFFERENT
lines cols=5000: exit 134/0, stdout 0/36123 bytes, DIFFERENT
lines cols=piped: exit 0/0, stdout 1683/1683 bytes, identical
=== diffs where both exited 0
--- priv-open cols=81
3c3
< @ MGMT O..n (privileged) version 1.22  {0x0001} [hci0] 2026-10-17 01:04:57.000100
---
> @ MGMT Open: bluetoothctl             {0x0001} [hci0] 2026-10-17 01:04:57.000100
--- priv-open cols=82
3c3
< @ MGMT Op.. (privileged) version 1.22  {0x0001} [hci0] 2026-10-17 01:04:57.000100
---
> @ MGMT Open: bluetoothctl              {0x0001} [hci0] 2026-10-17 01:04:57.000100
```

Every stock exit 134 has stderr `*** buffer overflow detected ***: terminated`.

Reading:
- Stock aborts at 3000 and 5000 columns too (both captures), and on the ordinary-records
  capture at 10, 40 and 60 columns: not only the privileged-Open record at <= 80.
- The rebuilt btmon exits 0 at every width tested.
- Where both run, the output is byte-identical except the privileged-Open label at 81 and
  82 columns, which the patch shortens differently (reviewer 4's finding, reproduced).
- Not tested: the live-socket path (`btmon` on the monitor socket, the `comm[pid]` prefix
  named in dca0f10fd). Running btmon live on this machine touches its Bluetooth stack; the
  stated limit stays.
