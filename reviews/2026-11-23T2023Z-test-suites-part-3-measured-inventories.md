# Part 3: the inventories measured, and what upstream already has (2026-11-23)

**Follows** [part 1](2026-11-23T2011Z-test-suites-that-would-have-caught-these-defects.md)
and [part 2](2026-11-23T2018Z-test-suites-part-2-the-whole-subsystem.md). Part 2 drew the map
from memory with one rough count. This page measures it in the upstream sources and reads
what upstream has built in the last three months. Two statements of the earlier parts turn
out wrong and are corrected in section 1.

Sources, all read on 2026-11-23: BlueZ master `1adfe662e`; bluetooth-next `cf357cfc02`;
the kernel fuzzer's interface descriptions (syzkaller `fab64d8`). Counts are by pattern
matching on named files and are good to a few per cent; the method is given with each so
that it can be repeated.

## Contents

1. Corrections to parts 1 and 2
2. What upstream built since September 2026
3. Inventory 1 measured: commands, events, options
4. Inventory 2 and 3 measured: objects, procedures, resources, endings
5. Inventory 4 measured: configurations
6. Inventory 6 measured: failures
7. The gap table: map against existing tests
8. What this changes in the design and in the order of work
9. What this project could contribute first

## 1. Corrections to parts 1 and 2

**C-1. "A third of the commands cannot be tested at all" (part 2, section 2) is misleading.**
The protocol header defines 328 commands (not 335: the first count included seven
non-opcode lines) and the emulated controller answers 210. But most of the 118 unanswered
ones are commands the kernel never sends (the removed high-speed feature, park and hold
modes, radio test commands, channel sounding). Of the **182 distinct commands the kernel
host stack does send**, the emulated controller lacks **19**:

`SNIFF_MODE`, `EXIT_SNIFF_MODE`, `SNIFF_SUBRATE`, `SWITCH_ROLE`, `ROLE_DISCOVERY`,
`READ_LINK_POLICY`, `WRITE_LINK_POLICY`, `PERIODIC_INQ`, `EXIT_PERIODIC_INQ`,
`REMOTE_OOB_DATA_REPLY`, `REMOTE_OOB_DATA_NEG_REPLY`, `REMOTE_OOB_EXT_DATA_REPLY`,
`USER_PASSKEY_REPLY`, `READ_LOCAL_PAIRING_OPTS`, `READ_DEF_ERR_DATA_REPORTING`,
`WRITE_DEF_ERR_DATA_REPORTING`, `WRITE_ENCRYPT_MODE`, `WRITE_SSP_DEBUG_MODE`, `NOP`.

So the true statement is: **about a tenth** of what the kernel sends has no emulated answer,
and it is concentrated in one area. The whole **link-policy group is 2 of 14 emulated**:
sniff mode, role switch and link policy cannot be exercised by any tester. That is the
classic-Bluetooth power-saving and role machinery, which every headset connection uses.

**C-2. "No whole-stack test exists upstream" (part 1, suite F; part 2, section 7 step 6) is
out of date.** Since September 2026 BlueZ carries a functional suite that boots several
virtual machines, each with the real kernel and the real daemon, joined by one emulated
controller process, and drives them over D-Bus (section 2). Suite F and generator 4.5 should
therefore be designed as extensions of it, not as a new thing, and its home is BlueZ, not
"the distributions".

**C-3. "The emulator has no hold gate" (part 1, suite A) is half wrong.** The emulated
controller has hooks before and after each command and each event, and a hook may swallow
the packet. A test can therefore already stop a procedure at a chosen command. What is
missing is the generation: the hooks are used in 34 places across all testers (mgmt 9,
l2cap 9, iso 6, sco 6, mesh 2, smp 2), each written by hand for one case.

**C-4. The tester counts in `doc/test-coverage.txt` are years old** (it lists 408 end-to-end
cases; the source registers about 1,000, and it still lists the removed Android testers).
Part 2's count from the sources stands; the document is not a usable coverage statement,
which supports part 2, section 7, step 1.

## 2. What upstream built since September 2026

Read from `doc/test-functional.rst`, `doc/functional-testing.rst`, `doc/test-runner.rst`,
`test/functional/` and `emulator/`.

- **A functional suite** (`test/functional`, first commit 2026-09-06, 43 commits since):
  49 test functions in 13 modules: Basic Audio Profile 18, bearer 8, the command-line
  client 6, A2DP 4, object exchange 3, media-player proxy 2, and one each for agent
  pairing, advertisement monitor, AVRCP, HID over GATT and the management tool. Each test
  is documented as setup, steps, expected, notes, with a topology diagram.
- **Topology:** one test driver, N virtual machines each running kernel + daemon, one
  emulated controller process serving all of them; or real USB or PCIe controllers passed
  through to the machines and talking over the air, selected by an option. So the same test
  can run on emulation and on hardware. That is part 1's "hardware shelf" already designed.
- **Simulated time** (`emulator/timetravel.c`, October 2026): with a user-mode kernel the
  machines run on a simulated clock for which the emulated controller is the calendar. Time
  advances only when every machine waits. Timeouts of seconds cost nothing, and a run is
  repeatable. This is precisely the instrument the interleaving walker needs to make
  "answer arrives one tick after the timeout" a deterministic case rather than a race.
- **Kernel test configuration** (`doc/ci.config`, `doc/tester.config`): memory-error
  detector on, lock-order prover on, sleeping-in-atomic check on. Not enabled: leak
  detector, undefined-behaviour checker, data-race detector, fault injection, coverage
  collection.
- **Regression marker for security advisories**, and a marker that keeps the kernel testers
  out of the daemon's release gate.
- **Two tests in the style of this project's findings already exist:**
  `test_a2dp_disconnect_during_setconf` and `test_a2dp_reconnect_pending_disconnect`. They
  are hand-written points of generator 4.2. Upstream is walking the same road one case at a
  time.

What the functional suite does not have: an audio server on top (no PipeWire or
WirePlumber in the machines), suspend and resume, rfkill, the hands-free profile, adapter
removal, and any generated case.

