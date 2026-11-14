import json, urllib.request
B = "/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle/logs/"
out = []
for s in ("resolute", "stonking", "tenacious"):
    u = ("https://api.launchpad.net/devel/ubuntu/+archive/primary?ws.op=getPublishedSources&distro_series=https://api.launchpad.net/devel/ubuntu/%s"
         "&exact_match=true&order_by_date=true&ws.size=4&source_name=bluez" % s)
    d = json.load(urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "qca9377-bt-hang/check"}), timeout=60))
    for e in d["entries"][:3]:
        out.append("%s %s %s %s %s" % (s, e["source_package_version"], e["pocket"], e["status"], e["date_published"][:19]))
open(B + "later-series.txt", "w").write("# fetched via api.launchpad.net, bin/later-series.py\n" + "\n".join(out) + "\n")
print("\n".join(out))
