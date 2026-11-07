"""Per-run and per-arm table from runs/<arm>-<n>/ (python3 -I analyze.py [runs dir]).

All times are the DUT guest clock (dbus-monitor reception time, btmon and
bluetoothd log time). The peer's advertising times come from the peer guest
clock (clock_check in events.jsonl shows the offset, tens of ms at most).
"""
import json
import re
import sys
from pathlib import Path

top = Path(sys.argv[1] if len(sys.argv) > 1 else
           "/root/exp/agent-work/u29-t2-temporary-lifetime/runs")
DEV = "dev_00_AA_01_01_00_42"
PEER = "00:AA:01:01:00:42"


def hms(ns):
    if ns is None:
        return "-"
    import time
    return time.strftime("%H:%M:%S", time.gmtime(ns / 1e9)) + ".%03d" % (ns // 10**6 % 1000)


def parse_dbus(path):
    msgs = []
    cur = None
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
        if DEV not in text:
            continue
        if "member=InterfacesAdded" in text:
            out.append((t, "InterfacesAdded", {}))
        elif "member=InterfacesRemoved" in text:
            out.append((t, "InterfacesRemoved", {}))
        elif "member=PropertiesChanged" in text:
            props = {}
            pending = None
            for i, l in enumerate(lines):
                m = re.match(r'\s+string "(\w+)"$', l)
                if m and i > 0 and "dict entry(" in lines[i - 1]:
                    pending = m.group(1)
                elif pending and "variant" in l:
                    props[pending] = l.split("variant", 1)[1].strip()
                    pending = None
            out.append((t, "PropertiesChanged", props))
    return out


def parse_btmon(path):
    """(ns, flags-or-None) of each MGMT Device Found for the peer"""
    found = []
    lines = path.read_text().splitlines()
    i = 0
    while i < len(lines):
        if "@ MGMT Event: Device Found" in lines[i]:
            ns = int(lines[i].split()[0])
            blk = []
            j = i + 1
            while j < len(lines) and not re.search(r"(MGMT|HCI) (Event|Command)|ACL Data", lines[j]):
                blk.append(lines[j])
                j += 1
            btxt = "\n".join(blk)
            if PEER in btxt:
                fl = re.findall(r"^\d+\s+Flags: (0x[0-9a-f]{2})$", btxt, re.M)
                # first Flags line is the mgmt flags (8 digits); AD flags are 2 digits
                found.append((ns, fl[-1] if fl else None))
            i = j
        else:
            i += 1
    return found


def count_adv_reports(path):
    txt = path.read_text()
    return len(re.findall(r"Legacy PDU Type: ADV_IND", txt))


rows = []
for rd in sorted(top.iterdir()):
    if not rd.is_dir() or not re.match(r"^[A-F]-\d+$", rd.name):
        continue
    sj = rd / "summary.json"
    if not sj.exists():
        rows.append(dict(run=rd.name, note="no summary.json"))
        continue
    s = json.loads(sj.read_text())
    d = parse_dbus(rd / "dbus-monitor.log")
    added = next((t for t, k, p in d if k == "InterfacesAdded"), None)
    disc = next((t for t, k, p in d if k == "PropertiesChanged" and p.get("Connected", "").endswith("false")), None)
    removed = next((t for t, k, p in d if k == "InterfacesRemoved"), None)
    rssi = [(t, p["RSSI"]) for t, k, p in d if k == "PropertiesChanged" and "RSSI" in p]
    other = {}
    for t, k, p in d:
        if k == "PropertiesChanged":
            for n in p:
                other[n] = other.get(n, 0) + 1
    found = [(t, f) for t, f in parse_btmon(rd / "btmon-dut.log") if disc and t > disc]
    adv_starts = s.get("adv_starts") or []
    row = dict(run=rd.name, added=added, disc=disc, removed=removed,
               n_beats=len(adv_starts), last_beat_peer_clock=s.get("last_adv"),
               n_found=len(found), found_flags=sorted(set(f for _, f in found if f)),
               last_found=found[-1][0] if found else None,
               n_rssi=len(rssi), rssi_vals=sorted(set(v for _, v in rssi)),
               props=other)
    # gap list between the disconnect, the Device Found events and the removal
    pts = ([disc] if disc else []) + [t for t, _ in found]
    row["max_gap_s"] = (max((b - a) / 1e9 for a, b in zip(pts, pts[1:])) if len(pts) > 1 else None)
    if removed and found:
        row["removed_after_last_found_s"] = (removed - found[-1][0]) / 1e9
    if removed and disc:
        row["removed_after_disc_s"] = (removed - disc) / 1e9
    if removed and s.get("last_adv"):
        row["removed_after_last_beat_s"] = (removed - s["last_adv"]) / 1e9
    expected = {"B": 13, "C": 13, "D": 13, "E": 13, "F": 31}.get(rd.name[0], 0)
    # the test stops sending as soon as the removal is seen: fewer beats than
    # planned means the object was removed while advertising was still going
    row["removed_during_adv_phase"] = bool(removed and expected and len(adv_starts) < expected)
    rows.append(row)


def f(v, p=1):
    return "-" if v is None else ("%.*f" % (p, v))


print("run | disconnect | last beat sent (peer clk) | last Device Found | removed | beats sent | Device Found after disc | removed-last beat s | removed-last Found s | removed-disc s | longest gap s | RSSI props | removed while still advertising")
print("--- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---")
for r in rows:
    if "note" in r:
        print(r["run"], "|", r["note"])
        continue
    print(" | ".join([
        r["run"], hms(r["disc"]), hms(r["last_beat_peer_clock"]), hms(r["last_found"]),
        hms(r["removed"]), str(r["n_beats"]), str(r["n_found"]),
        f(r.get("removed_after_last_beat_s")), f(r.get("removed_after_last_found_s")),
        f(r.get("removed_after_disc_s")), f(r.get("max_gap_s")),
        str(r["n_rssi"]), str(r["removed_during_adv_phase"])]))
if "--json" in sys.argv:
    for r in rows:
        print(json.dumps(r, default=str))
