import json, os, collections
D = "/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle/co40/runs/"
for name in ("base-hold", "bundle-hold", "base-none", "bundle-none"):
    f = D + name + "/results.jsonl"
    if not os.path.exists(f):
        print(name, "no results"); continue
    rows = [json.loads(l) for l in open(f)]
    c = collections.Counter(); r111 = 0
    for r in rows:
        cn = r.get("connect")
        txt = json.dumps(cn) if not isinstance(cn, str) else cn
        for k in ("br-connection-refused", "br-connection-unknown", "br-connection-key-missing"):
            if k in txt:
                c[k] += 1; break
        else:
            c["other:" + txt[:80]] += 1
        r111 += bool(r.get("avdtp_connect_cb_refused_111"))
    print(name, "runs", len(rows), dict(c), "| avdtp_connect_cb 'Connection refused (111)' seen in", r111)
