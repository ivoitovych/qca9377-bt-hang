# CO-02 — A new SCO connect reuses the closing link (U7)

**State (2026-10-23): the package to send is `patch/v5/send/`**: `kernel/` holds the cover letter
and three kernel patches, and `bluez/` holds the BlueZ test, a separate mail. Evidence is in
`experiments/results-2026-10-22-v3.md` (the stable lines) and `-v4.md` (bluetooth-next; v5
changed only the messages). The review rounds are in `reviews/`, and how each point was handled
is in `log.md`. Not sent.

**The run on the laptop (2026-10-23 to 2026-10-25):** done, `experiments/results-2026-10-24-hardware.md`
(`EX-067` to `EX-073`): patch 2 refused 3 of 3 earbuds switches, 8 of 8 switches on two other
headsets still got a new link, links closed, kernel log clean; patches 1 and 3 not reachable there.
With a stream playing, the earbuds' audio returns 5 s after a refused switch (PipeWire's immediate
retries, `U17`). Next: the cover letter's two paragraphs (`drafts/cover-letter-v6-hardware.txt`),
the operator's reading, then the operator's send.

**The laptop's kernel (2026-10-23):** Ubuntu 7.0.0-38 needs upstream `abd93c85c8667` +
`816fb1590a4c` under the series, or patch 1 leaves a `sco_conn` reference that keeps the SCO
link up (`log.md`, "the laptop's kernel"). The module for the laptop is
`tmp/co02-hw/module/full/` (built by `experiments/build-laptop-module-v2.sh`); the cover letter
has a paragraph for such trees.

The series:
1. stops a refused second connect from disconnecting the first socket's link (the hold fix;
   first so that it applies alone on 6.6 and 6.12);
2. refuses a SCO connect that would be handed a connection being disconnected;
3. waits for a disconnect worker that is already running before it reuses a connection.

Superseded and kept as history:
- `patch/v4/send/`, `patch/v3/`: the same code as v5, earlier messages.
- `patch/v2/`: the same code, with the refusal first.
- `patch/v1/` (round 2): patch 3 covered only connections with a link.
- `patch/kernel-final/`, `patch/kernel/`: two-patch drafts, with results in
  `experiments/results-2026-10-21.md`.
- `patch/kernel-rfc-defer/`: the deferral prototype, offered as an RFC only.

**Recommended contribution:** the kernel series with the BlueZ test case; the deferral (`patch/kernel-rfc-defer/`) as an RFC question to the
maintainers, since it changes `connect()` semantics; a PipeWire note later, the operator's
call.

---

*The section below is the finding as written before the reproducer.*

**Target:** the Linux kernel (`net/bluetooth/hci_conn.c`, `sco.c`). PipeWire's retry
behaviour may be a second contribution.

**Comes from:** `U7` (`docs/issues.md`, `EX-060`): after an HFP codec switch made during a
call, no new SCO link is ever set up.

## The finding

1. `hci_connect_sco()` looks for an existing connection with
   `hci_conn_hash_lookup_ba(hdev, type, dst)`, which matches on type and address only, not
   on state.
2. It sends a setup only when the connection it found is `BT_OPEN` or `BT_CLOSED`.
3. When PipeWire closes the old call link, the kernel queues its Disconnect
   (`hci_abort_conn()` sets `abort_reason`). The connection stays `BT_CONNECTED` until the
   Disconnection Complete arrives: nothing sets `BT_DISCONN` on an `hci_conn`.
4. A new connect to the same headset in that window therefore gets the old connection. No
   Setup Synchronous Connection is sent.
5. `sco_connect()` sees `BT_CONNECTED` and marks the new socket connected at once.
6. When the Disconnection Complete arrives, `sco_disconn_cfm()` → `sco_conn_del()` closes
   the new socket with an error.

This matches `EX-060`:
- **Earbuds:** the headset answered in 16 to 30 ms, while the old link took 177 to 205 ms to
  go. No setup was sent, and the new codec stayed silent.
- **MOMENTUM 4:** the old link was gone in 39 to 46 ms, before the connect. A fresh
  connection was made and the setup was sent.

The pending abandoned-setup series (CO-01) does not touch this path.

7. PipeWire 1.0.5 takes the socket as ready. Its only retry is for an immediate
   `ECONNABORTED` from `connect()`. A later HUP or error closes the socket and sets the
   transport IDLE, with no new connect. The error at the completion is `ECONNABORTED`
   (reason 0x16).

**Marker for a patch:** `conn->abort_reason` is set while the Disconnect is pending. A fix can
refuse to hand such a connection to a new connect, or defer the connect until the teardown
completes. Not a second connection to the same address: completions are matched by address.

## Open
- The behaviour itself needs a reproducer.
- Where the fix belongs:
  - kernel: do not hand a connection that is being aborted to a new connect; wait for it, or
    fail the connect so userspace can retry;
  - PipeWire: wait or retry;
  - or both.

## Next

An `hci_vhci` reproducer in QEMU:
1. Bring up an eSCO link.
2. Close its socket, and hold the Disconnection Complete.
3. Connect a second socket to the same address.
4. Expect no setup command, an immediately connected socket (`connect()` returns 0), and
   `ECONNABORTED` when the completion arrives. Record the `connect()` return, `SO_ERROR` and
   every outgoing command. Run the same case with the abandoned-setup series applied (CO-01):
   it is expected not to change this.
5. Control: the same sequence with the completion delivered before the connect.

**Decides:** sending anything is the operator's decision.
