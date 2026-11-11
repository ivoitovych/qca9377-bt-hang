#!/usr/bin/env python3
"""extract.py: stream journal exports (live boots via journalctl, archived boots via zstd)
and write one TSV per boot with the Bluetooth-relevant entries. Read-only.

Output columns: epoch_us, ident, pid, prio, uid, unit, message (tabs/newlines escaped).
Usage: extract.py <outdir> <jobs...> where a job is live:<bootid> or arch:<path>
"""
import re
import subprocess
import sys
from multiprocessing import Pool

IDENT = re.compile(r"bluetooth|bluez|pipewire|wireplumber|gnome-control|gnome-settings|org\.gnome\.Settings|gsd-|rfkill|coredump|btmon|^bt-|obex|gjs|gnome-shell|xdg-desktop|pulse", re.I)
KMSG = re.compile(r"Bluetooth|hci[0-9]|btusb|btqca|segfault|general protection|corrupted SCO|usb 3-[0-9.]+: .*(reset|disconnect|error|Not enough)|BUG:|WARNING:|Oops|Call Trace|rfkill|qca|ath10k|sco", re.I)
SHELLMSG = re.compile(r"[Bb]luetooth|bluez|pipewire|wireplumber|gnome-bluetooth|rfkill", re.I)
SYSDMSG = re.compile(r"bluetooth|pipewire|wireplumber|core-dump|rfkill|coredump", re.I)
SKIP_SYSD = re.compile(r"Started|Starting|Stopped|Stopping|Reached|Listening|Created slice|Removed slice|Succeeded|Deactivated", re.I)


def entries(stream):
    cur = {}
    while True:
        line = stream.readline()
        if not line:
            break
        if line == b"\n":
            if cur:
                yield cur
            cur = {}
            continue
        if b"=" in line:
            k, v = line.rstrip(b"\n").split(b"=", 1)
            cur[k] = v
        else:
            k = line.rstrip(b"\n")
            ln = stream.read(8)
            n = int.from_bytes(ln, "little")
            data = stream.read(n)
            stream.read(1)
            cur[k] = data
    if cur:
        yield cur


def esc(b):
    return b.decode("utf-8", "replace").replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n").replace("\r", "")


def run(job):
    outdir = sys.argv[1]
    kind, arg = job.split(":", 1)
    if kind == "live":
        cmd = ["journalctl", "-b", arg, "-o", "export", "--no-pager"]
        name = arg[:8]
    else:
        cmd = ["zstd", "-dcq", arg]
        name = arg.rsplit("boot-", 1)[1].split(".")[0]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, bufsize=1 << 20)
    n = k = 0
    with open(f"{outdir}/{kind}-{name}.tsv", "w") as out:
        for e in entries(p.stdout):
            n += 1
            ident = (e.get(b"SYSLOG_IDENTIFIER") or e.get(b"_COMM") or b"").decode("utf-8", "replace")
            comm = (e.get(b"_COMM") or b"").decode("utf-8", "replace")
            msg = e.get(b"MESSAGE", b"").decode("utf-8", "replace")
            tr = (e.get(b"_TRANSPORT") or b"").decode()
            keep = False
            if tr == "kernel":
                keep = bool(KMSG.search(msg))
            elif ident == "systemd" or comm == "systemd":
                keep = bool(SYSDMSG.search(msg)) and not SKIP_SYSD.search(msg[:20])
            elif ident.startswith("gnome-shell") or comm == "gnome-shell":
                keep = bool(SHELLMSG.search(msg))
            elif IDENT.search(ident) or IDENT.search(comm):
                keep = True
            if keep:
                k += 1
                ts = (e.get(b"__REALTIME_TIMESTAMP") or b"0").decode()
                out.write("\t".join([ts, ident, (e.get(b"_PID") or b"").decode(), (e.get(b"PRIORITY") or b"").decode(),
                                     (e.get(b"_UID") or b"").decode(), (e.get(b"_SYSTEMD_UNIT") or e.get(b"_SYSTEMD_USER_UNIT") or b"").decode(),
                                     esc(msg.encode())]) + "\n")
    p.wait()
    return f"{job}: {n} entries, {k} kept"


if __name__ == "__main__":
    jobs = sys.argv[2:]
    with Pool(8) as pool:
        for r in pool.imap_unordered(run, jobs):
            print(r, flush=True)
