#!/usr/bin/env python3
"""user-audio-streams.py: summarise a `pw-dump` JSON on stdin (see user-audio-streams.sh):
each Bluetooth card's active profile, then every stream node with its application, media name,
process id, state and target."""
import json
import sys

objs = json.load(sys.stdin)


def props(o):
    return (o.get("info") or {}).get("props") or {}


for o in objs:
    if o.get("type") != "PipeWire:Interface:Device":
        continue
    p = props(o)
    if p.get("device.api") != "bluez5":
        continue
    prof = None
    for par in ((o.get("info") or {}).get("params") or {}).get("Profile", []) or []:
        prof = par.get("name")
    print("card %s: active profile %s" % (p.get("device.description"), prof))

nodes = [o for o in objs if o.get("type") == "PipeWire:Interface:Node"]
# targets are given as an object serial or a node name; resolve both to the node name
by_key = {}
for o in nodes:
    p = props(o)
    by_key[str(p.get("object.serial"))] = p.get("node.name")
    by_key[str(o.get("id"))] = p.get("node.name")
    by_key[str(p.get("node.name"))] = p.get("node.name")
# which node each stream is actually linked to
linked = {}
for o in objs:
    if o.get("type") != "PipeWire:Interface:Link":
        continue
    info = o.get("info") or {}
    out_n, in_n = info.get("output-node-id"), info.get("input-node-id")
    linked.setdefault(out_n, set()).add(in_n)
    linked.setdefault(in_n, set()).add(out_n)
name_by_id = {o.get("id"): props(o).get("node.name") for o in nodes}

for o in sorted(nodes, key=lambda x: x.get("id", 0)):
    p = props(o)
    mc = p.get("media.class", "")
    if not mc.startswith("Stream/"):
        continue
    tgt = p.get("target.object") or p.get("node.target")
    peers = sorted(str(name_by_id.get(n)) for n in linked.get(o.get("id"), ()))
    print("stream %s: %s  app=%r  name=%r  pid=%s  state=%s  target=%s  linked to %s" % (
        o.get("id"), mc, p.get("application.name"), p.get("media.name"),
        p.get("application.process.id"), (o.get("info") or {}).get("state"),
        by_key.get(str(tgt), tgt), ", ".join(peers) or "nothing"))
