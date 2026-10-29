#!/usr/bin/env python3
"""prove-archive-budget-check.py: controls for archive-budget-check.py and the BUDGET_GB file.

Works in a scratch directory under the project's tmp/; never reads the real archive/.
Run: python3 -I prove-archive-budget-check.py, or directly (executable, as every script here
must be; CI's invariant caught it missing on 85114a8).
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CHECK = os.path.join(HERE, "archive-budget-check.py")
ARCHIVER = os.path.join(HERE, "bt-trace-archive.py")
PROJECT_TMP = "/root/exp/qca9377-bt-hang/tmp"
failures = 0


def expect(cond, what, detail=""):
    global failures
    print(("ok   " if cond else "FAIL ") + what)
    if not cond:
        failures += 1
        print(detail)


def store(root, name, zst_bytes, budget_gb):
    d = os.path.join(root, name)
    os.makedirs(d)
    open(os.path.join(d, "MANIFEST.tsv"), "w").close()
    with open(os.path.join(d, "a.zst"), "wb") as f:
        f.write(b"\0" * zst_bytes)
    if budget_gb is not None:
        with open(os.path.join(d, "BUDGET_GB"), "w") as f:
            f.write(budget_gb + "\n")


def check(*args):
    p = subprocess.run([sys.executable, "-I", CHECK, *args], capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


os.makedirs(PROJECT_TMP, exist_ok=True)
with tempfile.TemporaryDirectory(dir=PROJECT_TMP, prefix="prove-archive-budget-") as tmp:
    # budgets in GB scaled down: 1000 bytes of a 0.000001 GB budget is about 93 %
    root = os.path.join(tmp, "archive")
    os.makedirs(root)
    store(root, "low", 100, "0.000001")      # ~9 %
    store(root, "high", 1000, "0.000001")    # ~93 %
    store(root, "none", 100, None)
    os.makedirs(os.path.join(root, "not-a-store"))  # no MANIFEST.tsv: skipped
    code, out = check(root)
    expect(code == 0, "no store full: exit 0", out)
    expect("archive low:" in out and "⚠️" not in out.split("archive low:")[1].splitlines()[0],
           "a store under 80 % is OK", out)
    expect("archive high:" in out and "over 80%" in out, "a store over 80 % warns", out)
    expect("archive none: NO BUDGET" in out, "a store without BUDGET_GB is reported, not assumed", out)
    expect("not-a-store" not in out, "a directory without MANIFEST.tsv is not a store", out)
    code, out = check("--warn-only", root)
    expect("archive low" not in out and "archive high" in out and "archive none" in out,
           "--warn-only prints only what needs attention", out)

    store(root, "full", 2000, "0.000001")    # ~186 %
    code, out = check("--warn-only", root)
    expect(code == 1 and "archive full" in out and "FULL" in out, "a full store: FULL and exit 1", out)

    quiet = os.path.join(tmp, "quiet")
    os.makedirs(quiet)
    store(quiet, "fine", 10, "1")
    code, out = check("--warn-only", quiet)
    expect(code == 0 and out == "", "--warn-only with every store fine prints nothing", out)

    # The archiver writes BUDGET_GB for its store, with the budget it ran under.
    trace, arch = os.path.join(tmp, "trace"), os.path.join(tmp, "arch")
    os.makedirs(trace)
    env = dict(os.environ, BT_TRACE_DIR=trace, BT_TRACE_KEEP_DIR=os.path.join(tmp, "nokeep"),
               BT_ARCHIVE_DIR=arch, BT_ARCHIVE_BUDGET_GB="10", BT_ARCHIVE_SETTLE_SEC="0")
    p = subprocess.run([sys.executable, "-I", ARCHIVER], capture_output=True, text=True, env=env)
    with open(os.path.join(arch, "BUDGET_GB")) as f:
        written = f.read().strip()
    expect(p.returncode == 0 and written == "10", "the archiver records BUDGET_GB = 10", p.stdout + written)

print(f"{failures} failure(s)")
sys.exit(1 if failures else 0)
