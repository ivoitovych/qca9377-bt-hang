# CO-20 (SCO errors at call hang-up) - what is left to you

**Patches** (a series of two, on bluetooth-next `da3cc02587c6`, today's tip):
1. `0001-Bluetooth-btusb-Report-SCO-receive-failures-by-cause.patch`
2. `0002-Bluetooth-btusb-Log-SCO-data-for-a-just-closed-link-.patch` (needs patch 1: it uses the `-ENOENT`
   case and the `handle` out-parameter)

They are the 2026-11-11 prototype (`0003`/`0004-co20-...`), moved to `btusb_main.c` and to the tip without a
conflict; no `Fixes:` tag; no Signed-off-by. **Nothing has been sent.** The send is yours, with your own
Signed-off-by after the last body line of each patch, before the `---`, and a dry run from the project checkout.
`cover-letter.txt` is a short draft.

## Decisions

1. **One patch or two.** Patch 1 alone only improves the log (a distinct message and the handle); patch 2 is
   the one that stops a normal hang-up from being an error. They could be one patch; two keeps the diagnostic
   change reviewable apart from the heuristic. Say if you want them merged.
2. **The heuristic of patch 2** ("the handle equals the last header that validated"). It is cheap and
   local, but it is a guess, and a maintainer may prefer another way (for instance ignoring data between the
   Disconnection Complete and the stop of the isochronous URBs by asking the core). Its stated limits:
   with two links up, data of the closed link that follows a packet of the remaining one is still reported
   (6 or 7 "unknown handle dropped" instead of 5 in the emulator, `CHECKS.md`); a misaligned fragment whose
   first two bytes equal the closed link's handle, in the short window after it closed, is taken for residue.
3. **`err_rx`.** Residue is no longer counted in `hdev->stat.err_rx`; everything else still is. In
   `net/bluetooth` and `include/net/bluetooth` the name occurs only in `struct hci_dev_stats`
   (`hci_sock.h:93`, `grep -rn err_rx`), which user space reads through the HCIGETDEVINFO ioctl (tools such
   as `hciconfig`); drivers increment it. Patch 2's message says residue is not counted; it does not name the
   ioctl.
4. **No stable Cc.** Nothing user-visible fails: it is the severity and the counting of a log line. The
   newline defect that made the late lines look odd is fixed upstream (`f51ee3bb5fbe`, already in the tip);
   a backport of that one is the only stable candidate here, and it is not ours.
5. **Not covered.** The core's "SCO packet for unknown connection handle" (`net/bluetooth/hci_core.c`,
   rate limited) is untouched: it is what remains in the logs after patch 2 (the emulator shows 1 to 6 per
   run). The laptop's late lines (minutes after a hang-up, CO-02 boot) are a different matter, still open in
   the CO-20 README.
6. **Not tested on the laptop.** The numbers on the laptop quoted in the cover letter (155 of 181 closed links
   with data after the Disconnection Complete, up to 33.6 ms; 25 of 32 "corrupted SCO packet" lines within
   0.5 s of one) are from the CO-20 README's 2026-11-11 reading of the captures, not re-measured today.

## What the tests showed and did not show

- **Showed** (`CHECKS.md`): in the emulator the unpatched kernel logs an error for most hang-ups (17, 19 and
  24 "corrupted SCO packet" in 20 calls) and the series none (15 to 18 debug lines); injected packets for a
  handle that never was a link are still reported, as "unknown handle dropped"; checkpatch `--strict` clean
  except the missing Signed-off-by; the bot's build checks pass on both sides.
- **Did not show:** the effect on a real controller; a guest controller that delivers residue is the
  emulator's own model of what the captures showed. No tester covers this code.
