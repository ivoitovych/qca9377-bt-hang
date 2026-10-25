# EX-068 — co02-refused-connect-recovers-at-wireplumber-idle-suspend

**Claim.** With the CO-02 series loaded, PipeWire's SCO connect for the earbuds' codec switch at 2026-10-24 06:12:22 failed with ECONNABORTED three times within 80 microseconds (.340952 to .341032: the first connect and its two immediate retries), both Bluetooth nodes went to error, WirePlumber suspended them as idle 5.004 s later (06:12:27.344984), the still-linked stream resumed the sink and a new connect succeeded (sco_acquire_cb .350496, acquire complete .399885).

**Relevance.** The series turns the false success into an error, and PipeWire 1.0.5 retries that error at once, while the old link still needs about 150 ms to go (EX-067), so all three attempts fail; the audio comes back only through WirePlumber's 5 s idle suspend of the failed nodes. That is the user-visible result of the series on this desktop: about 5 s of silence where the unpatched kernel gave none until the stream was restarted (U7, EX-060). The kernel is right to refuse; the delay is PipeWire's retry policy (U17).

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/user-journal.sh --since "2026-10-24 06:12:22" --until "2026-10-24 06:12:28" -g "connection abort|-> error|suspending|acquire|-> running|-> idle|-> suspended"
```

## Output

Verbatim, 25 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
2026-10-24T06:12:22.299276+02:00 n pipewire[2868]: pw.node: (bluez_output.AA:BB:CC:00:00:01.1-67) running -> suspended
2026-10-24T06:12:22.302613+02:00 n pipewire[2868]: pw.node: (Google Chrome-79) running -> idle
2026-10-24T06:12:22.302896+02:00 n pipewire[2868]: pw.node: (GNOME Settings-95) running -> idle
2026-10-24T06:12:22.304205+02:00 n pipewire[2868]: pw.node: (GNOME Settings-95) idle -> suspended
2026-10-24T06:12:22.308486+02:00 n pipewire[2868]: pw.node: (GNOME Settings-95) creating -> suspended
2026-10-24T06:12:22.326051+02:00 n pipewire[2868]: pw.node: (bluez_input.AA:BB:CC:00:00:01.0-94) creating -> suspended
2026-10-24T06:12:22.326143+02:00 n pipewire[2868]: pw.node: (bluez_output.AA:BB:CC:00:00:01.1-99) creating -> suspended
2026-10-24T06:12:22.338414+02:00 n pipewire[2868]: pw.node: (GNOME Settings-97) creating -> suspended
2026-10-24T06:12:22.338910+02:00 n pipewire[2868]: pw.node: (Google Chrome-79) idle -> running
2026-10-24T06:12:22.338957+02:00 n pipewire[2868]: pw.node: (bluez_output.AA:BB:CC:00:00:01.1-99) suspended -> running
2026-10-24T06:12:22.340895+02:00 n wireplumber[2873]: transport 0x57a73ac226c0: enter sco_acquire_cb
2026-10-24T06:12:22.340952+02:00 n wireplumber[2873]: connect(): Software caused connection abort. Remaining retry:1
2026-10-24T06:12:22.340996+02:00 n wireplumber[2873]: connect(): Software caused connection abort. Remaining retry:0
2026-10-24T06:12:22.341032+02:00 n wireplumber[2873]: connect(): Software caused connection abort
2026-10-24T06:12:22.341254+02:00 n pipewire[2868]: pw.node: (bluez_input.AA:BB:CC:00:00:01.0-94) suspended -> error (Received error event)
2026-10-24T06:12:22.341293+02:00 n pipewire[2868]: pw.node: (bluez_output.AA:BB:CC:00:00:01.1-99) running -> error (Received error event)
2026-10-24T06:12:27.344984+02:00 n wireplumber[2873]: <WpNode:94:0x57a73af6f880> was idle for a while; suspending ...
2026-10-24T06:12:27.345352+02:00 n wireplumber[2873]: <WpNode:99:0x57a73af3e930> was idle for a while; suspending ...
2026-10-24T06:12:27.345999+02:00 n pipewire[2868]: pw.node: (bluez_input.AA:BB:CC:00:00:01.0-94) error -> suspended
2026-10-24T06:12:27.346416+02:00 n pipewire[2868]: pw.node: (bluez_output.AA:BB:CC:00:00:01.1-99) error -> suspended
2026-10-24T06:12:27.346935+02:00 n pipewire[2868]: pw.node: (Google Chrome-79) running -> idle
2026-10-24T06:12:27.348596+02:00 n pipewire[2868]: pw.node: (Google Chrome-79) idle -> running
2026-10-24T06:12:27.348646+02:00 n pipewire[2868]: pw.node: (bluez_output.AA:BB:CC:00:00:01.1-99) suspended -> running
2026-10-24T06:12:27.350496+02:00 n wireplumber[2873]: transport 0x57a73ac226c0: enter sco_acquire_cb
2026-10-24T06:12:27.399885+02:00 n wireplumber[2873]: transport 0x57a73ac226c0: acquire complete, read_mtu=50, write_mtu=50
```

**Evidence window.** `2026-10-24T06:12:22.299276+02:00` — `2026-10-24T06:12:27.344984+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-10-25T22:19:56+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | `257d1599` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
