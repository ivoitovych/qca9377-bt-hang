#!/usr/bin/env python3
"""Read-only: list the Bluetooth cards, their profiles with numbers, and the audio
sinks/sources, from `pw-dump`, so the numbers needed by wpctl commands can be copied.
Device addresses are masked.  Run as the desktop user (it needs the audio session).

  audio-ids.py            cards, profiles, sinks, sources
  audio-ids.py --json F   (test mode) read a saved pw-dump instead of running it
"""
import json
import re
import subprocess
import sys

ADDR = re.compile(r"(?<![0-9A-Fa-f])(?:[0-9A-Fa-f]{2}[:_]){5}[0-9A-Fa-f]{2}(?![0-9A-Fa-f])")


def mask(s):
    return ADDR.sub("<addr>", str(s))


if len(sys.argv) == 3 and sys.argv[1] == "--json":
    dump = json.load(open(sys.argv[2]))
else:
    r = subprocess.run(["pw-dump"], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("pw-dump failed: " + r.stderr.strip())
    dump = json.loads(r.stdout)

print("== Bluetooth cards")
found = False
for o in dump:
    if o.get("type") != "PipeWire:Interface:Device":
        continue
    props = o["info"]["props"]
    if props.get("device.api") != "bluez5":
        continue
    found = True
    params = o["info"].get("params", {})
    cur = params.get("Profile", [{}])[0]
    print("card id %s  \"%s\"   active profile: %s (index %s)" % (
        o["id"], mask(props.get("device.description", "?")), cur.get("name", "?"), cur.get("index", "?")))
    codec_less = False
    for p in params.get("EnumProfile", []):
        d = p.get("description", "")
        if p.get("name") == "headset-head-unit" and "codec" not in d.lower():
            codec_less = True
        print("   index %-4s %-26s %-9s %s" % (p.get("index"), p.get("name"), p.get("available", "?"), mask(d)))
    print("   codec-less Handsfree line (U1) present: %s" % ("YES" if codec_less else "no"))
    print("   example:  wpctl set-profile %s <index>" % o["id"])
if not found:
    print("   (no Bluetooth card in the graph)")

for title, cls in (("sinks", "Audio/Sink"), ("sources", "Audio/Source")):
    print("\n== audio %s" % title)
    for o in dump:
        if o.get("type") != "PipeWire:Interface:Node":
            continue
        p = o["info"]["props"]
        if p.get("media.class") == cls:
            print("node id %-5s %-48s %s" % (o["id"], mask(p.get("node.name", "?")), mask(p.get("node.description", ""))))
