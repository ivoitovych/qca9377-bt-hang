# Test classes, and mocking the external tools — assessing two proposals

**Written:** 2026-08-13T15:17Z
**Covers:** the tree after UT-07 + CS-02/03/05 landed (coverage 28.5%)
**Origin:** two proposals from the repository owner, assessed here
**Status of items:** [`reviews/README.md`](README.md), IDs `TC-nn`

The owner proposed two things: (1) distinguish the classes of test — unit,
integration, whole-suite — and decide which this project actually needs; and
(2) parameterise the code's use of external tools, defaulting to the real
tools, so tests can substitute mocks that exercise exactly the behaviour a
given test needs.

**Both are sound. The second is the design decision CS-08 was waiting on.**
The motivation behind both — that a bug in our tooling must never contaminate
the evidence this project exists to collect — is not a new constraint being
added; it is this project's founding constraint, already embodied in house
rule 4 and already violated twice in ways the record keeps: the published
45–66 s stage-2 figure was produced by our own watchdog's resets, and
`bt-boot-provenance` printed an inverted `hci` column for its whole life.
Both were tool bugs contaminating conclusions. The proposals aim at exactly
that class.

---

## 1. The mock proposal (TC-01)

### What already exists, so the new work is named precisely

The repository has converged, piecemeal, on three forms of the same idea:

| Form | Instance | Mocks |
|---|---|---|
| Fixture seam | `journal.sh` / `BT_JOURNAL_FIXTURE` | the **data** a query returns |
| PATH stubs | the sandbox `trial()` helper (`hciconfig`, `bt-incident` stubs) | the **tool** itself |
| Path overrides | `BT_STATE`, `BT_LIBDIR`, `BT_TRACE_DIR`, `BT_MODE_STAMP` | the **filesystem** a tool reads |

The proposal generalises this, and the generalisation is what category C
(1031 lines blocked on device access) needs. Two design points matter:

**Mock the data for queries; mock the tool for actions — and actions need a
spy.** `journalctl` is a query: a fixture file is the right mock, and the test
asserts on output. `hciconfig reset`, USB unbind, `systemctl restart` are
actions: the right mock is an executable stub that **records its invocation**
to a log the test reads afterwards. For `bin/bt-hang-watchdog` — 183 lines
deciding whether to intervene on a live controller, still 0% — the assertion
that matters is *"given this journal, the watchdog decides to intervene (or
holds off), escalates in this order, and stops when the controller answers"*.
The decision is testable; the actuation is not, and must not be. A spy log is
what separates them.

**A mock is a claim about the real tool's interface, and such claims rot.**
The provenance fixture originally lacked `--list-boots`'s header row, so the
fixture-driven tests happily passed while the real tool crashed on real
output; main found that bug by reading, not testing. Mocks must be built from
captured real output, and each fixture should say (in a comment) what
invocation produced its shape. Where the real tool is available at test time,
a cheap contract check — "does the real tool still emit the shape the fixture
claims?" — is worth having in CI.

### Recommended form

A `tools/lib/device.sh` sibling of `journal.sh`: wrapper functions for the
side-effecting tools (`bt_hciconfig`, `bt_systemctl`, `bt_usb_unbind`, …) that
default to the real commands. When `BT_TOOL_STUBS` names a directory, each
wrapper instead runs `$BT_TOOL_STUBS/<tool>` if present — an executable the
test wrote, scripted to exit as the test needs — and every invocation is
appended to `$BT_TOOL_STUBS/spy.log` regardless. Same policing invariant as
the journal seam: a converted tool must not regain a direct call.

## 2. The test-classes proposal (TC-02)

Naming the classes clarifies what exists and what is genuinely missing:

| Class | In this repository | State |
|---|---|---|
| Unit | awk fixture harness (17 cases, 3 libraries) | exists |
| Tool-level (integration) | whole-tool sections over fixtures/seams | exists, growing |
| Suite-of-parts | `bt-trial` lifecycle in the sandbox | exists |
| **System** | install → verify → uninstall → verify-restored, `--apply`, for real | **missing** |
| Hardware-in-loop | driving the real controller | correctly out of scope |

The one genuinely missing class is the **system round trip**, and today's
session accidentally proved it viable: a mutation experiment executed a real
install in the CI container, and `uninstall.sh --apply` restored it
completely. Done deliberately it is: `install.sh --apply` →
`bt-verify-install` → `uninstall.sh --apply` → `verify-restored.sh`, asserting
each gate. That exercises the ~40% of `install.sh` and ~70% of `uninstall.sh`
the dry run cannot reach — the `run()` apply branch, the generated drop-ins,
the removal loop.

**It must be impossible to run on the investigation machine by accident.**
Gate: run only when `BT_SYSTEM_TEST=1` is set explicitly AND no existing
install is present (`/usr/local/share/qca9377-bt-hang` absent) AND not run as
part of the default suite. In CI it runs as a separate workflow step; on a
developer machine it never runs unasked. The investigation machine has a live
deployment and a live evidence tree; a test that reinstalls the workarounds
there is the contamination this whole effort exists to prevent.

Do we need every class? No — hardware-in-loop stays out (category D's
argument/refusal paths are already covered), and no new framework is needed
for any of this: the classes differ in *what is mocked and what is asserted*,
not in harness machinery.

## 3. Items

| ID | Item | Absorbs |
|---|---|---|
| TC-01 | `tools/lib/device.sh`: action-tool seam with spy log; convert `bt-hang-watchdog` first | settles the design of CS-08 |
| TC-02 | CI-gated system round trip (`--apply` both ways, verified both ways) | new |
| TC-03 | Fixture provenance comments + CI contract check that real tools still emit the fixture shapes | new, small |
