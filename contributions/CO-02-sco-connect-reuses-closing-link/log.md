# CO-02 log

Append-only. Newest last.

## 2026-09-29 — U7 found
Lenovo earbuds, E1 boot: three codec switches in a row. The two made while an mSBC link was
up got a Disconnect and then no Setup Synchronous Connection; the test sound was silent
(`docs/issues.md`, U7).

## 2026-10-03 — the timing comparison (`EX-060`)
`scripts/sco-switch-windows.sh` on the retained captures:
- **Earbuds:** `AT+BCS=` came 16 to 30 ms after the Disconnect, and the old link's
  Disconnection Complete came 177 to 205 ms after it. No setup followed.
- **MOMENTUM 4:** the reply came at 67 to 75 ms and the completion at 39 to 46 ms. A setup
  followed 24 to 26 ms after `OK`.

PipeWire master had no commit addressing it. STATUS left the host-side handling "to be
examined separately".

## 2026-10-20 — related upstream work found
BlueZ #2562 and Hitalo Souza's "Fix SCO setup failures after an abandoned setup" (v3,
2026-10-08): the same area, with a different trigger (a socket closed while its setup is
pending). Recorded as CO-02 in `reviews/2026-10-20T2309Z-contribution-opportunities.md`, and
as item 1 of the source investigation task.

## 2026-10-21 — reviewer 1's pointer, checked in source
- **The reviewer's claim:** the kernel reuses the dying connection by address and sends no
  setup.
- **Checked** on bluetooth-next `27731ba09195` and Ubuntu `7.0.0-38` source. The claim
  holds, with one correction: the old connection is `BT_CONNECTED`, not `BT_DISCONN`, so
  `sco_connect()` marks the new socket connected at once.
- **The series:** patches 2 and 4 of the abandoned-setup series do not touch
  `hci_connect_sco()`'s lookup.
- **Full record:** `reviews/2026-10-21T0009Z-source-investigation-reviewer-1.md`, SI1.

## 2026-10-21 — dossier opened

## 2026-10-21 — reviewers 2, 3 and 4: the same mechanism; PipeWire's side read
- **All three found the reuse independently.** All three, like reviewer 1, called the old
  state `BT_DISCONN`.
- **Checked:** no `hci_conn` is ever set `BT_DISCONN` (`git grep` over `net/bluetooth`).
  `hci_disconnect_sync()` waits for the completion with the state unchanged.
- **So the new socket is connected at once** (`sco.c:417`). The completion then closes it
  with `ECONNABORTED` (reason 0x16, `lib.c:128`).
- **PipeWire 1.0.5, read here:** it retries only an immediate `ECONNABORTED` (`backend-native.c:1447`).
  On HUP/ERR it closes the socket and sets the transport IDLE, with no new connect
  (`1653–1669`).
- **For the patch:** a connection being torn down is marked by `conn->abort_reason`, not by
  a state.
- **Full record:** `reviews/2026-10-21T0033Z-source-investigation-reviewers-2-4.md`, RV1.
- **Our own record corrected:** `docs/issues.md` U7's "not a kernel defect" sentence.

## 2026-10-21, worker W2 (QEMU only), about 05:00 to 06:30 local — reproduced, patches drafted
On the operator's go, a worker built the reproducer and the fixes on bluetooth-next
`27731ba09195`; the full account is `experiments/results-2026-10-21.md`, raw material in
`tmp/co02-w2/` on the development host.
- **Reproduced:** sco-tester "Reconnect During Disconnect" fails on every unpatched run (UP 0/5,
  SMP 0/10, KCSAN SMP 0/5): the second `connect()` returns 0 with no setup sent, then
  `SO_ERROR 103`. The control passes in every run.
- **Fixed by** `patch/kernel/0001` (refuse an aborting connection with `-ECONNABORTED`) and
  `0002` (a second defect: a second connect to a live SCO link drops the owner's hold and the
  first link is disconnected; since `06149746e720`, v6.4). During passes 20/20.
- **Not enough for PipeWire 1.0.5:** its immediate retries still fail on the refusing kernel;
  the deferral prototype (`patch/kernel-rfc-defer/`) makes them succeed.
- **The test config is uniprocessor:** BlueZ's `doc/tester.config` sets `# CONFIG_SMP is not
  set`; the worker's first "4-CPU" runs were UP kernels in a 4-vCPU guest and are not counted
  as multi-CPU; SMP and KCSAN kernels were rebuilt with an SMP fragment.
- **Hitalo Souza's series** (14875449 to 14875454) does not fix it (During 0/5 with it alone);
  ours applies on top without conflict.

## 2026-10-21 04:44 UTC — re-checked before entering the dossier
The decisive pair re-run independently of the worker's own runs
(`tmp/co02-w2/run-case.sh <kernel> sco-tester <log> 1 -s Reconnect`, logs in
`tmp/co02-check/`):
- unpatched `27731ba09195`: After Passed, **During Failed**; "Second connect() returned 0
  (Success)", then "SO_ERROR 103 … 1 setup commands";
- refuse + hold `bfac3f388548`: **both Passed**; "Second connect() refused: Software caused
  connection abort (103)";
- `scripts/kernel-report-scan.py`: both logs clean, each the intended kernel.
The drafts were checked for tool or model names and trailers (none) before being copied in.
