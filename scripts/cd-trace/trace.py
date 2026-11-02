#!/usr/bin/env python3
"""Passive tracing of audio-CD playback (issue X1).

  trace.py <seconds> <outdir>

Collects, side by side, for <seconds>:
- strace.txt   system calls of the running gvfsd-cdda backend(s) (disc ioctls/reads and the
               writes to its client), with wall-clock times (-tt) and durations (-T);
- usbmon.txt   the CD drive's USB traffic only (bus/device from /sys/bus/usb/devices/1-1),
               from the kernel's text usbmon interface; nothing is sent to the device;
- pw-top.txt   PipeWire's per-node timing and error counters, once a second;
- journal.txt  at the end, the journal lines for the player's stream ([Videos]/[Totem]) and
               UNDERFLOWs over the same window.
"""
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

secs = float(sys.argv[1])
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
start = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

procs = []

pids = subprocess.run(["pgrep", "-f", "/usr/libexec/gvfsd-cdda"], capture_output=True,
                      text=True).stdout.split()
if pids:
    args = ["strace", "-f", "-tt", "-T", "-s", "0", "-e",
            "trace=ioctl,read,pread64,readv,write,writev,sendmsg,recvmsg",
            "-o", str(out / "strace.txt")]
    for p in pids:
        args += ["-p", p]
    procs.append(subprocess.Popen(args, stderr=subprocess.DEVNULL))
    print("strace on gvfsd-cdda pids", " ".join(pids))
else:
    print("no gvfsd-cdda running: start playback first, then rerun to catch it")

bus = Path("/sys/bus/usb/devices/1-1/busnum").read_text().strip()
dev = int(Path("/sys/bus/usb/devices/1-1/devnum").read_text().strip())
tag = f":{bus}:{dev:03d}:"

pw = open(out / "pw-top.txt", "w")
procs.append(subprocess.Popen(
    ["runuser", "-u", "i", "--", "env", "XDG_RUNTIME_DIR=/run/user/1000", "pw-top", "-b"],
    stdout=pw, stderr=subprocess.STDOUT))

end = time.time() + secs
n = 0
with open(f"/sys/kernel/debug/usb/usbmon/{bus}u") as mon, open(out / "usbmon.txt", "w") as u:
    u.write(f"# usbmon text, bus {bus}, only lines with '{tag}'; started {start}; "
            f"wall clock of first line follows\n")
    u.write(f"# {datetime.now().strftime('%H:%M:%S.%f')} monotonic {time.monotonic():.6f}\n")
    for line in mon:
        if tag in line:
            u.write(line)
            n += 1
        if time.time() > end:
            break

for p in procs:
    p.terminate()
j = subprocess.run(["journalctl", "--since", start, "--no-pager", "-o", "short-iso-precise",
                    "--grep", r"\[(Videos|Totem)\]|UNDERFLOW|sr 0:0:0:0|usb 1-1"],
                   capture_output=True, text=True).stdout
(out / "journal.txt").write_text(j)
print("done", out, "usbmon lines", n)
