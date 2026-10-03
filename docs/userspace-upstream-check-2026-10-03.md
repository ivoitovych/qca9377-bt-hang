# U7 / U6 upstream check — 2026-10-03

Read-only check of the upstream trees cached under `cache/` against the two userspace
issues recorded in `docs/issues.md` (U7, U6) and the rows in `docs/STATUS.md`. Every
statement is marked **[quoted]** (command + verbatim output, trimmed only where marked
`…`) or **[inferred]** (this check's reading of the quoted material). No machine-side
Bluetooth, PipeWire or audio tool was run; nothing tracked was modified. The only
side effects are `git fetch` operations on three cache clones (below).

**Method note (bounded-search rule, BRIEF §8a).** The GNOME Settings clone was
*shallow*; its `47.0` was a graft point, so `tag --contains` and range queries on it were
unreliable until it was deepened. Every GNOME result below was produced **after**:

```
$ git -C /root/exp/qca9377-bt-hang/cache/gnome-control-center-upstream rev-parse --is-shallow-repository
true
$ git -C /root/exp/qca9377-bt-hang/cache/gnome-control-center-upstream fetch --unshallow origin
(… ~34 KB of new tags/commits …)
$ git -C /root/exp/qca9377-bt-hang/cache/gnome-control-center-upstream rev-parse --is-shallow-repository
false
```

The PipeWire and libgnome-volume-control clones were full (`false` for both, same command).

---

## U7 — PipeWire skips the SCO setup after an HFP codec switch under an active link

### U7.1 Tree state

[quoted]
```
$ git -C /root/exp/qca9377-bt-hang/cache/pipewire-upstream fetch origin
From https://gitlab.freedesktop.org/pipewire/pipewire
   662fe053a..702a11de5  master     -> origin/master
   e7834a15d..682b97101  1.6        -> origin/1.6
$ git -C /root/exp/qca9377-bt-hang/cache/pipewire-upstream fetch origin --tags
$ git -C /root/exp/qca9377-bt-hang/cache/pipewire-upstream log -1 --format=%H%n%ad%n%s origin/master
702a11de5b6bd48dcd358d000588dfa1618174c9
Mon Sep 28 01:59:14 2026 +0000
bluez5: don't reply to method calls that don't expect a reply
```

The tag is `1.0.5`, not `v1.0.5` (`git log v1.0.5..origin/master` fails with
`fatal: bad revision 'v1.0.5..origin/master'`; `git tag -l "1.0.*"` lists `1.0.0` … `1.0.9`).

### U7.2 Commits since 1.0.5 in `spa/plugins/bluez5`

[quoted] `git -C /root/exp/qca9377-bt-hang/cache/pipewire-upstream log --oneline 1.0.5..origin/master -- spa/plugins/bluez5`
returns several hundred lines (not counted; kept in the session, not reproduced here). The
subset whose subject touches codec switching, `+BCS`/`AT+BCS`, SCO, transport acquire or
release, with the first release tag that contains each (`git tag --contains <id>`, first
entry quoted):

| id | subject | first tag |
|---|---|---|
| `6982bb8c7` | bluez5: backend-native: set best codec also when retrying on timeout | `1.5.81` |
| `9f34e962a` | bluez5: backend-native: don't hardcode available HFP codecs | `1.5.81` |
| `3f9fb8d66` | bluez5: bluez5-device: reduce special casing of HFP codec related things | (same series) |
| `83f6d719b` | bluez5: remove HFP codec id from transports | (same series) |
| `5b4e9dc33` / `665a27f28` | bluez5: replace sco-sink / sco-source with media-sink / media-source | (same series) |
| `f6fc30763` | bluez5: backend-native: Support legacy audio connection | `1.5.81` |
| `f46852908` | spa: bluez: backend-native: Fix audio connection policy for HSP/HFP | (Nov 2025) |
| `e15e50c5e` | spa: bluez: backend-native: Prevent HSP/HFP connection in both directions | (Dec 2025) |
| `7dd2c60b1` | bluez5: synchronize transport state after acquire of an acquired transport | (Nov 2025) |
| `8e62b08e5` | bluez5: hfp-hf: don't change hf_state after sending AT+BCS | (HF role only) |
| `656ebcfcb` | bluez5: fix handling of multiple transports for same profile | `1.3.81` |
| `d80b80602` | bluez5: reset the transport error count on a successful acquire | **none** (master only) |
| `b7246d0d5` | bluez5: deal with asynchronous device and node removal | **none** (master only) |

[quoted] `git -C … tag --contains b7246d0d5` and `… --contains d80b80602` both print nothing;
`git -C … branch -r --contains d80b80602` → `origin/HEAD -> origin/master`, `origin/master`.

[quoted] The 1.0 stable branch after 1.0.5 carries no related change:
```
$ git -C /root/exp/qca9377-bt-hang/cache/pipewire-upstream log --oneline 1.0.5..1.0.9 -- spa/plugins/bluez5
f5d544d99 bluez5: don't exit if system DBus goes down
bdae0b2ff bluez5: add quirk for Phonak hearing aids
55dc9c3c2 bluez5: backend-native: Handle AT+CCWA command
233565734 bluez5: media-sink: keep one more buffer free
513495eaa bluez5: drop queued data on node stop
f524271b8 treewide: fix errno assignments
```

**Verdict on each candidate [inferred from the quoted diffs]:**

- `6982bb8c7` changes only the *initial-setup retry* path (`codec_switch_timer_event`,
  `HFP_AG_INITIAL_CODEC_SETUP_SEND`), i.e. what is sent when the headset never answers
  `+BCS:`. U7's headset answers (`AT+BCS=1` → `OK` in the capture). Not a fix. Diff lines that
  matter:
  ```
  -		rfcomm->hfp_ag_initial_codec_setup = HFP_AG_INITIAL_CODEC_SETUP_WAIT;
  -		rfcomm_send_reply(rfcomm, "+BCS: 2");
  +		best_codec = codec_list_best(backend, &rfcomm->supported_codec_list);
  +		if (best_codec && best_codec->id != SPA_BLUETOOTH_AUDIO_CODEC_CVSD) {
  ```
- `9f34e962a`/`3f9fb8d66`/`83f6d719b`/`5b4e9dc33`/`665a27f28` rewrite the HFP codec plumbing
  (media_codec API, media-sink replaces sco-sink) without changing the switch *sequence*:
  on master the `AT+BCS=` handler still reads
  ```
  $ git -C … grep -n -A48 "AT+BCS=%u" origin/master -- spa/plugins/bluez5/backend-native.c
  …1255-		/* Recreate transport, since previous connection may now be invalid */
  …1256-		if (rfcomm_new_transport(rfcomm, selected_codec) < 0) {
  …1263-		spa_bt_device_connect_profile(rfcomm->device, rfcomm->profile);
  …1266-		rfcomm_send_reply(rfcomm, "OK");
  …1267-		if (was_switching_codec)
  …1268-			spa_bt_device_emit_codec_switched(rfcomm->device, 0);
  ```
  i.e. the same "free old transport, create new one, let the nodes acquire it" design as 1.0.5.
- `f6fc30763`, `f46852908`, `e15e50c5e`: legacy (no codec negotiation) AGs, SCO-listen policy,
  bidirectional HSP/HFP. Not the codec-switch path.
- `7dd2c60b1`: only the `transport->acquired` branch with keepalive (a transport that is still
  acquired). After a switch the new transport is fresh. Not a fix.
- `8e62b08e5`: PipeWire in the **HF** role (`hfp_hf_*` states). U7 is the AG role.
- `d80b80602` + `b7246d0d5`: the fix for upstream issue #5467 (see U7.5). They address error
  bookkeeping on `media-sink` when `set_profile()` releases a transport under a node that is
  still alive. **On 1.0.5 the HFP nodes are `sco-sink`/`sco-source`, which do not book such an
  error** — quoted:
  ```
  $ git -C … grep -n -A16 "^static void transport_state_changed" 1.0.5 -- spa/plugins/bluez5/sco-sink.c
  …1370-	if (state == SPA_BT_TRANSPORT_STATE_ACTIVE)
  …1371-		transport_start(this);
  …1372-	else if (state < SPA_BT_TRANSPORT_STATE_ACTIVE)
  …1373-		transport_stop(this);
  …1374-
  …1375-	if (state == SPA_BT_TRANSPORT_STATE_ERROR) {
  ```
  (only *reacts* to ERROR, never sets it), whereas 1.0.5's A2DP `media-sink.c:1976-1979` does
  (`"transport becomes inactive: stop and indicate error"` → `set_state(…ERROR)`). So the
  #5467 mechanism exists on 1.0.5 for **A2DP↔HFP** switches but not for the **mSBC↔CVSD**
  switch of U7. Also, U7 fails on the *first* switch under a live link, and #5467 needs three
  bookings within six seconds.

**Answer to task 1: no commit between 1.0.5 and `702a11de5` plausibly fixes U7 as recorded.**

### U7.3 The 1.0.5 code path for a codec switch while a transport is acquired

All line numbers at tag `1.0.5` [quoted from `git show 1.0.5:<file>` and `git grep -n … 1.0.5`].

1. `spa/plugins/bluez5/bluez5-device.c: set_profile()` (1156–1235). For an HFP codec change:
   ```
   1173	emit_remove_nodes(this);
   1175	spa_bt_device_release_transports(this->bt_dev);
   …
   1208	} else if (profile == DEVICE_PROFILE_HSP_HFP && get_hfp_codec(codec) && !(this->bt_dev->connected_profiles & SPA_BT_PROFILE_HFP_AG)) {
   1211		this->switching_codec = true;
   1213		ret = spa_bt_device_ensure_hfp_codec(this->bt_dev, get_hfp_codec(codec));
   ```
2. `bluez5-dbus.c: spa_bt_device_release_transports()` (2981–2987) → `spa_bt_transport_release_now()`
   (2964–2979) → backend `release` → `backend-native.c: sco_release_cb()` (1634–1651):
   `set_state(IDLE)` (1642) then `sco_destroy_cb(t)` (1648) which does `shutdown(); close(t->fd)`
   (1624–1628). **Closing the SCO socket is what makes the kernel send `HCI Disconnect` for
   the old handle** [inferred: there is no other disconnect call on this path].
3. `backend-native.c: backend_native_ensure_codec()` (2093–2128): `rfcomm_send_reply(rfcomm, "+BCS: %u", codec)`
   (2118), `hfp_ag_switching_codec = true` (2121), 20 s timer (2122).
4. Headset answers → `rfcomm_hfp_ag()` branch `sscanf(buf, "AT+BCS=%u", …)` (898–937):
   ```
   918		/* Recreate transport, since previous connection may now be invalid */
   919		if (rfcomm->transport)
   920			spa_bt_transport_free(rfcomm->transport);
   922		rfcomm->transport = _transport_create(rfcomm);
   931		rfcomm->transport->codec = selected_codec;
   932		spa_bt_device_connect_profile(rfcomm->device, rfcomm->profile);
   935		rfcomm_send_reply(rfcomm, "OK");
   936		if (was_switching_codec)
   937			spa_bt_device_emit_codec_switched(rfcomm->device, 0);
   ```
5. `bluez5-device.c: codec_switched()` (1237–1271): `emit_remove_nodes(this); emit_nodes(this);`
   (1259–1260) — new sink/source nodes bound to the new transport.
6. A stream links to a node → `sco-sink.c:731-734` (`do_accept = profile & HEADSET_AUDIO_GATEWAY`,
   false for a headset → connect) → `bluez5-dbus.c: spa_bt_transport_acquire()` (2882–2912;
   refuses with `-EIO` only when `error_count >= 3` within 6 s, 2895–2899) →
   `backend-native.c: sco_acquire_cb()` (1573–1608) → `sco_do_connect()` (1420–1475):
   `sco_create_socket()` (1441) then `connect()` (1446). Any error other than
   `EAGAIN/EINPROGRESS` → `return -1` (1468) → `set_state(ERROR)` (1606). A non-blocking
   connect is finished in `sco_ready()` (1479–1569): `SO_ERROR` read (1491–1498); on error
   `"acquire failed"` and `set_state(ERROR)` (1540–1544). A later `HUP|ERR` on the SCO fd
   (`sco_event`, 1653–1669) also runs `sco_ready()` and closes the fd.

**What the working cases show [inferred]:** the `Setup Synchronous Connection` observed
30 ms after the headset's `OK` (02:27:32 reference switch, 02:30:59 CVSD→mSBC) is step 6 — the
first stream (the Sound panel's meter or the test sound) acquiring the freshly emitted node.
PipeWire itself does not set the SCO up "as part of the switch"; a node must be acquired.

**What this check infers for the failing cases.** PipeWire's user-space path is identical
in the three failing switches and the two working ones on the earbuds, and identical on the
MOMENTUM 4 where both live-link switches succeeded. The only input that differs is timing
relative to the *old link's teardown*. The kernel side of `connect()` (Ubuntu source of the
running kernel, `cache/ubuntu-7.0.0-31/net/bluetooth/`) [quoted]:

```
$ grep -n -A60 "^struct hci_conn \*hci_connect_sco" /root/exp/qca9377-bt-hang/cache/ubuntu-7.0.0-31/net/bluetooth/hci_conn.c
1771-	sco = hci_conn_hash_lookup_ba(hdev, type, dst);
1772-	if (!sco) {
1773-		sco = hci_conn_add_unset(hdev, type, dst, 0, HCI_ROLE_MASTER);
…
1790-	if (acl->state == BT_CONNECTED &&
1791-	    (sco->state == BT_OPEN || sco->state == BT_CLOSED)) {
…
1801-		hci_sco_setup(acl, 0x00);
1802-	}
1804-	return sco;
```
and `sco.c: sco_connect()` (310–382) calls `hci_connect_sco()` (349) then `sco_conn_add(hcon)`
(357) and `sco_chan_add()` (376); `sco_conn_del()` (254–) kills the socket when the `hci_conn`
goes away.

[inferred] If `connect()` for the new codec is issued while the old (e)SCO `hci_conn` to the
same address is still in the hash — i.e. after `HCI Disconnect` was sent but **before the
`Disconnection Complete` event** — the kernel *reuses that dying connection*
(`hci_conn_hash_lookup_ba` finds it; its state is not `BT_OPEN/BT_CLOSED`), so **no
`Setup Synchronous Connection` is issued**, the socket parks in `BT_CONNECT`, and when the
`Disconnection Complete` arrives the socket is killed with an error → PipeWire's `sco_ready()`
books `ERROR` on the transport; `sco-sink`/`sco-source` stop and emit a node error; nothing
retries. That reproduces exactly "`Disconnect`, then nothing" with *no HCI command for the
new link*, and it is device-timing dependent (how fast the headset answers `AT+BCS=` versus
how fast its `Disconnection Complete` returns). If, instead, the `Disconnection Complete`
**event** (not merely the Command Status of `Disconnect`) is already in the capture before
the `OK`, then the kernel path above cannot apply and the fault is in user space — which
PipeWire's own debug log would show (`"enter sco_acquire_cb"`, `"doing connect"`,
`"connect(): …"`, `"acquire failed: …"` at `spa.bluez5.native` debug level).

**The deciding fact is already in the existing capture:** the `issues.md` table says the
`Disconnect` "completes between `+BCS:` and `AT+BCS=`"; this check could not tell from the
register whether that is the `HCI Command Status` for `Disconnect` or the
`HCI Event: Disconnect Complete` for handle 19/20. `capture-window.sh` with filter
`'Disconnect Complete|Synchronous|[+]BCS'` on the 02:30:44–02:30:47 and 02:31:12–02:31:15
windows, with timestamps, answers it without touching the machine's Bluetooth.

### U7.4 Issue tracker

[quoted] The HTML search pages are not served to a plain client:
```
$ curl -s -L -o … -w "%{http_code} %{url_effective}\n" "https://gitlab.freedesktop.org/pipewire/pipewire/-/issues?search=codec+switch+hfp"
404 https://gitlab.freedesktop.org/pipewire/pipewire/-/issues?search=codec+switch+hfp
$ curl … "https://gitlab.freedesktop.org/pipewire/pipewire/-/issues?search=mSBC+CVSD+switch"
404 …
```
The public JSON API answers (HTTP 200, `scope=all&state=all&per_page=50`); the issue notes
endpoint returns `HTTP 401` (login required), so comments were not read.

Search `codec switch hfp` (16 hits; `iid`, title, state):

| iid | title | state |
|---|---|---|
| 5467 | bluez5: a profile or codec switch is counted as a transport error, and the third one is refused | closed 2026-09-30 |
| 5465 | bluez5: auto-recover A2DP on Acquire NotAuthorized and on HFP-only reconnect (patches) | closed |
| 5449 | AirPods (004c:201b) A2DP AAC: periodic audible hiccups / spa.bluez5: Failure in Bluetooth audio transport — SBC-XQ stable on same hardware | opened |
| 5440 | bluez5 native HFP backend: Ray-Ban Meta (Gen 2) glasses drop the HFP link right after SLC because the AG does not advertise "Enhanced Call Status" | opened |
| 4968 | Bluetooth HFP Profile fails for Google Pixel Buds 2 Pro (No audio/mic) | opened |
| 3286 | Question about matching specific bluez_output in bluez-monitor.conf | closed |
| 2206 | Needs a system reboot for HFP/HSP profile to work. | opened |
| 2143 | Changing bluetooth codec in pavucontrol reverts audio to the built-in speaker | closed |
| 2016 | SPA handle 'api.alsa.acp.device' could not be loaded; is it installed? | closed |
| 1865 | Sporadic No sound (micro & hearphones) with Bluetooth Headset + pipewire/wireplumber | closed |
| 1705 | ASAN crash in pipewire impl-link.c:check_states | closed |
| 1671 | Very bad distortion & clipping (not just bad quality) after switching headset from A2SP to HFP/HSP | closed |
| 1560 | Dumbphone cannot send A2DP audio to PipeWire, SET_CONFIGURATION request rejected: Bad State | closed |
| 1481 | Low volume with HSP/HFP mode since 0.3.32 | closed |
| 1181 | Bluetooth Earbuds: sound from only one earbud in HSP/HFP mode | closed |
| 458 | (Bluetooth) Switching back from HSP/HFP to A2DP doesn't work | closed |

Search `mSBC CVSD switch` (16 hits): 5440, 5283, 5279 (Skullcandy Smokin' Buds mic not working,
RTL8723B), 5217 (Tribit StormBox A2DP transport never acquired), 4968, 4319 (Sony WH-1000XM5
mic regression+workaround), 2783 (mSBC proposed but switching to it fails, Pixel Buds Pro),
2689, 2678 (headset microphone always silent), 2206, 2092 (mSBC regression), 1934 (intermittent
mSBC playback), 1865, 1481, 1322 (hfp requires one profile switch before recording works), 1181.
Search `BCS`: only 645 (a bluetoothd a2dp-sink connect error, unrelated).

**None of the titles describes U7** (new codec's SCO never set up after a switch made under
a live link). The nearest, #5467, was read in full [quoted, trimmed]: author `spheenik`
(Martin Schrodt), created 2026-09-13, closed 2026-09-30 by `wtaymans`, 1 merge request;
reproducer is A2DP↔HFP profile cycling on pipewire 1.6.8; mechanism: `set_profile()` →
`emit_remove_nodes()` then `release_transports()`, `media-sink` still started books
`SPA_BT_TRANSPORT_STATE_ERROR`, three bookings → `spa_bt_transport_acquire()` returns `-EIO`
with "no AVDTP START, no SCO setup, and no `Acquire`". Fixed on master by `b7246d0d5` and
`d80b80602` (both 2026-09, no tag yet). As shown in U7.2 this does not cover an mSBC↔CVSD
switch on 1.0.5 (`sco-sink` books nothing), and U7 fails on the first switch.

### U7.5 Recommendation (U7)

**Needs a capture read first — then report upstream, not patch.** No upstream commit fixes
U7; the switch design (free the old transport, create a new one, let the next acquire call
`connect()`) is unchanged on master, so the defect, if it is PipeWire's, is still there — but
the recorded evidence does not yet separate "PipeWire never called `connect()`" from
"`connect()` was absorbed by the kernel because the old link's `Disconnection Complete` had
not arrived" (U7.3). Read the existing capture for the `Disconnect Complete` **event**
timestamp relative to `OK`+30 ms on the three failing switches and the two MOMENTUM
successes; that costs no machine time. If the event comes *after* the expected setup moment,
the report is "PipeWire reconnects before the old SCO is gone; the kernel reuses the dying
`hci_conn` and no `Setup Synchronous Connection` is sent" — a race PipeWire can close by
deferring the new `connect()` until the released socket's teardown completes (or retrying
once on the resulting error), and the report should go to the PipeWire tracker against 1.6.x
with the HCI excerpt, noting Ubuntu 24.04's 1.0.5 as the affected release (the 1.0 branch
got nothing in this area, U7.2). If the event comes *before*, the fault is in user space and a
`spa.bluez5*:4` debug log of one `pactl set-card-profile` switch with a stream playing is the
next capture — with the Sound panel closed, as `issues.md` already proposes, and only in a
window the operator opens. Do not cite #5467 as the same bug; cite it only as a related
switch-path defect fixed 2026-09.

---

## U6 — GNOME Settings input level meter reads the headset monitor

### U6.1 Tree state

[quoted]
```
$ git -C /root/exp/qca9377-bt-hang/cache/gnome-control-center-upstream log -1 --format=%H%n%ad%n%s origin/main
cc98ad952acb1937cdde9edffb298b4ac738fb17
Tue Sep 22 14:57:00 2026 +0200
network, connection-editor: Fall back to the current MAC address
$ git -C /root/exp/qca9377-bt-hang/cache/libgnome-volume-control-upstream log --oneline -1 --all
0a4eda0 mixer-control: Populate source state field
$ git -C /root/exp/qca9377-bt-hang/cache/libgnome-volume-control-upstream tag
(no output — the gvc repository carries no tags)
```

### U6.2 The commits that change how the panel's input meter follows the active device

[quoted] Searches requested by the task (full history):
```
$ git -C …gnome-control-center-upstream log --oneline --all -i --grep=monitor -- panels/sound
1610f04dc sound: Allow output peak meter to auto-suspend
4fbedb924 sound: Set pa_stream sink monitor for input rows
7b1af9c8b sound: Update theme directory modification time after bell sound changes
0f18a662b sound: update the volume-slider after getting a valid stream
9b81e0ee4 sound: update the profile list after getting the signal from gvc
$ git -C …libgnome-volume-control-upstream log --oneline --all -i --grep=monitor
d4eda71 gvc-mixer-source-output: Update volume and mute status
```
(`--grep=peak --grep="input level" --grep="level bar"` on `panels/sound` adds nothing newer
than `1610f04dc` that is relevant; full list kept in the session.)

[quoted] The sound-panel and gvc commits between the 46 release candidate and 47.0:
```
$ git -C …gnome-control-center-upstream log --oneline 46.rc..47.0 -- panels/sound subprojects/gvc
28f576bda sound: Give the volume levels page an empty state
a670744eb sound: Turn CcVolumeLevelsDialog into a subpage
d5897dd63 sound: Try AppInfo icon before icon name for a stream
def736cfd sound: Make AppInfo lookup a little more robust
a18eb3319 sound: Use AppInfo to get app icons and fallback to icon-theme
be7ef1319 sound: Adjust click effect
19e79cbe1 sound: Update metadata
0da10f03a sound: Don't show "No Input Devices" if an input device is present
354b6f424 general: Use gtk_widget_dispose_template instead of unparenting
ea014f24e general: Fix various strict-aliasing warnings with g_clear_pointer()
944a62daf sound: Make sliders more accessible with keyboard
b7e5ad875 sound: Remove need for translating speaker test button tooltip
b697433c7 alert-chooser-window: Remove the content-height property
6f5e3a41d sound: Port "No Input/Output Devices" rows to CcListRow
d31f8aeea volume-levels-window: Port to AdwDialog
e40880f7c output-test-window: Port to AdwDialog
88a964fe1 alert-chooser-window: Port to AdwDialog
b832a0e53 subprojects: Update gvc to latest commit
4afd08e23 sound: Don't call gvc_mixer_control_open() twice
3aeb837cb sound: Set input/output meter stream to NULL when there's no active device
afec106a8 sound: Unset active entry on the device comboBox when there's no active device
bf6f72278 sound: Update active-device UI on signals from gvc, not on combo box changes
a74bc5a84 sound: Block our own signal handlers while updating the active-device combo box
215289935 sound: Listen to signals from GvcMixerControl only in sound panel
```
and on the 46 maintenance branch:
```
$ git -C …gnome-control-center-upstream log --oneline 46.rc..46.8 -- panels/sound subprojects/gvc
92a4e4ef5 sound, volume-levels: Really filter out NULL stream names
10a72e6b6 sound, volume-levels: Only add named streams
ea22905d3 sound: Make sliders more accessible with keyboard
7ff32c929 sound: Remove need for translating speaker test button tooltip
4244d3ada subprojects: Update gvc to latest commit
```

**The fix series (Jonas Dreßler, 2024-03-07), [quoted] `git show`:**

- `bf6f72278` *sound: Update active-device UI on signals from gvc, not on combo box changes* —
  message: "Gvc is the actual 'source of truth' … we should update widget visibility and the
  input/output meter stream based on the information from gvc, not on changes to the combo
  box. … This fixes a few bugs where the stream for the input/output meter wouldn't get
  updated properly on active device changes." The load-bearing hunk in
  `panels/sound/cc-sound-panel.c: input_device_update_cb()`:
  ```
  -  if (cc_volume_slider_get_stream (self->input_volume_slider) == NULL)
  +  if (device)
       stream = gvc_mixer_control_get_stream_from_device (self->mixer_control, device);
     if (stream != NULL)
       set_input_stream (self, stream);
  ```
- `3aeb837cb` *sound: Set input/output meter stream to NULL when there's no active device* —
  removes the `if (stream != NULL)` guard so `set_input_stream (self, stream)` always runs:
  "This fixes a bug where the input/output meter doesn't get updated when the active input or
  output device gets unset."
- `a74bc5a84` *Block our own signal handlers while updating the active-device combo box*
  ("fixes a recursive call to gvc_mixer_control_change_input/output()"),
  `215289935` *Listen to signals from GvcMixerControl only in sound panel* (prerequisite),
  `afec106a8` *Unset active entry on the device comboBox when there's no active device* —
  its message names the Bluetooth case: "When the bluetooth profile gets changed from handset
  (input+output) to headphone (output only), the input device remains available, but there's
  no more active-input-device anymore. … This fixes a bug where the input switcher is not
  updated when there's no internal microphone but there's a bluetooth headset connected, and
  the bluetooth profile gets switched from Handset to Headphone."
- `0da10f03a` (2024-05-24) fixes a visibility inversion introduced by `bf6f72278`
  (`input_no_devices_group` shown with a device present; upstream issue #3070) — must travel
  with it.

[quoted] First release tag:
```
$ git -C …gnome-control-center-upstream tag --contains bf6f72278
47.0
47.alpha
47.beta
47.rc
48.0 … 51.rc.1
$ git -C …gnome-control-center-upstream tag --contains 3aeb837cb
47.0  (same list)
```
No `46.*` tag contains any of the six.

**Why these match U6 [inferred from 46.7 source, quoted below]:** in `46.7`
(`git show 46.7:panels/sound/cc-sound-panel.c`), the input meter's stream is replaced only
(a) from `input_device_changed_cb()` — the combo box's own "changed" handler — or (b) from
`input_device_update_cb()` **only while the slider holds no stream**:
```
  if (cc_volume_slider_get_stream (self->input_volume_slider) == NULL)
    stream = gvc_mixer_control_get_stream_from_device (self->mixer_control, device);
  if (stream != NULL)
    set_input_stream (self, stream);
```
So once the panel has an input stream (the headset's handsfree microphone), a change of the
*active* input announced by gvc (`active-input-update`) does not re-target the meter; the
combo box moves (`cc-device-combo-box.c:111-118 active_device_update_cb → gtk_combo_box_set_active_iter`)
and that programmatic change re-enters `input_device_changed_cb()`, which also calls
`gvc_mixer_control_change_input()` back into gvc — the recursion `a74bc5a84` removes. With
the headset back in A2DP its handsfree source is gone, so `gvc_mixer_control_get_stream_from_device()`
for the stale device returns NULL and the 46.7 guard keeps the old (dead) meter stream.

**On the observed "monitor of MOMENTUM 4" [inferred]:** `cc-level-bar.c: cc_level_bar_set_stream()`
(46.7) connects the peak stream by numeric index, `device = g_strdup_printf ("%u", gvc_mixer_stream_get_index (stream))`
→ `pa_stream_connect_record()`. pipewire-pulse 1.0.5 turns a numeric record target into
`PW_KEY_TARGET_OBJECT = "%u"` (`src/modules/module-protocol-pulse/pulse-server.c:2069-2074`),
i.e. a plain node id; a capture stream targeted at a *sink* node id captures that sink's
monitor. The panel's **output** meter is built the same way on the headset's A2DP sink, so
the single capture stream `bt-audio-policy` saw ("monitor of MOMENTUM 4") is most plausibly
the output meter working as designed, and the **input meter held no live stream at all** —
consistent with the 46.7 guard above, and with "the meter does not move" rather than "the
meter shows the headset". This is a reading of the code, not measured; the recorder output in
`issues.md` (U6 [log] 23:10:17) does not say which level bar owned the stream.

**Also found, but a different bug:** `4fbedb924` (2026-06-02, first in `51.0`) "sound: Set
pa_stream sink monitor for input rows" fixes upstream work item #3736 ("In 'Volume Levels',
recording input stream monitor is assigned to 'System Sounds' playback vumeter", filed
2026-04-25 against 50.1, milestone GNOME 51) — the *Volume Levels* page's per-application
rows, not the main input meter. Not U6.

### U6.3 libgnome-volume-control

[quoted] gvc submodule pointer per GNOME Settings tag (`git ls-tree <tag> subprojects/gvc`):

| tag | gvc commit |
|---|---|
| 46.rc | `dbfbacc` mixer-control: set max_volume to PA_VOLUME_NORM if no valid volume |
| 46.7 | `91f3f41` mixer-control: Fix a few oversights with signal connections |
| 47.0 | `91f3f41` |
| 48.0 | `91f3f41` |
| 49.0 | `91f3f41` |
| 50.0 | `d2442f4` mixer-control: Only stream-id for bluetooth devices only |
| 51.0 | `d2442f4` |

So **46.7 and 47.0 ship the identical gvc**; the GNOME 47 difference for U6 is entirely in
`panels/sound/`. The gvc side later gained a Bluetooth-specific series (Guido Günther,
2026-01-04: `8bf60ee` *Reset stream-ids on UI devices* — "Since wireplumber 1.5.84 will
merely flip the port but not the stream-id"; `3984af0` *Clear stream-ids from UI devices when
BT stream loses all ports*; `05c9f28`/`cd6c3c8` *Let source/sink update handle active output
change*; `d2442f4` *Only stream-id for bluetooth devices only*, `Fixes: 8bf60ee`, `Closes: #40`)
and `0a4eda0` *Populate source state field* (2026-05-14, after 51.0's pointer). These target
WirePlumber ≥ 1.5.84 port flipping, not the 0.4.17 on the machine; they are not needed to
explain U6 and are not SRU material for noble.

The two gvc commits matching the task's greps are old and unrelated: `ce8e488` (2014,
"Fix selecting Bluetooth input when on A2DP profile") and `d4eda71` (source-output volume).

### U6.4 Ubuntu 24.04 (noble)

[quoted] Index `https://changelogs.ubuntu.com/changelogs/pool/main/g/gnome-control-center/`
lists for noble: `46.0-0ubuntu1…6`, `46.0.1-1ubuntu1…7`, `46.1-1ubuntu1…3`,
`46.3-0ubuntu0.24.04.1`, `46.4-0ubuntu0.24.04.1`, `46.5-0ubuntu0.24.04.1`,
`46.7-0ubuntu0.24.04.1…6`. Newest noble changelog
(`…/gnome-control-center_46.7-0ubuntu0.24.04.6/changelog`), every noble entry since the 46.7
rebase, verbatim headers and bullets:
```
gnome-control-center (1:46.7-0ubuntu0.24.04.6) noble; urgency=medium
  [ Cyrus Lien ]
  * system, users: Keep fingerprint add-print popover visible when displays scaled
    (LP: #2158603)
 -- (Ubuntu maintainer; address elided for this repository's publish scan)  Fri, 14 Aug 2026 02:32:34 +0200
gnome-control-center (1:46.7-0ubuntu0.24.04.5) noble; urgency=medium
  * Fix Add Enterprise Login dialog not completing (LP: #2161027)
    + d/p/lp2161027-fix-domain-validate-timeout.patch
gnome-control-center (1:46.7-0ubuntu0.24.04.4) noble; urgency=medium
  * remote-desktop, desktop-sharing: Handle when keyring is locked (LP: #2000063)
  * d/p: Fix crash when entering remote-dekstop settings (LP: #2000063)
gnome-control-center (1:46.7-0ubuntu0.24.04.3) noble; urgency=medium
  * d/p/a11y-fix-accessibility-when-choosing-a-background.patch …
  * d/p/a11y: several accessibility patches (LP: #2115973) …
gnome-control-center (1:46.7-0ubuntu0.24.04.2) noble; urgency=medium
  * d/p/power-Add-increase-power-consuption-notice.patch … (LP: #2102343)
  * d/p/power-Set-suspend-notice-to-visible-by-default.patch … (LP: #2102343)
  * d/p/about-fix-multiple-gpu-name-with-nvidia-gpu-on-desktop-pc.patch … (LP: #2037076)
gnome-control-center (1:46.7-0ubuntu0.24.04.1) noble; urgency=medium
  * New upstream release (LP: #2095618).
```
The only sound-related patches in the noble series are Ubuntu's own feature patches, listed
in the `1:46.0.1-1ubuntu1` entry: `u/sound-Allow-volume-to-be-set-above-100.patch` and
`u/sound-Add-a-button-to-select-the-default-theme.patch`. **No noble entry mentions the sound
panel's active-device handling, the input meter, `bf6f72278` or any of the six commits.**
`grep -n -i "level\|meter\|microphone"` over the whole 6,200-line changelog finds only a 41.2
upstream NEWS item ("Ensure sound recording level indicator is cleared when microphone …"),
unrelated.

### U6.5 Recommendation (U6)

**Already fixed upstream — GNOME Settings 47.0, `panels/sound` only — and not carried by
Ubuntu 24.04; an SRU request is the right move, with one verification first.** The fix is
the six-commit series `215289935`, `a74bc5a84`, `bf6f72278`, `afec106a8`, `3aeb837cb` plus the
follow-up `0da10f03a` (all `cc-sound-panel.c`/`cc-device-combo-box.c`, small, no gvc change
needed since 46.7 and 47.0 share gvc `91f3f41`); `afec106a8`'s own message describes the
Bluetooth handset→headphone transition that U6 is. The project's existing "fixed upstream in
GNOME 47" row (`docs/STATUS.md`, `docs/issues.md`) had no source cited in the repository;
these ids are that source. Before filing on Launchpad, one cheap confirmation on the next
open window: with the panel open and the headset moved A2DP → handsfree → A2DP, record
(`bt-audio-policy.py --once`) whether GNOME Settings holds **one** capture stream (output
monitor only) or **two** (output monitor + a source) — the 46.7 code predicts one; a 47 build
predicts two, the second on the internal microphone. That single reading makes the SRU
"Test Case" and "Regression Potential" sections concrete. The Launchpad bug should quote
the six upstream ids, note that 46.7 and 47.0 ship the same gvc, and that the only Ubuntu
patches touching `panels/sound` are the two feature patches above (so the cherry-picks should
apply with at most context offsets; this check did not attempt the apply).

---

## Files and clones touched by this check

- Written: `/root/exp/qca9377-bt-hang/tmp/u7-u6-upstream-check-2026-10-03.md` (this file).
- Fetched: `cache/pipewire-upstream` (`fetch origin`, `fetch origin --tags`);
  `cache/gnome-control-center-upstream` (`fetch --unshallow origin`, now full history).
- Read only: `cache/libgnome-volume-control-upstream`, `cache/ubuntu-7.0.0-31/net/bluetooth/`.
- Not touched: `cache/linux`, `cache/full-bt-next`, `cache/mesh-guest`,
  `cache/bluez-upstream`, `cache/bluez-noasan`.
