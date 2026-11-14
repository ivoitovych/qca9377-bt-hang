#!/bin/bash
# work area for the resolute and stonking rebuilds (layout of CO-11a's scripts, paths under task4/work)
T=/root/exp/agent-work/lane5-status-stable-20261114/task4
W=$T/work
C=/root/exp/agent-work/co11a-ready-20261102
mkdir -p "$W"/{src/resolute,src/stonking,src/tenacious,patch,scripts,final,build/resolute,build/stonking,results,bin,logs}
for s in resolute stonking tenacious; do cp "$T/fetched/src-$s"/* "$W/src/$s/"; done
cp "$C/final/lines.btsnoop" "$C/final/priv-open.btsnoop" "$C/final/mkcap.py" "$W/final/"
cp "$C/scripts/replay2.py" "$C/scripts/inner-build.sh" "$W/scripts/"
sed -e 's/^Last-Update: .*/Last-Update: 2026-11-14/' -e 's#bug/XXXXXX#bug/<LP-BTMON>#' "$C/patch/monitor-clamp-max_len-in-print_packet.patch" > "$W/patch/monitor-clamp-max_len-in-print_packet.patch"
for pair in "resolute 5.85-4ubuntu0.6" "stonking 5.87-4ubuntu0.2"; do
  set -- $pair
  cat > "$W/patch/changelog-entry.$1" <<EOF
bluez ($2) $1; urgency=medium

  * btmon: fix abort (buffer overflow detected) in print_packet() when the
    computed line width is negative or larger than the line buffer
    (LP: #<LP-BTMON>)
    - debian/patches/monitor-clamp-max_len-in-print_packet.patch:
      upstream dca0f10fd560, clamp max_len to the space left in line[].

 -- Iaroslav Voitovych <yaroslav.voytovych@gmail.com>  Sat, 14 Nov 2026 15:00:00 +0000

EOF
done
grep -c "" "$W/patch/monitor-clamp-max_len-in-print_packet.patch"
