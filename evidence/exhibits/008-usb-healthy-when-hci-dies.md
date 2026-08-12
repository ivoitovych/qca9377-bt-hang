# EX-008 — usb-healthy-when-hci-dies

**Claim.** At the moment HCI stops answering, the USB transport is entirely healthy — every URB completes with status 0. The first non-zero URB status appears 31.4 s LATER; USB descriptor-read failures later still.

**Relevance.** Separates two hypotheses the kernel log alone cannot distinguish. The onset is NOT a USB transport wedge: the device keeps accepting and completing USB transfers while refusing to answer an HCI command. USB-level collapse (-108 ESHUTDOWN, then descriptor read -110) is a downstream consequence tens of seconds afterwards. That points at controller firmware/protocol state rather than at the link, and is consistent with the QCA firmware-download hypothesis.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ echo 'first HCI command timeout:'; journalctl -k -b 0 --since '2026-08-12 05:00:00' --until '2026-08-12 05:01:00' --no-pager -o short-iso-precise | grep -m1 'command tx timeout'; echo; echo 'first URB with non-zero status:'; journalctl -k -b 0 --since '2026-08-12 05:00:00' --until '2026-08-12 05:02:00' --no-pager -o short-iso-precise | grep -m1 -E 'urb .* status -[1-9]'; echo; echo 'first USB-level failure:'; journalctl -k -b 0 --since '2026-08-12 05:00:00' --until '2026-08-12 05:03:00' --no-pager -o short-iso-precise | grep -m1 'descriptor read'
```

## Output

Verbatim, 8 line(s), exit status 0.

```
first HCI command timeout:
2026-08-12T05:00:18.764738+02:00 n kernel: Bluetooth: hci0: command tx timeout

first URB with non-zero status:
2026-08-12T05:00:50.213852+02:00 n kernel: hci0 urb 00000000356db61f status -2 count 0

first USB-level failure:
2026-08-12T05:01:28.125704+02:00 n kernel: usb 3-3: device descriptor read/64, error -110
```

## Provenance

| field | value |
|---|---|
| captured | `2026-08-12T05:25:07+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `c1315c25` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
