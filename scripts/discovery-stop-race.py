#!/usr/bin/env python3
"""discovery-stop-race.py — how each BR/EDR+LE discovery cycle ended, from saved btsnoop traces.

    scripts/discovery-stop-race.py <file.btsnoop>...      (files in time order)

Read-only: runs `btmon -T -r` on saved traces; nothing is sent to any controller.

WHAT IT MEASURES. With HCI_QUIRK_SIMULTANEOUS_DISCOVERY the kernel runs LE active scanning
and a BR/EDR Inquiry (10.24 s) at the same time, and arms a 10.24 s timer (le_scan_disable)
for the LE half. Two things end a cycle at almost the same moment: the controller's Inquiry
Complete event, and the timer, which sends LE Set Scan Enable (Disabled). The kernel reports
DISCOVERY_STOPPED as the MGMT event "Discovering: Disabled".

Each cycle runs from a MGMT Start Discovery to the next one (or to a kernel-initiated
restart, recognised by "Discovering: Enabled" without a start command). Its end is one of:
  cancelled        Inquiry Cancel was sent (a client stopped discovery, or a connection)
  IC first         Inquiry Complete before the scan-off command
  off done first   the scan-off's Command Complete before Inquiry Complete
  IC in between    Inquiry Complete after the scan-off command and before its Command
                   Complete — the order in which both stop paths leave the stop to the other
and whether "Discovering: Disabled" followed within 2 s ("stopped") or only later ("stopped
only after N s", with what came just before it), or never in these traces.

btmon shortens packet names (and sometimes the "Command"/"Event" word) when not writing to
a terminal, so packets are matched by direction and by their numeric codes.

Output: per-file start counts; totals by end and outcome; one line per cycle that is not
"IC first, stopped"/"cancelled, stopped"; then, for each cycle not stopped within 2 s, its
packet timeline; and the replies to the first start commands after it.
"""
import datetime
import re
import subprocess
import sys

TS = re.compile(r"(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d{6})\s*(?!.)")
HDR = re.compile(r"^[<>@=]")
START_CODES = ("0x0023", "0x003a", "0x0041")
STOP_WINDOW = 2.0


def packets(path):
    """Yield (header, detail text) for every packet btmon decodes from path."""
    p = subprocess.Popen(["btmon", "-T", "-r", path], stdout=subprocess.PIPE,
                         stderr=subprocess.DEVNULL, text=True, errors="replace")
    hdr, body = None, []
    for line in p.stdout:
        s = line.rstrip("\n")
        if HDR.match(s):
            if hdr is not None:
                yield hdr, " ".join(body)
            hdr, body = s, []
        elif hdr is not None:
            body.append(s.strip())
    if hdr is not None:
        yield hdr, " ".join(body)
    p.wait()


def classify(hdr, text):
    """Return (kind, time, info) for the packets that matter, else None."""
    m = TS.search(hdr)
    if not m:
        return None
    t = m.group(1)
    if hdr.startswith("@ MGMT"):
        code = re.search(r"\((0x[0-9a-f]{4})\)", hdr)
        if not code:
            return None
        c = code.group(1)
        is_cmd = hdr.startswith("@ MGMT C") and not hdr.startswith("@ MGMT Close")
        if is_cmd:
            if c in START_CODES:
                return ("start", t, c)
            return None
        if c == "0x0013":
            return ("discovering", t, "Enabled" if "Enabled (0x01)" in text else "Disabled")
        if c in ("0x0001", "0x0002") and any("(" + s + ")" in text for s in START_CODES):
            st = re.search(r"Status: ([^(]+)\((0x[0-9a-f]{2})\)", text)
            return ("start-reply", t, st.group(1).strip() + " " + st.group(2) if st else "?")
        if c == "0x002d":
            return ("ctrl-suspend", t, "")
        if c == "0x002e":
            return ("ctrl-resume", t, "")
        if c == "0x0006":
            return ("new-settings", t, "powered" if " Powered" in text.split("Current settings")[-1] else "not powered")
        return None
    if hdr.startswith("= ") and ("Index Removed" in hdr or "Delete Index" in hdr or "Close Index" in hdr):
        return ("index-gone", t, hdr[2:20])
    if hdr.startswith("< HCI Comm"):
        if "(0x08|0x000c)" in hdr or "(0x08|0x0042)" in hdr:
            return ("le-scan", t, "off" if "Disabled (0x00)" in text else "on")
        if "(0x01|0x0001)" in hdr:
            return ("inquiry", t, "")
        if "(0x01|0x0002)" in hdr:
            return ("inquiry-cancel", t, "")
        if "(0x01|0x0028)" in hdr or "(0x01|0x003d)" in hdr:
            return ("sco-setup", t, "")
        return None
    if hdr.startswith("> HCI Ev"):
        if re.search(r"\(0x01\) plen", hdr):
            return ("inquiry-complete", t, "")
        if re.search(r"\(0x2c\) plen", hdr):
            return ("sco-complete", t, "")
        if re.search(r"\(0x0e\) plen", hdr) and ("(0x08|0x000c)" in text or "(0x08|0x0042)" in text):
            return ("le-scan-done", t, "")
    return None


def secs(t):
    return datetime.datetime.strptime(t, "%Y-%m-%d %H:%M:%S.%f").timestamp()


def main(files):
    cycles = []
    cur = None
    per_file = []
    for path in files:
        name = path.rsplit("/", 1)[-1]
        n_start = 0
        for hdr, text in packets(path):
            c = classify(hdr, text)
            if c is None:
                continue
            kind = c[0]
            if kind == "start":
                n_start += 1
                cur = {"file": name, "start": c[1], "how": "start " + c[2], "events": [c]}
                cycles.append(cur)
            elif kind == "discovering" and c[2] == "Enabled" and cur is not None and \
                    any(e[0] == "discovering" and e[2] == "Disabled" for e in cur["events"]):
                # a kernel-initiated (re)start, e.g. after resume: a new cycle without a command
                cur = {"file": name, "start": c[1], "how": "kernel restart", "events": [c]}
                cycles.append(cur)
            elif cur is not None:
                cur["events"].append(c)
        per_file.append((name, n_start))

    totals = {}
    lines = []
    detail = []
    after = []
    for i, cy in enumerate(cycles):
        ev = cy["events"]
        reply = next((e[2] for e in ev if e[0] == "start-reply"), None)
        if cy["how"].startswith("start") and reply is None:
            kind = "start with no reply in the trace"
        elif reply is not None and not reply.startswith("Success"):
            kind = "refused (" + reply + ")"
        else:
            off = next((e[1] for e in ev if e[0] == "le-scan" and e[2] == "off"), None)
            off_done = next((e[1] for e in ev if e[0] == "le-scan-done" and off and e[1] > off), None)
            ic = next((e[1] for e in ev if e[0] == "inquiry-complete"), None)
            cancel = next((e[1] for e in ev if e[0] == "inquiry-cancel"), None)
            dis = next((e for e in ev if e[0] == "discovering" and e[2] == "Disabled"), None)
            if cancel and (ic is None or cancel < ic):
                end, end_t = "cancelled", cancel
            elif ic and off and ic < off:
                end, end_t = "IC first", ic
            elif ic and off and off_done and off_done < ic:
                end, end_t = "off done first", ic
            elif ic and off and (off_done is None or ic < off_done):
                end, end_t = "IC in between", ic
            else:
                end, end_t = "end not in trace", None
            if dis is None:
                outcome = "never stopped in these traces"
            elif end_t is None or secs(dis[1]) - secs(end_t) <= STOP_WINDOW:
                outcome = "stopped"
            else:
                j = ev.index(dis)
                before = ev[j - 1][0] if j > 0 else "?"
                outcome = "stopped only %.0f s later (%s, just after %s)" % (
                    secs(dis[1]) - secs(end_t), dis[1], before)
            kind = end + ", " + ("stopped only later" if outcome.startswith("stopped only") else outcome)
            if kind not in ("IC first, stopped", "cancelled, stopped", "off done first, stopped"):
                sco = any(e[0] in ("sco-setup", "sco-complete") and (end_t is None or e[1] <= end_t)
                          for e in ev)
                lines.append(f"  {cy['start']}  {cy['how']:15s} {end:16s} {outcome}"
                             + ("  [SCO set up during the cycle]" if sco else ""))
                if not outcome.startswith("stopped") or outcome.startswith("stopped only"):
                    detail.append(cy)
                    after.append(i)
        totals[kind] = totals.get(kind, 0) + 1

    for name, n in per_file:
        print(f"{name}: {n} start command(s)")
    print()
    print("totals by how the cycle ended:")
    for k in sorted(totals):
        print(f"  {totals[k]:6d}  {k}")
    print()
    print("cycles other than '<IC first | off done first | cancelled>, stopped':")
    for ln in lines:
        print(ln)
    for cy, i in zip(detail, after):
        print()
        print(f"--- timeline of the cycle started {cy['start']} ({cy['file']}), first 16 events:")
        for e in cy["events"][:16]:
            print(f"    {e[1]}  {e[0]:17s} {e[2]}")
        nxt = [c for c in cycles[i + 1:i + 4]]
        if nxt:
            print("    the next cycles:")
            for c in nxt:
                r = next((e[2] for e in c["events"] if e[0] == "start-reply"), "-")
                print(f"      {c['start']}  {c['how']:15s} reply: {r}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: scripts/discovery-stop-race.py <file.btsnoop>...", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1:])
