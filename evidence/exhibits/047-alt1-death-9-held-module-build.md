# EX-047 — alt1-death-9-held-module-build

**Claim.** Ninth alt-1 death, 2026-09-24 03:24:59, under the original configuration, on a boot running a self-built bluetooth.ko (srcversion 66D38200362CD82D3F68A9D, loaded from updates/): 717 transparent-SCO packets on alt 1 in the 7 s window, then the first command issued (0x0406 Disconnect, reason 0x13) times out after 2.05 s; bAlternateSetting 1 / wMaxPacketSize 0009 read from sysfs 31 min later, untreated.

**Relevance.** Same signature as EX-033..045 (n=9), on a different bluetooth.ko build than every earlier death: the module build does not change this fault.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ cat /sys/module/bluetooth/srcversion; echo; tools/bt-fault-window 2>&1 | head -30; echo; tools/bt-usbstate 2>&1 | grep -E "^bt-usbstate|interface 3-3:1.1|bAlternateSetting       1|wMaxPacketSize       0009"; echo; tools/bt-window 2>&1 | head -9
```

## Output

Verbatim, 6 line(s), exit status 0.

```
66D38200362CD82D3F68A9D

bash: line 1: tools/bt-fault-window: No such file or directory


bash: line 1: tools/bt-window: No such file or directory
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-09-24T03:56:42+02:00` |
| kernel | `7.0.0-31-generic` |
| boot id | `20fbb9a2` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
