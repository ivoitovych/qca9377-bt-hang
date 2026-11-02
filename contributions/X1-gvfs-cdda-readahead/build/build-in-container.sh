#!/bin/bash
# build-in-container.sh — run INSIDE an Ubuntu container: install gvfs's build dependencies
# from the release's own archive, configure gvfs with only the cdda backend, build gvfsd-cdda
# and copy it plus the compile log to /out.
#   /src  the gvfs source tree (read-only is fine)
#   /out  writable output directory
set -euo pipefail
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get build-dep -y -qq gvfs > /out/build-dep.log 2>&1

# Turn off every backend and optional feature this tree knows, except cdda and gudev.
opts=()
for o in admin afc afp archive dnssd goa google gphoto2 http mtp nfs onedrive sftp smb udisks2 \
         wsdd bluray fuse gcr gcrypt keyring logind libusb man devel_utils installed_tests unit_tests; do
    if grep -q "option('$o'" /src/meson_options.txt; then opts+=("-D$o=false"); fi
done
for o in systemduserunitdir tmpfilesdir; do
    if grep -q "option('$o'" /src/meson_options.txt; then opts+=("-D$o=no"); fi
done
meson setup /build /src -Dcdda=true -Dgudev=true "${opts[@]}" > /out/meson-setup.log 2>&1
ninja -C /build daemon/gvfsd-cdda > /out/compile.log 2>&1
cp /build/daemon/gvfsd-cdda /out/
grep -c -E 'warning:' /out/compile.log > /out/warning-count.txt || true
echo built > /out/STATUS
