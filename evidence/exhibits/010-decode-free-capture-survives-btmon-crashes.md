# EX-010 — decode-free-capture-survives-btmon-crashes

**Claim.** btmon aborts continuously during capture — 74 times in a single boot — while the decode-free capture reading the same HCI monitor socket remains intact and current.

**Relevance.** Quantifies BT-4 for a BlueZ report, and demonstrates the mitigation works. The crash is in btmon's decoder, so a capture that never parses a packet cannot be ended by a malformed one. This matters beyond tidiness: btmon's crashes previously rotated away the synchronous-connection parameters that are now the leading discriminant between fatal and survived SCO transitions. A bug in the measuring instrument outranks a bug of equal size elsewhere.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ echo -n 'btmon aborts this boot: '; journalctl -u bt-trace -b 0 --no-pager -o cat | grep -c 'exited'; echo -n 'decode-free capture size: '; stat -c %s /var/log/bt-health/capture/*.btsnoop | tail -1; echo 'last decoded events from the decode-free capture:'; btmon -T -r $(ls -1t /var/log/bt-health/capture/*.btsnoop | head -1) 2>/dev/null | tail -3
```

## Output

Verbatim, 6 line(s), exit status 0.

```
btmon aborts this boot: 74
decode-free capture size: 193115
last decoded events from the decode-free capture:
@ RAW Close: hciconfig                      {0x0002} 2026-08-12 19:14:20.336471
@ MGMT Open: b.. (privileged) version 1.23  {0x0002} 2026-08-12 19:14:47.359513
@ MGMT Close: bluetoothctl                  {0x0002} 2026-08-12 19:14:47.361100
```

## Provenance

| field | value |
|---|---|
| captured | `2026-08-12T19:16:08+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `d28ebac2` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
