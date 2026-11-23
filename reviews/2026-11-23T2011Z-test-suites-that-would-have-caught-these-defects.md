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

