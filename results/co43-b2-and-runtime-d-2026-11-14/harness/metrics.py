#!/usr/bin/env python3
"""metrics.py <log> [<log> ...]: one line per run log, read from its kernel (dmesg) lines.

  verdict      PASS/FAIL from the guest's own PASS/FAIL line (none if the guest never finished)
  timeouts     number of 'command 0x.... tx timeout' lines
  stall        seconds from the first timeout line to the next line that shows hci_cmd_timeout()
               handing back (btusb_reset()'s own message: 'Resetting usb device.', 'not resetting',
               'Failed usb_autopm_get_interface'); the HCI workqueue is blocked that long
  usbresets    'reset full-speed USB device' lines (the USB core's resets)
  btusb_reset  'Resetting usb device.' lines (btusb_reset() queued a reset)
  skipped      'not resetting' lines (btusb_reset() declined)
  autopm_err   'Failed usb_autopm_get_interface' lines
  kreports     BUG: / WARNING: / KASAN / lockdep / hung task lines
"""
import re
import sys

TS = re.compile(r"\[\s*(\d+\.\d+)\]")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
HANDBACK = ("Resetting usb device", "not resetting", "Failed usb_autopm_get_interface")


def run(path):
    kl = []
    verdict = "none"
    result = ""
    for raw in open(path, errors="replace"):
        line = ANSI.sub("", raw.rstrip("\n"))
        m = TS.search(line)
        if m and "mono" not in line[:40]:
            kl.append((float(m.group(1)), line))
        if re.search(r"\] (PASS|FAIL) ", line):
            verdict = line.split("] ", 1)[1].split()[0]
        if "RESULT " in line:
            result = line[line.index("RESULT "):]
    tmo = [t for t, l in kl if "tx timeout" in l]
    stall = None
    if tmo:
        for t, l in kl:
            if t >= tmo[0] and any(h in l for h in HANDBACK):
                stall = t - tmo[0]
                break
    cnt = lambda s: len([1 for t, l in kl if s in l])
    bad = len([1 for t, l in kl if re.search(r"BUG:|WARNING:|KASAN:|possible circular|blocked for more than|Call Trace:|inconsistent lock", l)])
    return {
        "run": path.rsplit("/", 1)[-1].replace(".log", ""),
        "verdict": verdict,
        "timeouts": len(tmo),
        "stall": "none" if stall is None else "%.3f" % stall,
        "usbresets": cnt("reset full-speed"),
        "btusb_reset": cnt("Resetting usb device"),
        "skipped": cnt("not resetting"),
        "autopm_err": cnt("Failed usb_autopm_get_interface"),
        "kreports": bad,
        "result": result,
    }


def main():
    for p in sys.argv[1:]:
        r = run(p)
        print("%-28s %-4s timeouts=%d stall=%s usbresets=%d btusb_reset=%d skipped=%d autopm_err=%d kreports=%d" %
              (r["run"], r["verdict"], r["timeouts"], r["stall"], r["usbresets"], r["btusb_reset"],
               r["skipped"], r["autopm_err"], r["kreports"]))


if __name__ == "__main__":
    main()
