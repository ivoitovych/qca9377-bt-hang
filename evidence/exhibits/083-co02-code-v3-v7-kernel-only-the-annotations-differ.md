# EX-083 — co02-code-v3-v7-kernel-only-the-annotations-differ

**Claim.** Against v3's kernel mails, the v7 candidate's patches 1 and 3 carry identical code (diff text and git patch-id), and patch 2 differs only by the two v4 annotations: READ_ONCE(sco->abort_reason) in hci_connect_sco() and WRITE_ONCE(conn->abort_reason, reason) in hci_abort_conn(). So the 6.6.y and 6.12.y stable runs, which used v3's patch 1 alone, ran today's patch 1; 6.18.y and 7.2.y were rerun with v4's code (results-2026-10-22-v4.md, st6.18v4 and st7.2v4).

**Relevance.** The cover's stable paragraph rests on runs made with v3 (6.6.y, 6.12.y) and v4 (6.18.y, 7.2.y). This ties both to the outgoing code, and is a second positive control of the tool: it finds exactly the two changed lines.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ python3 -I /root/exp/qca9377-bt-hang/scripts/patch-code-compare.py /root/exp/qca9377-bt-hang/contributions/CO-02-sco-connect-reuses-closing-link/patch/v3/send/kernel /root/exp/qca9377-bt-hang/contributions/CO-02-sco-connect-reuses-closing-link/patch/v7-candidate/send/kernel
```

## Output

Verbatim, 34 line(s), exit status 1.

```
0001  0001-Bluetooth-hci_conn-hold-a-reused-SCO-connection-for-.patch
      code text: IDENTICAL (28 lines compared, index lines left out)
      patch-id : IDENTICAL  87b77ca498afea44 / 87b77ca498afea44
      message  : changed
0002  0002-Bluetooth-hci_conn-don-t-reuse-an-aborting-SCO-conne.patch
      code text: DIFFERS (18 lines compared, index lines left out)
      patch-id : DIFFERS  aace0ebc07a1fa56 / 8c349a094c3759f4
      message  : changed
        --- A
        +++ B
        @@ -6,5 +6,5 @@
          			return sco;
          		}
        -+	} else if (sco->abort_reason) {
        ++	} else if (READ_ONCE(sco->abort_reason)) {
         +		/* The connection is being disconnected and stays BT_CONNECTED
         +		 * until the Disconnection Complete event, so no setup would
        @@ -17,2 +17,11 @@
          
          	if (sco->link) {
        +@@ -3272,7 +3280,7 @@ int hci_abort_conn(struct hci_conn *conn, u8 reason)
        + 
        + 	bt_dev_dbg(hdev, "handle 0x%2.2x reason 0x%2.2x", conn->handle, reason);
        + 
        +-	conn->abort_reason = reason;
        ++	WRITE_ONCE(conn->abort_reason, reason);
        + 
        + 	/* Cancel the connect attempt. A return of 0 means the create command
        + 	 * was still queued and got dequeued, so there is nothing to disconnect.
0003  0003-Bluetooth-hci_conn-wait-for-a-running-SCO-disconnect.patch
      code text: IDENTICAL (21 lines compared, index lines left out)
      patch-id : IDENTICAL  9f50d1196989e2c7 / 9f50d1196989e2c7
      message  : changed
RESULT: the code DIFFERS (above)
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-26T06:49:25+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | none named by the command (it selects by index or not by boot) — see the window above |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `1` |
| redacted | `no` |
