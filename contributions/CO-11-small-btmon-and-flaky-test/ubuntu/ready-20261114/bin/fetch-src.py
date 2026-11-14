import json, os, urllib.request, hashlib
T = "/root/exp/agent-work/lane5-status-stable-20261114/task4/"
H = {"User-Agent": "qca9377-bt-hang/check"}
def get(u):
    return urllib.request.urlopen(urllib.request.Request(u, headers=H), timeout=180).read()
want = {"resolute": "5.85-4ubuntu0.5", "stonking": "5.87-4ubuntu0.1", "tenacious": "5.88-1"}
log = []
for s, v in want.items():
    d = T + "fetched/src-%s/" % s
    os.makedirs(d, exist_ok=True)
    u = ("https://api.launchpad.net/devel/ubuntu/+archive/primary?ws.op=getPublishedSources&distro_series=https://api.launchpad.net/devel/ubuntu/%s"
         "&exact_match=true&order_by_date=true&ws.size=6&source_name=bluez&version=%s" % (s, v))
    e = json.loads(get(u))["entries"][0]
    log.append("%s %s %s %s published %s" % (s, v, e["pocket"], e["status"], e["date_published"]))
    urls = json.loads(get(e["self_link"] + "?ws.op=sourceFileUrls"))
    for fu in urls:
        n = fu.rsplit("/", 1)[1]
        data = get(fu)
        open(d + n, "wb").write(data)
        log.append("  %s %d %s" % (n, len(data), hashlib.sha256(data).hexdigest()))
open(T + "logs/fetch-src.log", "w").write("\n".join(log) + "\n")
print("\n".join(log))
