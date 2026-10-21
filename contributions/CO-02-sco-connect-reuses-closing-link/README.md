# CO-02 — A new SCO connect reuses the closing link (U7)

**State:** investigating. The mechanism has been read in source, and no reproducer exists
yet.

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

## Open

- Does PipeWire 1.0.5 retry after the error? Reviewer 1 says no; not read here.
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
4. Expect no setup command, an immediately connected socket, and an error when the completion
   arrives.
5. Control: the same sequence with the completion delivered before the connect.

**Decides:** sending anything is the operator's decision.
