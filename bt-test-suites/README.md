# bt-test-suites: comprehensive testing for the Linux Bluetooth stack (sub-project, design stage)

**Started 2026-11-26.** This directory may become a project of its own one day. Until then it lives here, beside the
defects that motivate it.

## Why

Nearly every defect this project found in Linux Bluetooth was found by hand, on one laptop, in daily use. The defects
are in the kernel, `bluetoothd`, the sound server, its session policy and the desktop.
- **The idea behind this sub-project:** that each subsystem lacks a test suite comprehensive enough for that, or
  that the suites it has cover too little. In particular:
  - reliability and randomised tests;
  - dynamic, randomised load;
  - the whole stack run together, under emulation, virtual machines or containers, in conditions as harsh as real
    use.
- **What the design measured:**
  - the stack is tested one layer at a time and mostly on the expected path ("one operation, one answer");
  - the defects found lie between two events, at the end of an object's life, on error paths, in the transport
    driver below the emulated controller, and between layers.

## What is here

| file | what it is |
|---|---|
| `design/part-1-the-suites-that-would-have-caught-these-defects.md` | The project's defects sorted by the test that would have caught each. Seven suites, A to G; about 30 of 40 code defects need only emulation and instrumented builds. |
| `design/part-2-the-whole-subsystem.md` | Tests derived from a map of the whole subsystem, not from its history. Six inventories; five generators, including a randomised long-sequence walker; invariants as the verdict; coverage reported per inventory. |
| `design/part-3-measured-inventories.md` | The inventories counted in BlueZ master and bluetooth-next of 2026-11-23. It corrects parts 1 and 2, and lists what upstream already has, what is missing and the first contributions. |

All three were written by an outside reviewer on 2026-11-23 from this project's record and the upstream sources, and
moved here unchanged except for links between them. **They are a design, not a result.** Nothing in them has been
built or run, and their counts are textual and approximate (part 3 says how each was made).

## The idea in three lines

1. **Test the transitions and the endings, not only the operations:** a second event during the first operation; the
   object's end at every step (power-off, removal, peer loss, process death, suspend); every failure the lower layer
   may return.
2. **Generate the cases from inventories extracted from the source** (commands, states, endings, configurations,
   peers, failures), and judge them by a few invariants, not by expected outputs written per case.
3. **Report coverage against those inventories,** so that what is not tested is visible by name.

## Where upstream already is (part 3)

**Already there in BlueZ:**
- hooks to stop a procedure at a chosen command or event;
- simulated time (`emulator/timetravel.c`);
- a multi-machine functional suite with real kernels and daemons (`test/functional`, since September 2026), able to
  run on emulation or on real controllers;
- the kernel testers' memory-error and lock checkers.

**Missing:**
- generation and accounting;
- the leak detector and fault injection in the test kernel configuration;
- a scripted failing answer in the emulator;
- a quirk switch in the virtual driver;
- 19 command handlers, mostly the link-policy group (sniff mode, role switch);
- the sound server in the functional machines;
- an emulated USB controller.

## Possible first steps (part 3, section 9; none started)

- a coverage table over the existing testers, with the script that makes it, replacing BlueZ's outdated
  `doc/test-coverage.txt`;
- two functional tests in upstream's own form: the voice-link set-up interrupted by disconnect, and a profile
  connection interrupted by power-off;
- emulation of sniff mode, role switch and link policy;
- management-tester cases for `CANCEL_PAIR_DEVICE` and `SET_WIDEBAND_SPEECH`.

Each is small, checkable on upstream's machinery, and useful even if the larger design is never adopted. Whether and
when to start is the operator's decision.

## Relation to the rest of the project

- **The defect ids in the design** (`BT-n`, `CO-nn`, `U-n`, `M-n`) are this project's: `docs/issues.md` and
  `contributions/README.md`.
- **The CO-38 suite runs** (`contributions/CO-38-read-adv-features-hidden-instances/send-20261123/evidence/`) are the
  nearest existing piece of part 2's "stable-line matrix": base against patched, case by case, on eight trees.
- **The btusb emulation of 2026-11-13** (`results/bt17-emulation-2026-11-13/`) is a first instance of suite D: the
  real driver against an emulated USB device.
