#!/bin/bash
T=/root/exp/agent-work/lane5-status-stable-20261114/task5
W=$T/wp
mkdir -p "$W/extra/patches"
cp "$T/patches/lp-2122640-do-not-mark-skipped-stream-handled.patch" "$W/extra/patches/"
echo "lp-2122640-do-not-mark-skipped-stream-handled.patch" > "$W/extra/series"
cat > "$W/extra/changelog" <<'EOF'
wireplumber (0.4.17-1ubuntu4.2) noble; urgency=medium

  * Do not mark a stream as handled when its link was skipped during a
    Bluetooth profile transition, so that streams opened with "don't move",
    such as the input level meter of GNOME Settings' Sound panel, are linked
    after the two seconds instead of destroyed (LP: #<LP-WP-METER>).
    - d/p/lp-2122640-do-not-mark-skipped-stream-handled.patch: set
      was_handled in handleLinkable() only when createLink() was called;
      corrects d/p/lp-2122640-bluetooth-audio-glitch.patch.

 -- Iaroslav Voitovych <yaroslav.voytovych@gmail.com>  Sat, 14 Nov 2026 16:00:00 +0000

EOF
chmod +x "$T/bin/inner-build.sh"; cp "$T/bin/inner-build.sh" "$W/extra/inner-build.sh"
docker run --rm --cpus 4 -v "$W:/w" co03-noble-build:1 /w/extra/inner-build.sh wireplumber_0.4.17-1ubuntu4.1.dsc 0.4.17-1ubuntu4.2 /w/extra/patches /w/extra/changelog /w/extra/series > "$T/logs/build-wp.log" 2>&1
echo "wp build container rc=$?" >> "$T/logs/progress.log"
