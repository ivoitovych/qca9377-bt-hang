#!/usr/bin/env python3
"""Tabulate the repeated runs (run-kmemleak-reps.sh, run-busy-drain-reps.sh).

For each case and scan method: in how many runs the last of the five
scans reported an object allocated by mgmt_mesh_add() (the leaked
request) and one allocated by hci_sock_create() (its socket), and the
earliest round in which the request was reported.

busy-drain: per advertising type, in how many runs socket A had three
outstanding handles before B's send, was Busy after
power-on, Mesh Packet Complete was sent for A's failed handle 1 although it
was never started,
A's failed handles 2 and 3 were started (mesh_send_sync) and their data
reached the controller, B's first packet was started twice, and A could
send again.

Usage: tabulate-reps.py <logs-dir> <build-name>...   (Markdown to stdout)
"""
import collections
import glob
import os
import re
import sys

NAME = re.compile(r"(\w+)-(inproc-plain|inproc-shrink|after-exit)-r\d+$")
ROUND = re.compile(r"kmemleak round=(\d).*from_mgmt_mesh_add=(\d+) "
                   r"from_hci_sock_create=(\d+)")
METHODS = {
    "after-exit": "plain, after the reproducer exited",
    "inproc-plain": "plain, from the running reproducer",
    "inproc-shrink": "slab caches shrunk, from the running reproducer",
}


def main():
    logs = sys.argv[1]
    for build in sys.argv[2:]:
        busy_drain_table(logs, build)
        runs = collections.defaultdict(list)
        for f in sorted(glob.glob(os.path.join(logs, "reps-" + build, "*.log"))):
            m = NAME.match(os.path.basename(f)[:-4])
            if not m:
                continue
            rounds = []
            with open(f, errors="replace") as fh:
                for line in fh:
                    r = ROUND.search(line)
                    if r:
                        rounds.append(tuple(map(int, r.groups())))
            last = rounds[-1] if rounds else (0, 0, 0)
            first = next((n for n, mesh, _ in rounds if mesh), None)
            runs[m.groups()].append((last[1] > 0, last[2] > 0, first))

        if not runs:
            continue
        print(f"## {build}: kmemleak\n")
        print("| Case | Scan | Runs | Request reported | Socket reported "
              "| First round |")
        print("|---|---|---|---|---|---|")
        for (case, method), v in sorted(runs.items()):
            n = len(v)
            firsts = sorted({f for _, _, f in v if f})
            print(f"| `-{case.upper()}` | {METHODS[method]} | {n} "
                  f"| {sum(a for a, _, _ in v)}/{n} "
                  f"| {sum(b for _, b, _ in v)}/{n} "
                  f"| {', '.join(map(str, firsts)) or '-'} |")
        print()


BD_NAME = re.compile(r"busy-drain-(legacy|ext)-r\d+$")


def busy_drain(path):
    text = open(path, errors="replace").read().replace("\r", "")
    kp = {int(h): (int(a), int(sy), int(r)) for h, a, sy, r in re.findall(
        r"RESULT end kprobe handle=(\d+) added=(\d+) mesh_send_sync=(\d+) "
        r"removed=(\d+)", text)}
    tags = {int(t): int(n) for t, n in re.findall(
        r"RESULT end hci tag=(\d+) adv_data_writes=(\d+)", text)}
    first_b = re.search(r"sockB: Mesh Send tag 11 -> Success handle (\d+)", text)
    hb = int(first_b.group(1)) if first_b else None
    done = re.search(r"RESULT end sockB packet_complete_handles=([\d,]+)", text)
    completed = {int(h) for h in done.group(1).split(",")} if done else set()
    return {
        "A had 3 outstanding handles before B's send":
            "sockA_after_3_failures outstanding=3" in text,
        "A Busy after power-on":
            "sockA_send_after_power_on status=Busy" in text,
        "A has no outstanding handles after B's 1st send":
            "sockA_after_sockB_send_1 outstanding=0" in text,
        "Mesh Packet Complete for failed handle 1, never started":
            1 in completed and kp.get(1, (0, 0, 0))[1] == 0
            and tags.get(1) == 0,
        "failed handles 2, 3 started (mesh_send_sync)":
            all(kp.get(h, (0, 0, 0))[1] >= 1 for h in (2, 3)),
        "failed handles 2, 3 data reached controller":
            all(tags.get(t, 0) >= 1 for t in (2, 3)),
        "B's 1st packet started twice":
            hb is not None and kp.get(hb, (0, 0, 0))[1] == 2,
        "A can send again":
            "sockA_send_after_drain status=Success" in text,
    }


def busy_drain_table(logs, build):
    runs = collections.defaultdict(list)
    for f in sorted(glob.glob(os.path.join(logs, "reps-" + build, "*.log"))):
        m = BD_NAME.match(os.path.basename(f)[:-4])
        if m:
            runs[m.group(1)].append(busy_drain(f))
    if not runs:
        return
    print(f"## {build}: busy-drain\n")
    advs = sorted(runs)
    print("| Observation | " + " | ".join(advs) + " |")
    print("|---|" + "---|" * len(advs))
    for key in runs[advs[0]][0]:
        cells = [f"{sum(r[key] for r in runs[a])}/{len(runs[a])}" for a in advs]
        print(f"| {key} | " + " | ".join(cells) + " |")
    print()


if __name__ == "__main__":
    main()
