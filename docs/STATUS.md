# Status — the dated snapshot

**As of 2026-10-03.** One row per issue and per submission: what it is, how mature the
evidence is, where it stands, what happens next. This page is the one place that says what
is *current*; the reasoning behind each row lives where the row points. `README.md`
summarises; `BRIEF.md` is the maintainers' hand-off (machine state, constraints, rules);
`docs/issues.md` holds each issue's evidence and falsifiers; `HISTORY.md` is the narrative.

Lifecycle states used below: **observed** · **hypothesis** · **confirmed** · **patch
written** · **under review** (outside review before any submission) · **submitted** ·
**accepted** (in the subsystem maintainer's tree) · **released** · **in stable** ·
**delivered downstream** (a distribution package) · **withdrawn** · **superseded**.

## Submissions

| what | component | state | milestones | next |
|---|---|---|---|---|
| `adapter: Fix crash on short start discovery reply` | BlueZ | **accepted** | sent 2026-09-19 · applied 2026-09-21 as [`a734b06059cb`](https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=a734b06059cbe0d0f00442c901506ef17e960960) · release: none yet (past 5.87) · Ubuntu: not requested | watch the next BlueZ tag; consider an Ubuntu SRU with the kernel fix |
| `a2dp: Fix crash on NULL stream in transport_cb` | BlueZ | **accepted** | sent 2026-09-19 · applied 2026-09-21 as [`0bed9886cff3`](https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=0bed9886cff317d814f9b1f11c1461459f2b9a00) · release: none yet | same |
| `Bluetooth: MGMT: Fix status of pending commands flushed on power off` | Linux kernel | **accepted** | sent 2026-09-24 · applied 2026-09-29 as [`86ef0f58bdec`](https://github.com/bluez/bluetooth-next/commit/86ef0f58bdecdedb3a1240971c56d71b7e4ce3fc) on bluetooth-next · carries `Cc: stable` · mainline: not yet merged · stable: follows mainline | watch the next bluetooth-next pull into net-next and mainline |
| Stable backport of `dc16388d45ec` (the QCA9377 device-table entry, authored upstream by Tibor Harcsa) | Linux stable | **queued for stable** (7 lines) | requested 2026-10-02 03:25 +0200 for 7.2.y, 6.18.y, 6.12.y, 6.6.y, 6.1.y ([lore](https://lore.kernel.org/r/20261002012542.473669-1-yaroslav.voytovych@gmail.com)) · cherry-pick + build verified on all seven live lines (`EX-059`) · **queued by the stable team for 7.2, 6.18, 6.12, 6.6, 6.1, 5.15 and 5.10** ([reply](https://lore.kernel.org/r/2026-10-02-1-daily-reply-0005-re-btusb-qca9377-imc-backport@kernel.org), mirror [request](https://www.spinics.net/lists/linux-bluetooth/msg136622.html) / [reply](https://www.spinics.net/lists/linux-bluetooth/msg136667.html)); in the public stable queue by [`007ed56547de`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/stable-queue.git/commit/?id=007ed56547dedc050e1af25976bdfb299aa99b67) (2026-10-03), confirmed the same day (`EX-061`) · release: next stable release of each line · Ubuntu: follows its stable-update cadence | watch each line's next release; then the Ubuntu kernel that picks it up |
| Mesh advertising series (5 kernel patches) + BlueZ tester series (4 patches) | Linux kernel + BlueZ | **patch written; v3 ready for the third outside review** | v2 review (2026-10-03) answered in phase 5 (2026-10-04): depends on another author's posted cleanup (named, not included); power-off tests found an older bug, fixed as 4/5; mesh-tester 55/55 (unpatched 18/55), KASAN/lockdep/KCSAN clean; not sent | the operator's two decisions (Count vs deadline: 5/5 comment or the alternative; whether 4/5 goes with the series) → third review → the operator's word |

## Issues

| id | issue | component | evidence | state | next |
|---|---|---|---|---|---|
| `BT-1` | Controller stops answering HCI after a transparent SCO stream starts; only a power-off recovers it | QCA9377 firmware / `btusb` device table | 12 instances on the stock driver (`EX-033`…`053`); 0 in 58 + 16 links with the QCA firmware loaded (`EX-055`…`058`) | **confirmed cause, fix upstream** (`dc16388d45ec`, not authored here); **queued for seven stable lines** 2026-10-03 (`EX-061`) | the stable releases; then the Ubuntu kernel carrying it; more headsets on E3 meanwhile |
| `BT-2` | Opening the Bluetooth panel causes a 16.0 s HCI command desync | GNOME / BlueZ / kernel | characterised (`EX-002`, `EX-003`) | **observed**, not a cause of BT-1 | none planned |
| `BT-3` | `13d3:3503` absent from the `btusb` quirks table | `btusb` | `EX-001`; validated as the cause of BT-1 by E1/E3 | **superseded** into BT-1; fixed upstream 2026-08-07 | — |
| `BT-4` | `btmon` aborts repeatedly while capturing | BlueZ 5.72 | `EX-010`, `EX-011` (minimal reproducer) | **observed**; probes are the main trigger | check BlueZ master for the fix before reporting |
| `BT-5` | SCO link established, then carries almost no data | — | `EX-009` | **superseded** 2026-09-18 (`EX-043`: an idle link, not a precursor) | — |
| `BT-6` | ACL data for an unknown connection handle | kernel / controller | observed once | **observed** | none planned |
| `BT-7` | `bluetoothd` dereferences NULL at two sites | BlueZ | `EX-032`, `EX-041` (guard fired 4×) | **accepted upstream** (the two BlueZ patches) | release / downstream tracking |
| `BT-8` | Pending management commands flushed at power-off answered with a status read from the wrong object | kernel MGMT | the zero-length Success reply that crashed `bluetoothd` in BT-7's first site; reproduced with `hci_vhci` | **accepted upstream** (`86ef0f58bdec`) | mainline / stable tracking |
| `M-1` | Mesh transmission never stops advertising: the mesh instance keeps `adv_instances` non-empty; the done path completes the wrong request; a scheduler window starts a packet twice | kernel MGMT | reproduced in qemu with `tools/mesh-tester`; the list's bot fails this tester on every patch since June | **patch written, under review** (series v2) | second outside review |
| `M-2` | `u16 duration = adv->timeout * MSEC_PER_SEC` overflows for timeouts above 65 s | kernel hci_sync | source reading; corrected arithmetic note | **hypothesis**, note only | reproducer, then decide on a patch |
| `U1` | First line of the GNOME codec/profile list unselectable in handsfree mode | GNOME Settings | [operator] | **observed** | capture, then upstream search |
| `U2` | Volume display/route oddities after profile switch | PipeWire / GNOME | partial capture | **observed** | capture |
| `U3` | Profile priority comparison (design) | WirePlumber | measured on both sources | **observed** (design, not a defect) | none planned |
| `U4` | GNOME codec row shows a profile/route mismatch | GNOME Settings | two captures | **observed**, lead weakened | gcc/gvc source check |
| `U5` | Switching to handsfree picks CVSD over mSBC | — | — | **withdrawn** by the operator (a per-device setting) | — |
| `U6` | Input meter does not follow the active input device (GNOME Settings 46) | GNOME Settings | captured; the fix series located upstream (`215289935`…`3aeb837cb` + `0da10f03a`, first in 47.0; not in Ubuntu 24.04's 46.7 — [`docs/userspace-upstream-check-2026-10-03.md`](userspace-upstream-check-2026-10-03.md)) | **confirmed**, fixed upstream in GNOME 47.0 | one recorder reading with the panel open, then a Launchpad SRU request quoting the six commits |
| `U7` | After an HFP codec switch under a live SCO link the new link is never set up | PipeWire (and the host-side handling of the overlap) | HCI capture, earbuds 3/3 fail, MOMENTUM 0/2 (`EX-060`): the headset's `AT+BCS=` reply and PipeWire's new connect land before the old link's Disconnection Complete on the earbuds (reply +14…27 ms, event +177…202 ms), after it on the MOMENTUM (event +33…41 ms, reply +61…70 ms) | **confirmed: a race between the new connect and the old link's teardown**; no PipeWire commit through master fixes it | report to PipeWire with the capture excerpt; the host-side handling is examined separately before anything is said about it |
| `U8` | Earbuds silent in mSBC; `corrupted SCO packet` in the log (also seen once on the Shure) | kernel / firmware / earbuds | lead | **observed** | capture a silent link |
| `U9` | No reconnect after rfkill off/on (BlueZ policy reconnects only after link loss or suspend) | BlueZ policy | source + operator marks | **confirmed** (design) | decide whether to propose a change |

## The investigation machine

E3 (`updates/btusb.ko` carrying the exact upstream entry) is installed; trial E3 #1 is
open; the installed `/usr/local/bin` tools are the 2026-09-18 copies until the operator
installs the current ones. Nothing is changed on this machine without the operator's word.

## Repository health

CI (`checks` workflow) was red on every push from 2026-09-26 to 2026-10-02: four suite
invariants failed in code added that week while the suite could not run locally (it refuses
while a trial is open). Fixed on 2026-10-03 (`fix/ci-invariants-2026-10-03`), with one real
defect among them: the trial closer read a `journalctl --grep` no-match exit as an
unreadable journal. The badge on `README.md` shows the live result.

## How to update this page

Change a row when its state changes; date the page at the top; keep the lifecycle words.
Do not add a second "current" paragraph anywhere else — `README.md` and `BRIEF.md` link
here.
