# Part 3: the inventories measured, and what upstream already has (2026-11-23)

**Follows** [part 1](part-1-the-suites-that-would-have-caught-these-defects.md)
and [part 2](part-2-the-whole-subsystem.md). Part 2 drew the map
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

## 3. Inventory 1 measured: commands, events, options

| boundary | defined | exercised today | method |
|---|---|---|---|
| HCI commands | 328 in the protocol header; kernel sends 182 | emulator answers 210 (163 of the kernel's 182); testers name 69 as an expected command | `BT_HCI_CMD_` in `monitor/bt.h`, `emulator/btdev.c`, `tools/*-tester.c`; `HCI_OP_` used in `net/bluetooth` |
| HCI commands by group | link control 54, link policy 14, baseband 96, informational 13, status 12, testing 4, low energy 134 | emulated: 30, **2**, 55, 12, 4, 1, 106 | opcode group field |
| HCI events | 111 in the header; kernel defines 83 | emulator can emit 56 | `BT_HCI_EVT_`, `HCI_EV_` |
| management commands | 93 | 71 named in some tester; **22 in none** | `MGMT_OP_` in the kernel header against all testers |
| management events | 50 | 27 named; 23 in none | `MGMT_EV_` |
| socket options at the Bluetooth level | 16 | 12 named in testers; `BT_FLUSHABLE`, `BT_POWER`, `BT_CHANNEL_POLICY` and the error control message in none | constants in `bluetooth.h` |
| ioctls | 35 | 17 named | `_IO*` definitions |
| L2CAP signalling messages | 21 | not measured | `l2cap.h` |
| D-Bus | 55 interface documents, about 174 methods, about 241 properties, 28 error names | 49 functional tests touch perhaps a tenth; one `gap-tester` case | `doc/org.bluez.*.rst` |

Management commands named by no tester: `ADD_ADV_PATTERNS_MONITOR`,
`ADD_ADV_PATTERNS_MONITOR_RSSI`, `REMOVE_ADV_MONITOR`, `READ_ADV_MONITOR_FEATURES`,
`ADD_REMOTE_OOB_DATA`, `REMOVE_REMOTE_OOB_DATA`, `CANCEL_PAIR_DEVICE`, `CONFIRM_NAME`,
`GET_ADV_SIZE_INFO`, `GET_CONNECTIONS`, `HCI_CMD_SYNC`, `READ_DEF_RUNTIME_CONFIG`,
`SET_DEF_RUNTIME_CONFIG`, `READ_DEF_SYSTEM_CONFIG`, `SET_BLOCKED_KEYS`, `SET_DEBUG_KEYS`,
`SET_EXTERNAL_CONFIG`, `SET_HS`, `SET_PUBLIC_ADDRESS`, `SET_WIDEBAND_SPEECH`,
`START_LIMITED_DISCOVERY` (and one size constant). Two of these matter to this project
directly: `CANCEL_PAIR_DEVICE` is an "end it in the middle" command with no test at all, and
`SET_WIDEBAND_SPEECH` governs the voice path where BT-9 lives.

"Named in a tester" is a generous measure: it says the command appears, not in how many
states it was sent. The commands-by-states table of part 2 would be far emptier.

## 4. Inventories 2 and 3 measured: objects, procedures, resources, endings

Size of the thing under test: `net/bluetooth` is 75,857 lines in 36 files; the five largest
are the management interface (11,334), the command sequencer `hci_sync.c` (9,252), event
handling (8,815), L2CAP (8,484) and the core (4,428). Drivers are another 53,155 lines.

| item | count | meaning for the generators |
|---|---|---|
| socket and connection states | 9 (`BT_OPEN` to `BT_CLOSED`) | one shared state list for five socket families: the walker's state axis is small |
| adapter flags | 112 | the adapter's "state" is a set of flags, not an enumeration; the state table must be written as named combinations |
| connection flags | 35 | same |
| L2CAP channel flags | 33 | same |
| procedures in the command sequencer | 213 functions ending in `_sync`; 149 places that send a command and wait | the step list of generator 4.2 is at most a few hundred steps: **enumerable** |
| places that queue a procedure | 94 | the entry points for 4.2 |
| deferred-work items | 39, plus 3 timers | every one is a "runs later" site: the lifetime walker's list |
| reference-taking sites (connection, channel, socket, adapter) | 115 | the leak invariant has this many places to be wrong |
| allocation sites | 138 | the failure walker's list for allocation failure |
| fault-injection points declared in the subsystem | 0 | allocation failure is reachable only through the kernel-wide facility |
| in-kernel self-tests | one file, 307 lines (cryptographic vectors only); no unit-test framework use | no white-box test of any state machine exists |

Endings, as exercised by the testers today (by name of test case or helper):

| ending | where it is tested | where it is not |
|---|---|---|
| suspend and resume | management tester (15 named cases), isochronous tester (5) | SCO, L2CAP, RFCOMM, security: none |
| power-off | management tester; one SCO case | during connection set-up on any socket family |
| controller removal | only as the teardown at the end of every test | never in the middle of an operation |
| peer or ACL disconnect during set-up | SCO has two ("simultaneous disconnect", "ACL disconnect"), added after defects were found | not systematic anywhere |
| timeout | named in several testers | always the plain case; never "the answer arrives just after" |
| death of the owning process | none | everywhere |
| rfkill | none (the option is compiled in, nothing uses it) | everywhere |

The picture is consistent: **each ending is tested where a defect was once found**, and the
product "ending by object" that part 2 asks for has perhaps a tenth of its cells touched.

## 5. Inventory 4 measured: configurations

| item | count |
|---|---|
| controller quirk flags | 34; all 34 set by some driver; 29 read by the core |
| quirks the virtual driver can set | 4 (raw device, external configuration, non-persistent set-up, synchronous flow control) |
| so: quirks whose core paths no emulated test can reach | **about 25 of 29** |
| emulated controller types | 10 (classic 2.0 up to dual-mode 7.0) |
| virtual driver switches | 5: forced suspend, forced wake-up, a vendor extension opcode, a second vendor extension, forced crash dump |
| USB driver device table | 392 entries, 30 driver flags, **29 distinct flag combinations** |
| largest combinations | MediaTek with wideband speech 86 entries; Realtek with wideband speech 73; Qualcomm WCN6855 with wideband speech 55; Atheros 3012 52 |

The last two rows settle a question part 2 left open. The configuration space of the USB
driver is not "34 quirks times 400 devices": it is **29 combinations**, which is a matrix a
nightly run can walk whole once an emulated USB controller exists. And the quirk gap has a
cheap remedy that needs no USB emulation at all: a debug switch on the virtual driver that
sets any quirk, so that the existing testers can run under each. That is a small kernel
patch with a large coverage effect.

## 6. Inventory 6 measured: failures

| item | count |
|---|---|
| HCI error codes the kernel names | 19 |
| error codes the emulated controller can return | 19 distinct, but by its own logic only: success 229 places, invalid parameters 60, unknown connection 45, command disallowed 36, capacity exceeded 19 |
| testers that ask the emulator to fail a chosen command with a chosen code | effectively none (three mentions of an error code in all testers) |
| management status codes | 21 |
| management status codes the management tester expects | success 338, invalid parameters 106, invalid index 17, rejected 16, not supported 12, not powered 10, authentication failed 7, and four codes once each; **ten codes never** |

So the failure axis is the emptiest of all. The testers check that *bad input from above* is
refused (invalid parameters is the second most common expectation) and almost never what
happens when *the controller below* refuses or stays silent. Every one of this project's
error-contract findings (the CO-26 family, BT-21's lost error) is on that untested side.

## 7. The gap table

| inventory | size of the map | touched today (generous) | what blocks more |
|---|---|---|---|
| commands the kernel sends | 182 | 163 emulated, 69 expected by a test | 19 missing emulations, all in two areas |
| management commands | 93 | 71 | nothing; tests to write |
| commands by states | not yet countable | a few per cent | the state tables do not exist |
| procedure steps by endings | about 150 steps by 8 endings | a few dozen hand-written cells | a generator; the hooks exist |
| commands by failure codes | about 182 by 19, plus silence and lateness | near zero | a small emulator feature: scripted answer |
| quirks | 29 read by the core | 4 | a debug switch on the virtual driver |
| USB driver configurations | 29 | 0 | an emulated USB controller |
| D-Bus methods and properties | about 415 | a tenth | tests to write; the framework exists |
| whole stack with audio server | n/a | 0 | add the audio server to the test machines |
| kernel lines | 5 maintained | 1 (the development tree) | machine time only |

For comparison, the kernel fuzzer describes 65 Bluetooth socket calls and 131 event
structures for the virtual controller, and names no management opcode: it reaches the
packet parsers and the socket layer well, and the management interface and the multi-step
procedures only by chance.

## 8. What this changes in the design and in the order of work

1. **The instruments are mostly there.** Hooks to stop a procedure, simulated time to make
   timing deterministic, multi-machine topology with real daemons, hardware pass-through,
   memory and lock checkers. Parts 1 and 2 proposed building several of these; they exist.
   The missing things are small: a scripted answer (code, silence, lateness) in the
   emulator; a quirk switch in the virtual driver; 19 command handlers; the leak detector
   and fault injection in the test configuration.
2. **What is missing is generation and accounting.** Nothing upstream enumerates. Each test
   is a hand-written point; there is no table saying which points exist. The contribution of
   parts 1 and 2 that survives measurement is therefore exactly its central idea: the
   inventories, the walkers over them, and the coverage report.
3. **The numbers are small enough.** About 150 waiting steps, 8 endings, 19 codes, 29
   driver configurations, 29 quirks. The interleaving walker is on the order of a thousand
   cases and the failure walker a few thousand, each a fraction of a second on simulated
   time. "The whole subsystem" is a nightly run, not a research programme.
4. **Revised order** (replacing part 2, section 7): (a) the coverage report over the
   existing testers, including a replacement for the outdated `doc/test-coverage.txt`;
   (b) scripted answers in the emulator and the 19 handlers; (c) the failure walker, because
   its axis is emptiest and it needs only (b); (d) the interleaving walker on simulated
   time; (e) the quirk switch and a run of all testers per quirk; (f) the audio server in
   the functional machines, then the hands-free and A2DP scenarios of this project as
   functional tests; (g) the emulated USB controller; (h) the sequence generator.

## 9. What this project could contribute first

In the spirit of the project's rule that the homework is done before anything is sent:

- **Two functional tests that upstream would recognise at once**, in the form its own
  documentation prescribes (setup, steps, expected, notes): the voice-link set-up
  interrupted by disconnect (the BT-9 scenario), and a profile connection interrupted by
  power-off. They sit beside `test_a2dp_disconnect_during_setconf`, which is the same kind
  of test, and each should fail on a tree without the corresponding fix.
- **The coverage table of section 3 as a patch to the documentation**, with the script that
  produces it. It costs upstream nothing to take and replaces a file that is years out of
  date.
- **Emulation of sniff mode, role switch and link policy.** A defined, bounded piece of
  work (12 commands and their events) that opens the one command group which is closed
  today, and which every classic audio connection uses.
- **Tests for `CANCEL_PAIR_DEVICE` and `SET_WIDEBAND_SPEECH`** in the management tester.

Each of these is small, verifiable on the existing upstream machinery, and independent of
whether the larger design is ever adopted. Whether to do any of them is the author's
decision; none has been started.

## Limits of this page

Counts are textual: a name appearing in a file is counted as "exercised", which overstates
coverage; a command built from a computed opcode would be missed, which understates it. The
D-Bus counts depend on the documents' layout and may be off by a tenth. The functional
suite was read, not run. The fuzzer's actual reach was judged from its interface
descriptions, since its coverage pages could not be fetched from here.

---

Complete as of 2026-11-23. Written in two pieces (sections 1 to 2, then 3 to 9) and not
edited afterwards.
