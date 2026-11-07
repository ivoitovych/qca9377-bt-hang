# gnome-bluetooth: a failed `Pair()` shows nothing — current master, and open MR !137

Run 2026-11-07 by a separate worker; the checks marked **[checked]** were repeated here against
the logs and screenshots.

**Build.**
- Source: gnome-bluetooth master `adf070af` (2026-10-26, project version 47.1).
- Image: `fedora:latest` = Fedora 45 (GTK 4.24.1, libadwaita 1.10.0, python3-dbusmock 0.38.0).
- Environment: a private system and session bus with dbusmock's `bluez5` template, and Xvfb. No
  host bus, no host Bluetooth.
- Harness: `tests/widget-harness.c` puts the real `BluetoothSettingsWidget` in a window.
  `tests/pair-failure-test.py` overrides `Device1.Pair` to raise the given error, then activates
  the device row: `start_pairing()` → `bluetooth_client_setup_device()` → `create_callback()`.
- Recorded: the widget tree (dialogs, toasts, banners), the row label, and screenshots.

**Result.**

| error from `Pair()` | master `adf070af` | master + MR !137 (applied unedited) |
|---|---|---|
| `AuthenticationRejected` (U29) | nothing on screen; one `g_warning` "Setting up … failed: …AuthenticationRejected" | **nothing on screen**; the same `g_warning` |
| `AuthenticationFailed` (U13) | nothing on screen, nothing logged | toast "Unable to securely pair with “My Phone”" |
| `AuthenticationCanceled` | nothing on screen, nothing logged | toast "Unable to complete pairing process with “My Phone”" |

The row reads "Not Set Up" before and after in every case. No dialog or banner appeared.

**[checked]**
- Rejected on master: one "Setting up" line in `runs/out/AuthenticationRejected.stderr.log`;
  Failed: none.
- Every `HARNESS SUMMARY` on master has 0 dialogs, 0 toasts and 0 banners.
- With !137, the Rejected summary after the attempt has `ToastWidgets=0`, and the warning is
  still there. The Failed and Canceled summaries have `ToastWidgets=1` with the texts above.
- The toast counter is proven by `control-toast` (a toast added by the harness is counted).
- The `AuthenticationFailed-after.png` screenshots show the row unchanged on master, and the
  toast with !137.

**MR !137** ("settings-widget: show error toast when authentication fails", Erik Duxstad, opened
2022-06-20, rebased 2025-02-23, open):
- The diff is `src/mr-137.diff`, downloaded unedited. It applies cleanly
  (`runs/build-mr137.log`).
- It adds toasts in the `AuthenticationFailed` and `AuthenticationCanceled` branches. It leaves
  the `else` branch, which handles `AuthenticationRejected`, with `//FIXME show an error?`.
- **[inferred]** A NULL check is missing: `g_object_get()` runs on the result of
  `device_from_path()`, which is NULL if the device vanished.

**Edge cases on !137** (`runs/edge/`, `tests/pair-edge-test.py`, 3 runs each, every run exit 0):
- **Device removed while `Pair()` is pending.** The mock removes the device, flushes
  `InterfacesRemoved`, then returns the error.
  - With !137: `GLib-GObject-CRITICAL **: g_object_get: assertion 'G_IS_OBJECT (object)' failed`
    in 6 of 6 runs, for both `AuthenticationFailed` and `AuthenticationRejected`. The Failed
    toast then reads "Unable to securely pair", without the name.
  - On master: no CRITICAL, 0 of 6. **[checked]**
  - Not a crash in these runs. gnome-bluetooth's own integration test runs with
    `fatal_warnings`, where a CRITICAL would fail it [inferred, not run].
- **User presses Cancel in the pairing dialog.**
  - The widget answers the agent with `org.bluez.Error.Canceled`, and `Pair()` then returns
    whatever BlueZ chooses.
  - With !137, a returned `AuthenticationCanceled` shows "Unable to complete pairing process
    with “My Phone”" after a deliberate cancel. **[checked]** A returned `AuthenticationFailed`
    shows "Unable to securely pair with “My Phone”".
  - Which status real BlueZ returns after a declined confirmation was not checked.

**Upstream state, read 2026-11-07 through GitLab's public API:**
- gnome-bluetooth #18, "Show error when pairing or connecting fails", has been open since 2009.
- The two earlier attempts, !37 (2020) and !135 (2022), were reviewed by the maintainer ("Functional
  first pass"; split it up) and closed by their author when !137 replaced them.
- !137 had review comments in 2022. The author answered them in 2025, with no maintainer reply
  since.

**Not here:** the screenshots (binary), the container build logs, and the fetched GitLab JSON and
handbook pages (they carry contributors' details). All stay with checksums in `SHA256SUMS` under
`/root/exp/agent-work/u29-g1-gnome-pairing-feedback/runs/`; and the pairing-spinner phase (the
mock fails at once). No real BlueZ was used.

Run: `scripts/build.sh`, `scripts/run.sh`; with !137: `scripts/build-mr137.sh`, `scripts/run-mr137.sh mr137 out-mr137 AuthenticationRejected,AuthenticationFailed,AuthenticationCanceled 1`.
