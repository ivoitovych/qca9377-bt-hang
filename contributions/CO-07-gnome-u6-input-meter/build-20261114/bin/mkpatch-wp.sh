#!/bin/bash
# the CO-32 / U19 one-line fix as a DEP-3 quilt patch, made by editing a copy of the unpacked noble source and diffing
T=/root/exp/agent-work/lane5-status-stable-20261114/task5
P=$T/patches
mkdir -p "$P" "$T/mk"
rm -rf "$T/mk/a" "$T/mk/b"; mkdir -p "$T/mk/a/src/scripts" "$T/mk/b/src/scripts"
cp "$T/wp/base/src/scripts/policy-node.lua" "$T/mk/a/src/scripts/policy-node.lua"
python3 -I - <<'EOF'
T = "/root/exp/agent-work/lane5-status-stable-20261114/task5/"
s = open(T + "mk/a/src/scripts/policy-node.lua").read()
old = """    if skip_this_target == false then
      createLink (si, si_target, can_passthrough, exclusive)
    end
    si_flags[si.id].was_handled = true
"""
new = """    if skip_this_target == false then
      createLink (si, si_target, can_passthrough, exclusive)
      si_flags[si.id].was_handled = true
    end
"""
assert s.count(old) == 1
open(T + "mk/b/src/scripts/policy-node.lua", "w").write(s.replace(old, new))
EOF
{
cat <<'EOF'
Description: Do not mark a stream as handled when its link was skipped
 lp-2122640-bluetooth-audio-glitch.patch skips the link of a new stream to a
 non-Bluetooth target during the two seconds after a Bluetooth node was
 removed, but handleLinkable() still sets was_handled for that stream. A stream
 opened with "don't move" (PA_STREAM_DONT_MOVE, which pipewire-pulse turns into
 dont-reconnect) is then treated, at the rescan that ends the two seconds, as
 "already linked before": its target is dropped and the stream is destroyed
 ("target not found", "destroy node"). GNOME Settings' Sound panel opens its
 input level meter this way and does not retry, so after a headset leaves
 Handsfree for A2DP the meter on the laptop's microphone stays dead.
 Set was_handled only when a link was made, so that the rescan after the two
 seconds links the stream.
Author: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Origin: other, written for this update; corrects lp-2122640-bluetooth-audio-glitch.patch
Bug-Ubuntu: https://bugs.launchpad.net/ubuntu/+source/wireplumber/+bug/<LP-WP-METER>
Forwarded: not-needed
Last-Update: 2026-11-14

EOF
cd "$T/mk" && diff -u --label a/src/scripts/policy-node.lua --label b/src/scripts/policy-node.lua a/src/scripts/policy-node.lua b/src/scripts/policy-node.lua
} > "$P/lp-2122640-do-not-mark-skipped-stream-handled.patch"
cat "$P/lp-2122640-do-not-mark-skipped-stream-handled.patch" | tail -n 16
