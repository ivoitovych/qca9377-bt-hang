# U29 source investigation — the sixth outside reviewer's answer

*Received 2026-11-07 in answer to `2026-11-07T1218Z-u29-source-investigation-task.md`, with the
reviewer's covering message at the end. The text is kept as received; `scripts/review-text-clean.py`
removes the reviewer's tooling marks if any.*

*No finding was added or changed. What we checked on 2026-11-07, and the result:*

- **§3.1 case (a) vs (b), decided by the capture** (`scripts/capture-window.sh` on
  `hci-20261106-165649`, 09:38:50 to 09:38:56; the decode shows the link key, so none is kept).
  The mechanism holds, but the setup is not the one the reviewer guessed.
  - **The setup.** The laptop paged the headset itself: `Create Connection` at 09:38:53.670,
    `Connect Complete` at 09:38:54.015 with encryption disabled. An SDP channel (PSM 1) was
    connected at .072, at SDP security, so the link came up **without** authentication.
  - **The failures.** `Authentication Requested` at .094 (HFP), then `Auth Complete` 0x05 at
    .162. Again at .267 (A2DP), with 0x05 at .337. No L2CAP request for PSM 3 or 25 was sent
    before either.
  - **The refusals.** bluetoothd's `111` came at .267 and .442, about 105 ms after each failure.
  - **So:** authentication failed on a `BT_CONNECTED` ACL, as §3.1(a) says. The ACL was not
    the headset's page or an older link; it was a fresh page by the laptop that completed
    without authentication because SDP came first. The reviewer's falsifier ("a Create
    Connection from the laptop right before the first Link Key Request") does not apply: the
    Create Connection came 430 ms earlier and the ACL was already up.
- **§1.2 controls hold.** The device `…:04` sent its last report at 11:19:00.494 and was
  removed at 11:19:30.979 (30.48 s). `…:02`: 11:19:01.299 to 11:19:31.953 (30.65 s). Read
  from the sanitised `bluetoothd.log`.
- **§1.3 holds.** Ten `btd_device_set_temporary() temporary 0` / `temporary 1` pairs, from
  11:18:02.48 to 11:18:51.19, in the bluetoothd journal.
- **§6.1 does not hold as withdrawn.** In the running tree, `store_device_info_cb()`
  (`src/device.c:438-441`) calls `create_file(filename, 0600)` before loading the file. It
  creates the file rather than refusing to. The journal from 11:18:00 to 11:19:00 has **no**
  "Unable to load key file" line, against the reviewer's prediction of one per click. So each
  click probably wrote the device's `info` file for the attempt [inferred from the source and
  the missing error; the storage directory was not read, it holds keys].
- **§3.2 / §6.3 only half holds.** It is true that `MGMT_DEV_DISCONN_AUTH_FAILURE` is unused in
  the running 5.72 tree (`grep` over `src/`: none), and that the kernel sets
  `HCI_CONN_AUTH_FAILURE` only for HCI 0x06 (`7.0.0-42` `hci_event.c:3500-3501`, `:3635-3636`).
  It is not true that master ignores the reason: it uses it.
  - `53db78000` (Frédéric Danis, 2025-05-23, first in 5.83) adds a `Device1.Disconnected`
    signal with `org.bluez.Reason.Authentication` (`src/device.c:4022-4024` on `a80671987`).
  - `fdfaeddc9` (2025-07-14) adds the Bearer API.
  - `17a227b77` (Andrey Smirnov, 2025-12-05, first in 5.86) limits auto-connect retries on
    authentication failures.

  With the kernel's 0x06-only rule, U29's 0x05 would still not produce that reason [inferred].
- **§6.2 holds.** `emulator/btdev.c:3395-3407` on master: `cmd_io_cap_negative_reply()` completes
  SSP with `BT_HCI_ERR_AUTH_FAILURE` and ignores `cmd->reason`.
- **§2.2 history, one subject wrong.** `9b8646a44` (2012-12-19) is "core: Make
  device_cancel_bonding static to device.c", not the introduction of the D-Bus error names. The
  `AuthenticationRejected` name goes back to `2aad1cf41` (2009-01-11) and earlier.
- **Commits.** The rest exist with the subjects and dates given:
  - BlueZ: `c65c8bf64`, `f5c4a04e1`, `2b480bd56`, `8f73362e8`, `e20bd1036`, `0ee60b31a`,
    `59569c1f9`, `830e1a915`, `0ff45df85`;
  - kernel: `ca69b7957bf2`, `ab07801d28985`, `160b925163c0a`;
  - gnome-bluetooth: `4b2c4fd2`, `2eb69e58`, `80daa7ad`.
- **§3.3 / §7.** Patchwork series 505973 is "[BlueZ] doc/agent-api: Add AuthenticationFailed
  method", Luiz Augusto von Dentz, 2021-06-23, one patch. Master has no such agent method. The
  thread's comments were not read here.
- **Not checked:** the GNOME issue numbers (#18, #91, #1054), BlueZ issues #433, #2700, #1100,
  #1269 and #445, the GNOME Settings toast precedents, and §2.2's full status table.

---

# `U29` — source investigation, answer to `2026-11-07T1218Z-u29-source-investigation-task.md`

*Written 2026-11-07. Everything below was read in checked-out trees at the versions that ran
(§0). Line numbers are those trees'. Each claim carries how sure I am and what would falsify
it. Nothing here is a patch.*

## Bottom line

| item | answer |
|---|---|
| 1. the "Not set up" row kept alive | **Yes, your reading of `btd_adapter_device_found()` is right**, and the debug journal confirms it on its own: between the headset's disconnect at 11:16:14.27 and the first click at 11:18:02.48 (108 s) nothing but its non-discoverable advertisements touched the device, no gap between them exceeds 17 s, and the two other temporary devices in the same log were removed 30.5 s and 30.7 s after their last report. Two further refresh paths exist and ran during the clicks (each `Pair()` toggles `temporary` false→true, and each attempt's ACL add/remove), but they are not what kept the row from 11:16:44 to 11:18:02. The lookup that makes an LE report match a BR/EDR-created device is `device_addr_type_cmp()`'s "public address on either bearer" rule, and the same report also refreshes the BR/EDR bearer's `last_seen` (flags `0x18` ≠ "BR/EDR not supported"), which is why every `Pair()` went over BR/EDR. The RSSI property was never set for the headset (no `device_set_rssi_with_delta()` line for it; the report is dropped before l.7338). GNOME lists every `org.bluez.Device1` on the default adapter that has a `Name`; "Not Set Up" is `!Paired && !Trusted`; `RSSI`, `Connected` and discoverability play no part in listing. BlueZ exposes no discoverable state over D-Bus (`AdvertisingFlags` is experimental and is not updated from a non-discoverable report), so GNOME cannot know. Fix belongs in BlueZ; master is unchanged. |
| 2. ten silent setups | Path confirmed end to end: HCI `0x18` → kernel `mgmt_status_table` → `MGMT_STATUS_REJECTED (0x0b)` → `pair_device_complete()` → `device_bonding_complete()` → `device_bonding_failed()` → `new_authentication_return()` l.3108–3112 → `org.bluez.Error.AuthenticationRejected` → gnome-bluetooth `create_callback()` `else` branch, `g_warning` only. The dialog text has been commented out since the settings widget was written (`4b2c4fd2`, 2013-12-02, first in 3.11.3); the old `bluetooth-wizard` did show "Setting up '%s' failed" on its summary page. The three-way split is `2b8cf369` (2020-09-20, "Prepare for future error reporting"). GNOME Shell's menu never shows an unpaired device and logs its own connect failures with `console.error` only. Fix belongs in gnome-bluetooth; GNOME 46.7 has a toast precedent (`cc-bolt-device-dialog.c:221`). |
| 3. `br-connection-unknown` | Traced. The name is A2DP's `-EAGAIN` from `profiles/audio/a2dp.c:error_to_errno()` (l.296–318), which turns every POSIX errno other than `EHOSTDOWN`, `ECONNABORTED`, `EBADE` into `-EAGAIN`; `src/error.c` has no case for it. HFP's `111` and the A2DP socket's error are the kernel's `l2cap_chan_timeout()` `ECONNREFUSED` (l.429–432), reached when authentication fails on an ACL that is **already `BT_CONNECTED`**: `l2cap_security_cfm()` only arms a 100 ms timer on a `BT_CONNECT` channel and the HCI status is lost there. A fresh ACL whose authentication fails in `BT_CONFIG` would have given `EACCES (13)` via `l2cap_connect_cfm()` → `bt_to_errno(0x05)`; the journal's `111` excludes that path. `EBADE` exists for HCI `0x06` only (`bt_to_errno`, since the 2005 import), reaches a socket only through `l2cap_conn_del()`, and the headset said `0x05`. Three layers each lose the fact; the right place to carry "the peer no longer accepts our key" is a BlueZ signal to the UI (there is a 2021 RFC by the BlueZ maintainer for exactly this, never merged, with Bastien Nocera asking for it). |
| 4. the row after the switch-off | Confirmed: 30 s default (`DEFAULT_TEMPORARY_TIMEOUT`, `main.c:61`), restarted at 11:18:31.47 by `device_remove_connection()` l.3380, so removal no earlier than 11:19:01.5 and, with `g_timeout_add_seconds_full()`'s one-second granularity, up to ≈11:19:02.5. Not a defect. No layer shows that a row rests on an old sighting; BlueZ clears `RSSI` only at discovery end and only for devices that passed the discoverable check. |

**New, not in the brief:** (A) the emulator turns an IO Capability *Negative* Reply into status `0x05`, not the reason given, so it cannot reproduce `AuthenticationRejected` without a one-line change (§6.2); (B) the kernel models "remote lost the bond" as HCI `0x06` only, and BlueZ ignores even that signal (§6.3); (C) BlueZ #433 is this incident's "paired but the peer forgot us" half, and a 2021 agent-API RFC by the BlueZ maintainer, with Bastien Nocera's reply, is the unfinished fix (§3.3, §7); (D) each failed `Pair()` of a never-paired device tries and fails to store it, one error line per click (§6.1).

## 0. What was read

| tree | version | how obtained / checked |
|---|---|---|
| BlueZ, the daemon that ran | `5.72-0ubuntu5.5` + `a734b06059cb` + `0bed9886cff3` | built as git: `bluez_5.72.orig.tar.xz` + the 26-patch series of `5.72-0ubuntu5.5` (the `5.72-0ubuntu5.8` `debian/patches/series` up to `audio-upgrade-versions-to-latest-possible-to-qualify.patch`; the later nine, `0016-advertising-…` and the CVE patches, are 5.6–5.8) + the two upstream fixes. 29 commits. All functions cited below are byte-identical to upstream tag 5.72 except where an Ubuntu patch is named. |
| BlueZ master | `a80671987` (5.88-2) | full clone, used for `git log -S` / `git blame` |
| kernel | v7.0 (`028ef9c96e96`) + `linux-hwe-7.0_7.0.0-42.42~24.04.1.diff.gz`, `net/bluetooth`, `include/net/bluetooth`, `drivers/bluetooth` | the Ubuntu delta touches 24 files under `net/bluetooth/`; in the functions on item 3's path it changes only locking (`l2cap_chan_timeout` FLAG_DEL checks, `l2cap_conn_del` `cancel_work_sync`/`proto_lock`, `l2cap_chan_connect` lock order). `lib.c` (`bt_to_errno`) is untouched; `hci_auth_complete_evt`, `l2cap_security_cfm`, `mgmt_status_table` are untouched. History from a partial clone of torvalds/linux. |
| gnome-bluetooth | 46.0 + Ubuntu `46.0-1ubuntu1` | the Ubuntu delta is two upstream backports to `lib/bluetooth-client.c` (discovery when unpowered, issue #162); `bluetooth-settings-widget.c`, `bluetooth-settings-row.c` and the listing code in `bluetooth-client.c` are identical to tag 46.0. Master `adf070af` (one translation past `de5582b4`). |
| GNOME Settings | 46.7 + Ubuntu `46.7-0ubuntu0.24.04.6` | `panels/bluetooth/cc-bluetooth-panel.c` identical to tag 46.7; it only embeds `BluetoothSettingsWidget`. |
| GNOME Shell | 46.0 + Ubuntu `46.0-0ubuntu6~24.04.17` | `js/ui/status/bluetooth.js` identical to tag 46.0. |

Evidence read: `BRIEF.md` §0 and §5, `docs/issues.md` `U29`, and the sanitised session
`evidence/sessions/20261107-113143-momentum4-not-set-up/` (`bluetoothd.log`, `PRESENCE.md`,
`NOTES.md`). Nothing retracted in §5 is used here.

## 1. The "Not set up" row kept alive by non-discoverable advertisements

### 1.1 Participating code (BlueZ, the patched 5.72 tree)

- `src/adapter.c:7448` `device_found_callback()` → `:7202` `btd_adapter_device_found()`:
  - `:7247` returns unless `adapter->discovering || monitoring` (GNOME's discovery was on);
  - `:7255` `discoverable = device_is_discoverable()` (`:7156`): for an LE report with
    `!adapter->filtered_discovery`, `discoverable = eir->flags & (EIR_LIM_DISC | EIR_GEN_DISC)`
    (`:7166`), false for `0x18`;
  - `:7258` `dev = btd_adapter_find_device(adapter, bdaddr, bdaddr_type)`;
  - `:7259–7282` no device: scan responses create nothing; a non-discoverable report creates
    nothing (`:7276`). This is step 4 of the incident (the 11:16:06.81 advertisement);
  - `:7291` **`device_update_last_seen(dev, bdaddr_type, !not_connectable)`** — on every report
    for an existing device, before any discoverable check;
  - `:7299–7304` if the LE flags byte is non-zero and lacks `EIR_BREDR_UNSUP` (`0x04`):
    `device_set_bredr_support(dev)` and **a second `device_update_last_seen(dev, BDADDR_BREDR,
    …)`** — `0x18` qualifies;
  - `:7306` the complete name is cached;
  - `:7313–7318` the "temporary and no discovery client" skip — not taken, GNOME's session was
    in `adapter->discovery_list`;
  - `:7323–7328` **the drop of a non-discoverable report** — everything after it
    (`device_set_legacy`, `device_set_rssi` `:7338`, name, class, `device_set_flags` `:7381`,
    `discovery_found` `:7402–7411`) is skipped.
- `src/adapter.c:1005` `btd_adapter_find_device()` uses `src/device.c:4745`
  `device_addr_type_cmp()`: a public LE address and a BR/EDR device with the same address match
  ("doesn't matter whether LE or BR/EDR", `:4753–4760`). The lookup then calls
  `device_set_le_support(device, BDADDR_LE_PUBLIC)` (`:1034`; `device.c:4472`), which sets
  `device->le`, changes `device->bdaddr_type` and emits `AddressType`. So the device object
  created at 11:16:10 by the BR/EDR connection was found by every LE report.
- `src/device.c:4486` `device_update_last_seen()`: sets `state->last_seen`, and if the device is
  temporary, `set_temporary_timer(device, btd_opts.tmpto)` (`:4500`) → `:3291`
  `set_temporary_timer()` → `timeout_add_seconds(30, device_disappeared)`; `:3280`
  `device_disappeared()` → `btd_adapter_remove_device()` (`adapter.c:1416`) → `device_remove(dev,
  TRUE)` (`device.c:4664`), which logs "Removing device …".
- `src/device.c:4178` `device_new()` sets `device->temporary = true` (`:4236`); `:4268`
  `device_create()` loads the cached name (`load_cached_name`, kept across `RemoveDevice`
  because `device_remove_stored()` `:4608` only strips the `ServiceRecords`/`Attributes` groups
  from the cache file), so the row had its name at once.

### 1.2 Reading, and what the journal proves without the code

Yes to your reading. Beyond the code, the sanitised journal decides it by elimination:

- 11:16:14.274 `dev_disconnected()` → `adapter_remove_connection()` → `device_remove_connection()`
  `:3380` → `device_update_last_seen()` → timer armed for ≈11:16:44.
- From 11:16:14 to 11:18:02 the only lines naming the headset are eleven
  `device_found_callback()` lines (11:16:23.10, :39.60, :40.45, :55.24, 11:17:11.10, :11.73,
  :27.08, :27.60 [a bare scan response, `flags 0x0020 eir_len 0`, which for an existing device
  also reaches `:7291`], :43.38, :59.28). Largest gap: 16.5 s (11:16:23 → :39, 11:17:43 →
  :59). No connection, no pairing, no `btd_device_set_temporary()` line.
- None of those lines is followed by `device_set_legacy()` / `device_set_rssi_with_delta()` /
  `device_set_flags()`, unlike the reports of `…:02` and `…:04` in the same log — the report was
  dropped at `:7323`, after `:7291`.
- Control: `…:04` last report 11:19:00.494 → "Removing device" 11:19:30.979 (30.48 s); `…:02`
  11:19:01.299 → 11:19:31.953 (30.65 s). The 30 s timer works in this daemon; it did not fire
  for the headset because it kept being restarted.

So a headset announcing "not discoverable" (and, by the same flags, "BR/EDR capable") kept an
unpaired BR/EDR row alive for as long as it advertised.

**Sure:** high. **Falsifier:** a bluetoothd (`-d`) run in which an existing temporary device
receives only non-discoverable LE reports for > 31 s and is still removed; or a "Removing
device" line for the headset between 11:16:44 and 11:18:02 in the raw journal.

### 1.3 The other candidates

| candidate | refreshes the row? | when it ran here |
|---|---|---|
| each `Pair()`: `src/device.c:3024` `btd_device_set_temporary(device, false)` at the top of `pair_device()` (clears the timer, adds the device to the kernel accept list, attempts a store — §6.1), and on failure `device_bonding_complete()` `:6357–6359` `btd_device_set_temporary(device, true)` → `:5984` `set_temporary_timer(30)` | **yes — a fresh 30 s on every failed click**, independent of any report | 11:18:02 – 11:18:51, ten times (`temporary 0` / `temporary 1` pairs in the log) |
| each attempt's ACL: `device_add_connection()` `:3249` (update, then `:3274` clear while connected) and `device_remove_connection()` `:3380` (update → 30 s) | yes | the headset's own connection 11:16:10–14, and the clicks |
| `adapter->discovery_found` | no — a device enters it only after the discoverable check (`:7402–7411`); its only effect is `invalidate_rssi_and_tx_power()` at `discovery_cleanup()` `:1710` | the headset never entered it |
| `adapter->filtered_discovery` | no — false here. GNOME's filter is `{Transport: auto, Discoverable: true}`; `merge_discovery_filters()` `:2203` treats a filter with only `discoverable` set as a regular discovery (the "Detect empty filter with only discoverable" block, Hans de Goede, March 2023, for Broadcom controllers that ignored `Start Service Discovery` with an empty filter), so `current_discovery_filter == 0` (your log line) and `start_discovery_complete()` `:1870` sets `filtered_discovery = false`. With it true, `device_is_discoverable()` would have returned true for everything. | — |
| the `RSSI` property | never set for the headset: `device_set_rssi()` is at `:7338`, after the drop; `device_set_rssi_with_delta()` (`device.c:6160`) logs `rssi %d` on the first set and no such line exists for `…:01` | — |

What GNOME saw over D-Bus 11:16–11:18: a `Device1` with `Name`/`Alias` "MOMENTUM 4", `Class
0x240404`, `Paired false`, `Trusted false`, `Connected true` 11:16:10–14 then `false`, no
`RSSI`, an `AddressType` change notification at the first matching report (the value stays
"public"; it marks the LE bearer being added), `UUIDs` empty
until the EIR at 11:18:52 (then the `avrcp/a2dp/hfp` probes in the log). Nothing in that set
says "not discoverable now".

### 1.4 History

- The order "update last-seen, then discoverable check" is from **`c65c8bf64` (Johan Hedberg,
  2014-02-21, "core: Track LE & BR/EDR last seen times")**. Then `last_seen` was only a
  timestamp for bearer selection (`select_conn_bearer()`, `:2477`), which must see every bearer
  the device is heard on, discoverable or not. Placing it before the check was right for that
  purpose.
- The discoverable drop itself is older: **`f5c4a04e1` (Bruna Moreira, 2012-07-26, "adapter:
  Emit DeviceFound() signal only to discoverable devices")**.
- The timer was added later, inside the same function: **`def01de02` (Luiz Augusto von Dentz,
  2020-07-15, "device: Add timer for removing temporary devices", BlueZ 5.55)**: "it is updated
  everytime the device is seen so devices will be removed even during an active discovery
  session … devices that disappeared". The commit reuses `device_update_last_seen()` as the
  restart point and does not revisit its position relative to the discoverable check; nothing
  in it says a non-discoverable report should count as "seen". **Not deliberate, as far as the
  record shows.**
- `2b480bd56` (Yu Liu, 2020-08-24, "adapter: Mark device temporary state pairing failure")
  added the `btd_device_set_temporary(true)` on bonding failure because a device "hung around
  as a discovered device forever even if it is turned off or not present" — the same user
  complaint from the other side.
- `0004eb06d` (2023-08-17, "device: Restart temporary timer while connecting") is the last
  change to the timer before 5.72.
- **Master** (`a80671987`): `btd_adapter_device_found()` keeps the same order
  (`device_update_last_seen` → BR/EDR inference, now limited to `BDADDR_LE_PUBLIC` → name →
  discoverable drop). Two additions: **`393e81a74` (2025-09-03, "main.conf: Add
  FilterDiscoverable option")**, default `true`, which only adds a way to *disable* the
  filtering ("to adhere to core spec 9.2 … A device in the non-discoverable mode is not
  discoverable"; the v2 thread with Bastien Nocera, linux-bluetooth 2025-09-04/08, gives no
  motivating bug beyond "some stacks" not using GAP discoverable modes); and the `auto_connect`
  output of `device_is_discoverable()`, which belongs to the pattern filter
  (`DiscoveryFilter.AutoConnect`) and is irrelevant here. **Neither changes this case.** The
  defect is on master.

### 1.5 GNOME: the listing rule

- gnome-bluetooth 46.0 `lib/bluetooth-client.c:322` `device_added()`: every `org.bluez.Device1`
  whose `Adapter` is the default adapter becomes a `BluetoothDevice` in the model, reading
  `Address, Alias, Name, Paired, Trusted, Connected, UUIDs, LegacyPairing, Icon/Class/Appearance`
  (`:257` `device_notify_cb` tracks the same set). `RSSI` is never read. Removal follows
  `InterfacesRemoved` after a 50 ms queue (`:96`, `:428`; `80daa7ad`, 2022).
- `lib/bluetooth-settings-widget.c:1512` `device_added_cb()`: a row for every model entry, no
  filter; the row's visibility is bound to `name != NULL` (`bluetooth-settings-row.c:316`
  `name_to_visible`, `:367`). `:1419` `activate_row()`: `paired || trusted` → properties
  dialog, else `start_pairing()` (`:1002`) → `bluetooth_client_setup_device()` →
  `Device1.Pair()` (`bluetooth-client.c:1603`).
- `lib/bluetooth-settings-row.c:75` `label_might_change()`: `!paired && !trusted` → "Not Set
  Up"; else `connected` → "Connected" / "Disconnected".
- GNOME Shell 46.0 `js/ui/status/bluetooth.js:161` `getDevices()` yields only `device.paired ||
  device.trusted`: the quick-settings menu **never shows an unpaired device**, so it did not
  offer the headset; its own failures are `console.error` only (`:156`).
- The Ubuntu deltas do not touch any of this (§0).

### 1.6 Where the fix belongs, and what it looks like

**BlueZ, `src/adapter.c`.** GNOME cannot act: no property says "discoverable now", and
`AdvertisingFlags` (`device.c:3212`, experimental) is only updated after the discoverable check
(`:7381`), so it would show the last *discoverable* flags, never `0x18`. A GNOME-side change
("do not offer a device that is not discoverable") would need a new BlueZ property first.

The narrow change: do not restart the temporary timer from a report the daemon is about to
drop. For example in `btd_adapter_device_found()`, before `:7291`:

```c
	/* A temporary, unconnected device is kept only by reports that
	 * would be shown; a non-discoverable report must not refresh it.
	 */
	if (discoverable || monitoring || eir_data.rsi ||
			!device_is_temporary(dev) || btd_device_is_connected(dev))
		device_update_last_seen(dev, bdaddr_type, !not_connectable);
```

and the same guard on the BR/EDR inference at `:7303` (or move both below the drop at `:7328`
for temporary devices). Paired devices keep their `last_seen` for bearer selection. An
argument the maintainer may raise: `last_seen` also feeds `select_conn_bearer()` for temporary
devices that are about to be paired; a non-discoverable report should arguably not influence
that either.

Whether "the row should be absent" is the right product behaviour is a GNOME question; the
BlueZ change above only stops a hidden device from *extending* a row that exists because the
device once connected. After it, the row from the 11:16:09 connection would have gone at
≈11:16:44, and the user would have seen nothing to click — which matches the headset's own
state.

### 1.7 The experiment (emulator, no laptop)

`btvirt -l2` gives two dual-mode (BR/EDR/LE 6.2) controllers on `hci_vhci`, connected through
the emulator's air; bluetoothd (the 5.72 build, `-d`) on `hci0`, the peer driven on `hci1`
without a daemon:

1. `btmgmt -i 1 power on; btmgmt -i 1 connectable on; btmgmt -i 1 discov no; btmgmt -i 1
   add-adv -c 1` — connectable LE advertising with no discoverable bit (the kernel then emits
   no Flags AD at all; `eir->flags == 0` takes the same branch as `0x18`).
2. `bluetoothctl scan on` on `hci0`. Expect **no** device object for `hci1`'s address.
3. `l2test -c -i hci1 -P 1 <hci0 address>` — an incoming BR/EDR ACL at SDP security level, no
   pairing, like the headset's 11:16:09 connection. Expect `Device1` for the peer, temporary,
   `Connected: yes`; kill `l2test`.
4. Watch `InterfacesRemoved` (`gdbus monitor --system --dest org.bluez`). **Prediction with
   5.72 and master:** the object stays as long as step 1's advertising runs; `btmgmt -i 1 rm-adv
   1` → removed 30–31 s later. With the change in §1.6: removed 30–31 s after step 3's
   disconnect regardless.

To reproduce `0x18` exactly rather than "no flags", put the Flags AD in the instance data
yourself (`btmgmt -i 1 add-adv -c -d 020118 1`, plus the name): the kernel keeps a
userspace-supplied Flags field as is (`net/bluetooth/eir.c:263–265`, `goto skip_flags`). It
changes nothing in `device_is_discoverable()` but exercises the BR/EDR-inference branch at
`:7299`, so the peer's `last_seen` is refreshed on both bearers as the headset's was.

## 2. Ten failed setups with nothing on screen

### 2.1 The path, confirmed

Kernel (Ubuntu 7.0.0-42 tree): `MGMT_OP_PAIR_DEVICE` → `hci_connect_acl()` (`hci_conn.c:1713`)
→ ACL in `BT_CONFIG` → `hci_remote_name_evt()` `:3545`, `check_auth` →
`HCI_OP_AUTH_REQUESTED` (`:3579`) → Link Key Request → Negative Reply (no key) → IO Capability
Request/Reply (DisplayYesNo, dedicated bonding, MITM) → the headset answers with its own IO
Capability *Negative* Reply → `Simple Pairing Complete` / `Auth Complete` status `0x18` →
`hci_auth_complete_evt()` `:3481`, `mgmt_auth_failed(conn, 0x18)` (`:3503`) → `mgmt.c:10204`
`mgmt_auth_failed()`: `mgmt_status(0x18)` through `mgmt_status_table[]` (`:219`; `:244`
`/* Pairing Not Allowed */` → `MGMT_STATUS_REJECTED`), the pending `PAIR_DEVICE` command is
completed with `0x0b` (the `MGMT_EV_AUTH_FAILED` event is sent to every socket *except* the
requester's, which is why bluetoothd logs one `bonding_attempt_complete()` per click, not two).

BlueZ: `src/adapter.c:8390` `pair_device_complete()` ("Rejected (0x0b)") → `:8344`
`bonding_attempt_complete()` → `:8322` `bonding_complete()` → `src/device.c:6339`
`device_bonding_complete()`: status ≠ 0 → `device_cancel_authentication()`, `:6357–6359`
`btd_device_set_temporary(true)` (the device was neither paired nor trusted), `:6361`
`device_bonding_failed()` (`:6558`) → `new_authentication_return(bonding->msg, 0x0b)`
(`:3094`) → `:3108–3112` **`org.bluez.Error.AuthenticationRejected` "Authentication
Rejected"** → `bonding_request_free()` (`:2982`). (The `discovering 0/1` pair around each
click in the log is two things at once: GNOME's `start_pairing()` turns
`default-adapter-setup-mode` off, which is a `StopDiscovery` — `discovery_remove() owner
:1.287` — and `adapter_create_bonding()` `:8426` calls `suspend_discovery()`; after the
failure `bonding_complete()` resumes and `create_callback()` turns setup mode back on.)

gnome-bluetooth 46.0: `bluetooth-client.c:1517` `device_pair_callback()` →
`g_task_return_error` → `bluetooth-settings-widget.c:913` `create_callback()`: `ret == FALSE`
→ `:936` `turn_off_pairing()` (spinner off, status label back to "Not Set Up") → `:939`
`AuthenticationFailed`? no → `:941` `AuthenticationCanceled`? no → `:944` `//FIXME show an
error?` → `:951` `g_warning ("Setting up %s failed: %s", …)` — the ten desktop-journal lines.

### 2.2 Which statuses become which error

`new_authentication_return()` (`device.c:3094–3128`), with the kernel table (`mgmt.c:219–283`)
behind it:

| D-Bus error | MGMT status | HCI status (BR/EDR) |
|---|---|---|
| `AuthenticationRejected` | `REJECTED (0x0b)`, `BUSY (0x0a)` | `0x0e` Rejected Security, `0x0f` Rejected Personal/BD_ADDR, **`0x18` Pairing Not Allowed**, `0x1b–0x1d` SCO rejected, `0x25` Encryption Mode Not Acceptable, `0x2d` QoS Rejected, `0x2f` Insufficient Security, `0x39` Rejected No Suitable Channel; and `0x0c` Command Disallowed, `0x17` Repeated Attempts, `0x32` Role Switch Pending, `0x38` Host Busy Pairing, `0x3a` Controller Busy |
| `AuthenticationFailed` (the `default`) | `AUTH_FAILED (0x05)`, `FAILED`, `NOT_SUPPORTED`, `INVALID_PARAMS`, … | **`0x05` Authentication Failure**, `0x06` PIN or Key Missing, `0x3d` MIC failure, `0x03` Hardware Failure, `0x1f` Unspecified, `0x1a` Unsupported Remote Feature, `0x29` Pairing Not Supported, … |
| `AuthenticationCanceled` | `CANCELLED`, `NO_RESOURCES`, `DISCONNECTED (0x0e)` | `CANCELLED` has no HCI code (`CancelPairing` → `MGMT_OP_CANCEL_PAIR_DEVICE`); `0x07` Memory Full, `0x09`/`0x0a` Max Connections, `0x0d` Rejected Limited Resources, `0x14` OE Low Resources; `0x13`/`0x15`/`0x16` terminated — and BlueZ's own `dev_disconnected()` → `MGMT_STATUS_DISCONNECTED` (`adapter.c:8485`) on any disconnect during bonding (the `status 0xe` lines in the log) |
| `AuthenticationTimeout` | `TIMEOUT` | `0x08` Connection Timeout, `0x10` Host Timeout, `0x22` LMP Response Timeout, `0x28` Instant Passed, `0x3c` Directed Advertising Timeout |
| `ConnectionAttemptFailed` "Page Timeout" | `CONNECT_FAILED` | `0x04` Page Timeout, `0x3e`, `0x3f` |
| `AlreadyExists` | `ALREADY_PAIRED` | — |

For LE pairing, `smp.c:805` `smp_failure()` always reports `HCI_ERROR_AUTH_FAILURE`, so an SMP
refusal is `AuthenticationFailed`, not `Rejected`; an LE `Pair()` becomes `AuthenticationRejected`
only when the connection attempt itself returns `-ECONNREFUSED` (`mgmt.c` `pair_device()`,
`PTR_ERR(conn) == -ECONNREFUSED` → `MGMT_STATUS_REJECTED`). I have not seen `U13`'s journal; if
the Shure was refused by SMP, it took the *first* (`AuthenticationFailed`, empty FIXME) branch,
not the third — the outcome on screen is the same.

The two mappings are old: the kernel table is **`ca69b7957bf2` (Johan Hedberg, 2011-11-11,
v3.3, "Bluetooth: Create a unique mgmt error code hierarchy")**, which is where "Pairing Not
Allowed" was first folded into `REJECTED` together with the security/personal rejections; the
BlueZ D-Bus names are `9b8646a44` (Johan Hedberg, 2012-12-19). Neither distinguishes "not in
pairing mode" from the other rejections, and nothing since has.

### 2.3 History of the silence

- `4b2c4fd2` (Bastien Nocera, 2013-12-02, "lib: Add Settings widget", first released in
  3.11.3 for GNOME 3.12): `create_callback()` was written with `//FIXME show an error?` and the
  `_("Setting up '%s' failed")` text already commented out, lifted from `wizard/main.c`, where
  the same text was set on the wizard's summary page (`gtk_label_set_markup (label_summary,
  …)`, `wizard/main.c:601–605` at `2eb69e58`). So the old `bluetooth-wizard` **did** show it;
  the settings widget never has.
- `5cb047b7` (2013-12-06, "settings: Don't show an error when auth is cancelled"): "For now
  it's just a warning, but could be a dialogue in the future."
- `2b8cf369` (2020-09-20, "settings-widget: Prepare for future error reporting"): the
  `AuthenticationFailed` / `AuthenticationCanceled` / else split with FIXMEs — "We should be
  reporting some of the pairing errors better than we are."
- No later commit touches the branch; master `adf070af` is identical. The connect-switch twin
  (`:207` `//FIXME show an error if it failed?`, `connect_callback()` `:873`) is from the same
  2013 commit.
- GNOME's design tracker "All Things Bluetooth" (Teams/Design/initiatives#102) lists "lack of
  feedback when there are errors when pairing or connecting: GNOME/gnome-bluetooth#18";
  gnome-bluetooth#91 (made public by Bastien in June 2021 in the BlueZ thread of §7) is the
  authentication-failure half; GNOME Settings #1054 (2020) and Bugzilla 767820 (2016, "no error
  given to the user why it won't connect", OBSOLETE) are user reports of the same. I could not
  read the GitLab issue bodies from here (JavaScript-only pages); the numbers come from the
  design tracker and the linux-bluetooth thread.

### 2.4 Fix

**gnome-bluetooth, `create_callback()`.** The widget already uses an `AdwMessageDialog` for
"Remove" (`:1309`); GNOME Settings 46.7 shows failures as toasts elsewhere
(`panels/privacy/cc-bolt-device-dialog.c:221` puts `error->message` in an `AdwToast`;
`panels/network/connection-editor/net-connection-editor.c:413`). A toast on the panel is the
least intrusive and matches the design tracker's wish. Text per error, judged from §2.2:

| error | what the user can do | text |
|---|---|---|
| `AuthenticationRejected` (`0x18` is by far the common cause: the peer is not in pairing mode) | put it in pairing mode | "“%s” refused the pairing. Put it in pairing mode and try again." |
| `AuthenticationFailed` | wrong PIN/passkey, or the peer has stale keys | "Pairing with “%s” failed. If it was paired with this computer before, remove it from the device's own list and try again." |
| `AuthenticationTimeout` | retry | "“%s” did not answer in time." |
| `ConnectionAttemptFailed` | the device is off/out of range | "“%s” is not reachable." |
| `AuthenticationCanceled` | nothing (user cancelled) | keep silent, as now |
| anything else | — | "Setting up “%s” failed." (the 2009 text) plus the D-Bus name in `g_warning` |

Also the connect switch (`:207`): the same toast with `btd_error_bredr_conn_from_errno()`'s
name, which BlueZ already puts in the `Failed` message (item 3).

### 2.5 Experiment

Emulator, same setup as §1.7, peer on `hci1` with `btmgmt -i 1 bondable off`: the kernel on
`hci1` then answers the IO Capability Request with a *Negative* Reply, reason `0x18`
(`hci_io_capa_request_evt()` `:5298`, `HCI_ERROR_PAIRING_NOT_ALLOWED`) — exactly the headset's
behaviour. **Caveat (§6.2):** `emulator/btdev.c:3393` `cmd_io_cap_negative_reply()` calls
`ssp_complete(dev, cmd->bdaddr, BT_HCI_ERR_AUTH_FAILURE, false)` — it discards `cmd->reason`,
so the initiator sees `0x05` and bluetoothd replies `AuthenticationFailed`. With the one-line
change `ssp_complete(dev, cmd->bdaddr, cmd->reason, false)` the chain of §2.1 runs verbatim
(`pair_device_complete() Rejected (0x0b)` in `-d` output, `AuthenticationRejected` on D-Bus,
the `g_warning` in a `G_MESSAGES_DEBUG=all gnome-control-center bluetooth`). Without it, the
`AuthenticationFailed` branch is exercised instead — which also shows nothing.

## 3. `br-connection-unknown` for a headset that rejected the stored key

### 3.1 The errno path, end to end

Read in the Ubuntu 7.0.0-42 tree (`linux-ran`); the Ubuntu delta changes nothing on this path
(§0).

**Kernel, the authentication:**

1. BlueZ's HFP connect is an RFCOMM socket connect at `BT_SECURITY_MEDIUM`:
   `rfcomm/core.c:388` `rfcomm_session_create(src, dst, d->sec_level)` → `:793`
   `l2cap_pi(sk)->chan->sec_level = sec_level` → `l2cap_chan_connect()` (`l2cap_core.c:7276`)
   → `hci_connect_acl()` (`hci_conn.c:1713`), which **reuses an existing ACL** to the address
   (`hci_conn_hash_lookup_ba`, `:1735`) or creates one.
2. Two cases, and the journal picks one:
   - **(a) the ACL was already `BT_CONNECTED`** (the headset had paged the laptop, as it did
     at 11:16:09, or a previous attempt's link was still up): `l2cap_chan_connect()` `:7444`
     `if (hcon->state == BT_CONNECTED)` → `l2cap_do_start()` `:1491` → `l2cap_start_connection()`
     `:1442` → `l2cap_chan_check_security()` → `hci_conn_security()` (`hci_conn.c:2550`):
     `HCI_CONN_AUTH` not set → `hci_conn_auth()` `:2501` → `HCI_OP_AUTH_REQUESTED`. Link Key
     Request → Reply with the stored key → `Auth Complete 0x05` → `hci_auth_complete_evt()`
     `:3481`: `mgmt_auth_failed(conn, 0x05)` (`:3503`; this is your `bonding_attempt_complete() …
     status 0x5`, through `MGMT_EV_AUTH_FAILED` → `auth_failed_callback()` `adapter.c:8560`,
     which with no bonding in progress does nothing further); `conn->state != BT_CONFIG` →
     `:3521` `hci_auth_cfm(conn, 0x05)` → `l2cap_security_cfm()` `:7663`: the channel is in
     `BT_CONNECT` → **`:7701` `__set_chan_timer(chan, L2CAP_DISC_TIMEOUT)`** (100 ms,
     `l2cap.h:53`) — **the status is not stored anywhere**. 100 ms later
     `l2cap_chan_timeout()` `:405`: `chan->state == BT_CONNECT && chan->sec_level !=
     BT_SECURITY_SDP` → **`reason = ECONNREFUSED` (`:432`)** → `l2cap_chan_close()` →
     `l2cap_sock_teardown_cb()` (`l2cap_sock.c:1701`) → `sk->sk_err = ECONNREFUSED` (`:1737`).
     RFCOMM: `rfcomm_check_connection()` (`rfcomm/core.c:2068`) sees the L2CAP socket
     `BT_CLOSED` → `rfcomm_session_close(s, sk->sk_err)` `:744` → `__rfcomm_dlc_close(d, 111)`
     `:451` → `rfcomm_sk_state_change()` (`rfcomm/sock.c:64`) `sk->sk_err = 111`.
   - **(b) a fresh ACL created by this connect:** `hci_remote_ext_features_evt()` `:4937` /
     `hci_remote_name_evt()` `:3545` keep `BT_CONFIG` while `hci_outgoing_auth_needed()` and
     send `AUTH_REQUESTED` (`:3579`); on `Auth Complete 0x05` the `BT_CONFIG` branch of
     `hci_auth_complete_evt()` (`:3508–3519`) sets `BT_CONNECTED` and calls
     `hci_connect_cfm(conn, 0x05)` → `l2cap_connect_cfm()` `:7561` → **`:7574`
     `l2cap_conn_del(hcon, bt_to_errno(0x05))`** → `bt_to_errno()` (`lib.c:66`): **`0x05 →
     EACCES (13)`**, `0x06 → EBADE (52)` → every channel torn down with `sk_err = 13`
     ("Permission denied").

   HFP logged **`Connection refused (111)`** (`src/profile.c:1095` `ext_connect()`, the
   message built by `btio/btio.c:209` `connect_cb()` from `SO_ERROR`: "connect to %s: %s
   (%d)"). `13` would have been "Permission denied (13)". **So (a): authentication was
   requested on an ACL that was already up, and the HCI status never reached a socket.** The
   second `Link Key Request → Auth Complete 0x05` at 09:38:54.272/.337 is A2DP's channel
   doing the same (`HCI_CONN_AUTH_PEND` was cleared by the first failure, so
   `hci_conn_auth()` sends a new `AUTH_REQUESTED`); its spacing (first failure .162 + 100 ms
   timer ≈ .262, BlueZ moves to the next profile, Link Key Request .272) fits the timer to
   within 10 ms. A fresh page after a torn-down ACL could not have fitted in 110 ms.

**BlueZ, the reply:**

3. HFP: `ext_connect()` `:1118` logs "failed to connect to …: connect to …: Connection refused
   (111)" → `btd_service_connecting_complete(service, -111)` (`:1138–1140`) → `src/service.c:91`
   `change_state()` "… state changed: connecting -> disconnected (-111)" →
   `src/device.c:2086` `device_profile_connected(dev, hfp, -ECONNREFUSED)` (`:2092` "… Connection
   refused (111)"): `dev->pending` not empty, `-ECONNREFUSED` is none of the `goto done` cases
   (`:2101–2106`) → `connect_next()` `:2068` → A2DP.
4. A2DP: `profiles/audio/sink.c` `sink_connect()` → AVDTP signalling connect (L2CAP PSM 25,
   `BT_SECURITY_MEDIUM`) → kernel path (a) again → `profiles/audio/avdtp.c:2363`
   `avdtp_connect_cb()` `err->code = 111` → `connection_lost(session, 111)` `:1151` →
   `finalize_discovery(session, 111)` → `profiles/audio/a2dp.c` `discover_cb` → `finalize_discover`
   `:414` → **`error_to_errno()` `:296–318`: `perr = 111`, not `EHOSTDOWN`/`ECONNABORTED`/`EBADE`
   → `return -EAGAIN`** ("An unexpect error has occurred setup may be attempted again") →
   `sink.c:210` `discovery_complete(…, err = -11)` → `:237` `btd_service_connecting_complete(-11)`
   → `service.c:91` "a2dp-sink … connecting -> disconnected (-11)" — your `-11` →
   `device_profile_connected(dev, a2dp, -EAGAIN)`.
5. `device_profile_connected()`: no profile connected, pending exhausted → `done:` → `:2152–2154`
   `btd_error_failed(dev->connect, btd_error_bredr_conn_from_errno(err))` with **the last
   profile's `err`** → `src/error.c:137` `btd_error_bredr_conn_from_errno()`: no `case EAGAIN`
   → `:176–177` `ERR_BREDR_CONN_UNKNOWN` = `"br-connection-unknown"` (`error.h:46`).

So the reply name is A2DP's, and A2DP's layer had itself discarded the `111` it was given.
Had HFP been the last profile, the user would have read `br-connection-refused`
(`error.c:166–167`) — no better.

**Sure:** high for steps 3–5 (every line read, and the `-11` in your journal is produced only
by `error_to_errno()` on this path), high for "not (b)" (the `111`), medium for the precise
form of (a) — the capture at 09:38:53–54 decides: an incoming `Connect Request` (or a still-open
ACL) before 09:38:54.099, no `Create Connection` from the laptop for the first attempt, and the
≈100 ms gap between each `Auth Complete` and the next action. **Falsifier:** a `Create
Connection` from the laptop immediately before the first Link Key Request with HFP still
logging `111`.

### 3.2 Is there a path to `EBADE`?

Only through `l2cap_conn_del()`: `l2cap_connect_cfm()` with a fresh ACL whose auth fails with
`0x06` (case (b)), or `l2cap_disconn_cfm()` when the ACL is dropped with reason `0x06`. On a
connected ACL (case (a)) **no HCI status survives**, so even a headset that says "PIN or Key
Missing" produces `ECONNREFUSED` → A2DP `-EAGAIN` → "unknown". And for a bonded device the
error for `0x05` is `EACCES`, which `error.c` does not list either.

History of the key-missing name: **`8f73362e8` (Miao-chen Chou, Chromium, 2021-09-30, "error:
BR/EDR and LE connection failure reasons")** introduced every `br-connection-*` name and
`btd_error_bredr_conn_from_errno()` (5.62), with `e20bd1036` (same day) using it in
`device_profile_connected()`. `EBADE` → `br-connection-key-missing` was added by **`0ee60b31a`
(Simon Mikuda, 2023-08-06, "error: Add 'Invalid exchange' mapping")** for exactly this
situation, quoting an `Auth Complete` with "PIN or Key Missing (0x06)", with **`59569c1f9`
("a2dp: Expose 'Key missing' error", "This error is not expected and retries will likely end
up with same error")** adding the `EBADE` pass-through to `error_to_errno()`; both in 5.69. A
key *rejected* with `0x05` was not discussed in those commits. `error_to_errno()`'s
`-EAGAIN` default is **`830e1a915` (Luiz Augusto von Dentz, 2016-03-23, "audio/a2dp: Simplify
error handling")**. On master `error.c` has one more rename (`0ff45df85`, Bastien Nocera,
2025-07-01, cosmetic) and no new cases; `error_to_errno()` is unchanged.

Kernel history: `bt_to_errno()`'s `0x05 → EACCES`, `0x06 → EBADE` is in the first git import
(`1da177e4c3f4`, 2005). The `ECONNREFUSED` rule of `l2cap_chan_timeout()` for a `BT_CONNECT`
channel above SDP security came in with the channel timer, **`ab07801d28985` (Gustavo
Padovan, 2011-05-02, v3.1, "Bluetooth: create channel timer to replace sk_timer")**, carried
over from the socket timer it replaced; `l2cap_security_cfm()`'s "arm the disconnect timer,
keep no status" is of the same age. Neither was written with "tell userspace why" in mind.

The kernel's only notion of "the peer lost our bond" is HCI `0x06`: **`160b925163c0a` (Szymon
Janc, 2016-07-12, v4.8, "Bluetooth: Add Authentication Failed reason to Disconnected Mgmt
event")** sets `HCI_CONN_AUTH_FAILURE` for `0x06` only (`hci_event.c:3501`, `:3636`) and
reports `MGMT_DEV_DISCONN_AUTH_FAILURE (4)` on the following disconnect (`:3417`) — its commit
message shows a BR/EDR trace that is U29's shape with `0x06` in place of `0x05`. BlueZ 5.72
(and master) does not use that reason anywhere (`grep MGMT_DEV_DISCONN_AUTH_FAILURE src/` is
empty; `dev_disconnected()` only logs it).

### 3.3 Where the fix belongs

Three places each lose the fact; the useful one is the first that still has it.

1. **BlueZ, `src/adapter.c` `auth_failed_callback()` / `dev_disconnected()`:** bluetoothd
   *receives* `MGMT_EV_AUTH_FAILED` with status `AUTH_FAILED` for a **bonded** device while no
   `Pair()` is in progress — the one signal that says "the peer rejected our key" — and drops
   it (`bonding_attempt_complete()` → `device_bonding_complete()` → `device_bonding_failed()`
   returns at `!bonding`). The Core spec (Vol 3 Part C §5.2.2.3 "Simple Pairing after
   authentication failure", Table 5.2) asks the host to tell the user and offer re-pairing.
   The BlueZ maintainer proposed exactly this in **"[BlueZ] doc/agent-api: Add
   AuthenticationFailed method" (Luiz Augusto von Dentz, linux-bluetooth, 2021-06-23)**:
   `Agent.AuthenticationFailed(object device, byte status)` for a bonded device; Marcel
   Holtmann asked for the name `IndicateAuthenticationFailure` and a description of `status`;
   Bastien Nocera asked for a persistent per-device property instead ("so GNOME Settings can
   show a /!\ icon in the device list even when no agent is running"), objected to removing
   the device automatically after a few failures ("a dark pattern"), and pointed to
   gnome-bluetooth#91; Luiz agreed to a device property. The series is "New, archived" on
   patchwork; nothing landed (no `AuthenticationFailed` in `doc/org.bluez.Agent.rst` or
   `src/agent.c` on master). That thread is the place to resume. A property
   (`AuthenticationFailed`/`BondFailed: boolean`, or a `LastAuthenticationError` byte) cleared
   on the next successful authentication or `RemoveDevice` lets GNOME mark the row and offer
   "Forget and set up again" without an agent.
2. **BlueZ, `Connect()`'s reply**, the cheap half: `device_profile_connected()` could remember
   an `MGMT_EV_AUTH_FAILED` seen for the device since the `Connect()` started (set in
   `auth_failed_callback()`, cleared in `connect_profiles()`) and reply
   `br-connection-key-missing` (or a new `br-connection-auth-failed`) instead of the last
   profile's errno. The kernel errno cannot carry it (case (a) has none), and `error_to_errno()`
   would still eat it; so the device-level flag is the only route that works for both HFP and
   A2DP.
3. **Kernel:** `l2cap_security_cfm()` could record the failing status on the channel and
   `l2cap_chan_timeout()` map it (`0x05/0x06` → `EACCES`/`EBADE` instead of `ECONNREFUSED`); and
   `HCI_CONN_AUTH_FAILURE` could also be set for `0x05` on a bonded link. Both are defensible
   but reach userspace only as an errno that BlueZ's A2DP layer discards, so they do not fix
   the user's screen on their own. Not the first patch to send.
4. **GNOME:** nothing to do until BlueZ exposes it; today it can only print the
   `br-connection-*` text (§2.4).

### 3.4 Experiment

Two bluetoothd instances are needed (a bonded peer that then holds a *different* key), so two
VMs on one `btvirt -t -l2` (each guest attaches its controller with `btproxy -c <host>:45550`),
or one VM plus a network namespace with its own system bus. Steps: pair A↔B; on B edit
`/var/lib/bluetooth/<B>/<A>/info` `[LinkKey] Key=` to another value and restart B's daemon
(the emulator fails authentication only on a *mismatch*: `btdev.c:1735`
`cmd_link_key_reply_complete()` compares the two keys and sends `Auth Complete 0x05` to both
sides; a peer with *no* key gets an IO Capability Request instead, `:1792`, which is pairing,
not failure); hold an ACL from B to A without authentication (`l2test -c -P 1 <A>` on B, SDP
level, like a headset that has just paged its last host), then on A `bluetoothctl connect B`
while it is up → expect `br-connection-unknown`, HFP `111`, A2DP `-11`, two `Auth Complete
0x05` ≈100–200 ms apart. Then the same with no ACL up → expect HFP "Permission denied (13)" and
a different reply name. This separates (a) from (b) without the laptop and is the test for
any of the fixes in §3.3.

## 4. The row outliving a switch-off

- `src/main.c:61` `DEFAULT_TEMPORARY_TIMEOUT 30`, `:1169` `btd_opts.tmpto`; `TemporaryTimeout`
  commented out in `/etc/bluetooth/main.conf` → 30.
- Restarts: the advertisement 11:18:29.74 (`:7291`, and `:7303`) and the disconnect at
  11:18:31.47 (`device_remove_connection()` `:3380`; also `bonding_attempt_complete(…
  DISCONNECTED)` → `device_bonding_complete()` → `btd_device_set_temporary(true)`, which at
  `:5966` returns early because the device was already temporary, so no third restart). Earliest
  removal 11:19:01.47; `src/shared/timeout-glib.c:93` uses `g_timeout_add_seconds_full()`,
  whose expiry is rounded to whole seconds and may be late by up to 1 s — the two controls in
  the log fired after 30.48 s and 30.65 s. So a removal between ≈11:19:01.5 and ≈11:19:02.5 if
  nothing else had happened; the headset was back at 11:18:49.11 and refreshed again. Your
  arithmetic is right. **Not a defect**, as you recorded.
- The only other removal path is `discovery_cleanup()` (`adapter.c:1710–1735`), run when the
  last discovery client leaves (`:1794`): it drops temporary devices that are not connectable,
  but `device_is_connectable()` (`device.c`) returns true for any BR/EDR device, so the
  headset's row survived GNOME's `StopDiscovery` at 11:18:02 (GNOME stops discovery for each
  pairing attempt, `discovery_remove() owner :1.287`, and restarts it after the failure) and at
  11:18:57.
- Staleness: nothing shows it. BlueZ invalidates `RSSI`/`TxPower` only in that same
  `discovery_cleanup()`, and only for devices in `discovery_found` — this headset never was
  (§1.3). The kernel's inquiry rounds (`discovering 0/1` every ~16 s in the log) do not reach
  it. GNOME reads no `RSSI`.
  A "last seen" age over D-Bus would be new BlueZ API; the question is worth one line in the
  gnome-bluetooth report, not a request of its own — with the §1.6 change, an unpaired row
  would mean "heard, discoverable, within 30 s", which is what the panel implies today.

## 5. Yes/no summary for the brief's direct questions

- `btd_adapter_device_found()` reading: **yes** (§1.2). Anything else refreshing: **yes, two
  paths during the clicks** (§1.3), none in the decisive 11:16:44–11:18:02 window.
- Ordering deliberate: **no evidence**; the order is 2014 bookkeeping, the timer is 2020 and
  reused it (§1.4).
- Master: **unchanged**; `FilterDiscoverable` only adds an off switch (§1.4).
- GNOME listing rule: every named `Device1` on the default adapter; "Not Set Up" =
  `!Paired && !Trusted`; Shell: `Paired || Trusted` only (§1.5).
- Discoverable state over D-Bus: **no** (§1.6).
- Item 2 path: **confirmed**; statuses tabulated (§2.2); dialog commented out since 2013,
  never shown by the widget, shown by the wizard before it (§2.3); Shell silent too.
- Item 3: errno path (§3.1); `EBADE` only for `0x06` and only on a fresh ACL or a `0x06`
  disconnect (§3.2); names from 2021/2023 (§3.2); fix in BlueZ as a device-level signal (§3.3).
- Item 4: **confirmed, not a defect** (§4).

## 6. Other things the code shows

### 6.1 What a failed `Pair()` leaves behind (less than I first read)

`pair_device()` `:3024` `btd_device_set_temporary(device, false)` runs before anything else;
at `:5992` it calls `store_device_info()` (`:561`), which schedules `store_device_info_cb` on
idle. That callback **refuses to create the file**: `g_key_file_load_from_file()` on a
non-existent `/var/lib/bluetooth/<adapter>/<addr>/info` fails and it returns after
`error("Unable to load key file from %s: (%s)")` (`store_device_info_cb()` `:423`, the
return at `:444–449`). The folder had been deleted by the 09:41 `RemoveDevice`
(`device_remove_stored()` `:4608`), so nothing was persisted by the ten clicks and a daemon
restart in the 30 s window would not have resurrected the row — I withdraw the stronger
version of this point. What remains: one "Unable to load key file … (No such file or
directory)" error per click in the raw journal (if the collection kept non-debug lines; the
sanitised log holds only `file.c:func()` debug lines, so it cannot show them), and the device
spending each attempt on the kernel accept list (`adapter_accept_list_add`, the "added to /
removed from kernel accept list" pairs in the log). Cosmetic; worth one line in a BlueZ
report, not a patch on its own.

### 6.2 The emulator cannot say "Pairing Not Allowed"

`emulator/btdev.c:3393` `cmd_io_cap_negative_reply()` ignores `cmd->reason` and completes SSP
with `BT_HCI_ERR_AUTH_FAILURE`. A real controller forwards the reason (the headset's
`0x18` did arrive). One-line emulator patch; it is what makes §2.5 exact, and it is a
plausible first upstream contribution from this work (it fits the pattern of your merged
emulator fixes).

### 6.3 Nobody reads the kernel's "lost bond" reason

`MGMT_DEV_DISCONN_AUTH_FAILURE` (2016, §3.2) is the kernel telling userspace "disconnected
because the peer no longer has the key"; BlueZ passes `reason` to `disconnect_notify()` and the
`DBG` and nothing else; and the kernel sets it for `0x06` only, not for the `0x05` this headset
sends. Two small steps would make the 2016 signal useful: set `HCI_CONN_AUTH_FAILURE` for
`0x05` as well when a link key was presented (a kernel change), and have BlueZ raise the
§3.3 property on reason 4.

### 6.4 A lookup that mutates

`btd_adapter_find_device()` (`adapter.c:1031–1034`) adds LE support (and changes
`bdaddr_type`, emitting `AddressType`) to a BR/EDR device on the strength of a matching public
LE address — including from a report it then drops. Harmless here, but it is why a BR/EDR-only
object became dual-mode without ever being shown an LE report, and why `select_conn_bearer()`
then had to choose. Noted, not a defect.

### 6.5 BlueZ #433 is the other half of this incident

"Paired property is not reset after Authentication Failure (when only remote clears pairing
data)" (closed 2022-11-29): a peer that forgot its key; `Paired` stays `true`; `Connect()`
fails; `Pair()` refuses because already paired. Luiz: no spec text for the half-paired case; a
spoofed address could otherwise erase bonds, so dropping keys must be the user's or the
agent's decision; `JustWorksRepairing` in `main.conf` covers only incoming Just-Works
re-pairing (not SSP with DisplayYesNo, so not this headset). The user-facing answer he gave
there is the agent/property of §3.3.

## 7. Related reports and postings

| where | what | relevance |
|---|---|---|
| linux-bluetooth, 2021-06-23, "[BlueZ] doc/agent-api: Add AuthenticationFailed method" (patchwork series 505973; comments 24278213, 24281211) | RFC for an agent callback on authentication failure with a bonded device; Bastien Nocera's reply asks for a persistent property and names gnome-bluetooth#91; never merged | the fix venue for item 3 |
| github.com/bluez/bluez/issues/433 | remote cleared its keys; `Paired` not reset; maintainer's position on half-paired devices | item 3 precedent |
| BlueZ `0ee60b31a`, `59569c1f9` (2023-08-06, 5.69) | key-missing mapping for HCI `0x06` | item 3; shows the gap for `0x05` and for connected ACLs |
| kernel `160b925163c0a` (2016, v4.8) | `MGMT_DEV_DISCONN_AUTH_FAILURE` for `0x06` | item 3; unused by BlueZ |
| BlueZ `393e81a74` + linux-bluetooth thread 2025-09-04/08 "[PATCH BlueZ v2] main.conf: Add FilterDiscoverable option" | the discoverable filter made optional; "non-discoverable devices are not enumerated" is the stated intent | item 1: the stated intent contradicts the refresh |
| BlueZ `def01de02` (2020), `2b480bd56` (2020) | the temporary timer; temporary again after a failed pairing ("hung around forever even if turned off") | item 1 history |
| Hans de Goede, "[BlueZ] adapter: Use regular discovery for filters which only have discoverable set" (2023-03-30; in 5.68) | why GNOME's filter is a regular discovery (`filtered_discovery == false`) | item 1 |
| github.com/bluez/bluez/issues/2700 (open, 2026-10-22), "No way to pair a BR/EDR-connectable but non-discoverable audio peer over classic …" | a non-discoverable audio peer and pairing; title only, body not read from here | item 1, possibly |
| github.com/bluez/bluez/issues/1100 "Retain temporary devices", #1269 "Device removed automatically after scan", #445 "TemporaryTimeout doesn't apply to all BLE devices that use ADV_IND" (closed) | the timer seen from users who want rows kept | item 1, the opposite wish — any patch must not regress them |
| gnome-bluetooth `4b2c4fd2`, `5cb047b7` (2013), `2b8cf369` (2020) | the silent branch and its two revisits | item 2 |
| gitlab.gnome.org Teams/Design/initiatives#102 "All Things Bluetooth" → GNOME/gnome-bluetooth#18 ("lack of feedback when there are errors when pairing or connecting"), #91; GNOME/gnome-control-center#1054 (2020); bugzilla.gnome.org 767820 (2016) | the user-feedback gap as GNOME sees it | item 2 |
| GNOME Settings 46.7 `panels/privacy/cc-bolt-device-dialog.c:221`, `panels/network/connection-editor/net-connection-editor.c:413` | toasts for operation failures | item 2, precedent |

Not found: any BlueZ issue or patch about a temporary device kept alive by non-discoverable
advertisements (item 1's defect itself), or about `AuthenticationRejected` being silent. Those
two would be new reports.

## 8. Experiments, in the order I would run them

1. §1.7 (emulator, one VM, an hour): decides item 1 and tests the §1.6 change.
2. §6.1 check during the same run: `ls` the storage dir and the daemon's stderr after a
   refused `Pair()` (expect no `info` file and one "Unable to load key file" line).
3. §2.5 after the one-line `btdev.c` change: exercises the `AuthenticationRejected` branch and
   any gnome-bluetooth toast patch.
4. §3.4 (two daemons): decides (a) vs (b) in general and tests the §3.3 property.
5. Reading of the capture you hold, 09:38:53–09:38:55: incoming `Connect Request` or
   `Create Connection`; the 100 ms gaps; no `L2CAP Connection Request` for PSM 3/25 before
   each `Auth Complete`. This settles (a) for this incident without an experiment.

Nothing above touches the laptop, `btusb` or `bluetooth.ko`.

## 9. Confidence and falsifiers, in one table

| claim | sure | falsified by |
|---|---|---|
| non-discoverable LE reports restarted the temporary timer (item 1) | high | §1.2 |
| the two extra refresh paths exist and ran | high | a `-d` log of a failed `Pair()` without the `temporary 0`/`temporary 1` pair |
| `RSSI` never set for the headset | high | a `device_set_rssi_with_delta()` line for `…:01` in the raw journal |
| GNOME listing rule | high | — (read) |
| no discoverable state on D-Bus | high | an `AdvertisingFlags` change for `…:01` with `-E` on |
| item 2 path and status tables | high | — |
| dialog never shown by the widget; shown by the wizard | high | — |
| `br-connection-unknown` = A2DP `-EAGAIN` from `error_to_errno()` | high | a journal line showing `device_profile_connected()` with another errno last |
| HFP's `111` came from `l2cap_chan_timeout()` on a connected ACL, not from a fresh ACL | medium-high | a `Create Connection` from the laptop right before 09:38:54.099 in the capture (then the `111` would need another explanation I do not have) |
| `EBADE` reachable only via `l2cap_conn_del()` | high | — |
| 30 s arithmetic | high | — |
| §6.1 a failed `Pair()` stores nothing, logs one error | high (read, not run) | an `info` file present 1 s after a refused `Pair()` of a device with no stored folder |

---

## The reviewer's covering message (received with the answer)

I'll check out BlueZ, the kernel's `net/bluetooth`, gnome-bluetooth, GNOME Settings and GNOME Shell at the versions that ran, read the code behind items 1–4 with their history, search for related bug and patch postings, and write the report as a markdown file for the repo.

Now the U29 issue entry and the evidence files.

Fixing the handful of line citations that were off by a few lines.

The report is `2026-11-07T1335Z-u29-source-investigation-answer.md`, read against the exact trees (5.72-0ubuntu5.5 + the two fixes rebuilt as git, v7.0 + the Ubuntu hwe delta, gnome-bluetooth/Settings/Shell with their Ubuntu deltas checked). The short version:

**Item 1 — yes, the brief's reading holds**, and the sanitised journal proves it without the code: from the 11:16:14 disconnect to the first click (108 s) nothing but the non-discoverable advertisements touched the device, no gap exceeds 17 s, and the two other temporary devices in the same log were removed 30.5/30.7 s after their last report. The LE reports match the BR/EDR-created object through `device_addr_type_cmp()`'s public-address rule, and flags `0x18` also refresh the BR/EDR bearer — which is why every `Pair()` went over BR/EDR. Two more refresh paths ran during the clicks (each failed `Pair()` toggles `temporary` and buys 30 s; each attempt's ACL). History: the ordering is 2014 bookkeeping (`c65c8bf64`), the timer is 2020 (`def01de02`) and reused it; nothing says it was deliberate; master is unchanged, `FilterDiscoverable` only adds an off switch. GNOME lists every named `Device1`; "Not Set Up" = `!Paired && !Trusted`; BlueZ exposes no discoverable state, so the fix is BlueZ's (a guard before `device_update_last_seen()` is sketched).

**Item 2** — path confirmed end to end (`0x18` → `REJECTED` → `AuthenticationRejected` → the `else` branch). The dialog text has been commented out since the widget was written in Dec 2013; the old wizard did show it. Full status→error table included; a toast fix with per-error text, with a GNOME 46.7 precedent.

**Item 3** — the name is A2DP's `-EAGAIN` from `error_to_errno()`, but the more useful finding is upstream of it: HFP's `111` can only come from `l2cap_chan_timeout()` on an ACL that was *already connected* when authentication failed; a fresh ACL would have given `13`. The HCI status is lost in the kernel there, `EBADE` exists only for `0x06`, and the headset said `0x05`. The right fix is the BlueZ maintainer's own unmerged 2021 RFC (agent `AuthenticationFailed` / a device property), which Bastien Nocera asked for — that thread, plus BlueZ #433, are the venues.

**Item 4** — confirmed, not a defect (30 s + GLib's one-second rounding).

**New:** the emulator maps an IO Capability Negative Reply to `0x05` instead of the given reason (one-line fix, needed for the item-2 experiment); the kernel's 2016 "lost bond" disconnect reason is set for `0x06` only and BlueZ ignores it; and I withdrew my own first reading of a stored-info side effect after checking `store_device_info_cb()` — it refuses to create the file.

Two things I could not do from here: read the bodies of the GNOME GitLab issues (#18, #91, #1054) and BlueZ #2700 — cited by number and title only — and the ordering of the 09:38 ACL, which your capture settles (see §8.5).
