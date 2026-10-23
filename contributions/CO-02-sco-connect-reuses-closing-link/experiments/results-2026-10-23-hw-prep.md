# CO-02 — results, 2026-10-23: the laptop's kernel (Ubuntu 7.0.0-38) in the emulator, and the module

## Why
The laptop runs `linux-hwe-7.0 7.0.0-38.38~24.04.4`. Its Bluetooth code has the kref change
`e6720779ae61` and the CVE fix `8a5b0135d4a5`, but not `abd93c85c8667` ("give the socket its own
sco_conn reference") or `816fb1590a4c` ("serialise sco_conn lifetime against sco_recv_scodata()").
No kernel.org stable line has that combination. Before anything goes on the laptop, the series ran on
that code in QEMU with BlueZ's emulator.

## Trees (`cache/co02-ubuntu38`, a worktree of `cache/linux` at v7.0 `028ef9c96e96`)
| branch | commit | content |
|---|---|---|
| `co02-ubuntu38/base` | `82c24c0fdd59` | v7.0 + Ubuntu 7.0.0-38's `net/bluetooth`, `drivers/bluetooth`, `include/net/bluetooth` (from `cache/ubuntu-7.0.0-38`) |
| `co02-ubuntu38/series` | `b279810a5b2f` | base + v5 |
| `co02-ubuntu38/with816` | `96f7336a918f` | base + `abd93c85c8667` + `816fb1590a4c` (as in 6.18.y; `816fb1590a4c` alone fails 5 of 10 hunks, the pair applies with `-F0`) |
| `co02-ubuntu38/with816-series` | `ff077afb28e8` | with816 + v5 |
| `co02-ubuntu38/with816-park` | `637f96766701` | with816-series + the debug-only park (`race-park-2026-10-22.md`) |

Kernels: BlueZ's `doc/tester.config` (KASAN, PROVE_LOCKING, DEBUG_ATOMIC_SLEEP), UP as is, SMP with
`tmp/co02-w2/frag-smp.config` (4 vCPUs). No KCSAN: a KCSAN kernel from this v7.0 tree stops at boot
("9p: Bad value for 'source'"), so the KCSAN coverage stays the bluetooth-next one
(`results-2026-10-22-v4.md`). Tester: `sco-tester-v7` (the v5 BlueZ patch); `sco-tester-exp-v2` for
the park; `iso-`, `l2cap-`, `mgmt-tester` from `cache/co02-bluez`.

## 1. The series alone on Ubuntu's code leaks (`run-ubuntu38.sh`, 2026-10-22/23)
`grep -c "Timed out waiting for the next link event" -r tmp/co02-hw/runs`:
- `u38-up-twice-1..3`, `u38-smp-twice-1..3` (series): 1 each — **Connect Twice fails 6 of 6**;
- `u38-base-smp-twice-1..3` (unpatched): 0.

Cause (`log.md`, "the laptop's kernel"): Ubuntu's `sco_conn_add()` takes a `sco_conn` reference for an
existing connection and `sco_connect()`'s EBUSY path never puts it; that reference holds the
`hci_conn`, so once patch 1 stops the disconnect the SCO link stays up after both sockets close.

## 2. With the two upstream commits (`run-ubuntu38-816b.sh`, 2026-10-22 23:54 to 2026-10-23 01:14 UTC)
Logs `tmp/co02-hw/runs/u38w-*`, progress `tmp/co02-hw/progress-816.txt`.

| kernel | Reconnect (After, During) ×3 | Connect Twice ×3 | full sco-tester |
|---|---|---|---|
| `u38w-pre-smp` (control: the two commits, no series) | During fails 3/3, After passes | fails 3/3 | 31/33 (the two bug cases) |
| `u38w-up` (series, UP) | 2/2 ×3 | 1/1 ×3 | 33/33 |
| `u38w-smp` (series, SMP) | 2/2 ×3 | 1/1 ×3 | 33/33 |
| `u38w-park-smp` (park, "Race Park" both directions) | — | — | 2/2 ×3: the parked connect is refused |

- No "Timed out waiting for the next link event" in any `u38w-*` log.
- **Full suites, control vs series (SMP)**, per case (`tmp/co02-hw/compare-verdicts.sh <A> <B>`):
  - sco-tester: only "Connect Twice" and "Reconnect During Disconnect" differ (Failed → Passed);
  - iso-tester: 141/141 both, no verdict differs;
  - mgmt-tester: 490/514 both, no verdict differs (486 named verdicts each);
  - l2cap-tester: both stopped at the 30-minute limit at "L2CAP Ext-Flowctl Server - Accept 2 Close 1";
    the 101 cases before it give the same results. That case hangs on every released kernel tried
    (7.2.12, 6.18.58, 6.12.114, 6.6.160, Ubuntu) and passes on bluetooth-next: not this series
    (`tmp/l2cap-hang/`, to be registered).
- **Kernel reports:** none in the SCO, mgmt and l2cap logs. Both iso-tester logs, control and series
  alike, hold one `BUG: KASAN: slab-use-after-free in iso_conn_hold_unless_zero` in "ISO Defer Close -
  Success" (freed by `iso_chan_del` from `iso_sock_release`, read from `hci_conn_failed` →
  `iso_connect_cfm` → `iso_conn_del`). Present without the series, absent from every bluetooth-next
  iso-tester log here: an ISO defect of Ubuntu's code, not this series (to be registered; the
  laptop's controller has no ISO support).

## 3. The modules for the laptop (`build-laptop-module-v2.sh`)
Built against `/lib/modules/7.0.0-38-generic/build` from the trees above via `git archive`, after
checking that `co02-ubuntu38/base` equals `cache/ubuntu-7.0.0-38` for `net/bluetooth` and
`include/net/bluetooth`. No compiler warnings.

| module | tree | srcversion | bluetooth.ko SHA-256 |
|---|---|---|---|
| `tmp/co02-hw/module/full` | `with816-series` `ff077afb28e8` | `0D084A056A9EEFB98E8F331` | `702186d9d17dc6cc8e91b905f1aca56debaf17d39ee84f87795c9d704377cbff` |
| `tmp/co02-hw/module/pre` | `with816` `96f7336a918f` | `4F912DA1C7FAE3C43FEB0B1` | `6219cc2c9b16dbc11b1913da65a240d81385088f5627f5b673f16eb1221bb25b` |

Both export the same 94 symbols with the same CRCs (`Module.symvers`
`c3139c07823b…`). `scripts/module-updates.sh check <module>` (all install checks, nothing written):
33 dependants from `modules.dep`, E3's `updates/btusb.ko` included (21 symbols), 0 mismatches,
`SHA256SUMS` match, "ready to install", for both.

**On Ubuntu's real kernel** (`/boot/vmlinuz-7.0.0-38-generic` in QEMU/KVM, 4 vCPUs,
`tmp/co02-hw/vm/`): both load (`insmod bluetooth ok`, `hci_vhci ok`), srcversion as above, no
"Unknown symbol", "disagrees about version", WARNING or BUG line. sco-tester cannot run there:
the stock kernel sends the virtual controller's HCI Reset (2.17 s) and BlueZ's emulator never
answers it (`-110` at 4.16 s), with the stock `bluetooth.ko` as with ours; open, the behaviour tests are
section 2.

## 4. The install checks fixed on the way (2026-10-23, `scripts/`)
- `check-modversions.sh` counted a module whose versions could not be read as clean ("uses 0"): the
  old version printed "OK — every dependant accepts the new build" for a module that does not exist.
- `module-updates.sh install` checked CRCs against a name list under `kernel/` only, missing E3's
  `updates/btusb.ko`, and fell back to `tmp/bt-build`'s `Module.symvers` when none sat beside the
  module.
Now: dependants from `modules.dep`; the module's own `Module.symvers`, which must list its exports;
`SHA256SUMS` if present; a `check` mode; `install` refuses while a trial is open unless
`--trial-open-ok`. Tests: `test-module-checks.sh`, 10 of 10 (`check` only; `install` not run, as
this session is root).

## Not covered
- Hardware: the run on the laptop is next (`hardware-run-plan.md`).
- KCSAN on Ubuntu's code (the tree's KCSAN kernel does not boot here).
