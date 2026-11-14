import json, os, collections, sys
D = "/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle/l2runs/"
for run in sys.argv[1:] or ("base-l2rates", "bundle-l2rates"):
    f = D + run + "/results.jsonl"
    if not os.path.exists(f):
        print(run, "no results"); continue
    rows = [json.loads(l) for l in open(f)]
    by = collections.OrderedDict()
    for r in rows:
        by.setdefault(r["test"], []).append(r)
    print("==", run, "records", len(rows))
    tot = lost = ok = abort = san = 0
    for t, rs in sorted(by.items()):
        n = len(rs)
        l = sum(1 for r in rs if r.get("transport_alive") is False or r.get("lost_ms") is not None)
        ab = sum(1 for r in rs if r.get("abort_sent"))
        later = sum(1 for r in rs if (r.get("probe") or {}).get("flowed"))
        sa = sum(1 for r in rs if r.get("sanitizer"))
        print("  %-5s n=%-2d mode=%-8s A2DP lost %2d/%d  ABORT sent %2d/%d  later Acquire+media %2d/%d  sanitizer %d  Acquire reply: %s" % (
            t, n, rs[0].get("mode"), l, n, ab, n, later, n, sa, sorted({str((r.get("acquire") or {}).get("reply")) for r in rs})))
        tot += n; lost += l; abort += ab; ok += later; san += sa
    print("  total n=%d  A2DP lost %d  ABORT %d  later Acquire+media %d  sanitizer %d" % (tot, lost, abort, ok, san))
