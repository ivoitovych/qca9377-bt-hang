#!/bin/bash
# in-container.sh — run INSIDE an ubuntu:26.04 container.
#   /src    the gvfs source tree (read-only), checked out at the revised commit
#   /cases  base/ patch1/ revised/ daemon/gvfsbackendcdda.c copies and the test programs
#   /out    writable output directory
# Builds gvfsd-cdda with every other backend off and --werror, then runs the simulated-drive
# tests against the three backend sources.
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
apt-get update -qq
apt-get build-dep -y -qq gvfs > /out/build-dep.log 2>&1
apt-get install -y -qq python3 pkg-config dpkg-dev libcdio-dev libcdio-paranoia-dev >> /out/build-dep.log 2>&1

opts=()
for o in admin afc afp archive dnssd goa google gphoto2 http mtp nfs onedrive sftp smb udisks2 \
         wsdd bluray fuse gcr gcrypt keyring logind libusb man devel_utils installed_tests unit_tests; do
    if grep -q "option('$o'" /src/meson_options.txt; then opts+=("-D$o=false"); fi
done
for o in systemduserunitdir tmpfilesdir; do
    if grep -q "option('$o'" /src/meson_options.txt; then opts+=("-D$o=no"); fi
done
meson setup /build /src --werror -Dcdda=true -Dgudev=true "${opts[@]}" > /out/meson-setup.log 2>&1
echo "meson setup exit $?" > /out/build-status.txt
ninja -C /build daemon/gvfsd-cdda > /out/compile.log 2>&1
echo "ninja exit $?" >> /out/build-status.txt
grep -c -E 'warning:' /out/compile.log >> /out/build-status.txt
echo "tools: $(gcc -dumpfullversion) glib $(pkg-config --modversion glib-2.0) libcdio $(pkg-config --modversion libcdio) libcdio_paranoia $(pkg-config --modversion libcdio_paranoia)" >> /out/build-status.txt
grep -E "HAVE_PARANOIA_CACHEMODEL|cachemodel" /out/meson-setup.log >> /out/build-status.txt

mkdir /w
cd /w
apt-get source -qq libcdio > /dev/null 2>&1
LIB=$(find /w -maxdepth 1 -type d -name "libcdio-*" | head -1)
echo "libcdio source $LIB" >> /out/build-status.txt

run_cases() {   # $1 label for the program, $2 program, then case lines on stdin
  while read -r label args; do
    [ -z "$label" ] && continue
    for s in base patch1 revised; do
      res=$(timeout 60 python3 -I "$2" "/cases/$s/daemon/gvfsbackendcdda.c" "$LIB" $args 2>&1)
      rc=$?
      echo "=== $1 $label $s exit $rc"
      echo "$res"
      printf "%s\t%s\t%s\t%s\t%s\n" "$1" "$label" "$s" "$rc" "$(echo "$res" | tail -1)" >> /out/results.tsv
    done
  done
}
printf "test\tcase\tsource\texit\tlast line\n" > /out/results.tsv
{
run_cases open /cases/gvfs-cdda-track-test.py <<CASES
tracks-1-3_open-1 1 1
tracks-1-3_open-3 1 3
tracks-1-3_open-0 1 0
tracks-1-3_open-4 1 4
tracks-1-3_open-99 1 99
tracks-1-3_open-257 1 257
tracks-1-3_data-3_open-3 1 3 --data 3
tracks-1-3_data-3_open-2 1 2 --data 3
tracks-2-4_open-4 2 4
tracks-2-4_open-2 2 2
tracks-2-4_open-1 2 1
tracks-2-4_open-5 2 5
tracks-5-7_open-5 5 5
tracks-5-7_open-7 5 7
tracks-5-7_open-4 5 4
tracks-5-7_open-8 5 8
tracks-97-99_open-99 97 99
tracks-2-4_data-2_open-2 2 2 --data 2
CASES
run_cases listing /cases/gvfs-cdda-listing-test.py <<CASES
tracks-1-3 1
tracks-2-4 2
tracks-5-7 5
tracks-1-3_data-3 1 --data 3
tracks-2-4_data-2 2 --data 2
CASES
} > /out/run.log 2>&1
echo done >> /out/build-status.txt
