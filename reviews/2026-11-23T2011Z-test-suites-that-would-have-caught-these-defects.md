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

