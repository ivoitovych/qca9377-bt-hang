# BT-10 — l2cap-tester "L2CAP Ext-Flowctl Server - Accept 2 Close 1" hangs on released kernels

2026-10-23. The case (BlueZ `e9b6ee380`, Pauli Virtanen, 2026-09-02: "accepts + closes the first
before accepting the second. This triggers deadlock on some kernel versions") run alone on the kernels
already built for CO-02 (`tmp/co02-w2c/img/`, BlueZ `doc/tester.config`: KASAN, PROVE_LOCKING;
4 vCPUs), 180 s limit each:

```console
$ /root/exp/qca9377-bt-hang/tmp/l2cap-hang/sweep-images.sh
bzImage-v4-smp: L2CAP Ext-Flowctl Server - Accept 2 Close 1 Passed 0.044 seconds
bzImage-st7.2v4-base-smp: HANG (limit 180 s)
bzImage-st6.18v4-base-smp: HANG (limit 180 s)
bzImage-612-base-smp: HANG (limit 180 s)
bzImage-st6.6-base-smp: HANG (limit 180 s)
bzImage-u38w-pre-smp: HANG (limit 180 s)
```

| image | kernel |
|---|---|
| `v4-smp` | bluetooth-next `27731ba09195` + CO-02 v4 (same code as v5) |
| `st7.2v4-base-smp` | 7.2.12 |
| `st6.18v4-base-smp` | 6.18.58 |
| `612-base-smp` | 6.12.114 |
| `st6.6-base-smp` | 6.6.160 |
| `u38w-pre-smp` | v7.0 + Ubuntu 7.0.0-38's Bluetooth code + `abd93c85c8667` + `816fb1590a4c` |

Each `*.commit` file beside an image names its exact tree. The hanging guests print the case up to
"Accept deferred setup sk = …" and nothing after it; no lockdep, KASAN or hung-task report. Logs
(local, `tmp/l2cap-hang/logs/sweep-*.log`; they hold the emulator's addresses, so they stay out of
git). Scripts: `run-one.sh` (one case, a limit) and `sweep-images.sh`, copied here from
`tmp/l2cap-hang/`.

Next (as of 2026-10-23): bisect bluetooth-next for the fixing commit (Pauli Virtanen's L2CAP
locking series of 2026-08/09 is the likely place; `docs/STATUS.md`, `BT-10`). **Done 2026-10-28:**
`32d86e048d8ef` with its helpers `608e0b7a675b2`
(`contributions/CO-35-l2cap-ecred-defer-hang-stable/`).
