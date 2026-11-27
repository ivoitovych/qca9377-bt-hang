#!/bin/bash
# in-container-2404.sh — INSIDE ubuntu:24.04.
#   /patches  posted.patch squashed.patch and the !368 patch (0001-cdda-Limit-*.patch)
#   /tag      gvfs-1.54.4.tar (git archive of the upstream tag)
#   /t        test programs (gvfs-cdda-track-test.py, gvfs-cdda-listing-test.py)
#   /out      output directory
# For the upstream tag and for Ubuntu's source package: apply posted and squashed patches
# (patch -p1, offsets and fuzz logged), build gvfsd-cdda --werror from the squashed tree,
# run the 18 open cases and the 5 listing cases against base, posted and revised sources.
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
apt-get update -qq
apt-get build-dep -y -qq gvfs > /out/build-dep.log 2>&1
apt-get install -y -qq dpkg-dev patch python3 pkg-config libcdio-dev libcdio-paranoia-dev >> /out/build-dep.log 2>&1
mkdir -p /w
cd /w
tar -xf /tag/gvfs-1.54.4.tar
mv gvfs-1.54.4 tag
apt-get source -qq gvfs > /out/source.log 2>&1
mv "$(find /w -maxdepth 1 -type d -name 'gvfs-*' | head -n 1)" ubuntu
dpkg-parsechangelog -l ubuntu/debian/changelog -S Version > /out/ubuntu-version.txt
apt-get source -qq libcdio > /dev/null 2>&1
LIB=$(find /w -maxdepth 1 -type d -name "libcdio-*" | head -1)
{
echo "gcc $(gcc -dumpfullversion), glib $(pkg-config --modversion glib-2.0), libcdio $(pkg-config --modversion libcdio), libcdio_paranoia $(pkg-config --modversion libcdio_paranoia), libcdio source $LIB"
echo "ubuntu source version $(cat /out/ubuntu-version.txt)"
} > /out/env.txt

opts=()
for o in admin afc afp archive dnssd goa google gphoto2 http mtp nfs onedrive sftp smb udisks2 \
         wsdd bluray fuse gcr gcrypt keyring logind libusb man devel_utils installed_tests unit_tests; do
    if grep -q "option('$o'" /w/tag/meson_options.txt; then opts+=("-D$o=false"); fi
done
for o in systemduserunitdir tmpfilesdir; do
    if grep -q "option('$o'" /w/tag/meson_options.txt; then opts+=("-D$o=no"); fi
done

printf "test\ttarget\tcase\tsource\texit\tlast line\n" > /out/results.tsv
for T in tag ubuntu; do
  # posted patch alone
  cp -a /w/$T /w/$T-posted
  patch -p1 -d /w/$T-posted < /patches/posted.patch > /out/$T-posted-patch.log 2>&1
  echo "exit $?" >> /out/$T-posted-patch.log
  # squashed patch alone; if it does not apply cleanly, with !368 first
  cp -a /w/$T /w/$T-rev
  patch -p1 --dry-run -d /w/$T-rev < /patches/squashed.patch > /out/$T-squashed-dryrun.log 2>&1
  echo "dry-run exit $?" >> /out/$T-squashed-dryrun.log
  patch -p1 -d /w/$T-rev < /patches/squashed.patch > /out/$T-squashed-patch.log 2>&1
  echo "exit $?" >> /out/$T-squashed-patch.log
  # for information: !368 first, then the squashed patch, on a third copy
  cp -a /w/$T /w/$T-with368
  P368=$(ls /patches/0001-cdda-Limit-*.patch)
  patch -p1 -d /w/$T-with368 < "$P368" >/out/$T-with368-patch368.log 2>&1
  echo "exit $?" >> /out/$T-with368-patch368.log
  patch -p1 -d /w/$T-with368 < /patches/squashed.patch > /out/$T-with368-patch-squashed.log 2>&1
  echo "exit $?" >> /out/$T-with368-patch-squashed.log
done

for T in tag ubuntu; do
  extra=()
  if [ "$T" = ubuntu ]; then extra=(--prefix=/usr --libexecdir=lib/gvfs); fi
  meson setup /build-$T /w/$T-rev --werror "${extra[@]}" -Dcdda=true -Dgudev=true "${opts[@]}" > /out/$T-meson-setup.log 2>&1
  echo "meson setup exit $?" > /out/$T-build-status.txt
  ninja -C /build-$T daemon/gvfsd-cdda > /out/$T-compile.log 2>&1
  echo "ninja exit $?" >> /out/$T-build-status.txt
  echo "warnings: $(grep -c -E 'warning:' /out/$T-compile.log)" >> /out/$T-build-status.txt
  grep -E "cachemodel" /out/$T-meson-setup.log >> /out/$T-build-status.txt
  cp /build-$T/daemon/gvfsd-cdda /out/$T-gvfsd-cdda
  sha256sum /out/$T-gvfsd-cdda >> /out/$T-build-status.txt
  ls -l /out/$T-gvfsd-cdda >> /out/$T-build-status.txt
done

src_of() {   # target source -> backend file
  case "$2" in
    base) echo "/w/$1/daemon/gvfsbackendcdda.c" ;;
    patch1) echo "/w/$1-posted/daemon/gvfsbackendcdda.c" ;;
    revised) echo "/w/$1-rev/daemon/gvfsbackendcdda.c" ;;
  esac
}
run_cases() {   # $1 target, $2 label, $3 program; cases on stdin
  while read -r label args; do
    [ -z "$label" ] && continue
    for s in base patch1 revised; do
      res=$(timeout 60 python3 -I "$3" "$(src_of $1 $s)" "$LIB" $args 2>&1)
      rc=$?
      echo "=== $2 $1 $label $s exit $rc"
      echo "$res"
      printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$2" "$1" "$label" "$s" "$rc" "$(echo "$res" | tail -1)" >> /out/results.tsv
    done
  done
}
{
for T in tag ubuntu; do
run_cases $T open /t/gvfs-cdda-track-test.py <<CASES
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
run_cases $T listing /t/gvfs-cdda-listing-test.py <<CASES
tracks-1-3 1
tracks-2-4 2
tracks-5-7 5
tracks-1-3_data-3 1 --data 3
tracks-2-4_data-2 2 --data 2
CASES
done
} > /out/run.log 2>&1
echo done >> /out/build-status-final.txt
