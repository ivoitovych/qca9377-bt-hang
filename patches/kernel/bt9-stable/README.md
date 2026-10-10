# BT-9 — the stable backport of `96d006ae6445`, and a deterministic test for it

**State 2026-10-10: the stable backports were sent 2026-10-10 04:25 +0200** (three mails,
exactly the files in `send/` apart from the elided addresses:
[6.12.y](https://lore.kernel.org/r/20261010022523.2789588-1-yaroslav.voytovych@gmail.com),
[6.6.y](https://lore.kernel.org/r/20261010022523.2789588-2-yaroslav.voytovych@gmail.com),
[6.1.y](https://lore.kernel.org/r/20261010022523.2789588-3-yaroslav.voytovych@gmail.com)).
The BlueZ leak fix and the test series were sent to linux-bluetooth 2026-10-10 05:18 +0200,
exactly the files in `bluez-mgmt-tester/v2-leak-fix/` and `v2-test-series/`:
[leak fix](https://lore.kernel.org/r/20261010031846.2842837-1-yaroslav.voytovych@gmail.com),
[test series](https://lore.kernel.org/r/20261010031852.2842893-1-yaroslav.voytovych@gmail.com).

## What and why

BT-9 (`docs/issues.md`, `EX-062`): with `HCI_QUIRK_SIMULTANEOUS_DISCOVERY`, an Inquiry Complete
that arrives between the LE scan-off command and its Command Complete leaves discovery in
`DISCOVERY_FINDING`; every later Start Discovery is answered Busy. Jiajia Liu fixed it upstream:
`96d006ae6445` "Bluetooth: hci_event: fix simultaneous discovery stuck in FINDING" (v7.2-rc1;
stable 7.1.5, 6.18.40). It is missing from **6.12.y, 6.6.y and 6.1.y** (checked at v6.12.112,
v6.6.158, v6.1.189 and in the stable queue on 2026-10-09 and 2026-10-10). There it does not
apply unchanged: `hci_test_quirk()` does not exist on those lines.

Who has the quirk on those lines (`git grep` at each tag): btintel and btrtl set it for their
controllers, hci_qca for its UART controllers, and btusb for its ATH3012, ROME (`BTUSB_QCA_ROME`)
and WCN6855 entries and for CSR; the upstream report was an Intel AX201. The race needs combined
BR/EDR and LE discovery and an Inquiry Complete inside the scan-off; on this project's QCA9377
that happened in 2 of about 14,700 cycles (`EX-062`). The 13d3:3503 device-ID entry
(`dc16388d45ec`, queued for those lines at this project's request) brings that adapter the ROME
quirks, this one among them, without the fix.

## Contents

| path | what |
|---|---|
| `6.12.112/`, `6.6.158/`, `6.1.189/` | the backport per line: `96d006ae6445` cherry-picked, original author, date, message, `Fixes:` and sign-offs, `[ Upstream commit … ]` per `stable-kernel-rules.rst`; one change, `hci_test_quirk(hdev, Q)` → `test_bit(Q, &hdev->quirks)` as those lines test this quirk elsewhere; a bracketed note and our sign-off. One patch-id for all three (`results/backport-record.txt`) |
| `send/6.12.y/`, `send/6.6.y/`, `send/6.1.y/` | the same patches **as they would be mailed**: `[PATCH 6.N.y]` subject and the note below the `---` line (why, who is affected, how it was tested). Identical to the sendable files apart from the elided addresses (see the end of this file) |
| `bluez-mgmt-tester/v2-leak-fix/` | **current**, BlueZ master `7428ca2df935`: one patch, free the emulator's hooks in `btdev_destroy()` (`Fixes: 37199df506f4`). Stands alone. Message reworded 2026-10-10 after review (five leaking mgmt-tester cases by searchable name, not one; the l2cap-tester case; LeakSanitizer named); code unchanged, same tree as tested |
| `bluez-mgmt-tester/v2-test-series/` | **current**: a cover letter (`0000`), `btdev_send_event()`, `vhci_set_quirk_simultaneous_discovery()`, and two `mgmt-tester` cases, "Start Discovery - Simultaneous Inquiry First" (control) and "… Inquiry Late" (the race). Applies on master with or without the leak fix (same resulting tree either way); removes its own hooks, so it reports no leak without it. Patch 3, 2026-10-10 after review: message shortened, and the comment on the one-second Set Powered wait now names its cause (the only code change since the full test matrix; the two cases re-run with it on fixed and unfixed bluetooth-next, same verdicts, `summary-v2-r4.txt`) |
| `bluez-mgmt-tester/v1/` | the first version (four patches in one series), kept; superseded after outside review |
| `results/` | v1: `summary-F.txt` (every verdict), the packet-order extracts of the decisive runs, `lint-v1.log`. v2: `summary-v2.txt`, `summary-v2-stable-lines.txt`, `summary-recheck.txt`, `summary-v2-l2cap-master.txt`, `summary-v2-r4.txt`, `compare-full-recheck.txt`, `lint-v2.log`, `make-check-v2.log`. Both: `backport-record.txt`, `w1-positive-control.log` |

**What v2 changed after review.** The tests' delayed callbacks now live in per-test state and
are cancelled in post-teardown, which runs on every path (BlueZ's `tester_wait()` keeps no id,
so v1's waits could fire in the next test; shown with deliberately failing scratch builds);
setup and test calls check their return values; where the kernel has no
`quirk_simultaneous_discovery` debugfs entry the cases report **Not Run** (exit status 0)
instead of failing; the vhci debugfs path buffer is sized with `PATH_MAX`; the leak fix is
split out.

## How the test forces the race (the event order is forced; the kernel's 10.24 s LE timer still runs)

The kernel already exposes the quirk for every LE controller in debugfs
(`quirk_simultaneous_discovery`; writable while the controller is down). The test sets it on
the emulated controller, starts BR/EDR+LE discovery, suppresses the emulator's own Inquiry
Complete, and, when the kernel's LE scan timer sends LE Set Scan Enable (disable), injects
Inquiry Complete before the emulator answers that command. The control case sends Inquiry
Complete early, the normal order. Pass: `Discovering: Disabled` arrives before the restart
probe, a new Start Discovery one second after the scan-off, and that Start Discovery succeeds.
Fail, without the fix: no `Discovering: Disabled` before the probe, and the probe is answered
Busy (0x0a). (In the unfixed logs a Disabled event does appear later, at the test's teardown
power-off.) Each case takes about 13 s, most of it that timer.

Coverage: the emulated controller is LE 4.0, so the cases use legacy LE Set Scan Enable. The
kernel ends extended scanning through the same function, `le_set_scan_enable_complete()`, called
from both `hci_cc_le_set_scan_enable()` and `hci_cc_le_set_ext_scan_enable()` (checked at
v6.12.112); the upstream report was extended scanning.

The one-second wait after power-on in the setup: the kernel sends the Set Powered reply, and
New Settings to every socket but the requester's, before it frees the pending command
(`mgmt_set_powered_complete()`, v6.12.112), so no event marks the moment when the next Set
Powered is accepted rather than answered Busy (checked in bluetooth-next `964430c03896` too).
The code comment at the wait says so. A retry on Busy would be the alternative.

## Results (qemu, 4 CPUs, KASAN, lockdep)

Race case and control, per kernel; "runs" counts every run that includes the race case
(targeted runs, Start Discovery group runs, full suites):

| kernel | v1 tests (`summary-F.txt`) | v2 tests (`summary-v2*.txt`) | control | Start Discovery group | Stop Discovery group |
|---|---|---|---|---|---|
| bluetooth-next `964430c03896` with `96d006ae6445` reverted (test only) | **fail** 7/7 (Busy 0x0a) | **fail** 4/4 | pass | 13/14 | 5/5 |
| bluetooth-next `964430c03896` (has the fix) | pass 8/8 | pass 10/10 | pass | 14/14 | 5/5 |
| v6.12.112 | **fail** 8/8 | **fail** 3/3 | pass | 13/14 | 5/5 |
| v6.12.112 + backport | pass 8/8 | pass 4/4 | pass | 14/14 | 5/5 |
| v6.6.158 | **fail** 2/2 | **fail** 3/3 | pass | 13/14 | 5/5 |
| v6.6.158 + backport | pass 2/2 | pass 3/3 | pass | 14/14 | 5/5 |
| v6.1.189 | **fail** 2/2 | **fail** 3/3 | pass | 10/14 ¹ | 5/5 |
| v6.1.189 + backport | pass 5/5 | pass 3/3 | pass | 11/14 ¹ | 5/5 |

¹ Three extended-scanning cases fail on 6.1.189 with and without the backport, and pass on
bluetooth-next; not examined further.

**Full mgmt-tester, compared by test name** (fixed bluetooth-next; `compare-full-recheck.txt`,
13 runs). Without the series (master, 6 runs): 506 cases, 8 fail in every run (the "LL
Privacy" cases listed in the log), plus two that time out intermittently: "Pairing Acceptor -
SMP over BR/EDR 2" in 3 of 6 runs and "LL Privacy - Remove Device 4 (Disable Adv)" in 1 of 6.
With the series (v1 and v2, 7 runs): the same 8, the same two intermittently (5 of 7 and 2 of
7), and both new cases pass in every run. Every other existing case has the same verdict in all
13 runs. So the totals vary between 497 and 498 of 506 without the series and between 498 and
500 of 508 with it; the earlier "499/508 against 498/506" was one run each. Too few runs to
compare the two timeout rates. Run alone, the SMP case passed 10 of 10 with master and 10 of 10
with v2.

**Exit status and sanitizer** (verdicts above, process status here; ASan on, LeakSanitizer at
exit). Full mgmt-tester exits 1 in every run because of the failures. LeakSanitizer reports,
without the series: 120 bytes in 5 objects from `btdev_add_hook` in every run, plus 8 bytes
from `util_malloc` in some; with the leak fix: no `btdev_add_hook` leak, and 8 or 16 bytes from
`util_malloc` in some runs. The 120 bytes are five cases that leave a hook installed: "Add +
Remove Device Nowait - Success" (24 bytes) and the four "Adv. … & connected" cases on the LE
emulator (96 bytes); run alone, those four leak 96 bytes with master and with the test series
alone, and nothing with the leak fix (`summary-recheck.txt`). The 6.12 full runs (v1) reported
64 bytes from allocations unrelated to this work. l2cap-tester: 111/111 pass, but exits 1:
LeakSanitizer reports 3024 bytes in 48 objects from `l2cap_listen_cb` (`tools/l2cap-tester.c`,
not touched by the series); with unmodified BlueZ the same 3024 bytes plus 24 bytes from
`btdev_add_hook`, which the leak fix removes (`summary-v2-l2cap-master.txt`). sco-tester 30/30,
exit 0.

Also: `make W=1 KCFLAGS=-Werror net/bluetooth/` clean on all six stable kernels (the gate was
shown to fail on a planted unused variable); kernel checkpatch `--strict` reports only the
`[ Upstream commit … ]` line, the form the stable rules prescribe; BlueZ checkpatch and gitlint
clean on the four v2 patches and the cover letter (`lint-v2.log`; the 78-column line is the
`Fixes:` tag; its one FAIL is `scripts/gitlint-check.sh` reading the cover-letter file whole,
mail signature "-- " included, as a commit message);
BlueZ `make check` on master + leak fix + test series (ASan build): 41 of 42 pass, 0 fail,
`unit/test-mesh-crypto` skipped (`make-check-v2.log`; the unit tests do not run the testers,
whose results are above). Full mgmt-tester on 6.12.112 (v1): 463/508 unpatched, 464/508 backported (only the
race case differs, apart from one timing-dependent SMP case).

In the copies here, other people's e-mail addresses are replaced by `<address elided>` and the
device address quoted in the upstream message by `AA:BB:CC:00:00:01`; the patches as they
would be sent are kept with the rest of the kit. The raw guest logs, kernels and binaries are
kept on the development host with `SHA256SUMS`; the extracts here are taken from them by
`order-extracts.sh`.

## Before sending (operator's word)

Re-check on the day: the three stable tips and the stable queue (in case `96d006ae6445` was
picked up meanwhile), `patch --dry-run` on each tip, and the stable list for a "FAILED: patch"
thread on this commit (2026-10-10: none; the list holds only the 6.18 and 7.1 review posts).
The backport request goes to the stable list as three separate mails (`send/`). The BlueZ leak
fix and the test series are separate submissions to linux-bluetooth.
