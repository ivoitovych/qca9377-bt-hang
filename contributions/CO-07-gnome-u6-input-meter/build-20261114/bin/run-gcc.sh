#!/bin/bash
T=/root/exp/agent-work/lane5-status-stable-20261114/task5
W=$T/gcc
mkdir -p "$W/extra/patches"
cp "$T/patches-gcc"/*.patch "$W/extra/patches/"
cp "$T/patches-gcc/series.fragment" "$W/extra/series"
{
cat <<'EOF'
gnome-control-center (1:46.7-0ubuntu0.24.04.7) noble; urgency=medium

  * Sound panel: make the input level meter follow the selected input device
    (LP: #<LP-GCC-METER>). Cherry-picked from upstream (GNOME 47.0):
EOF
for p in $(cat "$W/extra/series"); do echo "    - d/p/$p"; done
cat <<'EOF'
    The panel now listens to the mixer's signals only while it is shown,
    updates the active-device UI from those signals and keeps the meter
    stream in step with the active device, so that the meter is re-pointed
    when the default input changes (before, only while it held no stream).

 -- Iaroslav Voitovych <yaroslav.voytovych@gmail.com>  Sat, 14 Nov 2026 16:00:00 +0000

EOF
} > "$W/extra/changelog"
cp "$T/bin/inner-build.sh" "$W/extra/inner-build.sh"; chmod +x "$W/extra/inner-build.sh"
docker run --rm --cpus 4 -v "$W:/w" co03-noble-build:1 /w/extra/inner-build.sh gnome-control-center_46.7-0ubuntu0.24.04.6.dsc 46.7-0ubuntu0.24.04.7 /w/extra/patches /w/extra/changelog /w/extra/series > "$T/logs/build-gcc.log" 2>&1
echo "gcc build container rc=$?" >> "$T/logs/progress.log"
