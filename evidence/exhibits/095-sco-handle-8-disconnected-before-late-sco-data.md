# EX-095 — sco-handle-8-disconnected-before-late-sco-data

**Claim.** 2026-11-13: the host disconnects eSCO handle 8 (the MOMENTUM 4's hands-free link) at 14:21:02.664 and the controller reports Disconnect Complete, Success, at 14:21:02.673411; the kernel's 'SCO packet for unknown connection handle 8' lines (EX-094) come after it.

**Relevance.** Shows the order: the late SCO data arrives after a clean local disconnect, so the message is a teardown race, not a lost link.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/capture-window.sh /var/log/bt-health/trace/bt-20261113-112428.btsnoop '2026-11-13 14:21:02.600' '2026-11-13 14:21:06.000' 'Disconnect|Handle: 8'
```

## Output

Verbatim, 10 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
< HCI Command: Disconnect (0x01|0x0006) plen 3                                                                         #46473 [hci0] 2026-11-13 14:21:02.664482
        Handle: 8 Address: AA:BB:CC:00:00:01 (Sonova Consumer Hearing GmbH)
        Reason: Remote User Terminated Connection (0x13)
> HCI Event: Command Status (0x0f) plen 4                                                                              #46474 [hci0] 2026-11-13 14:21:02.667417
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> HCI Event: Disconnect Complete (0x05) plen 4                                                                         #46477 [hci0] 2026-11-13 14:21:02.673411
        Status: Success (0x00)
        Handle: 8 Address: AA:BB:CC:00:00:01 (Sonova Consumer Hearing GmbH)
        Reason: Connection Terminated By Local Host (0x16)
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-11-13T14:31:23+01:00` |
| kernel | `7.0.0-43-generic` |
| capture boot id | `af3f9840` |
| evidence boot ids | `af3f9840` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
