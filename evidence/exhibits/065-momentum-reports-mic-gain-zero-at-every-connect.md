# EX-065 — momentum-reports-mic-gain-zero-at-every-connect

**Claim.** The MOMENTUM 4 reports a microphone gain of 0 (AT+VGM=00) when its hands-free connection is set up, and PipeWire takes it as the microphone volume (volume changed 0). Over every hands-free connection the journal still holds (2026-10-19 to 2026-10-23) it reported AT+VGM=00 32 times and no other microphone gain; the Shure reported AT+VGM=15 each time.

**Relevance.** The zero that WirePlumber saves and PipeWire later sends back as +VGM: 0 comes from the headset itself, at connect. The first command shows one connect in full; the second counts every report per headset.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ grep -a -E 'NewConnection path=.*HFPAG|AT\+BRSF|AT\+VG[MS]|volume changed' /root/exp/qca9377-bt-hang/archive/incidents/20261023-momentum-mic-gain-zero/journal-user-connect-0147.txt; python3 -I /root/exp/qca9377-bt-hang/scripts/hfp-gain-by-device.py /root/exp/qca9377-bt-hang/archive/incidents/20261023-momentum-mic-gain-zero/journal-user-gain-history.txt
```

## Output

Verbatim, 16 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
2026-10-23T01:47:58.979881+02:00 n wireplumber[2926]: NewConnection path=/org/bluez/hci0/dev_AA:BB:CC:00:00:01, fd=38, profile /Profile/HFPAG
2026-10-23T01:47:59.074728+02:00 n wireplumber[2926]: RFCOMM << AT+BRSF=955
2026-10-23T01:47:59.575856+02:00 n wireplumber[2926]: volume changed -1
2026-10-23T01:47:59.789084+02:00 n wireplumber[2926]: RFCOMM << AT+VGS=09
2026-10-23T01:47:59.789676+02:00 n wireplumber[2926]: volume changed 9
2026-10-23T01:47:59.914188+02:00 n wireplumber[2926]: RFCOMM << AT+VGM=00
2026-10-23T01:47:59.914922+02:00 n wireplumber[2926]: volume changed 0
2026-10-23T01:48:01.860595+02:00 n pipewire-pulse[2928]: mod.protocol-pulse: stream 0x6122bc36a240: volume changed 1.000000
2026-10-23T01:48:02.921009+02:00 n wireplumber[2926]: transport 0x596dfd0bb1d0: volume changed 90(0.355890) 
AA:BB:CC:00:00:02
  AT+VGM=15  x5    first 2026-10-21T06:40:45.899451+02:00  last 2026-10-23T00:50:54.562850+02:00
  AT+VGS=06  x5    first 2026-10-21T06:40:45.885988+02:00  last 2026-10-23T00:50:54.488826+02:00
AA:BB:CC:00:00:01
  AT+VGM=00  x32   first 2026-10-19T21:53:39.724714+02:00  last 2026-10-23T01:47:59.914188+02:00
  AT+VGS=09  x27   first 2026-10-20T13:36:48.686925+02:00  last 2026-10-23T01:47:59.789084+02:00
  AT+VGS=12  x5    first 2026-10-19T21:53:39.700611+02:00  last 2026-10-20T11:50:13.148343+02:00
```

**Evidence window.** `2026-10-19T21:53:39.724714+02:00` — `2026-10-23T01:48:02.921009+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-10-23T03:10:46+02:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `d479d374` |
| evidence boot ids | none named by the command (it selects by index or not by boot) — see the window above |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
