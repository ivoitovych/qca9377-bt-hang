#!/bin/sh
# Inside the container: compile the harness, run pair-failure-mr137-test.py under Xvfb.
export OUTDIR=/out
export HARNESS=/work/widget-harness
export LD_LIBRARY_PATH=/build/builddir/lib:/usr/local/lib64:/usr/local/lib
export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig
git -C /build/gnome-bluetooth status --short > /out/applied-state.txt 2>&1
grep -c "overlay" /build/gnome-bluetooth/lib/settings.ui > /out/settings-ui-overlay-count.txt
gcc -o /work/widget-harness /work/tests/widget-harness.c $(pkg-config --cflags --libs gnome-bluetooth-ui-3.0 gtk4 libadwaita-1) || exit 10
exec xvfb-run -a -s "-screen 0 1024x768x24" python3 /work/tests/pair-failure-mr137-test.py
