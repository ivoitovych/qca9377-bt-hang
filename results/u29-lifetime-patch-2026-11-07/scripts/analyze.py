"""One table per tree (master, 5.72) from runs/<tree>-<build>-<arm>-<n>/.

python3 -I analyze.py [runs dir] [--json]

All times are on the DUT guest clock (dbus-monitor reception time, btmon time),
except "last beat" which is the peer guest clock when the advertisement was
sent (the offset is tens of ms at most, see clock_check in events.jsonl).
Columns:
  rem-disc      removal (InterfacesRemoved) relative to the disconnect (s)
  rem-prevrep   removal relative to the last Device Found that arrived BEFORE it
  rem-lastrep   removal relative to the last Device Found for the peer that
                reached bluetoothd after the disconnect (s)
  rem-lastbeat  same against the last advertisement sent (peer clock)
  reports       number of MGMT Device Found events for the peer after disconnect
  AD flags      AD Flags values seen in those reports ("none" = no Flags AD)
  RSSI          number of RSSI PropertiesChanged on the device, distinct values
  re-added      InterfacesAdded for the device after the removal
"""
import json
import re
import sys
import time
from pathlib import Path

top = Path([a for a in sys.argv[1:] if not a.startswith("--")][0]
           if [a for a in sys.argv[1:] if not a.startswith("--")] else
           "/root/exp/agent-work/u29-t3-lifetime-patch/runs")


def hms(ns):
    if ns is None:
        return "-"
    return time.strftime("%H:%M:%S", time.gmtime(ns / 1e9)) + ".%03d" % (ns // 10**6 % 1000)


def f(v, p=1):
    return "-" if v is None else ("%.*f" % (p, v))


def parse_dbus(path, dev):
    msgs, cur = [], None
    for line in path.read_text().splitlines():
        m = re.match(r"### recv_ns=(\d+)", line)
        if m:
            cur = [int(m.group(1)), []]
            msgs.append(cur)
        elif cur is not None:
            cur[1].append(line)
    out = []
    for t, lines in msgs:
        text = "\n".join(lines)
        if dev not in text:
            continue
        if "member=InterfacesAdded" in text:
            out.append((t, "InterfacesAdded", {}))
        elif "member=InterfacesRemoved" in text:
            out.append((t, "InterfacesRemoved", {}))
        elif "member=PropertiesChanged" in text:
            props, pending = {}, None
            for i, l in enumerate(lines):
                m = re.match(r'\s+string "(\w+)"$', l)
                if m and i > 0 and "dict entry(" in lines[i - 1]:
                    pending = m.group(1)
                elif pending and "variant" in l:
                    props[pending] = l.split("variant", 1)[1].strip()
                    pending = None
            out.append((t, "PropertiesChanged", props))
    return out


def parse_btmon(path, peer):
    """(ns, AD flags or None) of each MGMT Device Found for the peer"""
    found = []
    lines = path.read_text().splitlines()
    i = 0
    while i < len(lines):
        if "@ MGMT Event: Device Found" in lines[i]:
            ns = int(lines[i].split()[0])
            blk, j = [], i + 1
            while j < len(lines) and not re.search(r"(MGMT|HCI) (Event|Command)|ACL Data", lines[j]):
                blk.append(lines[j])
                j += 1
            btxt = "\n".join(blk)
            if peer in btxt:
                fl = re.findall(r"^\d+\s+Flags: (0x[0-9a-f]{2})$", btxt, re.M)
                found.append((ns, fl[-1] if fl else None))
            i = j
        else:
            i += 1
    return found


def bearer_after(path, t0):
    """first connection-creating HCI command after t0 (ns) in a btmon log"""
    for line in path.read_text().splitlines():
        m = re.match(r"(\d+) < HCI Command: (LE Create Connection|LE Extended Create Connection|Create Connection)\b", line)
        if m and int(m.group(1)) >= t0:
            return ("LE" if m.group(2).startswith("LE") else "BR/EDR"), int(m.group(1))
    return None, None


def analyse(rd):
    s = json.loads((rd / "summary.json").read_text())
    dev = "dev_" + s["peer"].replace(":", "_")
    d = parse_dbus(rd / "dbus-monitor.log", dev)
    disc = s.get("t_disconnected")
    removed = s.get("removed")
    added = s.get("t_added")
    found = [(t, fl) for t, fl in parse_btmon(rd / "btmon-dut.log", s["peer"])
             if disc and t > disc]
    rssi = [p["RSSI"] for t, k, p in d if k == "PropertiesChanged" and "RSSI" in p]
    row = dict(run=rd.name, arm=s["arm"], disc=disc, removed=removed,
               n_beats=len(s.get("adv_starts") or []),
               last_beat=s.get("last_adv"), n_found=len(found),
               flags=sorted(set(fl or "none" for _, fl in found)),
               last_found=found[-1][0] if found else None,
               n_rssi=len(rssi), rssi_vals=sorted(set(rssi)))
    row["rem_disc"] = (removed - disc) / 1e9 if removed and disc else None
    # reports that reached bluetoothd before the removal: the removal is
    # expected 30 s after the last of those (a scan gap of more than 30 s
    # in the delivered reports makes the object go during the adv phase)
    before = [t for t, _ in found if removed and t < removed]
    row["rem_prevrep"] = (removed - before[-1]) / 1e9 if before else None
    row["n_before_removal"] = len(before)
    row["rem_lastrep"] = (removed - found[-1][0]) / 1e9 if removed and found else None
    row["rem_lastbeat"] = ((removed - s["last_adv"]) / 1e9
                           if removed and s.get("last_adv") else None)
    row["readded"] = sum(1 for t, k, p in d if k == "InterfacesAdded"
                         and removed and t > removed)
    row["removed_before_disc"] = s.get("removed_before_disconnect")
    row["removed_during_adv"] = s.get("removed_during_adv_phase")
    if "pair_start" in s:
        row["pair"] = "%s %.1fs" % (s["pair_result"].rsplit(":", 1)[-1],
                                   (s["pair_end"] - s["pair_start"]) / 1e9)
        row["rem_in_pair"] = bool(removed and s["pair_start"] <= removed <= s["pair_end"])
        row["rem_vs_pair_end"] = ((removed - s["pair_end"]) / 1e9) if removed else None
    if "connect_called" in s:
        b, tb = bearer_after(rd / "btmon-dut.log", s["connect_called"] - 2 * 10**9)
        # (connect_called is stamped after the async call returned, so the
        # HCI command can precede it by a few ms; the pairing's own Create
        # Connection is a minute earlier)
        row["connect"] = s["connect_result"].rsplit(":", 1)[-1]
        row["connect_error"] = s.get("connect_error")
        row["bearer"] = b
    return row


def check(row, build):
    """expected-result check (the matrix of the task); returns 'ok' or a reason"""
    a = row["arm"]
    # "rl": removal relative to the last report that arrived BEFORE it
    rd, rl, rem = row["rem_disc"], row["rem_prevrep"], row["removed"]
    in30 = lambda v: v is not None and 27 <= v <= 36
    if a == "A":
        return "ok" if in30(rd) else "removed %s s after disc" % f(rd)
    if a in ("B", "D"):
        if build == "base":
            return "ok" if (in30(rl) and row["rem_disc"] and row["rem_disc"] > 40) else "base: rem-disc %s rem-lastrep %s" % (f(rd), f(rl))
        return "ok" if in30(rd) else "patched: rem-disc %s" % f(rd)
    if a in ("C", "E"):
        # kept while reports arrive; removal 30 s after the last delivered one
        return "ok" if (in30(rl) and rd and rd > 40) else "rem-disc %s rem-lastrep %s" % (f(rd), f(rl))
    if a == "G":
        if build == "base":
            return "ok" if (in30(rl) and rd and rd > 40) else "base: rem-disc %s rem-lastrep %s" % (f(rd), f(rl))
        return "ok" if in30(rd) else "patched: rem-disc %s" % f(rd)
    if a == "H":
        return "ok" if (rem is None and row.get("connect") == "reply") else \
            "removed=%s connect=%s %s" % (hms(rem), row.get("connect"), row.get("connect_error"))
    if a == "I":
        return "ok" if not row.get("rem_in_pair") else "removed during pairing"
    if a == "J":
        if row.get("removed_before_disc"):
            return "removed while connected"
        return "ok" if in30(rd) else "rem-disc %s" % f(rd)
    return "?"


def main():
    runs = [rd for rd in sorted(top.iterdir()) if rd.is_dir()
            and re.match(r"^(master|5\.72)-(base|patched)-[A-J]-\d+$", rd.name)]
    rows = {}
    for rd in runs:
        tree, build, arm, n = re.match(
            r"^(master|5\.72)-(base|patched)-([A-J])-(\d+)$", rd.name).groups()
        if not (rd / "summary.json").exists():
            rows.setdefault(tree, []).append((build, arm, n, dict(run=rd.name, note="no summary.json")))
            continue
        rows.setdefault(tree, []).append((build, arm, n, analyse(rd)))
    for tree in sorted(rows):
        print("\n=== tree: %s ===" % tree)
        print("run | disconnect | last beat (peer) | last report | removed | beats | reports | AD flags | rem-disc s | rem-prevrep s | rem-lastrep s | rem-lastbeat s | RSSI (n: values) | re-added | arm-specific | expected?")
        print("--- | " * 15 + "---")
        for build, arm, n, r in sorted(rows[tree], key=lambda x: (x[1], x[0], x[2])):
            if "note" in r:
                print(r["run"], "|", r["note"])
                continue
            extra = []
            if "pair" in r:
                extra.append("Pair() %s; removed during pairing: %s; removed-pair_end %s" % (r["pair"], r["rem_in_pair"], f(r["rem_vs_pair_end"])))
            if "connect" in r:
                extra.append("Connect %s (%s) bearer %s" % (r["connect"], r["connect_error"], r["bearer"]))
            if r["removed_before_disc"] is not None:
                extra.append("removed before disconnect: %s" % r["removed_before_disc"])
            if r["removed_during_adv"] is not None:
                extra.append("removed during adv phase: %s" % r["removed_during_adv"])
            print(" | ".join([
                r["run"], hms(r["disc"]), hms(r["last_beat"]), hms(r["last_found"]),
                hms(r["removed"]), str(r["n_beats"]), str(r["n_found"]),
                ",".join(r["flags"]) or "-", f(r["rem_disc"]), f(r["rem_prevrep"]), f(r["rem_lastrep"]),
                f(r["rem_lastbeat"]),
                "%d: %s" % (r["n_rssi"], ",".join(r["rssi_vals"]) or "-"),
                str(r["readded"]), "; ".join(extra) or "-", check(r, build)]))
    if "--json" in sys.argv:
        for tree in rows:
            for build, arm, n, r in rows[tree]:
                print(json.dumps(r, default=str))


if __name__ == "__main__":
    import contextlib
    import io
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        main()
    (top.parent / "logs" / "analysis.txt").write_text(buf.getvalue())
    sys.stdout.write(buf.getvalue())
