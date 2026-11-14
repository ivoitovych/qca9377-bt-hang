#!/bin/bash
# btmon of the resolute and stonking source packages (stock proposed upload, and with the new patch), compiled in the NOBLE container with
# the package's own hardening flags (dpkg-buildflags, _FORTIFY_SOURCE=3), only to run them in the noble-userspace live guest.
T=/root/exp/agent-work/lane5-status-stable-20261114/task4
W=$T/work
mkdir -p "$T/live/bin" "$T/live/build"
for s in resolute stonking; do
  case $s in resolute) dsc=bluez_5.85-4ubuntu0.5.dsc ;; stonking) dsc=bluez_5.87-4ubuntu0.1.dsc ;; esac
  rm -rf "$T/live/build/$s"; mkdir -p "$T/live/build/$s"
  cp "$W/src/$s"/* "$T/live/build/$s/"
  docker run --rm --cpus 4 -v "$T/live/build/$s:/b" -v "$W/patch:/p:ro" -v "$T/live/bin:/out" -w /b co03-noble-build:1 sh -c "
dpkg-source -x --no-check $dsc stock > extract.log 2>&1 || { echo extract failed; exit 1; }
cp -a stock patched
patch -d patched -p1 < /p/monitor-clamp-max_len-in-print_packet.patch > patch.log 2>&1 || { echo patch failed; exit 1; }
CF=\$(dpkg-buildflags --get CFLAGS); LF=\$(dpkg-buildflags --get LDFLAGS)
for v in stock patched; do
  ( cd \$v && ./configure CFLAGS=\"\$CF\" LDFLAGS=\"\$LF\" --enable-monitor --disable-obex --disable-cups --disable-mesh --disable-midi --disable-manpages --disable-systemd --disable-udev --disable-client --disable-tools > ../configure-\$v.log 2>&1 && make -j4 monitor/btmon > ../make-\$v.log 2>&1 ) ; echo \"\$v build rc=\$?\"
  cp \$v/monitor/btmon /out/btmon-$s-\$v 2>/dev/null
done
ls -la /out" > "$T/logs/live-bins-$s.log" 2>&1
  tail -n 6 "$T/logs/live-bins-$s.log"
done
