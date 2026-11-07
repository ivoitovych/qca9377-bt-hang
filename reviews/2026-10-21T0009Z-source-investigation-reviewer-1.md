# Source investigation — the first reviewer's answer, checked against the source

**The task:** `2026-10-20T2332Z-source-investigation-task.md`. **The answer, verbatim:**
`2026-10-21T0009Z-source-investigation-reviewer-1-verbatim.md`.

**Checked against:**
- bluetooth-next `27731ba09195` (fetched 2026-10-21 00:0x UTC);
- Ubuntu's `7.0.0-38` source (`cache/ubuntu-7.0.0-38`, the laptop's kernel);
- patchwork's diffs of the abandoned-setup series;
- BlueZ tag 5.72.

**Verdict:**
- **Item 1 (U7) is the result that matters, and it holds:** with one correction, the kernel
  path explains the U7 capture.
- **Item 6:** the backport claim is confirmed.
- **Items 2 and 5** hold, with corrections.
- **Items 3, 4 and 7 to 9** mostly restate the brief; they include two small inaccuracies and
  three claims nobody has verified.

## SI1 — U7: the new connect reuses the old, closing connection (confirmed in source, with a correction)

**What holds.** In `hci_connect_sco()` (bluetooth-next `hci_conn.c:1892`; the same lines in
`-38` at 1771 to 1801):
- the lookup is `hci_conn_hash_lookup_ba(hdev, type, dst)`, and it filters on type and
  address only, not on state (`hci_core.h:1285`);
- a setup is sent only when the found connection is `BT_OPEN` or `BT_CLOSED`.

So a new connect to the same headset finds the old eSCO `hci_conn` while that one's
Disconnect is pending, and sends no Setup Synchronous Connection.

**The correction: the state is `BT_CONNECTED`, not `BT_DISCONN`.**
- Nothing in `hci_conn.c`, `hci_sync.c` or `hci_event.c` sets `BT_DISCONN` on a connection
  (`git grep BT_DISCONN`: one hit, the socket state in `sco.c`). `hci_abort_conn()` only
  sets `abort_reason` and queues the Disconnect.
- So the old connection is still `BT_CONNECTED`, and the consequence is sharper than the
  reviewer says. `sco_connect()` (`sco.c:417`) sees `hcon->state == BT_CONNECTED` and marks
  the new socket **connected at once**, with no HCI traffic.
- The old socket's close had already detached it (`sco_chan_del()` clears `conn->sk`), so
  `sco_chan_add()` accepts the new one.
- When the old link's Disconnection Complete arrives, `sco_disconn_cfm()` →
  `sco_conn_del()` closes the new socket with an error.

**This matches EX-060:** no setup command at all on the earbuds, where the headset answered
in 16 to 30 ms and the old link took 177 to 205 ms to go. A fresh connection and a setup came
on the MOMENTUM 4, whose old link was gone in 39 to 46 ms, before the connect.

**Not covered by the abandoned-setup series**, as the reviewer says: patches 2 and 4 (read
from patchwork's diffs of 14875450 and 14875452) guard `hci_sco_setup()`,
`hci_enhanced_setup_sync()` and the completion events. They do not touch the lookup in
`hci_connect_sco()`, or a connection with `abort_reason` set.

**Not yet shown:**
- whether PipeWire 1.0.5 retries after that error (the reviewer says no; not read here);
- the behaviour itself, which needs a reproducer.

**Next:** an `hci_vhci` reproducer in QEMU. Hold the old link's Disconnection Complete, then
connect a second SCO socket. Expect no setup command, an immediately connected socket, and an
error when the completion arrives. If it shows that, this is a kernel patch candidate: do not
hand a connection that is being aborted to a new connect. It may be offered on the series'
thread or on its own; that is the operator's decision. **Status: open (CO-02).**

## SI2 — the two SCO error messages (holds in part)

- **"SCO packet for unknown connection handle":** `hci_core.c:4043` (bluetooth-next), logged
  when `sco_recv_scodata()` returns `-ENOENT`. It is `bt_dev_err_ratelimited`, so our 14 lines
  may stand for more packets.
- **"corrupted SCO packet":** `btusb.c:1668` (`-38`; in bluetooth-next the driver is split and
  the line is `drivers/bluetooth/btusb_main.c:1842`), when `btusb_recv_isoc()` fails. It fails
  not only on reassembly. `btusb_validate_sco_handle()` (`btusb.c:1344`) also rejects any SCO
  header whose handle is not a live SCO/eSCO connection: a lost fragment that leaves the
  reassembly misaligned, **or data for a connection already deleted.**
- **So the reviewer's reading is one possibility:** "reassembly failures on alt 1 explain the
  silence". The message alone does not show it.
- **"Residual URBs" does not explain the late lines.** Since btusb checks the handle when the
  packet arrives, an "unknown handle" line from `hci_core` means the connection existed when
  btusb took the packet and was gone when the receive work handled it. "Seconds later" (4 to 6
  s, CO-20) is not explained that way: an isochronous URB covers milliseconds.
- **Status: open (CO-20).** The deciding record is the HCI capture around those hang-ups.

## SI3 — M-2: the duration overflow (holds; the quoted code is the old form)

- **The current line** (bluetooth-next `hci_sync.c:1702`) is
  `u16 duration = adv->mesh ? adv->timeout : adv->timeout * MSEC_PER_SEC;`, followed by
  `set->duration = cpu_to_le16(duration / 10);`. The reviewer quoted the form before
  `8a8d51eeedeb`.
- **MGMT Add Advertising** carries `__le16 timeout` in seconds (`mgmt.h:565`), so userspace
  can ask for up to 65,535 s.
- **The arithmetic:** a timeout of 66 s becomes 66,000 ms. That truncates to 464 ms in a
  `u16`, so the controller is told 46 (460 ms). A multiple of 65.536 s becomes 0, which the
  HCI command reads as no duration limit.
- **The HCI field** is itself 16 bits in 10 ms units (at most 655.35 s), so long timeouts
  cannot go to the controller at all. That supports "a timeout design, not a clamp".
- **Status: open (CO-12)**; a QEMU reproducer decides it.

## SI4 — U12: `a14d59725` on 5.72 (confirmed)

- **The check:** `git format-patch -1 a14d59725`, then `git apply --check -v` on a 5.72
  worktree.
  - Hunk 1 applies at offset −8.
  - Hunk 2 fails: "patch failed: profiles/audio/transport.c:394", in
    `a2dp_resume_complete()`.
- **The range:** 24 commits touch `profiles/audio/transport.c` between 5.72 and the fix
  (`git log --oneline 5.72..a14d59725~1 -- profiles/audio/transport.c`).
- **Open:** which of them changed that context, and whether any is a fix a backport must carry
  (the reviewer says so but names none). Candidates by subject: `47da1efdc` ("Unset transport
  owner before owner free") and `87ad4c66b` ("fix crash when freeing transport").
- **Status: open (CO-03):** a hand backport of hunk 2, then the build and tests.

## SI5 — the rest

| item | the reviewer's claim | as checked |
|---|---|---|
| 3, patch 6 and btusb | "the never-came-up notification is rare once the device-table entry is present" | not supported by anything cited; no behaviour change expected on the sequences we hold, which is plausible but not checked |
| 4, I12 | take `hdev->lock` for the list change, "then queue the command-sync work" | `mesh_send_sync()` already runs on the command-sync worker and sends its HCI commands synchronously. The rule our state-machine document already has stands: `hdev->lock` for the list, never across an HCI command |
| 4, the mesh patches | "they do not appear to conflict textually" | wrong for two of them: 14888791 carries 14831271's `mesh_send()` hunk verbatim, so they cannot both apply. The lock-order question about `mesh_next()` restates the brief; no lockdep run was made |
| 7, 8, 9 | U11 opt-in, the U10 test, U4 "unchanged in main", U2 "matches" | restatements of the brief; "unchanged in main" (U4) and "matches" (U2) are not checked by them or us; the QCA ID sweep was not done |

**What the review added:**
- SI1, through its pointer to the state check in `hci_connect_sco()`, which our reading
  sharpened;
- the confirmed backport gap (SI4).

The rest needs no action beyond the CO items.
