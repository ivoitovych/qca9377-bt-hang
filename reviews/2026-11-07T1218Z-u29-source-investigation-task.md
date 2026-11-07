# Source investigation task — `U29`: a headset that cannot be set up, offered as "Not set up", and errors that say nothing, 2026-11-07

*The brief for outside reviewers, written 2026-11-07T12:18Z. It follows
`2026-10-20T2332Z-source-investigation-task.md`, whose answers (`2026-10-21T0009Z-…` to
`2026-10-21T0033Z-…`) confirmed `U7`'s mechanism in source.*

## What is asked

A **source-code investigation** of the code behind one incident, `U29`, on the laptop
described below. Everything observable is already recorded: the HCI capture, the bluetoothd
debug journal and the desktop journal. What is missing is the code, at the exact versions that
ran: which function, which state and which ordering produce what the user saw. We also want
the history: when each piece of behaviour was introduced, in which commit, and why.

Please **check out the code and read it**; do not rely on this brief alone. For each item,
tell us:
- which code participates (tree, version or commit, file, function, line);
- what in that code explains the observation, and what does not;
- how sure you are, and what would falsify your reading;
- **the history:** the commit that introduced the behaviour (`git log -S` / `git blame`), its
  stated reason, and whether a later commit on master changed it;
- what a fix would look like, and where it belongs (kernel, BlueZ, gnome-bluetooth, GNOME
  Settings, GNOME Shell or Ubuntu);
- the one experiment that would decide it. Prefer BlueZ's emulator (`emulator/`,
  `btvirt`) or `hci_vhci` in QEMU; next best is a reading of the capture we hold.

**Findings that contradict this brief are as welcome as ones that support it.** "I read X and
it cannot be the cause" is a result. If the code shows a defect we have not listed, tell us.

## The machine: exactly what ran

- **Kernel:** Ubuntu `7.0.0-42-generic`, package `linux-image-7.0.0-42-generic
  7.0.0-42.42~24.04.1`. Source: v7.0 plus the `linux-hwe-7.0` `7.0.0-42.42~24.04.1` delta
  (archive.ubuntu.com, `pool/main/l/linux-hwe-7.0/`). Read the Ubuntu delta too: it patches
  `net/bluetooth/`. btusb is stock btusb plus the upstream device-table entry `dc16388d45ec`;
  nothing in btusb is expected to matter here.
- **Controller:** Qualcomm QCA9377 "ROME", USB `13d3:3503`, BR/EDR and LE.
- **BlueZ (the daemon that ran):** `/usr/local/libexec/bluetooth/bluetoothd -d`, this
  project's build of Ubuntu's **`5.72-0ubuntu5.5`** source (Launchpad:
  `https://launchpad.net/ubuntu/+source/bluez/5.72-0ubuntu5.5`) with two later upstream fixes,
  `a734b06059cb` ("adapter: Fix crash on short start discovery reply") and `0bed9886cff3`
  ("a2dp: Fix crash on NULL stream in transport_cb"). Ubuntu's 31 patches touch
  `src/device.c` and `plugins/policy.c` among others: **do not read upstream 5.72 and call it
  what ran.** We compared the functions named below in the patched tree with upstream tag 5.72
  and found them identical. Line numbers below are the patched tree's. The packaged
  `5.72-0ubuntu5.8` is installed but was not running. `/etc/bluetooth/main.conf` sets nothing
  that matters here: `TemporaryTimeout` is commented out, so it defaults to 30 s.
- **GNOME:** gnome-bluetooth `46.0-1ubuntu1` (`libgnome-bluetooth-3.0-13`,
  `libgnome-bluetooth-ui-3.0-13`); GNOME Settings `1:46.7-0ubuntu0.24.04.6`; GNOME Shell
  `46.0-0ubuntu6~24.04.17`. We read gnome-bluetooth at tag 46.0 and at master `de5582b4`, but
  not Ubuntu's `46.0-1ubuntu1` delta: please check whether that delta touches the code below.
- **The headset:** Sennheiser MOMENTUM 4 (class `0x240404`, dual-mode, Secure Simple Pairing).
- **Repository:** <https://github.com/ivoitovych/qca9377-bt-hang>. Read `BRIEF.md` §0 first,
  and its retracted claims (§5), which must not be re-asserted. The incident is `U29` in
  `docs/issues.md`. The sanitised evidence is in
  `evidence/sessions/20261107-113143-momentum4-not-set-up/`:
  - `bluetoothd.log`, the debug journal from 11:15:30;
  - `timeline.txt`;
  - `NOTES.md`;
  - `PRESENCE.md`: the advertising and inquiry analysis, with its commands and output.

  In those files the headset is `AA:BB:CC:00:00:01`. The raw captures are not published,
  because they contain link keys; every packet fact below comes from them.

**Not in question:** the headset's refusals. It answered "Authentication Failure" to a key it
no longer had, and "Pairing Not Allowed" outside pairing mode; both are correct. Why it dropped
the key between 2026-11-04 and 11-06 is not known and cannot be learned now.

## The incident (all times 2026-11-07, local)

1. **09:38–09:41, Connect fails with a meaningless name.** The headset rejects the stored key:
   `Link Key Request Reply`, then `Auth Complete` "Authentication Failure (0x05)" at
   09:38:54.162. bluetoothd: `bonding_attempt_complete() … status 0x5`. Of the profiles
   `connect_profiles()` tries, hands-free gets "Connection refused (111)" and A2DP `-11`. GNOME
   Shell shows `Failed to connect device "MOMENTUM 4": GDBus.Error:org.bluez.Error.Failed:
   br-connection-unknown`.
2. **09:41:42, the device is removed** (`RemoveDevice` path: `btd_device_set_temporary()
   temporary 1`, accept-list removal, "Removing temporary device", `Unpair Device`). The
   Bluetooth panel was open. Who clicked is not recorded.
3. **11:16:06, the panel opens and discovery starts.** The filter is `transport: 7 rssi: 32767
   pathloss: 32767 duplicate data: false discoverable true pattern (null)`, then
   `adapter->current_discovery_filter == 0`.
4. **The headset is not discoverable until 11:18:52.**
   - Its LE `ADV_IND` (public address, every 2–16 s) carries AD flags `0x18`, with neither
     discoverable bit, plus one 16-bit UUID `0xfcfe` and the complete name.
   - It answers none of nine BR/EDR inquiry rounds (11:16:16 to 11:18:39).
   - At 11:18:52.344 it answers one: an Extended Inquiry Result with Handsfree, Headset, Audio
     Sink, A2DP and AVRCP. That is pairing mode.
   - The first advertisement, 11:16:06.81, created no device object.
5. **11:16:09.509, the headset connects to the laptop by itself** (`Connect Request` from the
   headset). bluetoothd `device_create()` runs at 11:16:10.138. The headset sends three Link
   Key Requests; the laptop sends three Negative Replies, having no key. The headset
   disconnects at 11:16:14.275 ("Remote User Terminated Connection"). The new, unpaired device
   is the panel's **"Not set up"** row.
6. **11:16:23 – 11:18:51, the row stays.** Every advertisement logs `device_found_callback() …
   flags 0x0000 eir_len 19`. The row is never removed.
7. **11:18:02 – 11:18:51, ten clicks, ten silent failures.** Each `Pair()`:
   - pages the headset, then Authentication Requested;
   - Link Key Request, Negative Reply;
   - IO Capability Reply: DisplayYesNo, "Dedicated Bonding - MITM required";
   - about 50 ms later, `Simple Pairing Complete` / `Auth Complete` "Pairing Not Allowed
     (0x18)".

   bluetoothd: `bonding_attempt_complete() … status 0xb`. GNOME Settings logs `Setting up …
   failed: GDBus.Error:org.bluez.Error.AuthenticationRejected` and shows nothing on screen.
8. **11:18:29.74 → 11:18:49.11, silence from the headset (19.4 s; the user switched it off).**
   The laptop was scanning: 8 reports from other devices, and an inquiry round ended at
   11:18:39.74. The row stays. Back on at 11:18:49, the headset refuses the tenth click, drops
   the link at 11:18:51.887 and enters pairing mode.
9. **11:18:57, a click in pairing mode works:** new link key 11:18:58.578, A2DP streaming at
   11:19:03.

## The items, in priority order

### 1. The "Not set up" row kept alive by the headset's own non-discoverable advertisements

**Our reading** (BlueZ, patched 5.72 tree):
- `src/adapter.c:7156` `device_is_discoverable()`: for LE, outside a filtered discovery,
  discoverable is `eir->flags & (EIR_LIM_DISC | EIR_GEN_DISC)`, false for `0x18`.
- `src/adapter.c:7202` `btd_adapter_device_found()`: with no existing device, a
  non-discoverable report creates none (step 4). With an existing device, it calls
  `device_update_last_seen()` at **l.7291**, and the BR/EDR one just below. Only then, at
  **l.7320**, does it drop a non-discoverable report.
- `src/device.c:4486` `device_update_last_seen()` restarts the temporary-device timer
  (`set_temporary_timer(device, btd_opts.tmpto)`, l.4499).

So a headset that announces it cannot be paired keeps an unpaired row alive indefinitely, and
the panel offers to set it up.

**Questions:**
- Is that reading right? Is anything else refreshing the row? Candidates:
  - each `Pair()` attempt's connection: `device_add_connection()` clears the timer (l.3274),
    and `device_remove_connection()` re-arms it through `device_update_last_seen()` (l.3380);
  - the `discovery_found` list;
  - `adapter->filtered_discovery`;
  - the RSSI property.
- Was the device's `RSSI` property set or cleared during 11:16–11:18? What did GNOME see over
  D-Bus: did the row look "present"?
- **History:** when did `device_update_last_seen()` come to run before the discoverable check,
  and when did it start restarting the temporary timer? Was the ordering deliberate, for
  example to keep a connected or recently connected device alive?
- **Master:** master's `device_is_discoverable()` has a `btd_opts.filter_discoverable` branch
  (`FilterDiscoverable` in `main.conf`) and an auto-connect output. When were they added, why,
  and do they change this case?
- **GNOME:** which code decides which BlueZ devices the panel lists, and the "Not set up"
  label? That is gnome-bluetooth's `BluetoothClient` model and the settings widget's filter,
  and GNOME Settings' panel. Does it look at `Paired`, `Bonded`, `Trusted`, `RSSI`,
  `Connected`, or none of them? Does GNOME Shell's quick-settings menu use the same filter?
- **The fix:** BlueZ (do not refresh a temporary, unpaired device from a non-discoverable
  report), GNOME (do not offer, or mark, an unpaired device that is not discoverable now), or
  both? Is the discoverable state of a found device exposed over D-Bus at all? If it is not,
  GNOME cannot know it.

### 2. Ten failed setups with nothing on screen (`AuthenticationRejected`)

**Our reading:** gnome-bluetooth 46.0 `lib/bluetooth-settings-widget.c:944-951` (master
`de5582b4`, l.934–941): the error branch of the setup callback turns off the spinner; the
dialog is commented out (`//FIXME show an error?`), leaving only `g_warning("Setting up %s
failed: %s", …)`. The `AuthenticationFailed` and `AuthenticationCanceled` branches nearby are
empty FIXMEs. `U13` (a Shure AONIC 50 refused over LE, `docs/issues.md`) takes the same branch.

**Questions:**
- Confirm the path from the `Pair()` D-Bus reply (BlueZ `src/device.c`:
  `device_bonding_complete()` l.6339, `bonding_request_free()` l.2982, the
  `AuthenticationRejected` reply at l.3111) to that branch. Which HCI/MGMT statuses become
  `AuthenticationRejected`, and which become `AuthenticationFailed`?
- **History:** when was the dialog commented out, and why? Is there a GNOME issue or MR about
  it (gnome-bluetooth, GNOME Settings, GNOME Shell's Bluetooth menu)? Was it ever shown, in an
  older version?
- Does GNOME Shell's quick-settings Bluetooth menu fail silently the same way?
- **The fix:** what message fits each error? For `AuthenticationRejected` from Pairing Not
  Allowed, something like "put the device in pairing mode". Is there a precedent in GNOME's
  other panels?

### 3. "br-connection-unknown" for a headset that rejected the stored key

**Our reading:**
- `src/error.c:137` `btd_error_bredr_conn_from_errno()` maps errno to the D-Bus error name.
  `EBADE` becomes `ERR_BREDR_CONN_KEY_MISSING` (l.174); everything unlisted becomes
  `ERR_BREDR_CONN_UNKNOWN` (l.176–177).
- A2DP failed with `-11` (`EAGAIN`), the last profile to fail, and **[inference]** that is
  where the name came from. The authentication failure itself never reached the user.

**Questions:**
- Trace it from the kernel: the `Auth Complete` 0x05 at 09:38:54.162 → `hci_event.c` →
  `hci_conn` security failure → L2CAP channels (`l2cap_core.c`). What error does the waiting
  L2CAP socket get? Then BlueZ: AVDTP and the A2DP connect, and the hands-free RFCOMM connect,
  up to `connect_profiles()` and the D-Bus reply. Where does `-11` come from, where does `111`
  come from, and which one is chosen for the reply?
- Is there a code path that yields `EBADE` (key missing) for an authentication failure on a
  bonded device? When was the key-missing name added, and for which case?
- **History:** when were the `br-connection-*` names introduced, and was a key-rejected case
  discussed?
- **The fix:** should an authentication failure against a stored key reach the user as
  "key missing" (or as a dedicated name), so the desktop can say "the device no longer
  recognises this computer; remove and pair it again"? Where would that belong: the kernel
  errno, BlueZ's profile code, or the error mapping?

### 4. The row outliving a switch-off (doubtful; check, do not build on it)

The row stayed for the 19.4 s the headset was off. BlueZ removes an unpaired device 30 s after
it was last seen. We take that to be by design and record it as **doubtful as a defect**.

**Questions:**
- Confirm the 30 s: `TemporaryTimeout` / `btd_opts.tmpto` and `device_disappeared()`
  (`src/device.c:3280`). Our reading: the last advertisement (11:18:29.74) and then the
  disconnect at 11:18:31.47 (`device_remove_connection()` → `device_update_last_seen()`,
  l.3380) each restarted the timer, so the row could go at about 11:19:01.5 at the earliest.
  Is that right?
- Does any layer show that a row rests on an old sighting (for example the RSSI cleared at the
  end of a discovery round)? If none does, is that worth a GNOME request?

## What we would like back

1. **Per item:**
   - the participating code (tree, version or commit, file, function, line), read in the
     versions that ran;
   - your reading, how sure you are, and its falsifier;
   - the introducing commit and its reason, and any later change on master;
   - where the fix belongs;
   - the experiment you would run first.
2. **Item 1:** a yes or no on our reading of `btd_adapter_device_found()`, and the GNOME
   listing rule.
3. **Item 3:** the errno path, end to end.
4. **Anything else** the code shows that we have not listed.

**Constraints:**
- The laptop is in daily use; experiments on it are short and must not need the headset
  re-paired.
- Do not propose unloading, reloading or rebinding `btusb` or `bluetooth.ko` on the running
  system: a reload kills even a healthy controller here (`EX-046`).
- Prefer BlueZ's emulator, `hci_vhci` and QEMU wherever they can decide the question.
- Nothing is sent upstream on the strength of a review alone: each finding is checked against
  the source and our captures first.
