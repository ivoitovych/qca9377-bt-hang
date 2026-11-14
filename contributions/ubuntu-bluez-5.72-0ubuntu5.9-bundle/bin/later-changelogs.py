import json, urllib.request
B = "/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle/logs/"
H = {"User-Agent": "qca9377-bt-hang/check"}
def get(u):
    return urllib.request.urlopen(urllib.request.Request(u, headers=H), timeout=60).read()
want = {"resolute": "5.85-4ubuntu0.5", "stonking": "5.87-4ubuntu0.1", "tenacious": "5.88-1"}
res = []
for s, v in want.items():
    u = ("https://api.launchpad.net/devel/ubuntu/+archive/primary?ws.op=getPublishedSources&distro_series=https://api.launchpad.net/devel/ubuntu/%s"
         "&exact_match=true&order_by_date=true&ws.size=6&source_name=bluez&version=%s" % (s, v))
    d = json.loads(get(u))
    e = d["entries"][0]
    cl = get(e["self_link"] + "?ws.op=changelogUrl").decode().strip().strip('"')
    txt = get(cl).decode(errors="replace")
    open(B + "changelog-%s-%s.txt" % (s, v), "w").write(txt)
    res.append("== %s %s (%s)\n%s" % (s, v, cl, "\n".join(txt.splitlines()[:30])))
print("\n\n".join(res))
