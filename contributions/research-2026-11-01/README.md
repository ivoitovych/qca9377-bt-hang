# Research on the parked contributions, 2026-11-01

Six research passes covered every item parked as "idea" or "blocked": CO-01, CO-06 to CO-08,
CO-12 to CO-18, CO-20 to CO-22, CO-24 and CO-30. Each item got:
- its record;
- its upstream state on 2026-11-01;
- the source at named commits;
- the project's archived evidence;
- QEMU runs where a question needed one;
- a recommendation.

Nothing was sent, posted or filed, and nothing touched the laptop's Bluetooth. Claims are
marked: quoted, source (`path:line` at a commit), log (file and time), or inferred.

| folder | items | state |
|---|---|---|
| [`gnome/`](gnome/) | CO-07, CO-17 | finished |
| [`policy/`](policy/README.md) | CO-08, CO-15, CO-16, CO-24 | finished; notes per item in `policy/notes/` |
| [`mesh/`](mesh/) | CO-06, CO-12, CO-13, CO-14 | finished; CO-12's draft fix is in [`../CO-12-m2-adv-duration-overflow/patch/draft-2026-11-01/`](../CO-12-m2-adv-duration-overflow/patch/draft-2026-11-01/) |
| [`btusb/`](btusb/) | CO-18, CO-20, CO-21 | finished; CO-21's candidate diffs are in [`../CO-21-btusb-sco-alt-setting/`](../CO-21-btusb-sco-alt-setting/README.md) |
| — | CO-01, CO-30; CO-22 | in progress; added when finished |

Raw captures, downloaded web pages and mboxes (they hold addresses) stay in the work areas under
`/root/exp/agent-work/research-*/`.

## Results

| item | finding | recommendation | next step | decides |
|---|---|---|---|---|
| CO-07 (U6) | GNOME 47's fix is 6 commits (`215289935` … `0da10f03a`, +68/−75). They apply cleanly to 46.7 and after Ubuntu's 41 patches; not built. No Ubuntu SRU exists. **On Ubuntu the fix alone would not help:** 46.7 does re-target the meter, as the journal shows (2026-10-24 08:04:59, 2026-10-29 04:46:01), and Ubuntu's 2-second WirePlumber patch (U19) destroys the new stream 2.0 s later | merge with CO-32; do CO-32 first | with CO-32's user override in place: Handsfree → A2DP three times with the Sound panel open; read `[GNOME Settings] CREATE_RECORD_STREAM` / `ERROR` in the user journal | operator |
| CO-17 / U2 | **Explained by the archived capture** (`archive/bt-trace/bt-20260926-203857`, `-224246`; excerpts in `gnome/captures/`). The 0.00 is the headset's own 0 (`+VGM: 0` at each link start, U15). 0.27 and 0.08 are laptop-side `+VGM: 4` and `+VGM: 1` (sliders while the panel was open, 22:06 to 22:08; the 22:55:45 sender is not logged) | close U2's "unexplained" part; it is not CO-36 | none | operator (wording) |
| CO-17 / U4 | The guard `if (device == self->device) return;` (`cc-profile-combo-box.c:96`, 46.7) is **unchanged on GNOME main** `60f83317c` (`cc-profile-combo-row.c:183`). The route/profile "mismatch" is by design (PipeWire's route reports the base profile). The cause of a missing row (U21) is still open | proceed: one manual test | with the panel open in Handsfree/mSBC, run `wpctl set-profile <card> 260`; record whether the row stays on mSBC, then leave and return to the panel | operator |
| CO-08 (U10) | The 10-11 captures are in `archive/hci-capture/hci-20261010-230942` and `-004736`, not `archive/bt-trace`. **Every SBC-XQ test sound was single-channel** (left, then right), so "silent" cannot tell none from one-sided. There was a fourth test at 01:40:19. Volume (AVRCP 39/127) and signal levels were equal in both modes. PipeWire's quirk practice accepts a marked test; entries are keyed by Modalias | proceed | a 10-minute A-B-A-B test with marks: `policy/notes/CO-08.md` | operator, test and merge request |
| CO-15 (U11/U3) | WirePlumber 0.5.19 has **no** option for a new device to become the default (`find-selected-default-node.lua:55`, `state-default-nodes.lua:47`). PipeWire 1.0.5's `module-switch-on-connect` with `blocklist=hdmi\|^alsa_\|^bluez_input` limits it to Bluetooth outputs (from source, untested) | reduce to a configuration note | try the drop-in in `policy/notes/CO-15.md`, or order the default history once | operator |
| CO-16 (U9) | BlueZ master reconnects only after link loss or resume (`policy.c:920`). Upstream #294 was closed by the stale bot after the maintainer had proposed an opt-in. rfkill disconnects reported reason 21 (raw HCI) before kernel `c1cec2bbbeb5` and reason 3 after, so the reason cannot tell rfkill from a headset switched off | wait | if pursued: ask the maintainers first (a power-on callback and a `[Policy]` key) | operator |
| CO-24 (U5) | **Answered from source.** With no saved choice, every path picks the best codec: WirePlumber 0.4.17 and 0.5, GNOME's Handsfree item, and PipeWire's `+BCS` (`policy-bluetooth.lua:239`, `bluez5-device.c:1787`, `backend-native.c:870`) | drop; a note in U5 | none | operator |
| CO-12 (M-2) | **Reproduced in QEMU** (22 mgmt-tester "AdvDur" cases on an extended-advertising emulator). A 66 s timeout ends after 463 ms; 6357 s and 8192 s give the controller Duration 0, never removed. bluetoothd is not affected (own timer); MGMT clients are. Origin `10bbffa3e88e` (2019), effective since `f16a491c65d9` (2021). **Draft fix:** a u32 computation clamped to `U16_MAX`; AdvDur 9/22 → 20/22 (the 2 left are correct 1 s controls); mgmt-tester Advertising 127/127 both sides. Above 655 s it now ends at 655.35 s, a limit to state. Conflicts textually with Cen Zhang's 14927631 (10-30) | proceed | the clamp as a fix with the limit stated and the design question asked, or design first | operator |
| CO-06 | 14864878 still `new`. Rerun on the tip: base 8/26 → 21/26 and 20/26 with it; the backlog-3 and devdown cases still fail ("completed after power on, never started"). Its fallback runs without `req_lock`/`hdev->lock`. It does not apply on top of CO-04 | wait | if a reply is ever wanted: refresh the lock trace and the removal cases (~1 h) | operator |
| CO-13 | Count does not set how often a mesh packet is sent: air time is about 1 s whatever the Count. Count 0 is accepted; Addr, Instant and Delay are never read; Count ≥ 52 wraps the u16 duration. The only client (bluetooth-meshd) always sends Count 1 | wait (low) | one mesh-semantics question after CO-04/05 | operator |
| CO-14 | The lock-order inversion at removal is still at the tip (`hci_cmd_sync_clear()` → `mesh_next` → `hci_cmd_sync_submit()`). The backlog is never drained at removal and pins the socket (inferred, untested). CO-04 removes the lock-order half | wait for CO-04 | after it: a natural-timing QEMU leak check, then ask the maintainers | operator |

| CO-20 | **Explained and harmless.** SCO data queued behind a link's Disconnection Complete, 0–20 ms after it, is dropped as "unknown connection handle": 119 packets in the capture = 119 lines, CO-02 boot; 220 in all captures from 10-19 to 10-30, none outside a closing link. Data arriving between `hci_conn_del()`'s unhook and btusb's stop is the "corrupted SCO packet" line (all events checked). **The "late" lines are journal stamping**: the kernel's own print time puts them at the hang-up (one 950 s "late" line was printed 9 µs after its neighbour) | close; no patch (the same message is the signal of real USB loss elsewhere) | none | coordinator |
| CO-18 (U8) | Not a kernel fault. The laptop sent the earbuds valid mSBC carrying the test sounds, and their microphone stream was complete. Every "corrupted SCO packet" line of the session was at teardown, none during a call. The message appears in every era, stock included | drop as a kernel item, folded into CO-20; U8 stays open on the earbuds' side | a 10 s Settings test sound to the earbuds in handsfree mSBC on E3 | operator |
| CO-21 | **Confirmed in source, and wider than recorded.** Besides two SCO links: while one SCO link is still being set up, any other connection added or removed makes btusb pick alt 0 (zero bandwidth here), and the link's own notification is then ignored. Two such races are in the journal (2026-09-02, boot `c128a59a`, stock era; the links never came up); in 281 pending setups over 68 boots no link ever ran on alt 0. A model test replays the real `btusb_notify`/`btusb_work` code: the original gives alt 0 in 5 of 7 scenarios. A candidate fix compiles cleanly against `-42` and bluetooth-next and gives the right alt in all 7; never loaded. Hitalo Souza's patchwork 14875454 covers one of the 7 scenarios | proceed: the race first, the two-link case second | an outside review; the bot's CI on base and base + patch; optionally a laptop run | coordinator; operator for the laptop and the send |

## Records corrected with this commit

- U2, U5, U6, U8 (pointer only), U10 and U19 in `docs/issues.md` and `docs/STATUS.md`, as far as the
  findings above reach. The full lists are in the agents' reports, summarised here.
- The index rows of the items above in [`../README.md`](../README.md).
- CO-05: Cen Zhang's 14927631 (2026-10-30, `new`) takes `hdev->lock` around
  `hci_add_adv_instance()` in `mesh_send_sync()`. CO-05 1/2 no longer applies on top of it;
  CO-04 still does.
