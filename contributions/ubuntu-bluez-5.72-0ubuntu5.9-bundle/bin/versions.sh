#!/bin/bash
# newest bluez in noble (all pockets) and download of the 5.72-0ubuntu5.8 source package
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
mkdir -p "$B/logs" "$B/src"
A="https://api.launchpad.net/devel/ubuntu/+archive/primary?ws.op=getPublishedSources&distro_series=https://api.launchpad.net/devel/ubuntu/noble&exact_match=true&order_by_date=true&ws.size=8&source_name=bluez"
{
  date -u +"# %F %T UTC  $A"
  curl -s -m 60 -A "qca9377-bt-hang/check" "$A" -o "$B/logs/lp-bluez-noble.json"
  python3 -I -c "
import json
d=json.load(open('$B/logs/lp-bluez-noble.json'))
for e in d['entries']: print(e['source_package_version'], e['pocket'], e['status'], e['date_published'][:19], e.get('date_removed') or '')
"
} > "$B/logs/noble-versions.txt" 2>&1
cd "$B/src" || exit 2
for f in bluez_5.72-0ubuntu5.8.dsc bluez_5.72-0ubuntu5.8.debian.tar.xz bluez_5.72.orig.tar.xz; do
  curl -s -L -m 120 -A "qca9377-bt-hang/check" -o "$f" "https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/bluez/5.72-0ubuntu5.8/$f"
done
sha256sum bluez_5.72-0ubuntu5.8.* bluez_5.72.orig.tar.xz > "$B/logs/src-sha256.txt"
for f in bluez_5.72-0ubuntu5.8.dsc bluez_5.72-0ubuntu5.8.debian.tar.xz bluez_5.72.orig.tar.xz; do
  cmp "$f" "/root/exp/agent-work/co03/src/archive/$f" && echo "same as co03 copy: $f" >> "$B/logs/src-sha256.txt"
done
