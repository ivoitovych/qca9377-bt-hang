#!/usr/bin/python3 -I
"""Round 2 analysis: one block per run of runs-v2/.

analyze-v2.py [runs-v2 dir]   (shebang runs python3 -I)
Writes logs-v2/analysis-v2.txt next to the runs dir and prints it.

For every run: removal relative to the disconnect and to the last report
delivered before it; for P1/P2 the Pair() window with the count of LE
advertising reports for the peer seen by the DUT controller (btmon) and the
matching bluetoothd device_found_callback lines inside the window, plus the
HCI Create Connection / Connect Complete events of the window.
All times: DUT guest clock (ns in the logs).
"""
import json
import re
import sys
import time
from pathlib import Path

top = Path(sys.argv[1] if len(sys.argv) > 1 else
           "/root/exp/agent-work/u29-t3-lifetime-patch/runs-v2")


def hms(ns):
    if ns is None:
        return "-"
    return time.strftime("%H:%M:%S", time.gmtime(ns / 1e9)) + ".%03d" % (ns // 10**6 % 1000)


def sec(a, b):
    return None if a is None or b is None else (a - b) / 1e9


def f(v, p=1):
    return "-" if v is None else "%.*f" % (p, v)


def adv_reports(path, peer):
    """(ns, flags-or-None, event type) of each LE advertising report for the
    peer in a btmon file; the ns of the report is the one of its header line"""
    out = []
    lines = path.read_text().splitlines()
    i = 0
    while i < len(lines):
        if re.search(r"> HCI Event: LE Meta Event|LE Extended Advertising Report|LE Advertising Report", lines[i]) \
                and ("Advertising Report" in lines[i]):
            ns = int(lines[i].split()[0])
            blk, j = [], i + 1
            while j < len(lines) and not re.search(r"\d+ (<|>|@) ", lines[j]) \
                    and not re.search(r"LE (Extended )?Advertising Report", lines[j]):
                blk.append(lines[j])
                j += 1
            txt = "\n".join(blk)
            if peer in txt:
                kind = re.search(r"Legacy PDU Type: ([A-Z_]+)", txt)
                fl = re.findall(r"Flags: (0x[0-9a-f]{2})", txt)
                out.append((ns, fl[-1] if fl else None, kind.group(1) if kind else "?"))
            i = j
        else:
            i += 1
    return out


def bd_found(path, peer):
    out = []
    for line in path.read_text().splitlines():
        if "device_found_callback()" in line and peer.lower() in line.lower():
            out.append(int(line.split()[0]))
    return out


def hci_events(path, t0, t1):
    out = []
    lines = path.read_text().splitlines()
    for k, line in enumerate(lines):
        m = re.match(r"(\d+) (<|>) HCI (Command|Event): (Create Connection|Connect Complete|Simple Pairing Complete|Disconnect Complete|Connect Request|Inquiry Cancel)\b", line)
        if m and t0 <= int(m.group(1)) <= t1:
            st = ""
            for l2 in lines[k + 1:k + 12]:
                mm = re.match(r"\d+\s+Status: (.*)$", l2)
                if mm:
                    st = mm.group(1)
                    break
            out.append((int(m.group(1)), m.group(4), st))
    return out


def one(rd):
    s = json.loads((rd / "summary.json").read_text())
    peer = s["peer"]
    dev = "dev_" + peer.replace(":", "_")
    disc, removed = s.get("t_disconnected"), s.get("removed")
    advs = adv_reports(rd / "btmon-dut.log", peer)
    bdf = bd_found(rd / "bluetoothd-dut.log", peer)
    after = [t for t, _, _ in advs if disc and t > disc]
    before_rem = [t for t in bdf if disc and t > disc and (removed is None or t < removed)]
    lines = ["== %s (arm %s)" % (rd.name, s["arm"])]
    lines.append("  disconnect %s  removed %s  removed-disc %s s  removed-lastdeliveredreport %s s  adv sent %d  adv reports at DUT controller after disc %d  bluetoothd device_found after disc %d"
                 % (hms(disc), hms(removed), f(sec(removed, disc)),
                    f(sec(removed, before_rem[-1]) if before_rem else None),
                    len(s.get("adv_starts") or []), len(after), len(before_rem)))
    if "pair_start" in s:
        ps, pe = s["pair_start"], s.get("pair_end")
        pe_eff = pe or (s.get("scan_end") or ps)
        w_adv = [x for x in advs if ps <= x[0] <= pe_eff]
        w_bd = [t for t in bdf if ps <= t <= pe_eff]
        lines.append("  Pair() window %s .. %s (%s s) result: %s" % (
            hms(ps), hms(pe), f(sec(pe, ps)), s.get("pair_result")))
        lines.append("    pair_out: %s" % (s.get("pair_out") or "-")[:200].replace("\n", " "))
        lines.append("    removed during Pair(): %s   removed-pair_end %s s" % (
            bool(removed and ps <= removed <= pe_eff), f(sec(removed, pe))))
        lines.append("    LE adv reports for the peer in the window (btmon, DUT controller): %d  (flags %s)" % (
            len(w_adv), ",".join(sorted(set(x[1] or "none" for x in w_adv))) or "-"))
        lines.append("    bluetoothd device_found_callback for the peer in the window: %d" % len(w_bd))
        for t, fl, kind in w_adv[:6]:
            lines.append("      adv %s +%.2fs flags %s %s" % (hms(t), sec(t, ps), fl, kind))
        for t in w_bd[:6]:
            lines.append("      device_found %s +%.2fs" % (hms(t), sec(t, ps)))
        for t, ev, st in hci_events(rd / "btmon-dut.log", ps - 10**9, pe_eff + 10**9)[:12]:
            lines.append("      hci %s %s %s %s" % (hms(t), "+%.3fs" % sec(t, ps), ev, st))
        # first / last adv relative to link events
    ev = [json.loads(l) for l in (rd / "events.jsonl").read_text().splitlines()]
    return "\n".join(lines)


def main():
    out = []
    for rd in sorted(top.iterdir()):
        if rd.is_dir() and (rd / "summary.json").exists():
            try:
                out.append(one(rd))
            except Exception as exc:       # keep going, report the failure
                out.append("== %s ANALYSIS ERROR %r" % (rd.name, exc))
        elif rd.is_dir():
            out.append("== %s: no summary.json" % rd.name)
    text = "\n".join(out) + "\n"
    (top.parent / "logs-v2" / "analysis-v2.txt").write_text(text)
    sys.stdout.write(text)


main()
