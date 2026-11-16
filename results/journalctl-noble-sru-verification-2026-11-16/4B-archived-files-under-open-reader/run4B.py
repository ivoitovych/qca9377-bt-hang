#!/usr/bin/env python3
"""run4B.py : archived journal files removed under an open reader (inside co46-verify:1).

Fixture: 16 archived files (4 boots x 4 files), 600 entries each, MESSAGE "B f<file> e<entry>", sequential in time.
For every run a fresh COPY of the fixture is made (so that every file has its own inode: with a hard link, nlink would
stay above zero and the data would not be deallocated). A reader (journalctl or the API program) is started on the copy
and its output is consumed slowly; when the consumer has seen K entries (K varied) the victims are removed:
  unlink    plain unlink()
  dealloc   what unlinkat_deallocate() does (src/basic/fs-util.c, v255): open O_WRONLY, unlink, fstat; if the file has blocks and
            nlink == 0: fallocate(PUNCH_HOLE|KEEP_SIZE, 0, round_up(size, blksize)), else ftruncate(0)
  truncate  unlink, then ftruncate(0) (what unlinkat_deallocate falls back to where hole punching is not supported)
Victims, relative to the file the consumer is in: current, future (the next file in reading order), future2 (the one after
next and the one after that), past (the file before).
Checked per run: exit status, stderr, entries output, entries missing from the surviving files, duplicates, entries from the
deleted files, order. TSV on stdout.
usage: run4B.py BUILD(s819|p820) READER MODE VICTIM REPS SEED"""
import ctypes
import os
import random
import re
import shutil
import signal
import subprocess
import sys
import time

build, reader, mode, victim, reps, seed = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5]), int(sys.argv[6])
P = "/work/pkgx"
FIX = "/work/verify/data/4B/fixture"
RUN = "/work/verify/run4B"
NF, NE = 16, 600
libc = ctypes.CDLL(None, use_errno=True)
libc.fallocate.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_longlong]
LD = f"{P}/{build}/usr/lib/x86_64-linux-gnu/systemd:{P}/{build}/usr/lib/x86_64-linux-gnu"
env = dict(os.environ, LD_LIBRARY_PATH=LD)


def make_fixture():
    if os.path.isdir(FIX) and len(os.listdir(FIX)) == NF:
        return
    os.makedirs(FIX, exist_ok=True)
    base = 1_700_000_000_000_000
    rt = base
    for i in range(NF):
        b = i // 4
        if i % 4 == 0:
            rt += 30_000_000
            mono = 5_000_000
        lines = []
        for e in range(NE):
            rt += 2000
            mono += 2000
            lines.append(f"__REALTIME_TIMESTAMP={rt}\n__MONOTONIC_TIMESTAMP={mono}\n_BOOT_ID={b:08x}{'b007' * 6}\n"
                         f"_MACHINE_ID=0123456789abcdef0123456789abcdef\n_HOSTNAME=fx\n_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\n"
                         f"PRIORITY=6\nMESSAGE=B f{i:02d} e{e:04d}\n\n")
        p = f"{FIX}/system@{i:05d}.journal"
        subprocess.run([f"{P}/remote-s819", f"--output={p}", "-"], input="".join(lines).encode(), check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        with open(p, "r+b") as f:
            f.seek(16); f.write(b"\x02")


def command(d):
    if reader == "jc-fwd":
        return [f"{P}/jc-{build}", f"--directory={d}", "--no-pager", "-o", "export"]
    if reader == "jc-rev":
        return [f"{P}/jc-{build}", f"--directory={d}", "--no-pager", "-o", "export", "-r"]
    if reader == "jc-follow":
        return [f"{P}/jc-{build}", f"--directory={d}", "--no-pager", "-o", "export", "-f", "-n", "all"]
    if os.environ.get("GDBBT") and reader == "api-fwd":
        g = ["gdb", "-batch", "-nx", "-ex", "set debuginfod enabled off", "-ex", f"set debug-file-directory {P}/p820dbg/usr/lib/debug",
             "-ex", "handle SIGBUS stop print pass", "-ex", "run"]
        for _ in range(4):
            g += ["-ex", "bt 14", "-ex", "continue"]
        return g + ["--args", "/work/verify/bin/reader", d, "forward"]
    if reader == "api-fwd":
        return ["/work/verify/bin/reader", d, "forward"]
    if reader == "api-bwd":
        return ["/work/verify/bin/reader", d, "backward"]
    raise SystemExit("reader?")


backwards = reader in ("jc-rev", "api-bwd")


def remove(path, how):
    if how == "unlink":
        os.unlink(path)
        return
    fd = os.open(path, os.O_WRONLY | os.O_CLOEXEC | os.O_NOCTTY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        os.unlink(path)
        st = os.fstat(fd)
        if how == "truncate":
            os.ftruncate(fd, 0)
            return
        if st.st_blocks == 0 or st.st_nlink > 0:
            return
        bs = max(st.st_blksize, 512)
        ln = (st.st_size + bs - 1) // bs * bs
        if libc.fallocate(fd, 0x01 | 0x02, 0, ln) >= 0:       # KEEP_SIZE | PUNCH_HOLE
            return
        os.ftruncate(fd, 0)
    finally:
        os.close(fd)


def one(rep, rng):
    d = f"{RUN}/{build}-{reader}-{mode}-{victim}-{rep}"
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(RUN, exist_ok=True)
    shutil.copytree(FIX, d)
    K = rng.randrange(150, NF * NE - 1500)
    if reader == "jc-follow":
        cmd = command(d)
    else:
        cmd = command(d)
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, text=True, bufsize=1)
    seen = []
    gdbl = []
    removed = set()
    acted = False
    last_file = None
    t_last = time.time()
    import select
    stdout_fd = p.stdout
    done = False
    while True:
        r, _, _ = select.select([p.stdout], [], [], 4.0 if reader == "jc-follow" else 30.0)
        if not r:
            break                                   # idle: for the follower this is the end; for the others a hang
        line = p.stdout.readline()
        if not line:
            break
        m = re.match(r"(?:MESSAGE=|MSG )B f(\d\d) e(\d{4})", line)
        if not m:
            if line.startswith("ERR"):
                seen.append(("ERR", line.strip()))
            elif line[:1] == "#" or line.startswith("Program "):
                gdbl.append(line.strip()[:150])
            continue
        f, e = int(m.group(1)), int(m.group(2))
        seen.append((f, e))
        last_file = f
        time.sleep(0.0002)
        if not acted and len([s for s in seen if s[0] != "ERR"]) >= K and mode != "none":
            acted = True
            step = -1 if backwards else 1
            if victim == "current":
                vs = [f]
            elif victim == "future":
                vs = [f + step]
            elif victim == "future2":
                vs = [f + 2 * step, f + 3 * step]
            elif victim == "past":
                vs = [f - step]
            vs = [v for v in vs if 0 <= v < NF]
            for v in vs:
                try:
                    remove(f"{d}/system@{v:05d}.journal", mode)
                    removed.add(v)
                except OSError as ex:
                    pass
    if reader == "jc-follow":
        p.send_signal(signal.SIGTERM)
    try:
        rc = p.wait(timeout=10)
    except subprocess.TimeoutExpired:
        p.kill(); rc = "HUNG"
    err = p.stderr.read().strip().replace(d, "<dir>")
    err = re.sub(r"\s+", " ", err)[:160]
    ent = [s for s in seen if s[0] != "ERR"]
    errs = [s[1] for s in seen if s[0] == "ERR"]
    got = set(ent)
    dup = len(ent) - len(got)
    missing_surv = sum(1 for f in range(NF) if f not in removed for e in range(NE) if (f, e) not in got)
    from_removed = sum(1 for s in ent if s[0] in removed)
    keyf = (lambda s: (-s[0], -s[1])) if backwards else (lambda s: (s[0], s[1]))
    ordered = all(keyf(a) <= keyf(b) for a, b in zip(ent, ent[1:]))
    if reader == "jc-follow":
        rc_s = "followed" if rc in (-15, 0, "HUNG") else str(rc)
    else:
        rc_s = str(rc)
    shutil.rmtree(d, ignore_errors=True)
    return (build, reader, mode, victim, rep, K, ",".join(map(str, sorted(removed))) or "-", rc_s, len(ent), missing_surv,
            dup, from_removed, "ordered" if ordered else "UNORDERED", (errs[0] if errs else "") + (" | " if errs and err else "") + err + (" GDB: " + " ## ".join(gdbl) if gdbl else ""))


make_fixture()
rng = random.Random(seed)
for rep in range(reps):
    row = one(rep, rng)
    print("\t".join(str(x) for x in row), flush=True)
