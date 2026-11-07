# U29 — the second outside reviewer's fourth message: both tracks, and a draft GNOME report

*Received 2026-11-07. The text is kept as received. It is an opinion, recorded for the project
author, who writes and files any report.*

*What came of it, 2026-11-07:*
- Both tracks were started, locally:
  - a candidate BlueZ lifetime patch on master `a80671987`, with the regression matrix in
    QEMU;
  - a runtime check of the silent branch on gnome-bluetooth master `adf070af`, plus a survey of
    issues #18 and #91.
- Nothing is filed or sent. The draft below is the reviewer's starting point for the author,
  not a report text.
- A fact used in its draft, checked here: the `create_callback()` failure branch is unchanged on
  gnome-bluetooth master `adf070af` (`lib/bluetooth-settings-widget.c:903`).

---

I recommend both, pursued in parallel, with different levels of authorization.
The two QEMU experiments have now reproduced the essential U29 behaviors. The evidence is strong enough to justify an upstream-quality GNOME issue report and a local BlueZ patch candidate. It is not yet a reason to submit either one upstream.
My preferred order is:

1. GNOME: prepare the silent-pairing-failure report now. This is a demonstrated usability defect, independent of the BlueZ device-lifetime problem, and it also covers the same failure-handling path implicated in U13.
2. BlueZ: authorize a local candidate patch and regression tests for temporary-device lifetime, including the three missing controls. Review the patch's consequences before approving submission.

I would keep the tested A2DP backport, `a6ac17f0e393`, as a separate, already-validated contribution candidate. It corrects an error message, but does not diagnose a rejected key.
One procedural concern: GNOME asks for reports against its two most recent stable releases or current development version. The original hardware reproduction is on GNOME 46, so the report should also establish that the faulty branch remains in current upstream source, and preferably demonstrate it in a current build.
GNOME Project Handbook

Proposed instructions to the project maintainer
YES — proceed with both tracks, in parallel.
GNOME track: Prepare an upstream-quality issue report for the silent pairing failure. Cover U29, and include U13 if its evidence supports the same failure-handling defect. Verify existing GNOME issues #18 and #91 before proposing a new one. Keep the scope narrow: `Device1.Pair()` fails, but Bluetooth Settings gives the user no visible explanation.
Please gather the smallest relevant, sanitized evidence excerpt and confirm whether the failure-handling branch remains present in current upstream code. Do not file the report yet; I want to review its final text.
BlueZ track: Prepare a minimal local candidate patch for the temporary-device lifetime problem. Run it against the successful U29 reproduction and the remaining regression cases: advertisements without Flags, paired/trusted devices, and devices with an active connection or pairing operation.
Please also preserve the existing tests for flags `0x18`, discoverable advertisements, and broadcasts stopping. Pay particular attention to bearer selection, BR/EDR inference, discovery filters, and temporary-device cleanup. The patch should not alter the lifetime of legitimate devices as an unintended side effect.
Keep the original and patched results separately reproducible. Record the exact source revision, patch, test commands, results, and limitations.
No changes to the laptop's working Bluetooth stack. No upstream issues, merge requests, patch emails, or other external submissions without my separate explicit YES.
Once both drafts and the local tests are ready, we will review them and decide independently which contributions are worth submitting.
GNOME issue — initial draft
This is the report I would start from, rather than making the maintainer invent a new description of an already-investigated defect.
Bluetooth Settings silently ignores pairing failures returned by Device1.Pair()
Observed behavior
When setting up a Bluetooth device, GNOME Bluetooth Settings can receive a failed `org.bluez.Device1.Pair()` response without displaying any error or explanation to the user.
In a recorded incident on GNOME Bluetooth 46.0 (`46.0-1ubuntu1` on Ubuntu 24.04), a Sennheiser MOMENTUM 4 headset was listed as "Not Set Up". Clicking the device initiated pairing, but the headset rejected the attempt.
Ten consecutive pairing attempts returned:
`org.bluez.Error.AuthenticationRejected`
For every attempt, the pairing activity ended and the row returned to "Not Set Up". No error message, notification, or recovery guidance appeared in the interface. The failure was visible only in the journal.
Expected behavior
Bluetooth Settings should provide visible, non-intrusive feedback when pairing fails, explaining that the setup did not succeed and suggesting an appropriate next action where the error provides sufficient information.
For example:
"Could not pair with ‘MOMENTUM 4’. Check that the device is ready to pair and try again."
The message should not assume that `AuthenticationRejected` necessarily means the device is outside pairing mode: several underlying Bluetooth errors can produce that D-Bus result.
User-initiated cancellations should remain silent.
Source-code analysis
In gnome-bluetooth's `lib/bluetooth-settings-widget.c`, `create_callback()` receives the failure from `bluetooth_client_setup_device_finish()`.
The failure-handling branches for `AuthenticationFailed`, `AuthenticationCanceled`, and other errors contain unfinished error-reporting paths. The fallback logs a `g_warning()` but presents no user-visible error.
The behavior dates back to the introduction of the Settings widget in 2013. It was revisited in commit `2b8cf369` in 2020, which explicitly prepared the code for future error reporting.
The Ubuntu `46.0-1ubuntu1` changes do not modify this failure-handling code. A source review of the upstream development tree also found the branch still present.
Reproduction and verification
The hardware incident was recorded with BlueZ debug logging and GNOME's failure messages. The BlueZ response was traced from HCI status `0x18` through `MGMT_STATUS_REJECTED` to `org.bluez.Error.AuthenticationRejected`.
A deterministic UI regression test should substitute a BlueZ `Device1` implementation whose `Pair()` method returns `AuthenticationRejected`, then verify that a visible error is presented. A separate `AuthenticationFailed` case should exercise the corresponding branch.
The original reproduction used GNOME 46. A current-build reproduction would help confirm the runtime behavior on a supported GNOME release.
Scope
This report concerns missing feedback when a pairing request fails.
Whether BlueZ should list a non-discoverable temporary device is a separate issue. Likewise, the accuracy of BR/EDR connection-error names is a separate BlueZ concern.
Related work
Potentially related GNOME tracking issues include gnome-bluetooth #18 and #91. Their current status and possible overlap should be checked before filing a duplicate report.
The remaining BlueZ work should now concentrate on proving the safety of the proposed correction, not reproducing U29 yet again. The reproduction has already succeeded.
I would also keep the one-line BlueZ emulator correction as a separate small contribution, since it fixes a test-infrastructure behavior and may be useful regardless of what happens to the U29 product-level fixes.
