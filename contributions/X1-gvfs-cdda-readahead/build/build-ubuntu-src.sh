#!/bin/bash
# build-ubuntu-src.sh — run INSIDE an ubuntu:24.04 container: fetch Ubuntu's gvfs source package,
# apply its own patches (dpkg-source does) plus /patch/readahead.diff, build gvfsd-cdda only.
#   /patch  holds readahead.diff
#   /out    writable output directory
set -euo pipefail
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get build-dep -y -qq gvfs > /out/build-dep.log 2>&1
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq dpkg-dev patch > /dev/null 2>&1
mkdir -p /work
cd /work
apt-get source -qq gvfs > /out/source.log 2>&1
SRC="$(find /work -maxdepth 1 -type d -name 'gvfs-*' | head -n 1)"
dpkg-parsechangelog -l "$SRC/debian/changelog" -S Version > /out/ubuntu-version.txt
patch -d "$SRC" -p1 < /patch/readahead.diff > /out/patch.log 2>&1

opts=()
for o in admin afc afp archive dnssd goa google gphoto2 http mtp nfs onedrive sftp smb udisks2 \
         wsdd bluray fuse gcr gcrypt keyring logind libusb man devel_utils installed_tests unit_tests; do
    if grep -q "option('$o'" "$SRC/meson_options.txt"; then opts+=("-D$o=false"); fi
done
for o in systemduserunitdir tmpfilesdir; do
    if grep -q "option('$o'" "$SRC/meson_options.txt"; then opts+=("-D$o=no"); fi
done
meson setup /build "$SRC" --prefix=/usr --libexecdir=lib/gvfs -Dcdda=true -Dgudev=true "${opts[@]}" > /out/meson-setup.log 2>&1
ninja -C /build daemon/gvfsd-cdda > /out/compile.log 2>&1
cp /build/daemon/gvfsd-cdda /out/
cp "$SRC/daemon/gvfsbackendcdda.c" /out/gvfsbackendcdda.c.patched
echo built > /out/STATUS
