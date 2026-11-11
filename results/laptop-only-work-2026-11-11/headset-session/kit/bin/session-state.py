#!/usr/bin/env python3
"""Read-only snapshot of the facts the headset session changes.  Run it before the
first change, after each step and at the end; compare by eye or with diff.

Reads: dpkg-query, /proc (executables and mapped plugin files), the drop-in directory
of the bluetooth unit (file names and SHA-256 only), the kit's user overrides.
Does not talk to bluetoothd, PipeWire or WirePlumber, and never reads /var/lib/bluetooth.

  session-state.py            (as any user; run as root to see all processes' environment)
"""
import hashlib
import os
import subprocess
import sys

PKGS = ["bluez", "libbluetooth3", "bluez-obexd", "bluez-cups", "pipewire", "pipewire-bin", "pipewire-pulse",
        "pipewire-alsa", "pipewire-audio", "libpipewire-0.3-0t64", "libpipewire-0.3-modules",
        "libpipewire-0.3-common", "libspa-0.2-modules", "libspa-0.2-bluetooth", "gstreamer1.0-pipewire",
        "wireplumber", "libwireplumber-0.4-0", "gnome-control-center", "gnome-bluetooth-3-common"]


def sha(path):
    try:
        h = hashlib.sha256()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
        return h.hexdigest()
    except OSError as e:
        return "unreadable (%s)" % e.strerror


def procs(name):
    out = []
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            exe = os.readlink("/proc/%s/exe" % pid)
            comm = open("/proc/%s/comm" % pid).read().strip()
        except OSError:
            continue
        if comm == name:
            out.append((int(pid), exe))
    return sorted(out)


def environ(pid, key):
    try:
        for item in open("/proc/%d/environ" % pid, "rb").read().split(b"\0"):
            if item.startswith(key.encode() + b"="):
                return item.decode(errors="replace")
    except OSError:
        return "(not readable: run as root)"
    return "(not set)"


def maps(pid, needle):
    seen = []
    try:
        for line in open("/proc/%d/maps" % pid):
            if needle in line:
                p = line.split(None, 5)[-1].strip()
                if p not in seen:
                    seen.append(p)
    except OSError:
        return ["(not readable)"]
    return seen


print("== packages (dpkg-query)")
r = subprocess.run(["dpkg-query", "-W"] + PKGS, capture_output=True, text=True)
print(r.stdout.rstrip())

print("\n== bluetooth daemon")
for pid, exe in procs("bluetoothd"):
    print("pid %d  exe %s" % (pid, exe))
    print("   sha256 %s" % sha("/proc/%d/exe" % pid))
for p in ("/usr/libexec/bluetooth/bluetoothd", "/usr/local/libexec/bluetooth/bluetoothd"):
    print("file %s  sha256 %s" % (p, sha(p)))
d = "/etc/systemd/system/bluetooth.service.d"
if os.path.isdir(d):
    for f in sorted(os.listdir(d)):
        print("drop-in %s/%s  sha256 %s" % (d, f, sha(os.path.join(d, f))))
else:
    print("no drop-in directory %s" % d)

print("\n== audio session")
for name in ("pipewire", "wireplumber", "pipewire-pulse"):
    for pid, exe in procs(name):
        print("%s pid %d  started %s" % (name, pid, subprocess.run(
            ["ps", "-o", "lstart=", "-p", str(pid)], capture_output=True, text=True).stdout.strip()))
        for key in ("WIREPLUMBER_DEBUG", "PIPEWIRE_DEBUG", "SPA_PLUGIN_DIR"):
            v = environ(pid, key)
            if v != "(not set)":
                print("   %s" % v)
        for m in maps(pid, "libspa-bluez5.so"):
            print("   mapped %s%s" % (m, "" if "(deleted)" not in m else "   <- replaced on disk, old code still running"))
print("stock plugin file: %s" % sha("/usr/lib/x86_64-linux-gnu/spa-0.2/bluez5/libspa-bluez5.so"))

print("\n== user overrides written by the kit")
for home in sorted(os.listdir("/home")) if os.path.isdir("/home") else []:
    rec = os.path.join("/home", home, ".config", "kit-session-overrides.json")
    if os.path.exists(rec):
        print("%s: %s" % (rec, open(rec).read().replace("\n", " ")))
    for sub in (".config/wireplumber", ".config/pipewire"):
        base = os.path.join("/home", home, sub)
        if os.path.isdir(base):
            for dp, _, fn in os.walk(base):
                for f in sorted(fn):
                    print("   %s  sha256 %s" % (os.path.join(dp, f), sha(os.path.join(dp, f))[:16]))
