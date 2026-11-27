# The test suites that would have caught what this project found by hand (2026-11-23)

**What this is.** An analysis and a design sketch, written from the project's own record of
defects as the reviewer knows it from the earlier reviews; no new reading, nothing run. It is
opinion with reasons. Defect ids (`BT-n`, `M-n`, `U-n`, `CO-nn`) are the project's.

## Contents

1. The answer in one page
2. Why manual testing found them: what the existing suites do not do
3. The defects sorted by the kind of test that would have caught each
4. The suites, one by one: purpose, architecture, content
5. Principles of composition
6. What exists already and what would have to be built
7. What tests cannot do, and a first step

## 1. The answer in one page

The Linux Bluetooth stack is tested, and well, **one layer at a time and on the happy
path**: BlueZ's testers drive the kernel through an emulated controller and check that an
operation answered as expected; unit tests check parsers; the list's CI runs both on every
patch. Almost everything this project found lies where those tests do not look:

- **between two events** (a second operation arrives while the first is still being torn
  down or completed): CO-02, BT-9, BT-8, U12, U16, U22, M-1;
- **at the end of an object's life** (power-off, removal, exit, disconnect during an
  operation): M-4, M-5, CO-04, U23 to U27, BT-7, BT-24, BT-25;
- **on the error path** (what is reported when something fails): BT-21, BT-8, CO-26, U29,
  CO-41;
- **in the driver below the emulated controller** (USB transport, suspend and resume,
  alternate settings): BT-18 to BT-25, CO-21, CO-20;
- **in real firmware** (BT-1, BT-16, BT-17);
- **between layers** (kernel, `bluetoothd`, the sound server, the session policy, the
  desktop): U7, U12, U14, U15, U17, U19, U13, U18;
- **in a stable line that received half of a change** (BT-10, BT-14, BT-15).

Seven suites would cover these, and five of them need no hardware:

| | suite | catches | needs |
|---|---|---|---|
| A | **Interleaving tests**: every tester operation re-run with a second event injected at each step of the first | races between events | the emulator, with a hook to hold and release events |
| B | **Lifetime tests under sanitizers**: every tester case ended by power-off, removal, peer loss or daemon exit at each step, with KASAN, kmemleak, lockdep, ASan | use-after-free, leaks, lock cycles at teardown | the testers, instrumented builds |
| C | **Error-contract tests**: every command made to fail in every way the code allows, and the reported status checked against the documented one | wrong or lost error reports | fault injection in the emulator and the kernel |
| D | **Transport tests**: the real USB driver against an emulated USB controller that can stall, vanish, reset and offer chosen endpoints | driver defects below HCI | a userspace USB device model |
| E | **Stable-line matrix**: suites A to D on every maintained line and every release candidate | half-applied backports | machine time |
| F | **Stack tests**: kernel, `bluetoothd`, the sound server and its policy running together against a scripted emulated headset | defects between layers | an emulated peer that speaks the audio profiles |
| G | **Hardware conformance**: a short fixed script on a shelf of real controllers | firmware and device-table defects | hardware |

The principle behind all seven is one sentence: **test the transitions and the endings, not
only the operations, and derive the cases mechanically from the operations that are already
tested**, so that coverage grows with the stack and does not depend on someone imagining the
race in advance.

## 2. Why manual testing found them

Three properties of the existing tests explain it.

1. **A case is one operation with one expected answer.** "Start Discovery answers Success."
   A person at a laptop never does one operation: they click Connect while a search is
   running, switch a codec while a call is up, close the lid during a transfer. The defects
   live in the second event.
2. **A case ends when its answer arrives.** The tester then tears everything down at once.
   What happens to pending work when the adapter powers off, the controller is unplugged or
   the daemon exits is run thousands of times a day and checked by nobody: the result of a
   teardown is not an assertion. This project's leak fix in `shared/mgmt` (233 leaked
   allocations across the testers, every verdict unchanged) is the plainest proof.
3. **The emulated controller is perfect and instant.** It answers every command, in order,
   at once, and it sits above the transport driver. So nothing tests a late event, an event
   out of order, a command that is never answered, a device that stops during a resume, or
   any line of `btusb`.

And one property of the ecosystem: **each project tests itself.** The kernel list's CI runs
BlueZ's testers; BlueZ has no test with a sound server; PipeWire has no test with a kernel.
The headset that says "mute on" at every call (U15) or loses A2DP when a browser opens the
microphone (U12) is correct in every single project's tests.

## 3. The defects, sorted by the test that would have caught each

| defect | what happened | suite | the case that catches it |
|---|---|---|---|
| CO-02 / U7 | a new SCO connect was handed a link being torn down | A | "connect" injected between "disconnect sent" and "disconnection complete" of the same peer |
| BT-9 | Inquiry Complete between the scan-off command and its answer: discovery never stops | A | each event of a discovery cycle delivered at each point of the stop sequence (the project wrote exactly this case; it is in BlueZ 5.88) |
| BT-8, BT-7 | commands pending at power-off answered Success with no payload; the daemon read it | A, C | power-off injected while each MGMT command is pending; reply length and status asserted |
| U16 | a new search refused while the stop of the old one is queued | A | StartDiscovery injected while StopDiscovery is pending |
| U12 | Release during a pending Acquire aborts A2DP for good | A, F | Release injected at each step of Acquire; with a sound server: record while playback starts |
| U22 | reconfigure while an AVDTP Close is pending: write to freed memory | A + B | SetConfiguration injected at each step of Close, under ASan |
| M-1, CO-04, CO-05 | mesh sends: wrong request completed, raw pointer used after free, list changed without the lock | A + B | two sends and a cancel in every order, on 4 CPUs, KASAN and lock assertions on |
| M-4, M-5, CO-14 | sends pending at controller removal leaked; lock cycle at unregister | B | remove the controller at each step of each operation, kmemleak and lockdep on |
| U23 to U27 | use-after-free at daemon exit and when an endpoint goes while its transport is held | B | daemon exit, bus loss and adapter removal at each step of a stream, under ASan |
| BT-24, BT-25, BT-23 | deferred USB requests parked or leaked on a failed resume or a close | D + B | the device stops answering at each step of suspend, resume and close; kmemleak on |
| BT-18, BT-19, BT-20 | driver never resumed after a reset-resume; a reset blocks the work queue; a failed resume is silent | D | resume that fails, resume that needs a reset, each during traffic |
| CO-21, CO-20 | wrong alternate setting with two SCO links; errors at hang-up | D | two SCO links, one closed, endpoint and packet sizes asserted on the emulated device |
| BT-21 | a command timeout reported as Authentication Failed | C | controller never answers command X, for every X; status asserted |
| CO-26, CO-38, M-2 | a failed add is lost; instances hidden from a listing; a duration overflows | C | allocation failure injected in each path; listing after every add and remove; boundary values of every field |
| U29, CO-41, U13, U18 | a peer's refusal reported as "unknown"; pairing over the wrong bearer; "connected" with no profile | C, F | the emulated peer refuses in each documented way; the reported error and the resulting state asserted |
| BT-10, BT-14, BT-15 | a hang and two regressions present only in stable lines | E | the existing testers, run on each line and release candidate |
| U14, U15, U17, U19 | the session policy forces a profile; a volume command is resent after the link is gone; a refused connect is retried at once; a meter stays dead | F | scripted headset plus sound server: start and stop recording, switch codec, hang up, with the commands on the air asserted |
| BT-1, BT-16, BT-17 | firmware hang on one transport path; controller wrong at start-up; controller lost at resume | G | on real hardware: wideband call, hang up, 20 times; cold and warm boot; suspend and resume idle |
| BT-4 / U28 | the capture tool overflows a buffer on a long line | (fuzz) | the decoder fed generated records at several widths under ASan |
| BT-12 | two test cases under one name | (lint) | uniqueness of case names |

Count: of about forty defects in the register that are code defects, about thirty fall to
suites A, B and C, which need nothing but the emulator and instrumented builds.

## 4. The suites, one by one

### A. Interleaving tests

*Purpose.* Find what goes wrong when event B arrives during operation A.

*Architecture.* The emulated controller gets one new ability: **hold**. Every command it
receives and every event it would send passes a gate; a test can stop at the gate, do
something else, and release. An existing tester case then becomes a list of steps (command
sent, status event, complete event, each MGMT reply). The generator takes two cases A and B
that concern the same adapter or the same peer and produces one test per step of A: run A to
that step, hold, run B, release. The expected result is not written by hand; it is a small
set of **invariants** that must hold in every interleaving:

- every command gets exactly one reply, of the documented length;
- no reply says Success for something that did not happen;
- when both operations are over, the state that userspace is told equals the state the
  controller is in (discovering, connected, advertising, powered);
- a later, plain operation still works (the adapter is not stuck Busy).

*Content.* Pairs within discovery, connection set-up and tear-down (ACL, SCO, ISO, LE),
advertising, power and the mesh send path; in the daemon, the same for D-Bus methods
(StartDiscovery and StopDiscovery, Connect and Disconnect, Acquire and Release,
SetConfiguration and Close).

*Why it is tractable.* Twenty operations of five steps give some two thousand cases of a
second each in a virtual machine. BT-9's fix test is one such case written by hand; the
suite is that case, generated.

### B. Lifetime tests under sanitizers

*Purpose.* Find what is used after it is freed, never freed, or locked in two orders, when
something ends.

*Architecture.* The same step list as in A, with a fixed set of **endings** injected at each
step: power off; remove the controller; the peer disappears; the socket is closed; the
daemon gets SIGTERM; the daemon loses its bus; the client that asked leaves the bus. The
kernel is built with KASAN, kmemleak, lockdep and the lock-assertion option, on several
CPUs; the daemon with ASan and leak checking. The verdict is **the absence of a report**,
plus the invariants of A. A teardown that leaks fails the case.

*Content.* Every tester case times seven endings. The existing testers, run to the end with
leak checking on, are the first tenth of this suite and cost nothing to switch on.

### C. Error-contract tests

*Purpose.* Check what is *said* when something fails.

*Architecture.* A table, per command, of the ways it can fail (the controller answers with
each error status; never answers; answers late; memory allocation fails at each call in the
path, using the kernel's fault injection) and of the status the management interface and
the D-Bus API document for that failure. The test injects each and compares. Where no
status is documented, the test's first run is the finding.

*Content.* Every MGMT command; every D-Bus method of the adapter, device and media
interfaces; boundary values of every numeric field (zero, one, the largest, one more);
listings read back after every change.

### D. Transport tests

*Purpose.* Test the driver that every real adapter uses and no emulated one does.

*Architecture.* A controller model that is a **USB device in userspace** (the project built
one over usbip for the btusb work), exposing chosen descriptors, endpoints and alternate
settings, and scriptable to: stall an endpoint, delay or drop a transfer, stop answering,
disappear, come back needing a reset, refuse a resume. The real `btusb` binds to it in a
virtual machine. Cases: probe with each descriptor layout in the device table's families;
set-up of each vendor path with a firmware download that succeeds, fails or is already
done; suspend and resume idle and under traffic, with each failure; SCO over each alternate
setting with one and two links; close and disconnect with requests pending. Assertions on
both sides: what the kernel reports, and what the device saw on the wire.

*Note.* The same idea serves the UART and SDIO transports with a different model.

### E. Stable-line matrix

*Purpose.* Catch a change that reached a stable line without what it depends on.

*Architecture.* No new tests: suites A to D and the existing testers, run on the tip of
every maintained line and on every release candidate, compared case by case with the
previous release of the same line. The project did this once by hand for 6.6.160 and found
four visible fixes and one hang; done by a machine for every candidate it would have found
BT-10, BT-14 and BT-15 before they were released.

### F. Stack tests

*Purpose.* Test what the user has: the kernel, `bluetoothd`, the sound server and its
session policy together.

*Architecture.* One virtual machine with all of them, and a second emulated controller
driven by a **scripted peer**: a small program that plays a headset (hands-free and A2DP
roles, the AT command dialogue, codec negotiation, volume reports) or a speaker, a keyboard,
an LE-only device, with each documented quirk as a switch ("reports microphone gain 0",
"answers the codec switch before the old link is gone", "advertises with flags 0",
"refuses pairing outside pairing mode"). A test is a short story: connect, play, open the
microphone, switch codec, hang up, switch the adapter off and on. Assertions at three
levels: what went over the air (from the capture), what each daemon reported, and what a
client sees (which profile, which default device, is audio flowing).

*Content.* The stories are the project's own incident records, one per `U` issue. Each
recorded headset becomes a profile of the scripted peer, which is how a quirk found on one
laptop becomes a regression test for everyone.

### G. Hardware conformance

*Purpose.* The one thing emulation cannot do: real firmware.

*Architecture.* A shelf of controllers (one per family in the driver's device table is
about a dozen), each on a host that can cut its power, running one fixed script per kernel
candidate: enumerate, load firmware, scan, connect a reference peer, a wideband call
repeated twenty times with a hang-up each, suspend and resume idle and in a call, cold and
warm boot. The verdict is the absence of a command timeout and of a transport error. Second
part, with no hardware at all: a **static check of the device table** against the vendor
families' known USB ids, which is the check that would have flagged this laptop's
controller years ago.

## 5. Principles of composition

1. **Generate from what exists.** A hand-written case covers the race someone already
   thought of. A step list and a generator cover the ones nobody did, and they grow when a
   new operation gets its first plain test.
2. **Invariants, not expected outputs.** In an interleaving the "right" answer is often one
   of several. What must always hold is small and can be stated once.
3. **Endings are first-class.** Every operation is tested to its normal end and to every
   abnormal one.
4. **Instrumented builds are the default verdict.** A sanitizer report is a failure in
   every suite; a test that passes while the kernel log has a warning has not passed.
5. **Imperfect peers.** The emulated controller and the emulated peer must be able to be
   late, out of order, silent and wrong, each as a named, repeatable switch.
6. **Assert on both sides of every boundary.** What the upper layer was told, and what the
   lower layer actually did.
7. **Deterministic first, random second.** Each case replays exactly; a random walk over
   the same steps and endings runs beside it and saves its seed.
8. **Every field defect becomes a profile or a case.** A bug report is not closed by the
   fix but by the test that fails without it. This project already works that way.
9. **One matrix.** The same suites on mainline, the development tree and every stable line.

## 6. What exists already, and what would have to be built

*Exists:* BlueZ's testers and the emulated controller; its unit tests; the test runner that
boots a kernel in a virtual machine; the newer functional tests with two virtual hosts; the
list's CI on every patch; syzbot for the socket interfaces; the kernel's sanitizers and
fault injection. From this project: the hold-like hook used for BT-9's test, the userspace
USB controller, the leak and lock sweeps for the mesh path, the tester comparison across
stable lines.

*To build, smallest first:*
1. leak and sanitizer checking as part of every existing tester verdict (suite B's first
   tenth; days);
2. the stable-line run for every release candidate (suite E; machine time and a script the
   project has in pieces);
3. the hold gate in the emulator and the step lists (suite A; the core piece, weeks);
4. the endings and the generator (suites A and B complete);
5. the error table (suite C; it is also documentation the interfaces lack);
6. the userspace USB controller as a maintained tool (suite D);
7. the scripted peer and the combined virtual machine (suite F; the largest, and the one
   that needs agreement between three projects);
8. the hardware shelf (suite G; money and a place, not code).

## 7. What tests cannot do, and a first step

- **Firmware that nobody can read** stays outside everything but suite G, and G sees only
  the devices on the shelf.
- **Design choices** are not defects: that a newly connected headset does not become the
  default output (U11) passes any test until someone decides what should happen.
- **A generator finds what its invariants can express.** "Audio is flowing" needs a real
  signal check; "the user was told" needs a desktop.
- **Cost.** Suites A and B multiply cases by steps and endings; they need a budget and a
  way to run the changed part first.

*A first step that fits this project.* Items 1 and 2 of section 6 are within its reach now
and are contributions in the project's own style: a patch to the test runner that fails a
case on a leak or a sanitizer report, with the count of what it finds on the current tree,
and a published table of the testers on each stable release candidate. Either would be
welcome upstream because it gives the maintainers results and asks nothing of them. The
hold gate is the piece worth proposing as a design on the list before writing it, with
BT-9's test and the SCO reuse test as the two examples of what it turns from a week's work
into a generated case.

*Complete. Written on 2026-11-23; not edited afterwards.*
