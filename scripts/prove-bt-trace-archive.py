#!/usr/bin/env python3
"""prove-bt-trace-archive.py: positive and negative controls for bt-trace-archive.py.

Works on copies of three small captures in a scratch directory under the project's tmp/;
never touches /var/log/bt-health or /root/bt-trace-keep. Run: python3 prove-bt-trace-archive.py
"""
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "bt-trace-archive.py")
PROJECT_TMP = "/root/exp/qca9377-bt-hang/tmp"
SAMPLES = ["bt-20260924-182910.btsnoop", "bt-20260924-183217.btsnoop", "bt-20260924-183220.btsnoop"]
failures = 0


def expect(cond, what, detail=""):
    global failures
    print(("ok   " if cond else "FAIL ") + what)
    if not cond:
        failures += 1
        print(detail)


def run(env_extra, *args):
    env = dict(os.environ, **env_extra)
    p = subprocess.run([sys.executable, TOOL, *args], capture_output=True, text=True, env=env)
    return p.returncode, p.stdout + p.stderr


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


os.makedirs(PROJECT_TMP, exist_ok=True)
with tempfile.TemporaryDirectory(dir=PROJECT_TMP, prefix="prove-bt-trace-archive-") as tmp:
    trace, keep, arch = (os.path.join(tmp, d) for d in ("trace", "keep", "archive"))
    os.makedirs(trace)
    os.makedirs(keep)
    for i, name in enumerate(SAMPLES):
        src = os.path.join("/var/log/bt-health/trace", name)
        if not os.path.exists(src):
            src = os.path.join(PROJECT_TMP, "evidence-20261011-sbc-xq-bt-20261011-003713.btsnoop")
        shutil.copy(src, os.path.join(trace, name))
        os.utime(os.path.join(trace, name), (time.time() - 1000 + i, time.time() - 1000 + i))
    shutil.copy(os.path.join(trace, SAMPLES[0]), os.path.join(keep, SAMPLES[0]))
    env = {"BT_TRACE_DIR": trace, "BT_TRACE_KEEP_DIR": keep, "BT_ARCHIVE_DIR": arch, "BT_ARCHIVE_SETTLE_SEC": "0"}

    code, out = run(env)
    expect(code == 0, "first run succeeds", out)
    zsts = sorted(n for n in os.listdir(arch) if n.endswith(".zst"))
    expect(zsts == sorted(n + ".zst" for n in SAMPLES[:2]), "the two closed captures archived, the newest left", str(zsts))
    for n in SAMPLES[:2]:
        d = subprocess.run(["zstd", "-dcq", os.path.join(arch, n + ".zst")], capture_output=True).stdout
        expect(hashlib.sha256(d).hexdigest() == sha(os.path.join(trace, n)), f"{n}: archive decompresses to the original")
    with open(os.path.join(arch, "MANIFEST.tsv")) as f:
        lines = f.read().splitlines()
    expect(len(lines) == 3 and lines[1].split("\t")[2] == sha(os.path.join(trace, SAMPLES[0])), "manifest: header + 2 rows with sha256", "\n".join(lines))
    expect("skipped 1" in out, "the keep copy of an archived capture is skipped", out)
    expect(all(os.path.exists(os.path.join(trace, n)) for n in SAMPLES), "no capture deleted")

    code, out = run(env)
    expect(code == 0 and "archived 0" in out, "second run archives nothing new", out)

    os.utime(os.path.join(trace, SAMPLES[2]), (time.time() - 500, time.time() - 500))
    with open(os.path.join(trace, "bt-29990101-000000.btsnoop"), "wb") as f:
        f.write(b"btsnoop\0")  # now SAMPLES[2] is no longer the newest
    code, out = run(dict(env, BT_ARCHIVE_BUDGET_GB="0.0000001"))
    expect(code == 3 and "BUDGET REACHED" in out, "over budget: stops with exit 3", out)
    expect(not os.path.exists(os.path.join(arch, SAMPLES[2] + ".zst")), "over budget: nothing written")

    fakebin = os.path.join(tmp, "fakebin")
    os.makedirs(fakebin)
    with open(os.path.join(fakebin, "zstd"), "w") as f:
        f.write("#!/bin/sh\nfor a; do o=$a; done\n"
                "case \" $* \" in *' -dcq '*) printf garbage;; *) prev=; for a; do [ \"$prev\" = -o ] && printf x > \"$a\"; prev=$a; done;; esac\n")
    os.chmod(os.path.join(fakebin, "zstd"), 0o755)
    code, out = run(dict(env, PATH=fakebin + os.pathsep + os.environ["PATH"]))
    expect(code == 1 and "FAILED" in out, "a compressor that corrupts is caught by verification", out)
    expect(not os.path.exists(os.path.join(arch, SAMPLES[2] + ".zst")), "a failed archive is never renamed into place")
    with open(os.path.join(arch, "MANIFEST.tsv")) as f:
        expect(SAMPLES[2] not in f.read(), "a failed archive gets no manifest row")

    code, out = run(env)
    expect(code == 0 and "archived 1" in out, "the next good run archives the pending capture", out)

    # The desktop capture's hci-* files: ignored under the default prefix, archived with
    # BT_TRACE_PREFIX=hci- (the newest one left open, as for bt-*).
    desk, darch, dkeep = (os.path.join(tmp, d) for d in ("desk", "desk-archive", "desk-keep"))
    os.makedirs(desk)
    os.makedirs(dkeep)
    hci = ["hci-20261010-193534.btsnoop", "hci-20261010-194953.btsnoop"]
    for i, name in enumerate(hci):
        shutil.copy(os.path.join(trace, SAMPLES[i]), os.path.join(desk, name))
        os.utime(os.path.join(desk, name), (time.time() - 1000 + i, time.time() - 1000 + i))
    denv = dict(env, BT_TRACE_DIR=desk, BT_TRACE_KEEP_DIR=dkeep, BT_ARCHIVE_DIR=darch)
    code, out = run(denv)
    expect(code == 0 and "archived 0" in out, "default prefix: hci-* captures are not picked up", out)
    code, out = run(dict(denv, BT_TRACE_PREFIX="hci-"))
    expect(code == 0 and sorted(os.listdir(darch)) == sorted(["MANIFEST.tsv", hci[0] + ".zst"]),
           "BT_TRACE_PREFIX=hci-: the closed hci-* capture archived, the newest left", out)
    expect(all(os.path.exists(os.path.join(desk, n)) for n in hci), "prefix run: no capture deleted")

print(f"{failures} failure(s)")
sys.exit(1 if failures else 0)
