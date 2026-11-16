#!/usr/bin/env python3
"""make-noble-default.py REMOTE OUTROOT [options] : a synthetic journal shaped like a default Ubuntu 24.04 desktop's.

  OUTROOT/system/  archived system files   system@<n>.journal      (journald-style entries: units, kernel lines, stdout)
  OUTROOT/user/    archived user files     user-1000@<n>.journal   (the desktop session's own journal, same machine, same boots)

Layout (defaults): 10 boots over about 60 days, each boot up for about 5.5 days; per boot 10 system files and 5 user
files, each file covering an equal slice of the boot's uptime, so the system files of a boot hold 13 h each and
the user files 26 h each and their time ranges overlap: a reader merging both meets entries of system and user
files interleaved by time, as on a real desktop (the laptop's journal has about a third of its files as
user-*.journal). One machine ID, one boot ID per boot, monotonic time rising across the files of a boot, sequence
numbers rising within each file (journal-remote numbers them from 1 in each file; seqnum IDs differ per file).
Entries carry the usual trusted fields. Files are ARCHIVED (header state byte = 2), as rotated files are.
Deterministic (seeded); written by systemd-journal-remote from export streams.

options: --system-per-boot N --user-per-boot N --entries-system N --entries-user N --boots N --system-only
         --calibrate N   write a single system file of N entries, print its size and the time taken, and exit"""
import os
import random
import subprocess
import sys
import time

REMOTE, ROOT = sys.argv[1], sys.argv[2]
opt = {"system-per-boot": 10, "user-per-boot": 5, "entries-system": 40000, "entries-user": 30000, "boots": 10}
flags = set()
a = sys.argv[3:]
i = 0
while i < len(a):
    if a[i] in ("--system-only",):
        flags.add("system-only"); i += 1
    else:
        opt[a[i][2:]] = int(a[i + 1]); i += 2

MACHINE = "6f1c2a9d4b8e4f3aa1c5d7e9b0a2c4e6"
HOST = "laptop"
BASE = 1_706_000_000_000_000           # realtime of the first boot (usec)
BOOT_SPAN = 132 * 3600 * 1_000_000     # uptime of a boot: 5.5 days
BOOT_GAP = 6 * 24 * 3600 * 1_000_000   # boots start 6 days apart
SYSTEM_UNITS = [
    ("systemd", "init.scope", 1, "/usr/lib/systemd/systemd"),
    ("systemd-logind", "systemd-logind.service", 745, "/usr/lib/systemd/systemd-logind"),
    ("NetworkManager", "NetworkManager.service", 812, "/usr/sbin/NetworkManager"),
    ("gdm3", "gdm.service", 901, "/usr/sbin/gdm3"),
    ("cron", "cron.service", 733, "/usr/sbin/cron"),
    ("dbus-daemon", "dbus.service", 735, "/usr/bin/dbus-daemon"),
    ("avahi-daemon", "avahi-daemon.service", 748, "/usr/sbin/avahi-daemon"),
    ("wpa_supplicant", "wpa_supplicant.service", 818, "/usr/sbin/wpa_supplicant"),
    ("systemd-resolved", "systemd-resolved.service", 702, "/usr/lib/systemd/systemd-resolved"),
    ("snapd", "snapd.service", 1020, "/usr/lib/snapd/snapd"),
    ("udisksd", "udisks2.service", 910, "/usr/libexec/udisks2/udisksd"),
    ("cupsd", "cups.service", 1105, "/usr/sbin/cupsd"),
]
USER_UNITS = [
    ("gnome-shell", "session-2.scope", 2310, "/usr/bin/gnome-shell"),
    ("systemd", "user" + "@1000.service", 2105, "/usr/lib/systemd/systemd"),
    ("pipewire", "pipewire.service", 2150, "/usr/bin/pipewire"),
    ("wireplumber", "wireplumber.service", 2152, "/usr/bin/wireplumber"),
    ("gsd-media-keys", "org.gnome.SettingsDaemon.MediaKeys.service", 2340, "/usr/libexec/gsd-media-keys"),
    ("firefox", "app-gnome-firefox-4821.scope", 4821, "/usr/lib/firefox/firefox"),
    ("evolution-alarm", "app-org.gnome.Evolution-alarm-notify" + "@autostart.service", 2480, "/usr/libexec/evolution-data-server/evolution-alarm-notify"),
]
WORDS = ("connection state activated device wlp2s0 lease renewed dhcp4 address gateway route scan completed timeout "
         "retry session opened closed user seat login logout service started stopped reloaded failed deactivated "
         "bluetooth adapter power resume suspend device usb hub port disconnected interface carrier mount volume "
         "cache update package check authentication agent request granted denied policy rule applied profile").split()


def message(rng, ident):
    n = rng.randint(5, 26)
    s = " ".join(rng.choice(WORDS) for _ in range(n))
    if rng.random() < 0.5:
        s += f" [{rng.randint(1, 99999)}]"
    return f"{ident}: {s}"


def entry(rt, mono, boot, uid, kind, rng):
    if kind == "kernel":
        ident, unit, pid, exe = "kernel", None, None, None
    elif uid == 0:
        ident, unit, pid, exe = rng.choice(SYSTEM_UNITS)
    else:
        ident, unit, pid, exe = rng.choice(USER_UNITS)
    msg = message(rng, ident)
    prio = rng.choice([6, 6, 6, 6, 5, 4, 3, 7, 6])
    f = [f"__REALTIME_TIMESTAMP={rt}", f"__MONOTONIC_TIMESTAMP={mono}", f"_BOOT_ID={boot}", f"_MACHINE_ID={MACHINE}",
         f"_HOSTNAME={HOST}", f"PRIORITY={prio}", f"MESSAGE={msg}", f"SYSLOG_IDENTIFIER={ident}"]
    if kind == "kernel":
        f += ["_TRANSPORT=kernel", "SYSLOG_FACILITY=0", f"_SOURCE_MONOTONIC_TIMESTAMP={mono}", "_KERNEL_SUBSYSTEM=usb",
              "_KERNEL_DEVICE=+usb:1-1"]
    else:
        transport = rng.choice(["journal", "journal", "stdout", "syslog"])
        f += [f"_TRANSPORT={transport}", f"_PID={pid + rng.randint(0, 3)}", f"_UID={uid}", f"_GID={uid}",
              f"_COMM={os.path.basename(exe)[:15]}", f"_EXE={exe}", f"_CMDLINE={exe}",
              f"_CAP_EFFECTIVE={'1ffffffffff' if uid == 0 else '0'}", "_SELINUX_CONTEXT=unconfined\n"[:-1],
              f"_SYSTEMD_CGROUP=/{'system.slice' if uid == 0 else 'user.slice/user-1000.slice'}/{unit}",
              f"_SYSTEMD_SLICE={'system.slice' if uid == 0 else 'user-1000.slice'}", f"_SYSTEMD_INVOCATION_ID={rng.getrandbits(128):032x}",
              f"SYSLOG_FACILITY={3 if uid == 0 else 1}", f"_RUNTIME_SCOPE=system"]
        if uid == 0:
            f.append(f"_SYSTEMD_UNIT={unit}")
        else:
            f += [f"_SYSTEMD_USER_UNIT={unit}", f"_SYSTEMD_OWNER_UID={uid}", f"_SYSTEMD_USER_SLICE=app.slice"]
    return "\n".join(f) + "\n\n"


def write_file(path, text):
    p = subprocess.run([REMOTE, f"--output={path}", "-"], input=text.encode(), stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if p.returncode != 0:
        sys.exit(f"journal-remote failed on {path}: {p.stderr.decode()[-300:]}")
    with open(path, "r+b") as fh:
        fh.seek(16); fh.write(b"\x02")


def slice_file(path, rng, boot, boot_start_rt, span_start, span_end, n, uid):
    """n entries spread (with random gaps) over [span_start, span_end) of the boot's uptime."""
    gaps = [rng.expovariate(1.0) for _ in range(n)]
    tot = sum(gaps)
    t = span_start
    parts = []
    for g in gaps:
        t += g / tot * (span_end - span_start)
        ti = int(t)
        kind = "kernel" if (uid == 0 and rng.random() < 0.04) else "msg"
        parts.append(entry(boot_start_rt + ti, 5_000_000 + ti, boot, uid, kind, rng))
    write_file(path, "".join(parts))


if "calibrate" in opt:
    os.makedirs(ROOT, exist_ok=True)
    rng = random.Random(1)
    t0 = time.time()
    p = f"{ROOT}/calib.journal"
    slice_file(p, rng, "00000001" + "ab12" * 6, BASE, 0, BOOT_SPAN // 10, opt["calibrate"], 0)
    print(f"{opt['calibrate']} entries: {os.path.getsize(p) / 1e6:.1f} MB, {time.time() - t0:.1f} s")
    sys.exit(0)

os.makedirs(f"{ROOT}/system", exist_ok=True)
if "system-only" not in flags:
    os.makedirs(f"{ROOT}/user", exist_ok=True)
rng = random.Random(20240101)
t0 = time.time()
nsys = nusr = 0
for b in range(opt["boots"]):
    boot = f"{b + 1:08x}" + "ab12" * 6
    if b == opt["boots"] - 1 and os.environ.get("LASTBOOT"):
        boot = os.environ["LASTBOOT"]
    start = BASE + b * BOOT_GAP
    spf, upf = opt["system-per-boot"], opt["user-per-boot"]
    for k in range(spf):
        p = f"{ROOT}/system/system@{b:03d}{k:03d}.journal"
        if not os.path.exists(p):
            slice_file(p, rng, boot, start, BOOT_SPAN * k // spf, BOOT_SPAN * (k + 1) // spf, opt["entries-system"], 0)
        nsys += 1
    if "system-only" not in flags:
        for k in range(upf):
            p = f"{ROOT}/user/user-1000@{b:03d}{k:03d}.journal"
            if not os.path.exists(p):
                slice_file(p, rng, boot, start, BOOT_SPAN * k // upf, BOOT_SPAN * (k + 1) // upf, opt["entries-user"], 1000)
            nusr += 1
    print(f"boot {b + 1}: {nsys} system and {nusr} user files so far, {time.time() - t0:.0f} s", flush=True)
