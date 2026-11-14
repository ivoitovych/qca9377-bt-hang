import json, os, urllib.request, hashlib
T = "/root/exp/agent-work/lane5-status-stable-20261114/task5/"
H = {"User-Agent": "qca9377-bt-hang/check"}
def get(u):
    return urllib.request.urlopen(urllib.request.Request(u, headers=H), timeout=180).read()
log = []
for pkg in ("wireplumber", "gnome-control-center"):
    u = ("https://api.launchpad.net/devel/ubuntu/+archive/primary?ws.op=getPublishedSources&distro_series=https://api.launchpad.net/devel/ubuntu/noble"
         "&exact_match=true&order_by_date=true&ws.size=6&source_name=%s" % pkg)
    d = json.loads(get(u))
    open(T + "fetched/lp-noble-%s.json" % pkg, "w").write(json.dumps(d, indent=1))
    log.append("== %s noble versions (%s):" % (pkg, __import__("datetime").datetime.utcnow().strftime("%F %T UTC")))
    for e in d["entries"]:
        log.append("  %s %s %s %s" % (e["source_package_version"], e["pocket"], e["status"], e["date_published"][:19]))
    e = [x for x in d["entries"] if x["status"] == "Published"][0]
    ver = e["source_package_version"]
    dd = T + "fetched/src-%s/" % pkg
    os.makedirs(dd, exist_ok=True)
    for fu in json.loads(get(e["self_link"] + "?ws.op=sourceFileUrls")):
        n = fu.rsplit("/", 1)[1]
        data = get(fu)
        open(dd + n, "wb").write(data)
        log.append("  file %s %d %s" % (n, len(data), hashlib.sha256(data).hexdigest()))
open(T + "logs/fetch-src.log", "w").write("\n".join(log) + "\n")
print("\n".join(log))
