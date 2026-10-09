# BT-9 — the stable backport of `96d006ae6445`, and a deterministic test for it

**State 2026-10-10: built and tested in qemu; nothing sent.** Sending is the operator's call.

## What and why

BT-9 (`docs/issues.md`, `EX-062`): with `HCI_QUIRK_SIMULTANEOUS_DISCOVERY`, an Inquiry Complete
that arrives between the LE scan-off command and its Command Complete leaves discovery in
`DISCOVERY_FINDING`; every later Start Discovery is answered Busy. Jiajia Liu fixed it upstream:
`96d006ae6445` "Bluetooth: hci_event: fix simultaneous discovery stuck in FINDING" (v7.2-rc1;
stable 7.1.5, 6.18.40). It is missing from **6.12.y, 6.6.y and 6.1.y** (checked at v6.12.112,
v6.6.158, v6.1.189 and in the stable queue on 2026-10-09). There it does not apply unchanged:
`hci_test_quirk()` does not exist on those lines. And `BTUSB_QCA_ROME` sets the quirk there,
so the 13d3:3503 entry (`dc16388d45ec`), queued for those lines at this project's request, gives
this device the quirk without the fix.

## Contents

| path | what |
|---|---|
| `6.12.112/`, `6.6.158/`, `6.1.189/` | the backport per line: `96d006ae6445` cherry-picked, original author, date, message, `Fixes:` and sign-offs, `[ Upstream commit … ]` per `stable-kernel-rules.rst`; one change, `hci_test_quirk(hdev, Q)` → `test_bit(Q, &hdev->quirks)` as those lines test this quirk elsewhere; a bracketed note and our sign-off. One patch-id for all three (`results/backport-record.txt`) |
| `bluez-mgmt-tester/` | four BlueZ patches on master `7428ca2df935`: free the emulator's hooks in `btdev_destroy()` (a leak LeakSanitizer reports for any test that adds a hook), `btdev_send_event()`, `vhci_set_quirk_simultaneous_discovery()`, and two `mgmt-tester` cases: "Start Discovery - Simultaneous Inquiry First" (control) and "… Inquiry Late" (the race) |
| `results/` | `summary-F.txt` (every verdict), the packet-order extracts of the decisive runs, `backport-record.txt`, `lint.log`, `w1-positive-control.log` |

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
power-off.)

## Results (qemu, 4 CPUs, KASAN, lockdep; `results/summary-F.txt`)

| kernel | race case | control | Start Discovery group | Stop Discovery group |
|---|---|---|---|---|
| bluetooth-next `964430c03896` with `96d006ae6445` reverted (test only) | **fail** 6/6 (Busy 0x0a) | pass | 13/14 | 5/5 |
| bluetooth-next `964430c03896` (has the fix) | pass 6/6 | pass | 14/14 | 5/5 |
| v6.12.112 | **fail** 6/6 | pass | 13/14 | 5/5 |
| v6.12.112 + backport | pass 6/6 | pass | 14/14 | 5/5 |
| v6.6.158 | **fail** | pass | 13/14 | 5/5 |
| v6.6.158 + backport | pass | pass | 14/14 | 5/5 |
| v6.1.189 | **fail** | pass | 10/14 ¹ | 5/5 |
| v6.1.189 + backport | pass 4/4 | pass | 11/14 ¹ | 5/5 |

¹ Three extended-scanning cases fail on 6.1.189 with and without the backport, and pass on
bluetooth-next; not examined further.

Also: `make W=1 KCFLAGS=-Werror net/bluetooth/` clean on all six stable kernels (the gate was
shown to fail on a planted unused variable); kernel checkpatch `--strict` reports only the
`[ Upstream commit … ]` line, the form the stable rules prescribe; BlueZ checkpatch and gitlint
clean on the four BlueZ patches; full mgmt-tester on fixed bluetooth-next 500/508 with the
series (the two new cases pass; the remaining failures also occur without it). The full-suite
runs are **not** sanitizer-clean: LeakSanitizer still reports 16 bytes (fixed bluetooth-next)
and 64 bytes (both 6.12 kernels) from allocations unrelated to this work, also present with
unmodified BlueZ. What the emulator patch removes is specific: with master, the existing case
"Add + Remove Device Nowait - Success" leaks 24 bytes allocated in `btdev_add_hook`; with the
series that report is gone. l2cap-tester
111/111, sco-tester 30/30; full mgmt-tester on 6.12.112 463/508 unpatched, 464/508 backported
(only the race case differs, apart from one timing-dependent SMP case).

In the copies here, other people's e-mail addresses are replaced by `<address elided>` and the
device address quoted in the upstream message by `AA:BB:CC:00:00:01`; the patches as they
would be sent are kept with the rest of the kit. The raw guest logs, kernels and binaries
(279 files) are kept on the development host with
`SHA256SUMS`; the extracts here are taken from them by `order-extracts.sh`.

## Before sending (operator's word)

Re-check on the day: the three stable tips and the stable queue (in case `96d006ae6445` was
picked up meanwhile), `patch --dry-run` on each tip. The backport request goes to the stable
list with the three patches; the BlueZ series is a separate submission to linux-bluetooth.
