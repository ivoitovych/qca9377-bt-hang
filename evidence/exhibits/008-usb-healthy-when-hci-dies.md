# EX-008 — usb-healthy-when-hci-dies

**Claim.** At the moment HCI stops answering, the USB transport is entirely healthy — every URB completes with status 0. The first non-zero URB status appears 31.4 s LATER; USB descriptor-read failures later still.

**Relevance.** Establishes the ordering: **HCI non-response precedes any observable USB failure by 31.4 seconds.** The device keeps accepting and completing USB transfers while refusing to answer an HCI command; USB-level collapse (-108 ESHUTDOWN, then descriptor read -110) follows tens of seconds later.

**What this rules out, stated narrowly:** *USB transport failure as the immediate cause of the first HCI timeout.* The kernel log alone cannot distinguish that from the actual ordering, and this settles it.

**⚠️ What it does NOT rule out.** An earlier draft said this "eliminates the entire class of USB transport wedge explanations", which is broader than the evidence supports. A stream of ordinary URBs completing normally says nothing about a *configuration* action on the same bus. In particular, btusb switches the USB interface alternate setting to obtain isochronous bandwidth for SCO (`Looking for Alt no :6 / :3`, and the recurring `setting interface failed (110)`), and an alternate-setting transition is a different proposition from bulk/interrupt traffic succeeding. It remains possible that a USB-side configuration action places the controller into the state in which it later stops answering HCI. Two adjacent candidate layers are still live:

1. **HCI/controller synchronous-link state**, and
2. **btusb USB isochronous-interface state.**

This exhibit constrains the *ordering* of the collapse. It does not adjudicate between those two.

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
