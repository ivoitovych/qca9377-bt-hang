#!/usr/bin/env python3
"""bt-audio-policy — record, on every change, the audio-policy state that the
desktop's Bluetooth audio behaviour depends on. Read-only; event-driven.

    bt-audio-policy [--user NAME]          follow changes forever; one line per changed fact
    bt-audio-policy [--user NAME] --once   print the current snapshot and exit

Run as the desktop user, or as root with --user NAME: pw-dump is then started
as that user against /run/user/<uid> (the checkout under /root is not readable
by the desktop user).

WHY. The userspace problems in docs/issues.md (U1-U5) were first known only
from what the operator saw in GNOME Settings and heard in the headset. The
panel logs nothing about what it draws, but everything it decides from lives
in PipeWire: each Bluetooth device's active profile and the profile its active
routes claim (a mismatch, 261 against 3, was measured at 22:55:59 on
2026-09-26 while the codec dropdown was missing), the default sink and source
(configured and actual), node volumes and mute, and which recording stream
reads which source. This follows `pw-dump --monitor` — PipeWire's own change
stream, so it costs nothing while nothing changes — and writes a timestamped
line only when one of those facts changes, to stdout (the journal, when run as
a service), so a moment like 22:55:59 is on record without anyone watching.

Lines:
    <iso-time> snapshot <key> = <value>          at start (and --once)
    <iso-time> change   <key>: <old> -> <new>    afterwards
Keys: bt-device[<desc>] profile | routes | profile-route (MATCH / MISMATCH),
node[<desc> <class>] volume, default <which>, capture[<app>].

Node names carry device addresses; values use the node's description instead
where one is known. Nothing is sent to any device: it only listens.
"""
import json
import os
import pwd
import re
import subprocess
import sys
import time

DEC = json.JSONDecoder()
MAC = re.compile(r"([0-9A-Fa-f]{2}[_:]){5}[0-9A-Fa-f]{2}")


def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")


def cubic(linear):
    # wpctl and GNOME show cubic volume; PipeWire stores linear.
    try:
        return round(float(linear) ** (1.0 / 3.0), 2)
    except (TypeError, ValueError):
        return None


def props(o):
    return ((o.get("info") or {}).get("props") or o.get("props") or {})


def params(o):
    return (o.get("info") or {}).get("params") or {}


def summarize(state):
    s = {}
    nodes = {oid: o for oid, o in state.items() if o.get("type", "").endswith(":Node")}
    by_name = {props(o).get("node.name"): props(o).get("node.description")
               for o in nodes.values()}

    def label(name):
        # A node that no longer exists has no description; mask the device
        # address its name carries (bluez_input.AA_BB_CC_DD_EE_FF.0).
        return by_name.get(name) or MAC.sub("XX_XX_XX_XX_XX_XX", str(name))

    for o in state.values():
        t = o.get("type", "")
        p = props(o)
        if t.endswith(":Device") and p.get("device.api") == "bluez5":
            desc = p.get("device.description", "?")
            prof = (params(o).get("Profile") or [{}])[0]
            routes = params(o).get("Route") or []
            key = f"bt-device[{desc}]"
            s[f"{key} profile"] = f"{prof.get('name')}#{prof.get('index')} save={prof.get('save')}"
            s[f"{key} routes"] = "; ".join(
                f"{r.get('direction')}:{r.get('name')}->#{r.get('profile')}" for r in routes) or "none"
            claimed = sorted({r.get("profile") for r in routes})
            if not routes or prof.get("index") is None:
                s[f"{key} profile-route"] = "n/a"
            elif claimed == [prof.get("index")]:
                s[f"{key} profile-route"] = "MATCH"
            else:
                s[f"{key} profile-route"] = f"MISMATCH active #{prof.get('index')} routes {claimed}"
        elif t.endswith(":Node") and p.get("media.class") in ("Audio/Sink", "Audio/Source"):
            pr = (params(o).get("Props") or [{}])[0]
            vols = pr.get("channelVolumes") or []
            vol = cubic(vols[0]) if vols else None
            s[f"node[{p.get('node.description', '?')} {p.get('media.class')}] volume"] = \
                f"{vol} mute={pr.get('mute')}"
        elif t.endswith(":Metadata") and p.get("metadata.name") == "default":
            for m in o.get("metadata") or []:
                k = m.get("key", "")
                if k in ("default.configured.audio.sink", "default.configured.audio.source",
                         "default.audio.sink", "default.audio.source"):
                    v = m.get("value")
                    name = v.get("name") if isinstance(v, dict) else v
                    s[f"default {k[len('default.'):]}"] = label(name)
    for o in state.values():
        if not o.get("type", "").endswith(":Link"):
            continue
        i = o.get("info") or {}
        src = nodes.get(i.get("output-node-id"))
        dst = nodes.get(i.get("input-node-id"))
        if not src or not dst:
            continue
        dp = props(dst)
        if dp.get("media.class") != "Stream/Input/Audio":
            continue
        sp = props(src)
        what = sp.get("node.description", "?")
        if sp.get("media.class") == "Audio/Sink":
            what = f"monitor of {what}"
        app = dp.get("application.name") or dp.get("node.name", "?")
        key = f"capture[{app}]"
        s[key] = "; ".join(sorted(set(filter(None, [s.get(key), what]))))
    return s


def apply(state, update):
    for o in update:
        oid = o.get("id")
        if oid is None:
            continue
        if o.get("info") is None and "type" not in o:
            state.pop(oid, None)
        elif o.get("type", "").endswith(":Metadata") and oid in state:
            # pw-dump prints only the metadata entries that CHANGED (1.0.5
            # metadata_dump skips e->changed == 0), and a removal as value null.
            # Replacing the object dropped every key the update did not name:
            # 2026-09-27 00:37:53 logged "default audio.source -> -" while the
            # source was set, and nothing after it.
            merged = {(m.get("subject"), m.get("key")): m
                      for m in state[oid].get("metadata") or []}
            for m in o.get("metadata") or []:
                if m.get("value") is None:
                    merged.pop((m.get("subject"), m.get("key")), None)
                else:
                    merged[(m.get("subject"), m.get("key"))] = m
            state[oid] = dict(o, metadata=list(merged.values()))
        else:
            state[oid] = o


def emit(kind, s_old, s_new):
    ts = now()
    if kind == "snapshot":
        for k in sorted(s_new):
            print(f"{ts} snapshot {k} = {s_new[k]}")
    else:
        for k in sorted(set(s_old) | set(s_new)):
            a, b = s_old.get(k, "-"), s_new.get(k, "-")
            if a != b:
                print(f"{ts} change {k}: {a} -> {b}")
    sys.stdout.flush()


def main():
    args = sys.argv[1:]
    once = "--once" in args
    # Line-buffered: into a pipe, pw-dump's stdio is block-buffered, and a
    # single change would wait unwritten (and be timestamped late) until more
    # output piled up — seen 2026-09-26 as a delayed start-up snapshot.
    cmd = ["stdbuf", "-oL", "pw-dump", "-N"] + ([] if once else ["-m"])
    if "--user" in args:
        user = args[args.index("--user") + 1]
        uid = pwd.getpwnam(user).pw_uid
        cmd = ["runuser", "-u", user, "--", "env", f"XDG_RUNTIME_DIR=/run/user/{uid}"] + cmd
    elif os.geteuid() == 0:
        print("bt-audio-policy: running as root needs --user <desktop user>", file=sys.stderr)
        return 2
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True, bufsize=1)
    state, buf, last, first = {}, "", {}, True
    for line in proc.stdout:
        buf += line
        while True:
            buf = buf.lstrip()
            if not buf:
                break
            try:
                update, end = DEC.raw_decode(buf)
            except json.JSONDecodeError:
                break
            buf = buf[end:]
            if isinstance(update, list):
                apply(state, update)
                cur = summarize(state)
                emit("snapshot" if first else "change", last, cur)
                first, last = False, cur
    return proc.wait()


if __name__ == "__main__":
    sys.exit(main())
