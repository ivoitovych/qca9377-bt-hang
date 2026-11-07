# U29 source investigation — the second outside reviewer's answer

*Received 2026-11-07 in answer to `2026-11-07T1218Z-u29-source-investigation-task.md`. The text
is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes: tracking parameters in links, favicon lines with their
site labels, and HTML space entities.*

*No finding was added or changed. What we checked on 2026-11-07, and what holds:*

- **Item 3, the strongest finding, confirmed in the log.** At each of the four desktop connects
  (09:38:54, 09:39:38, 09:40:13, 09:41:21) bluetoothd logged
  `avdtp.c:avdtp_connect_cb() connect to <headset>: Connection refused (111)`, then
  `a2dp-sink … disconnected (-11)` (once `Connection reset by peer (104)`, 09:40:27, also -11):
  `journalctl -o short-iso-precise _COMM=bluetoothd --since "2026-11-07 09:38:50" --until
  "2026-11-07 09:41:30" --grep "avdtp|a2dp|connect_cb|refused|profile_connected|Unable|error"`.
  The running tree's `profiles/audio/a2dp.c:296-318` `error_to_errno()` passes only
  `EHOSTDOWN`, `ECONNABORTED` and `EBADE`; `ECONNREFUSED` becomes `-EAGAIN`, which
  `src/error.c:176` maps to `br-connection-unknown`. Upstream `a6ac17f0e393` (2024-08-21,
  first in 5.78) adds `case ECONNREFUSED:`, and with it `src/error.c:166-167` would answer
  `br-connection-refused`.
- **How the authentication failure becomes `ECONNREFUSED`** (the step the reviewer left open),
  read in `cache/ubuntu-7.0.0-42`: `l2cap_security_cfm()` (`net/bluetooth/l2cap_core.c:7697-7701`)
  arms `L2CAP_DISC_TIMEOUT` (100 ms) for a channel in `BT_CONNECT` when security failed, and
  `l2cap_chan_timeout()` (l.430-432) closes it with `ECONNREFUSED`. The timing agrees: the
  second `Auth Complete` failure at 09:38:54.337, the refusal at 09:38:54.442.
- **Item 1** holds in the running tree: `src/adapter.c:7291` `device_update_last_seen()` before
  the discoverable drop (l.7320-7325); the BR/EDR refresh at l.7299-7304 for flags without
  `EIR_BREDR_UNSUP` (the headset's `0x18` has no `0x04`); `device_set_rssi*()` only after the
  drop (l.7336-7338), so `RSSI` is not updated by those reports.
- **Item 2:** kernel `mgmt.c:244` maps HCI `0x18` to `MGMT_STATUS_REJECTED`. gnome-bluetooth
  46.0 `lib/bluetooth-settings-row.c` `label_might_change()` reads "Not Set Up" for
  `!paired && !trusted`, as quoted; the row is also visible only once the device has a name
  (`name_to_visible`), which the answer does not mention.
- **Commits:** all ten BlueZ commits and the four gnome-bluetooth commits exist with the subjects
  described (`cache/bluez-upstream` at `a80671987`, `cache/gnome-bluetooth-upstream`). Two dates
  are a few days out: `c53e232f` is 2020-07-17 and `0004eb06` 2023-08-17.
- **Not checked yet:** the Ubuntu delta of gnome-bluetooth `46.0-1ubuntu1`, and the emulator
  experiments of §7.

---

# U29 — Source-code investigation

Linux Bluetooth Bug Hunt · 7 November 2026

## Executive findings

The source examination already establishes two important results.

First, the BlueZ device-lifetime hypothesis is correct at the control-flow level. BlueZ 5.72 can refresh the lifetime of an existing temporary device from an LE advertisement that it subsequently rejects as non-discoverable. This is precisely the ordering described in the U29 brief.

Second, GNOME Bluetooth 46.0 contains an explicit unfinished error-reporting path. On failure, the pairing callback stops the setup operation but does not display the error. It logs a warning instead. This directly explains why repeated pairing failures can appear silent.

There is also an important distinction that affects a potential fix: the advertisement refreshes BlueZ's internal last-seen timestamp without necessarily updating the public D-Bus `RSSI` property. Therefore, a device can remain in GNOME's list without fresh signal-strength information being delivered to GNOME.

The investigation must keep three failures separate:

| Observable problem                                                | Primary component                              | Initial assessment                                                              |
| ----------------------------------------------------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------- |
| Non-discoverable headset remains available for setup              | BlueZ device discovery and lifetime management | Confirmed code behavior; defect classification needs care                       |
| Ten failed pairings produce no visible error                      | gnome-bluetooth pairing UI                     | Confirmed missing UI behavior                                                   |
| Stored-key authentication failure becomes `br-connection-unknown` | Kernel → BlueZ profiles → D-Bus                | Error mapping identified; exact errno propagation requires further verification |
| Row remains during a 19.4-second power-off                        | BlueZ temporary-device expiration              | Expected under the 30-second timeout                                            |

These are distinct contribution candidates. They should not be combined into one patch merely because they were exposed by the same headset incident.

## 1. Why the “Not Set Up” row survived

### The relevant BlueZ 5.72 execution path

Source-confirmed

BlueZ 5.72; Ubuntu function equivalence reported by project maintainer

The decisive source locations are:

- [`src/adapter.c`, `device_is_discoverable()` and `btd_adapter_device_found()`](https://github.com/bluez/bluez/blob/5.72/src/adapter.c): the existing-device branch updates `last_seen` before the later discoverability check.
- [`src/device.c`, `device_update_last_seen()`](https://github.com/bluez/bluez/blob/5.72/src/device.c): updates the timestamp and connectability state, then restarts the temporary-removal timer.
- [`src/device.c`, connection handling](https://github.com/bluez/bluez/blob/5.72/src/device.c): a connection clears the timer; the final disconnection restarts it.

This produces an asymmetric outcome: without an existing object, the non-discoverable advertisement is ignored. Once the headset creates an object through an incoming connection, similar advertisements can prolong that object's existence.

### GNOME's exact listing rule

The source shows that GNOME Settings does not independently decide whether an unpaired headset is currently discoverable.

In gnome-bluetooth 46.0, `BluetoothClient` imports `org.bluez.Device1` objects associated with the default adapter into its model. It does not require `Paired`, `Trusted`, `Connected`, or `RSSI` for inclusion. The settings widget then adds a row for each imported device. [`bluetooth-client.c`](https://github.com/GNOME/gnome-bluetooth/blob/46.0/lib/bluetooth-client.c) · [`bluetooth-settings-widget.c`](https://github.com/GNOME/gnome-bluetooth/blob/46.0/lib/bluetooth-settings-widget.c)

The row label is determined by a simple rule in [`bluetooth-settings-row.c`](https://github.com/GNOME/gnome-bluetooth/blob/46.0/lib/bluetooth-settings-row.c):

```
if (!self->paired && !self->trusted)
    gtk_label_set_text (GTK_LABEL (self->status), _("Not Set Up"));
```

Clicking such a row calls the pairing path; it does not first check LE discoverability. Thus the label means not paired or trusted, not available for pairing now.

An important contrast: [GNOME Shell 46.0](https://github.com/GNOME/gnome-shell/blob/46.0/js/ui/status/bluetooth.js) filters its quick-settings device list to `device.paired || device.trusted`. The unpaired U29 row therefore belongs to the Settings-panel behavior, not the Shell quick-settings list.

### One additional implication

In BlueZ 5.72, LE advertisements whose flags do not contain `EIR_BREDR_UNSUP` can also update the device's BR/EDR last-seen timestamp. U29's `0x18` flags satisfy that condition. This can make BR/EDR appear recently seen even without a BR/EDR inquiry response.

That does not prove that this affected U29's successful or failed pairing choices, but it is worth including in the emulator regression test. The distinction between advertised BR/EDR support and actual BR/EDR inquiry discoverability matters here.

Assessment: the lifetime mechanism is confirmed. Whether refreshing a known, non-discoverable device is incorrect for all device types is not established; a patch must preserve legitimately connected, paired, trusted and monitored devices.

### Why this behavior exists: the Git history

The history is unusually clear. It is not one accidental change; it is the interaction of several deliberately introduced behaviors.

| Date        | Introducing commit                                                                                                  | Original motivation                                                                                                                   |
| ----------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| 22 Mar 2014 | [`d8eed451`](https://github.com/bluez/bluez/commit/d8eed4517a16cb6c4d7115b65c5a37909d41211d) | Use non-discoverable LE reports to update already-known devices, without creating new device objects                                  |
| 15 Jul 2020 | [`def01de0`](https://github.com/bluez/bluez/commit/def01de02593afeb37d2d985ac7ee47cfa720cce) | Introduce a 30-second temporary-device timer, refreshed upon sightings, so long discovery sessions do not accumulate vanished devices |
| 23 Jul 2020 | [`c53e232f`](https://github.com/bluez/bluez/commit/c53e232f210a7171d767392a108c71e674d66c2f) | Give newly disconnected temporary devices a grace period rather than immediately deleting them                                        |
| 18 Aug 2023 | [`0004eb06`](https://github.com/bluez/bluez/commit/0004eb06d5d9a2f27521d9ce3b206d6f3f82c61e) | Prevent a temporary device from expiring while a connection attempt is underway                                                       |

The 2014 decision explains why BlueZ processes non-discoverable advertisements for existing objects. The 2020 timer explains why those reports can now prolong object lifetime.

This is a design interaction, not evidence of an obvious coding mistake. Both original changes served legitimate requirements. Their combination produces an undesirable setup experience for U29.

On master, [`393e81a`](https://github.com/bluez/bluez/commit/393e81a7473c636a6a00f49d9246e8a2e6d5674a), merged in September 2025, introduced `FilterDiscoverable`, defaulting to true. Its stated reason was compliance with Bluetooth GAP discovery semantics. It does not correct the early timer refresh for already-existing devices.

Two other master developments matter:

- [`9965f36`](https://github.com/bluez/bluez/commit/9965f36c6318e3a6f9879f5b0d842791a290e3ee), July 2026, restricts inference of BR/EDR support from LE advertising to public LE addresses. U29 uses a public address, so that fix would not eliminate the reported behavior.
- [`6afb6e7`](https://github.com/bluez/bluez/commit/6afb6e729270a3e85f020c724baae621a413fc8e), October 2026, introduces a `Connectable` D-Bus property reflecting advertising connectability. Connectable is not the same as discoverable or pairable. Its existence helps clients in other situations but is insufficient to identify the U29 state.

My preferred first experiment is to inject a temporary device, then supply non-discoverable LE reports at intervals shorter than 30 seconds using an isolated virtual controller. Verify that `InterfacesRemoved` never arrives while the reports continue, but does arrive after they cease. Repeat with a paired device, an active BR/EDR connection, and an advertisement monitor to define the permitted exceptions before considering a BlueZ change.

## 2. Silent `AuthenticationRejected` during pairing

### End-to-end source path

Source-confirmed for kernel and upstream BlueZ/GNOME 46.0; actual packet status from the project's capture summary

```
HCI Simple Pairing Complete: 0x18 (Pairing Not Allowed)
    ↓
Linux net/bluetooth/mgmt.c
    mgmt_status(0x18) → MGMT_STATUS_REJECTED (0x0b)
    ↓
BlueZ src/adapter.c
    bonding_attempt_complete() → bonding_complete()
    ↓
BlueZ src/device.c
    device_bonding_complete() → device_bonding_failed()
    new_authentication_return(MGMT_STATUS_REJECTED)
    → org.bluez.Error.AuthenticationRejected
    ↓
gnome-bluetooth lib/bluetooth-client.c
    device_pair_callback() → GTask error
    bluetooth_client_setup_device_finish() → FALSE
    ↓
gnome-bluetooth lib/bluetooth-settings-widget.c
    create_callback()
    → stop pairing UI, log warning, show no error
```

The critical mapping is in the [kernel's `mgmt_status_table`](https://github.com/torvalds/linux/blob/v7.0/net/bluetooth/mgmt.c), followed by [BlueZ's `new_authentication_return()`](https://github.com/bluez/bluez/blob/5.72/src/device.c).

In this BlueZ version, the pairing statuses have these user-visible D-Bus outcomes:

| MGMT status                                  | BlueZ D-Bus error        |
| -------------------------------------------- | ------------------------ |
| `REJECTED`, `BUSY`                           | `AuthenticationRejected` |
| `AUTH_FAILED` and otherwise unhandled errors | `AuthenticationFailed`   |
| `TIMEOUT`                                    | `AuthenticationTimeout`  |
| `CANCELLED`, `NO_RESOURCES`, `DISCONNECTED`  | `AuthenticationCanceled` |

These categories are broader than individual headset behaviors. In particular, `AuthenticationRejected` does not invariably mean that the user forgot to enable pairing mode.

### The GNOME history establishes why the error is silent

The relevant behavior was intentionally left unfinished long before GNOME 46.

- On 6 December 2013, [`5cb047b`](https://github.com/GNOME/gnome-bluetooth/commit/5cb047b799ada7bde396b0840f86fb7b74d87483) excluded user-cancelled authentication from failure warnings. The commit explicitly described a possible future dialog.
- Later, [`2b8cf36`](https://github.com/GNOME/gnome-bluetooth/commit/2b8cf369dd719aa61cebe803be6bc2d75b671b6b) separated `AuthenticationFailed`, `AuthenticationCanceled` and other errors, explaining that pairing errors should be better reported. It introduced the empty explanatory `FIXME` branches.
- On 20 September 2020, [`a6dec3f`](https://github.com/GNOME/gnome-bluetooth/commit/a6dec3fa118903ff40d437f495e804d6cb6b18a5) additionally ensured that a failed pairing closes the pairing dialog.

The historical code already had commented-out error-label operations. I found no evidence that the current settings widget once displayed a working error dialog that was later deliberately removed; the 2013 commit instead indicates an unfinished feature.

GNOME Shell's quick-settings menu follows a different operation: it connects or disconnects already paired/trusted devices and logs connection failures to the journal in [`js/ui/status/bluetooth.js`](https://github.com/GNOME/gnome-shell/blob/46.0/js/ui/status/bluetooth.js). It does not own the U29 `Pair()` setup flow.

### Suggested GNOME contribution

The smallest useful correction belongs in gnome-bluetooth's settings widget, not in the kernel or GNOME Shell. A failed `Pair()` should terminate the spinner and produce a visible, translated, non-blocking error message.

For `AuthenticationRejected`, a defensible message would be:

> Could not pair with MOMENTUM 4. Make sure the device is in pairing mode and try again.

The wording should not claim the exact cause from the generic status alone. Distinguish timeout and cancellation; avoid showing an error for deliberate user cancellation. A mock `BluetoothClient` that returns each D-Bus pairing error is sufficient to test this without the headset.

Confidence: high. Falsifier: an Ubuntu-specific change or a surrounding GNOME Settings component that actually displayed a notification during this failure. The recorded GNOME journal and observed silence support the finding, but the Ubuntu packaging delta still requires comparison.

## 3. The `br-connection-unknown` failure: a particularly important upstream match

Existing upstream fix found

I found a BlueZ commit that describes almost the exact U29 symptom, including the combination of HFP and A2DP profiles and the misleading `br-connection-unknown` result.

[`a6ac17f0e393` — “a2dp: Fix connection error message”](https://github.com/bluez/bluez/commit/a6ac17f0e3932d6b07ced87e41fe7a108fe55149), committed 21 August 2024.

Its commit message describes a phone that has forgotten its pairing, where A2DP alone can produce `br-connection-key-missing`, HFP alone produces `br-connection-refused`, but both profiles together produce `br-connection-unknown`. That is an exceptionally close match to U29.

The fix is only one line:

```
 case EHOSTDOWN:
 case ECONNABORTED:
 case EBADE:
+case ECONNREFUSED:
     return -perr;
 default:
     return -EAGAIN;
```

This change is not present in upstream BlueZ 5.72. In that version, [`profiles/audio/a2dp.c:298–317`](https://github.com/bluez/bluez/blob/5.72/profiles/audio/a2dp.c) translates `ECONNREFUSED` into `-EAGAIN`, which is later mapped to the generic unknown connection error.

That gives the following high-confidence reconstruction:

```
Headset refuses authentication with the stored key
    ↓
HCI: Authentication Failure (0x05)
    ↓
Kernel: connection/security failure
    ↓
AVDTP / A2DP connection attempt fails
    ↓
A2DP's error_to_errno()
    ECONNREFUSED → -EAGAIN       [BlueZ 5.72 behavior]
    ↓
device_profile_connected(..., -EAGAIN)
    final Connect() reply
    ↓
btd_error_bredr_conn_from_errno(-EAGAIN)
    ↓
org.bluez.Error.Failed: br-connection-unknown
```

The kernel-to-AVDTP exact intermediate errno still has to be proven from the captured event ordering; `ECONNREFUSED` is a plausible value and matches the historical bug report. The destructive A2DP conversion and final generic D-Bus mapping are confirmed in source.

### The kernel distinction matters

[`net/bluetooth/lib.c:66–90`](https://github.com/torvalds/linux/blob/v7.0/net/bluetooth/lib.c) maps:

| HCI error                     | Linux errno   | Meaning               |
| ----------------------------- | ------------- | --------------------- |
| `0x05` Authentication Failure | `EACCES` (13) | Authentication failed |
| `0x06` PIN or Key Missing     | `EBADE` (52)  | Key missing           |

The kernel's [`hci_auth_complete_evt()`](https://github.com/torvalds/linux/blob/v7.0/net/bluetooth/hci_event.c) feeds the authentication outcome into connection/security completion. L2CAP's [`l2cap_connect_cfm()`](https://github.com/torvalds/linux/blob/v7.0/net/bluetooth/l2cap_core.c) uses `bt_to_errno(status)` on a failed connection, while [`l2cap_security_cfm()`](https://github.com/torvalds/linux/blob/v7.0/net/bluetooth/l2cap_core.c) can instead leave a pending channel to time out. The exact socket error depends on which stage of connection establishment was reached.

It would be incorrect to claim that HCI `0x05` always becomes `EBADE`, or that a lost remote key can be inferred solely from the status byte. The lost key is established by U29's wider packet history, not by `0x05` alone.

### There is also a later BlueZ fix

[`00969bdb`](https://github.com/bluez/bluez/commit/00969bdb17ea01af8722d5bdcf8b2c19e06e9456), from 15 May 2025, adds tracking of the bonding outcome during `Connect()` and returns `br-connection-key-missing` when a pending connection is interrupted by `MGMT_STATUS_AUTH_FAILED`. Its commit message specifically says it replaces a misleading `br-connection-canceled` reply in that path.

This is a different code path from the 2024 A2DP errno fix. It should not be assumed to cure U29 unless the capture proves that the pending `Connect()` reaches `device_request_disconnect()` before the A2DP profile-completion reply.

There is a caution from the more recent [BlueZ issue #2661](https://github.com/bluez/bluez/issues/2661): `br-connection-key-missing` can itself be misleading for authentication-related failures that occur despite a valid stored key. Therefore, adding more unconditional “key missing” classification is not the best first approach.

Practical conclusion for item 3: first compare the locally built `profiles/audio/a2dp.c` against `a6ac17f0e393`. If the `ECONNREFUSED` case is absent, test that existing one-line upstream fix against the preserved U29 evidence and an emulator regression. This is much stronger than designing a new error-mapping patch from scratch.

## 4. The row remaining after the headset was switched off

Expected behavior — not a demonstrated defect

The evidence gives us a particularly useful boundary condition.

Last advertisement

11:18:29.736

Advertising resumes

11:18:49.111

19.4 seconds without advertisements30-second timeout

The last advertisement was at 11:18:29.736, but the subsequent disconnect at 11:18:31.47 restarted the temporary-device timer again through `device_remove_connection()` → `device_update_last_seen()`.

Consequently, without other events the earliest expiration would have been approximately 11:19:01.5. The headset resumed advertising at 11:18:49 and successfully paired before that original expiration point.

The 2020 BlueZ commit [`c53e232f`](https://github.com/bluez/bluez/commit/c53e232f210a7171d767392a108c71e674d66c2f) explicitly documents why the grace period exists: applications should have time to react to a disconnected temporary device.

There is no evidence that the timer malfunctioned. I would not open an issue about the switch-off observation.

The deciding test, if this is reconsidered, is a virtual temporary device that goes silent for more than 30 seconds, with no connections, pairing attempts or advertisement monitors. It should generate `InterfacesRemoved`. An expiry failure under those controlled conditions would be a separate finding.

## 5. Additional related upstream findings

### Existing precedent for non-discoverable devices appearing in Settings

An especially relevant precedent is [`4a7ee309`](https://github.com/bluez/bluez/commit/4a7ee30978da919cc820116be6ced323b35e4ebd), 4 June 2025, titled “adapter: Fix exposing coordinate sets if LE Audio is disabled.”

The maintainer's rationale was that exposing non-discoverable coordinated-set members in system device settings could lead users to attempt pairing that would not work.

That fix addresses a different mechanism: LE Audio coordinated-set discovery and advertisement monitoring. It is not a fix for U29. But its underlying usability concern is closely related.

It references [BlueZ issue #523](https://github.com/bluez/bluez/issues/523), where users reported confusing or duplicate device appearances, with a device sometimes pairable through BR/EDR-specific discovery but not through the GUI.

This history supports raising the U29 setup-readiness problem without presenting the mere existence of a non-discoverable device object as inherently wrong.

### Earlier GNOME pairing-error behavior

I also found [`75d3546`](https://github.com/GNOME/gnome-bluetooth/commit/75d3546cce621409d28b7076a464499dc7ce0aa4) from 16 June 2009, associated with GNOME bug 575352, “Offer to retry pairing when pairing fails.”

That code belonged to an older pairing assistant, not today's settings widget. It demonstrates that GNOME has previously implemented explicit recovery from failed pairing, but it does not establish that the GNOME 46.0 widget regressed from a working equivalent.

### Related failure that must not be conflated with U29

[BlueZ issue #2661](https://github.com/bluez/bluez/issues/2661), opened on 11 October 2026, reports a connected, authenticated dual-mode device whose later BR/EDR SMP/CTKD exchange fails, leading to a misleading `br-connection-key-missing` result.

In U29, the stored-key authentication itself failed at HCI `Auth Complete`, before that kind of successful authenticated connection. Therefore the two incidents should not be described as having the same root cause.

However, #2661 is a useful warning: a bonding-related authentication failure does not necessarily prove that the remote device lost its key. Error classifications should distinguish what the software actually knows from what it merely suspects.

## 6. Why U29 escaped detection

The source and history suggest three separate explanations.

BlueZ's lifetime behavior emerged from individually reasonable design decisions. In 2014, developers wanted to use advertisements from already-known non-discoverable devices. In 2020, developers introduced a timer whose purpose was to keep discovery results current without accumulating disappeared devices. The interaction permits a stream of otherwise filtered advertisements to refresh an object that a desktop presents as ready to configure.

GNOME's pairing-error path was left unfinished. Its source contains an explicit `FIXME`; this was not a recently introduced defect in the Bluetooth controller or kernel. The UI provides no effective feedback even when BlueZ correctly communicates `AuthenticationRejected`.

The misleading connection error already has a historical upstream correction. The August 2024 A2DP fix directly addresses an error combination matching U29, but the laptop's BlueZ 5.72 baseline predates that change. Whether Ubuntu independently backported it into `5.72-0ubuntu5.5` remains a packaging-verification question; the observed `-EAGAIN` is consistent with its absence.

It is reasonable to suspect a regression-test coverage gap involving an inbound BR/EDR connection, a temporary unpaired object, and continuing non-discoverable LE advertisements. I have not audited the complete BlueZ test suite to prove that such a test is missing.

The headset's loss of its stored key remains outside these findings. The available material cannot establish why it happened.

## 7. Recommended regression experiments

Each experiment should run in an isolated environment, without changing the laptop's Bluetooth kernel modules or disturbing its present pairing.

| Priority                  | Environment and procedure                                                                                                                                       | Deciding result                                                                                         |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| 1 — BlueZ device lifetime | `btvirt`/`hci_vhci`: create an unpaired device through an inbound BR/EDR connection; disconnect; inject LE advertisements with AD Flags `0x18` every 10 seconds | Temporary device survives beyond 30 seconds only while reports refresh its timer                        |
| 2 — GNOME error reporting | Mock BlueZ `Device1.Pair()` returning `AuthenticationRejected`, `AuthenticationFailed`, `AuthenticationTimeout` and cancellation                                | Current widget displays no error; candidate shows appropriate feedback, except intentional cancellation |
| 3 — BR/EDR error mapping  | Simulated AVDTP profile failure `ECONNREFUSED`, alongside HFP failure, on the Ubuntu-patched BlueZ baseline; repeat with `a6ac17f`                              | Baseline returns `br-connection-unknown`; patched tree preserves a meaningful connection error          |
| 4 — Timer expiration      | Virtual unpaired temporary device; end connection; stop all advertising for over 30 seconds                                                                     | D-Bus object is removed after expiration; no bug if removal occurs                                      |

The first experiment should also record `InterfacesAdded`, `InterfacesRemoved`, and `PropertiesChanged` for `RSSI`, `Connected`, `Paired`, `Trusted` and `AdvertisingFlags`, where supported.

One detail matters when interpreting the journal: `device_found_callback()` reports MGMT event flags `0x0000`, whereas the headset's advertising payload contains LE AD Flags `0x18`. They are different fields. Do not use the journal's `flags 0x0000` as evidence that the AD Flags were zero.

### A potential BlueZ fix for item 1

I would not simply move `device_update_last_seen()` below the discoverability check without more analysis. That could accidentally suppress useful freshness updates for already-paired, connected, trusted or advertisement-monitored devices.

A narrower candidate is to distinguish between:

- Last radio sighting, which can legitimately affect bearer selection, connectability and presence tracking.
- Visibility for device discovery and setup, which should not automatically be prolonged by non-discoverable advertisements for an unpaired, disconnected temporary device.

A small first patch might condition the temporary-timer refresh on discoverability for the specific unpaired/untrusted/disconnected case, but only after tests establish how it interacts with active pairing, filtered discovery and monitors.

A separate GNOME solution could make setup availability clearer, but BlueZ 5.72 does not expose a reliable `Device1` property meaning “the peer is currently in pairing mode.” GNOME cannot infer that condition reliably from `Paired`, `Connected`, `RSSI` or the newer `Connectable` property. An error shown after a rejected setup is therefore more straightforward than disabling the row in advance.

## 8. Exact-version verification: what is complete and what is not

This is an important qualification to the report.

I read the relevant files from the public source repositories at BlueZ 5.72, GNOME Bluetooth 46.0, GNOME Shell 46.0, and Linux v7.0, and retrieved the introducing upstream commits and their diffs.

I also read the project's public `BRIEF.md`, U29 issue description, `NOTES.md`, `PRESENCE.md` and timeline.

I was not able to perform an actual local source checkout and build in this investigation environment. Consequently, the following are not independently verified:

| Target                                                                | Status                                                                                                     |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| BlueZ upstream `5.72` functions                                       | Read directly                                                                                              |
| Ubuntu-patched `5.72-0ubuntu5.5` plus the project's two later changes | Maintainer reports the identified functions match upstream; complete patch-series comparison not performed |
| GNOME Bluetooth Ubuntu `46.0-1ubuntu1` delta                          | Not inspected; verification required                                                                       |
| GNOME Settings `46.7` Ubuntu delta                                    | Not comprehensively audited                                                                                |
| GNOME Shell `46.0` Ubuntu delta                                       | Not comprehensively audited                                                                                |
| Kernel `v7.0` relevant Bluetooth files                                | Read directly                                                                                              |
| Kernel Ubuntu `7.0.0-42.42~24.04.1` Bluetooth delta                   | Not compared completely                                                                                    |
| HCI packet-by-packet reconstruction                                   | Based on the project's published decoded findings; unpublished raw capture not available                   |

The Ubuntu package versions and source downloads are independently listed by Ubuntu: [BlueZ 5.72-0ubuntu5.5](https://packages.ubuntu.com/noble-updates/amd64/bluez), [gnome-bluetooth3 46.0-1ubuntu1](https://packages.ubuntu.com/noble-updates/gnome-bluetooth-3-common) and [linux-hwe-7.0 7.0.0-42.42\~24.04.1](https://packages.ubuntu.com/eu/source/noble-updates/amd64/linux-hwe-7.0).

Details of package bluez in noble-updates+2



For the project's maintainer, this is the smallest useful source-verification sequence on a separate development machine with the corresponding Ubuntu source repositories enabled:

```
# Retrieve Ubuntu's source packages, not merely upstream tags.
apt-get source bluez=5.72-0ubuntu5.5
apt-get source gnome-bluetooth3=46.0-1ubuntu1
apt-get source gnome-control-center=1:46.7-0ubuntu0.24.04.6
apt-get source 'gnome-shell=46.0-0ubuntu6~24.04.17'
apt-get source 'linux-hwe-7.0=7.0.0-42.42~24.04.1'

# Check whether the existing upstream A2DP error fix is present.
grep -n -A25 'static int error_to_errno' \
    bluez-5.72/profiles/audio/a2dp.c

# Check that the GNOME UI still has the silent-error branch.
grep -n -A55 'create_callback (' \
    gnome-bluetooth-*/lib/bluetooth-settings-widget.c

# Review the Ubuntu patch series and the files each patch changes.
find bluez-5.72/debian/patches \
    -type f -maxdepth 2

find gnome-bluetooth-*/debian/patches \
    -type f -maxdepth 2
```

For source-history verification, run against proper upstream Git clones rather than the unpacked source-package directories:

```
git -C bluez blame 5.72 -L 7260,7335 -- src/adapter.c
git -C bluez log --all --oneline \
    -S'device_update_last_seen(dev' -- src/adapter.c
git -C bluez log --all --oneline \
    -S'case ECONNREFUSED:' -- profiles/audio/a2dp.c

git -C gnome-bluetooth blame 46.0 \
    -L 920,960 -- lib/bluetooth-settings-widget.c
```

The line ranges are starting points; line positions shift between upstream, Ubuntu-patched and master trees.

The most important pending source check is the Ubuntu 5.72 A2DP `error_to_errno()` implementation, followed by GNOME's Ubuntu patch delta. No new contribution should be based on the assumption that those exact packaged versions are identical to upstream without that comparison.

## 9. Contribution priorities

Priority 1 — Check the existing BlueZ A2DP fix for backporting

Compare Ubuntu 5.72 against `a6ac17f0`, test its impact on the U29 error, and reuse the existing upstream solution if applicable. No need to invent a replacement for a problem already diagnosed upstream.

Priority 2 — GNOME Bluetooth: visible pairing failure

This appears the most straightforward new user-facing contribution. It has a confirmed source-level omission, a reproducible behavior and a small potential patch. U13 and U29 provide two distinct examples.

Priority 3 — BlueZ temporary-device visibility

Reproduce the lifetime effect under emulation, examine existing exceptions, and decide whether to change timer semantics or expose more precise setup-readiness information.

Close item 4 as expected behavior

Keep the switch-off observation in the dossier, but do not file a bug about it without a controlled expiration failure.

## Final assessment

U29 is a useful incident because it exposes three independent ways the Bluetooth stack can fail to communicate its state to a user even when the headset itself behaves correctly.

The strongest new finding is the precise August 2024 BlueZ A2DP patch that describes practically the same misleading error under a forgotten pairing. The GNOME error-reporting defect is also directly supported by source and history. The temporary-device behavior is real, but choosing the right fix will require greater care because the underlying mechanisms were deliberately designed for other legitimate use cases.

The work is ready to enter a source-exact verification and emulator-testing stage, not an upstream-submission stage. The remaining uncertainty is narrow and actionable: confirm the Ubuntu deltas, reproduce the early timer refresh under emulation, and verify the connection-error chain using the existing capture and the already-known upstream patch.

Nothing has been modified on the laptop, and nothing has been submitted upstream.
