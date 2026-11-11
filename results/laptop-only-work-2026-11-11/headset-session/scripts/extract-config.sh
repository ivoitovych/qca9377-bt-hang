#!/bin/sh
# Install Noble's own wireplumber/pipewire in a throw-away ubuntu:24.04
# container and copy their shipped configuration and scripts out for reading.
# No device passed, nothing from the host except the output directory.
top=/root/exp/agent-work/laptop-headset-session-20261111
out=$top/work/shipped
mkdir -p "$out"
"$top/scripts/log.sh" START extract-config
docker run --rm -v "$out:/out" ubuntu:24.04 sh -c '
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends wireplumber pipewire pipewire-pulse libspa-0.2-bluetooth libspa-0.2-modules pipewire-bin >/dev/null
dpkg-query -W wireplumber pipewire pipewire-pulse libspa-0.2-bluetooth libspa-0.2-modules > /out/versions.txt
cp -a /usr/share/wireplumber /out/usr-share-wireplumber
cp -a /usr/share/spa-0.2/bluez5 /out/spa-bluez5
cp -a /usr/share/pipewire /out/usr-share-pipewire
ls -la /etc/wireplumber /etc/pipewire 2>&1 > /out/etc-listing.txt || true
'
echo "exit $?"
"$top/scripts/log.sh" END extract-config
