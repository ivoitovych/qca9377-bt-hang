# U29 — the second outside reviewer's follow-up

*Received 2026-11-07 in answer to the checked first answer
(`2026-11-07T1341Z-u29-source-investigation-reviewer-2-verbatim.md`). Kept as received; it
carried no tooling marks. It adds no new technical claim; it agrees with the checks and sets an
order for the next steps. The last paragraph's CI state is as of the reviewer's message: the
access audit of `d0edec3` finished green afterwards (run `42378454320`).*

---

This is a valuable follow-up. The maintainer has closed the most important uncertainty in my investigation: the exact origin of `-EAGAIN` in U29 is now supported by the historical bluetoothd journal, rather than merely inferred from the BlueZ source.
The confirmed connection-error chain

```
HCI Authentication Failure (0x05)
    ↓
Kernel / L2CAP connection failure
    ↓
~100 ms later: socket reports ECONNREFUSED (111)
    ↓
BlueZ 5.72 AVDTP receives ECONNREFUSED
    ↓
A2DP error_to_errno()
    converts ECONNREFUSED → -EAGAIN (11)
    ↓
device_profile_connected()
    returns the final profile failure
    ↓
btd_error_bredr_conn_from_errno(-EAGAIN)
    ↓
br-connection-unknown
```

The distinction between the original HCI authentication status and the subsequent socket error matters. It explains how an authentication failure can eventually appear as a connection refusal without contradicting the kernel's `bt_to_errno(0x05) = EACCES` mapping.
The upstream commit `a6ac17f0e393` preserves `ECONNREFUSED`, so this is now a strong, evidence-supported backport candidate, rather than just a plausible match.
Two other useful corrections
The maintainer's observation that GNOME only shows the row once the device has a name is an important qualification to my earlier description of its listing rule.
And the conclusion about the 30-second timeout remains unchanged: that behavior is intentional, whereas the repeated refresh from non-discoverable advertisements is a separate usability concern.
What I would prioritize next

1. Backport validation: apply `a6ac17f0e393` to the exact Ubuntu-patched BlueZ 5.72 tree and verify the changed error with a controlled regression test.
2. GNOME's silent pairing failure: inspect the Ubuntu `46.0-1ubuntu1` delta, then create a test that supplies `AuthenticationRejected` and verifies visible feedback.
3. The misleading setup row: reproduce the non-discoverable advertisement/timer interaction in BlueZ's emulator before proposing a lifetime change.

I would not expand the investigation into the controller, firmware or `btusb` without new evidence implicating those components.
One final distinction: the connection-error reporting is already fixed upstream; U29 as a whole is not. GNOME's silent failures and BlueZ's setup-readiness behavior remain separate questions.
The recorded state is also clear: `d0edec3` contains the saved, checked investigation; the main CI checks passed, while the latest push's access audit was still running at the last reported observation. Nothing was submitted upstream.
This is a solid result from the independent-review process: the source investigation produced a specific historical fix, and the maintainer independently confirmed its mechanism against the original incident logs.
