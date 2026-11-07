#!/bin/sh
# Runs inside the container: compile the harness, run the test under Xvfb.
export OUTDIR=/out
export HARNESS=/work/widget-harness
export LD_LIBRARY_PATH=/usr/local/lib64:/usr/local/lib
# GnomeBluetoothPriv is not installed (install: false); use the build dir
export LD_LIBRARY_PATH=/build/builddir/lib:$LD_LIBRARY_PATH
export GI_TYPELIB_PATH=/build/builddir/lib:/usr/local/lib64/girepository-1.0:/usr/local/lib/girepository-1.0
export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig
cat /etc/os-release > /out/os-release.txt
git -C /build/gnome-bluetooth log -1 --format=%H > /out/commit.txt 2>&1
meson --version > /out/versions.txt
pkg-config --modversion gtk4 libadwaita-1 gnome-bluetooth-ui-3.0 >> /out/versions.txt
rpm -q python3-dbusmock >> /out/versions.txt
gcc -o /work/widget-harness /work/tests/widget-harness.c $(pkg-config --cflags --libs gnome-bluetooth-ui-3.0 gtk4 libadwaita-1) || exit 10
exec xvfb-run -a -s "-screen 0 1024x768x24" python3 /work/tests/pair-failure-test.py
