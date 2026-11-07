# U29 — the second outside reviewer's third message

*Received 2026-11-07, after the checked answer of the sixth reviewer
(`2026-11-07T1415Z-u29-source-investigation-reviewer-6-verbatim.md`) and the first emulator
test. Written before the reviewer had seen the second test's result
(`results/u29-emulator-2026-11-07/` §2). The text is kept as received, except for the
reviewer's tooling marks, which `scripts/review-text-clean.py` removes.*

*No finding was added or changed. What it adds, checked against the record:*

- §2's two master commits are the ones checked on 2026-11-07 (`53db78000`, first in 5.83;
  `17a227b77`, first in 5.86). The point taken into U29: evaluate master's
  `Device1.Disconnected` reason before proposing any new D-Bus API. It is transient, and for
  U29's 0x05 it would not fire [inferred from the kernel's 0x06-only rule].
- §4's acceptance matrix, against test 2 as run:
  - **Covered:** flags 0x18 (arms B, D, F); discoverable flags 0x1A (C); advertising stopping
    (every arm, removal 29.8 to 30.4 s after the last report); the no-advertising control (A).
  - **Not covered:** an advertisement with no Flags field; a paired or trusted device; expiry
    during an active connection or pairing.

  These are regression checks for a lifetime *change*, not for the behaviour, which is
  reproduced.
- The storage-file point is already recorded as inferred, not observed.

---

Reviewer 6 has substantially strengthened the U29 investigation, and the maintainer's independent checks have corrected several important details. Most significantly, the first experiment has moved the A2DP finding from source-code analysis to a reproduced regression with a tested upstream fix.

## 1. The BlueZ backport is now experimentally established

QEMU regression results — reported and independently checked by the project maintainer

Original Ubuntu BlueZ 5.72

# 10/10

`br-connection-unknown`

With upstream `a6ac17f0e393`

# 10/10

`br-connection-refused`

The fresh-ACL control returned `br-connection-unknown` in both builds, 5/5 times each.

That is exactly the result predicted by the upstream [A2DP fix `a6ac17f0e393`](https://github.com/bluez/bluez/commit/a6ac17f0e3932d6b07ced87e41fe7a108fe55149), whose commit message describes essentially the same multi-profile error-reporting problem.

The fresh-ACL control is especially valuable. It demonstrates the fix's boundary: it preserves `ECONNREFUSED`; it does not solve authentication diagnosis generally.

## 2. The most important new discovery is about BlueZ master

Reviewer 6's claim that BlueZ master ignores authentication-related disconnection reasons is outdated.

I independently checked these two commits:

- [BlueZ `53db78000`](https://github.com/bluez/bluez/commit/53db78000e3e8d9a961363ee2a1aac65e16a7446) introduces `Device1.Disconnected(reason, message)`, including `org.bluez.Reason.Authentication`, emitted before the `Connected` property changes.
- [BlueZ `17a227b77`](https://github.com/bluez/bluez/commit/17a227b77b4ebcb3bd83cc2444f5c3ebd09a174c) adds authentication-failure retry limits and backoff for automatic reconnections.

This changes how I would approach the proposed continuation of the 2021 authentication-failure RFC.

I would not propose a new D-Bus API until evaluating the existing `Disconnected` signal. It may already provide some of the information that the old RFC wanted to expose.

However, it does not fully address U29:

- The existing signal represents a disconnection event, not persistent per-device authentication status.
- The reported kernel path marks authentication-related disconnections for HCI `0x06`, while the headset returned `0x05`.
- A GNOME application launched after the event would not recover that event from a transient signal.

So Reviewer 6's suggestion of persistent error state still has merit, but it now needs to be framed as a possible extension to existing functionality, rather than an entirely missing authentication-reporting mechanism.

The related [BlueZ issue #433](https://github.com/bluez/bluez/issues/433) also establishes an important security constraint: automatically erasing a bond in response to failed authentication can let an impersonating device disrupt legitimate pairings. The right interface should inform the user and offer recovery, not silently discard keys.

## 3. The two findings I would now treat as separate contribution tracks

Track A — BlueZ temporary-device lifetime. The journal evidence is compelling: repeated non-discoverable LE advertisements refresh a temporary device that GNOME still presents as set-up capable. The pending QEMU test is primarily needed to validate a safe fix, not merely to establish that the original incident happened.

Track B — GNOME's silent pairing failures. This is independently actionable. `AuthenticationRejected` reaches the application, but the UI only emits a warning. The exact Ubuntu packaging delta has now been checked, removing an important uncertainty. A narrow, user-visible failure message could be developed without waiting for the broader BlueZ authentication API work.

One UX detail matters: `AuthenticationRejected` covers multiple underlying reasons. The interface should not state as fact that the headset is not in pairing mode unless it has evidence for that particular cause.

## 4. What I would require from test 2

The outstanding temporary-device experiment should cover more than the easy case of an advertisement with no Flags field.

I would retain this acceptance matrix:

| Scenario                                     | Required check                                             |
| -------------------------------------------- | ---------------------------------------------------------- |
| Non-discoverable advertisement, Flags `0x18` | Existing temporary device is not kept alive indefinitely   |
| Advertisement with no Flags field            | Same lifetime behavior, with the distinction recorded      |
| Discoverable advertisement                   | Normal temporary-device refresh remains intact             |
| Paired or trusted device                     | Bearer tracking and legitimate reconnection are not broken |
| Active connection or pairing                 | No premature expiry                                        |
| Advertising stops                            | `InterfacesRemoved` occurs after the configured timeout    |

The exact `0x18` case matters because U29 also exercised the BR/EDR-support inference path. An emulator reproduction using only advertisements without Flags would be useful but incomplete.

I would also treat the storage-file question as unresolved. The maintainer has shown why Reviewer 6's claimed error is wrong, but without a storage-state observation we should not claim that a failed click definitely persisted an `info` file.

## Overall assessment

The investigation now has three different evidence levels:

- Reproduced: the A2DP error transformation and upstream backport behavior.
- Strongly established from original logs and exact source: the temporary-device lifetime mechanism and GNOME's silent `Pair()` failure.
- Still a design question: how BlueZ should expose authentication failures persistently and how GNOME should present recovery options.

I agree with the maintainer's approach of keeping test 2 running independently, recording its results, and making no upstream submissions yet.

The key next decision should be based on that second result: whether the proposed lifetime correction can be made without compromising legitimate dual-mode discovery and pairing behavior. That is where another carefully designed test could prevent an otherwise plausible patch from introducing a regression.
