#!/usr/bin/env python3
"""midread-test.py LIBSYSTEMD REMOTE WORKDIR : files added to and removed from a directory while it is being read,
through the sd-journal API (ctypes), with inotify active (the journal is not opened ASSUME_IMMUTABLE and
sd_journal_get_fd() is called, so sd_journal_process() sees directory changes).

Run once per libsystemd.so under test with the same arguments; the output is a list of 'scenario: count sha256'
lines, to be compared between builds. Each scenario starts from a fresh copy of the same static files, so the
result does not depend on timing: changes are made at fixed entry counts and sd_journal_process() is called at fixed
entry counts. Entries are returned as 'realtime|message'.

Scenarios (static set: 24 archived files of 500 entries over 3 boots of one machine, entries 2 ms apart; extra
files are made in advance):
  add_newer       a file whose entries are all newer than the static set is added after 3000 entries
  add_interleaved a file whose entries fall between the static files' later entries is added after 3000 entries
  add_older       a file whose entries are all older than the reader's position is added after 6000 entries
  add_twomachines a file of another machine ID, interleaved in time, is added after 3000 entries
  remove_future   a not yet reached file is removed after 3000 entries
  remove_current  the file the reader is in is removed after 3000 entries
  remove_all_but  the first 20 files are removed after 3000 entries
  each of them also with the reader going backwards (seek_tail, sd_journal_previous) and with a match
  (SYSLOG_IDENTIFIER=kernel), and with an OR match (_BOOT_ID=boot0 + _BOOT_ID=boot1)."""
import ctypes
import hashlib
import os
import shutil
import subprocess
import sys

LIB, REMOTE, WORK = sys.argv[1], sys.argv[2], sys.argv[3]
# MODE restart: monotonic time restarts in every file of a boot (not what a real journal looks like);
# MODE rising: it rises across the files of a boot, as it does in journals written by journald.
MODE = sys.argv[4] if len(sys.argv) > 4 else "restart"
M1 = "0123456789abcdef0123456789abcdef"
M2 = "fedcba9876543210fedcba9876543210"
BASE = 1_700_000_000_000_000
STEP = 2000
PER = 500

lib = ctypes.CDLL(LIB)
lib.sd_journal_open_directory.argtypes = [ctypes.POINTER(ctypes.c_void_p), ctypes.c_char_p, ctypes.c_int]
for n in ("sd_journal_next", "sd_journal_previous", "sd_journal_process", "sd_journal_get_fd", "sd_journal_seek_tail",
          "sd_journal_seek_head", "sd_journal_flush_matches", "sd_journal_add_disjunction"):
    getattr(lib, n).argtypes = [ctypes.c_void_p]
lib.sd_journal_add_match.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t]
lib.sd_journal_get_realtime_usec.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint64)]
lib.sd_journal_get_data.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_size_t)]
lib.sd_journal_close.argtypes = [ctypes.c_void_p]


def entry(rt, mono, boot, machine, msg):
    return (f"__REALTIME_TIMESTAMP={rt}\n__MONOTONIC_TIMESTAMP={mono}\n_BOOT_ID={boot}\n_MACHINE_ID={machine}\n_HOSTNAME=repro\n"
            f"_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\nPRIORITY=6\nMESSAGE={msg}\n\n")


def mkfile(path, lines):
    p = subprocess.run([REMOTE, f"--output={path}", "-"], input="".join(lines).encode(), stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if p.returncode != 0:
        sys.exit(f"journal-remote failed: {p.stderr.decode()[-200:]}")
    with open(path, "r+b") as f:
        f.seek(16); f.write(b"\x02")


def boot_of(i):
    return f"{i // 8:08x}" + "b007" * 6


# the static files and the extra files (made once, copied for every scenario)
STATIC = f"{WORK}/static"
EXTRA = f"{WORK}/extra"
os.makedirs(STATIC, exist_ok=True)
os.makedirs(EXTRA, exist_ok=True)
if not os.listdir(STATIC):
    for i in range(24):
        off = (i % 8) * PER if MODE == "rising" else 0
        lines = [entry(BASE + (i * PER + e) * STEP + (i // 8) * 40_000_000, 5_000_000 + (off + e) * STEP, boot_of(i), M1, f"static {i} {e}") for e in range(PER)]
        mkfile(f"{STATIC}/system@{i:05d}.journal", lines)
    top = BASE + (24 * PER) * STEP + 2 * 40_000_000
    mkfile(f"{EXTRA}/newer.journal", [entry(top + e * STEP, 5_000_000 + e * STEP, "00000009" + "b007" * 6, M1, f"newer {e}") for e in range(PER)])
    # interleaved with the static files from entry 4000 on: same boot and monotonic scale as static file 12
    mkfile(f"{EXTRA}/interleaved.journal", [entry(BASE + (12 * PER + 3 + 2 * e) * STEP + 40_000_000, 5_000_000 + (3 + 2 * e) * STEP + 1, boot_of(12), M1, f"inter {e}") for e in range(PER)]) if MODE == "restart" else mkfile(f"{EXTRA}/interleaved.journal", [entry(BASE + (12 * PER + 3 + 2 * e) * STEP + 40_000_000, 5_000_000 + ((12 % 8) * PER + 3 + 2 * e) * STEP + 1, boot_of(12), M1, f"inter {e}") for e in range(PER)])
    mkfile(f"{EXTRA}/older.journal", [entry(BASE + e * STEP - 1000, 5_000_000 + e * STEP - 1000, "000000aa" + "b007" * 6, M1, f"older {e}") for e in range(PER)])
    mkfile(f"{EXTRA}/twomachines.journal", [entry(BASE + (6 * PER + 1 + e) * STEP + 500, 5_000_000 + e * STEP, "000000bb" + "c007" * 6, M2, f"m2 {e}") for e in range(PER)])


def run(name, extra, remove, backwards, matches):
    d = f"{WORK}/run-{name}"
    shutil.rmtree(d, ignore_errors=True)
    shutil.copytree(STATIC, d)
    j = ctypes.c_void_p()
    r = lib.sd_journal_open_directory(ctypes.byref(j), d.encode(), 0)
    assert r >= 0, r
    lib.sd_journal_get_fd(j)                       # starts inotify
    if matches == "kernel":
        lib.sd_journal_add_match(j, b"SYSLOG_IDENTIFIER=kernel", 0)
    elif matches == "or":
        lib.sd_journal_add_match(j, (f"_BOOT_ID={boot_of(0)[:32]}").encode(), 0)
        lib.sd_journal_add_disjunction(j)
        lib.sd_journal_add_match(j, (f"_BOOT_ID={boot_of(8)[:32]}").encode(), 0)
    if backwards:
        lib.sd_journal_seek_tail(j)
        step = lib.sd_journal_previous
    else:
        lib.sd_journal_seek_head(j)
        step = lib.sd_journal_next
    h = hashlib.sha256()
    count = 0
    acted = False
    names = sorted(os.listdir(d))
    while True:
        r = step(j)
        if r <= 0:
            break
        rt = ctypes.c_uint64()
        lib.sd_journal_get_realtime_usec(j, ctypes.byref(rt))
        p = ctypes.c_void_p(); n = ctypes.c_size_t()
        lib.sd_journal_get_data(j, b"MESSAGE", ctypes.byref(p), ctypes.byref(n))
        h.update(f"{rt.value}|{ctypes.string_at(p, n.value).decode()}\n".encode())
        count += 1
        if count == 3000 and not acted:
            acted = True
            if extra:
                shutil.copy(f"{EXTRA}/{extra}", f"{d}/.new")
                os.rename(f"{d}/.new", f"{d}/system@{extra}")     # appears complete, atomically
            for f in remove(names, count):
                os.unlink(f"{d}/{f}")
        if acted and count % 100 == 0:
            lib.sd_journal_process(j)
    # the end: process once more and read on (new entries appended at the end)
    lib.sd_journal_process(j)
    while step(j) > 0:
        rt = ctypes.c_uint64()
        lib.sd_journal_get_realtime_usec(j, ctypes.byref(rt))
        h.update(f"tail {rt.value}\n".encode())
        count += 1
    lib.sd_journal_close(j)
    shutil.rmtree(d, ignore_errors=True)
    return count, h.hexdigest()[:16]


none = lambda names, c: []
scen = {
    "add_newer": ("newer.journal", none),
    "add_interleaved": ("interleaved.journal", none),
    "add_older": ("older.journal", none),
    "add_twomachines": ("twomachines.journal", none),
    "remove_future": (None, lambda names, c: [names[20]]),
    "remove_current": (None, lambda names, c: [names[(c - 1) // PER]]),
    "remove_all_but": (None, lambda names, c: names[:20]),
}
for backwards in (False, True):
    for matches in (None, "kernel", "or"):
        for name, (extra, rem) in scen.items():
            tag = f"{name}{' backwards' if backwards else ''}{' match=' + matches if matches else ''}"
            count, digest = run(name, extra, rem, backwards, matches)
            print(f"{tag}: {count} {digest}", flush=True)
