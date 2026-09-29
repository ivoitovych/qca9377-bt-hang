#!/usr/bin/env python3
"""prove-audio-policy-metadata.py — standalone proof of the suite's two checks on
scripts/bt-audio-policy.py's metadata handling, for when the suite cannot run
(trial open). pw-dump -m prints only the metadata entries that CHANGED and a
removal as value null; the recorder must keep the keys an update does not name
and drop a key whose value is null. Prints "kept" and "removed" on the fixed
code; "lost …" / "not-removed" on the 2026-09-26 code.

    scripts/prove-audio-policy-metadata.py [path-to-bt-audio-policy.py]
"""
import importlib.util
import os
import sys

path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts", "bt-audio-policy.py")
spec = importlib.util.spec_from_file_location("bap", path)
bap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bap)


def md(entries):
    return {"id": 40, "type": "PipeWire:Interface:Metadata",
            "props": {"metadata.name": "default"}, "metadata": entries}


def e(key, value):
    return {"subject": 0, "key": key, "type": "Spa:String:JSON", "value": value}


st = {}
bap.apply(st, [md([e("default.audio.sink", {"name": "sinkA"}),
                   e("default.audio.source", {"name": "srcA"})])])
bap.apply(st, [md([e("default.audio.sink", {"name": "sinkB"})])])
s = bap.summarize(st)
print("kept" if s.get("default audio.source") == "srcA" and s.get("default audio.sink") == "sinkB"
      else f"lost {s}")
bap.apply(st, [md([e("default.audio.source", None)])])
print("removed" if "default audio.source" not in bap.summarize(st) else "not-removed")
