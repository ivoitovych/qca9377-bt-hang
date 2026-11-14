#!/bin/bash
# the two installed-package VM images: bundle (my .debs 5.72-0ubuntu5.9) and stock (archive 5.72-0ubuntu5.8), both with Noble's own
# PipeWire and WirePlumber (as CO-03's review images). Only inside the images; nothing is installed on the host.
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
I=$B/installed
mkdir -p "$I/bundle/debs" "$I/stock"
cp "$B/tree/bluez_5.72-0ubuntu5.9_amd64.deb" "$B/tree/libbluetooth3_5.72-0ubuntu5.9_amd64.deb" "$I/bundle/debs/"
cat > "$I/bundle/Dockerfile" <<'EOF'
FROM co03-noble-vm:1
ENV DEBIAN_FRONTEND=noninteractive
COPY debs /debs
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         /debs/libbluetooth3_5.72-0ubuntu5.9_amd64.deb \
         /debs/bluez_5.72-0ubuntu5.9_amd64.deb \
         pipewire pipewire-bin wireplumber libspa-0.2-bluetooth pipewire-audio-client-libraries \
    && apt-get clean \
    && dpkg-query -W bluez libbluetooth3 pipewire wireplumber libspa-0.2-bluetooth
EOF
cp /root/exp/agent-work/co03/review-20261101/docker/installed-stock/Dockerfile "$I/stock/Dockerfile"
sha256sum "$I"/bundle/debs/* > "$B/logs/installed-debs.sha256"
docker build -t bundle572-installed:bundle "$I/bundle" > "$B/logs/image-bundle.log" 2>&1
echo "bundle image exit $?"
docker build -t bundle572-installed:stock "$I/stock" > "$B/logs/image-stock.log" 2>&1
echo "stock image exit $?"
grep -E "^(bluez|libbluetooth3|pipewire|wireplumber|libspa)" "$B/logs/image-bundle.log" "$B/logs/image-stock.log" | tail -n 12
