#!/usr/bin/env python3
"""Prove run-l1.sh's two modes with a stub in place of docker.

Each scenario is a canned container output and exit status; the runner is
run in verify mode against an expected-results file, and in observation
mode, and its exit status is compared with what each mode must return.
Writes the stub outputs and the runner logs under tmp/prove-run-l1/ and
prints one row per scenario; exit 0 only if every row is as required.

Usage: prove-run-l1.py
"""
import os
import re
import subprocess
import sys
from pathlib import Path

R = Path("/root/exp/agent-work/co03/review-20261101")
RUN = R / "scripts/run-l1.sh"
STUB = R / "scripts/stub-docker.sh"
EXP_FIXED = R / "expected/l1-fixed.txt"
EXP_BASE = R / "expected/l1-base.txt"
D = R / "tmp/prove-run-l1"
D.mkdir(parents=True, exist_ok=True)

TITLES = {}
for line in open("/root/exp/agent-work/co03/tests/l1/test-co03-transport.c", encoding="utf-8"):
    m = re.match(r'\s*run\("(U\d{3})", "(.*)", t_u\d{3}\);', line)
    if m:
        TITLES[m.group(1)] = m.group(2)
IDS = sorted(TITLES)
BASE_FAIL = {"U120", "U121", "U122", "U123", "U125", "U126", "U133", "U134"}


def results(fail=(), drop=(), extra=(), summary=None, harness_rc=0, build=True,
            after=None, cut_after=None, malformed=None, dup=None):
    out = []
    if not build:
        return "gcc: error: compilation terminated\nBUILD FAILED 1\n"
    out.append("BUILD OK")
    np_ = nf = 0
    for tid in IDS:
        if tid in drop:
            continue
        o = "FAIL" if tid in fail else "PASS"
        np_ += o == "PASS"
        nf += o == "FAIL"
        out.append(f"RESULT {tid} {o} {TITLES[tid]}" + (" :: detail" if o == "FAIL" else ""))
        if malformed and tid == malformed[0]:
            out.append(malformed[1])
        if dup and tid == dup:
            out.append(f"RESULT {tid} PASS {TITLES[tid]}")
        if after and tid == after[0]:
            out.extend(after[1])
        if cut_after and tid == cut_after:
            out.append(f"harness exit {harness_rc}")
            return "\n".join(out) + "\n"
    out.extend(extra)
    if summary is None:
        summary = f"SUMMARY pass={np_} fail={nf}"
    if summary:
        out.append(summary)
    out.append(f"harness exit {harness_rc}")
    return "\n".join(out) + "\n"


ASAN = [
    "=================================================================",
    "==17==ERROR: AddressSanitizer: heap-use-after-free on address 0x602000000010 at pc 0x55d0 bp 0x7ffd sp 0x7ffd",
    "READ of size 8 at 0x602000000010 thread T0",
    "    #0 0x55d0 in a2dp_cancel_resume_cb /b/profiles/audio/transport.c:400",
    "SUMMARY: AddressSanitizer: heap-use-after-free /b/profiles/audio/transport.c:400 in a2dp_cancel_resume_cb",
    "==17==ABORTING",
]
UBSAN = ["/b/profiles/audio/transport.c:512:7: runtime error: load of null pointer of type 'struct a2dp_transport'"]

# name: (container output, container exit, expected file,
#        verify exit must be 0?, observation exit must be 0?)
S = {
    "pass-fixed": (results(), 0, EXP_FIXED, True, True),
    "pass-base": (results(fail=BASE_FAIL), 0, EXP_BASE, True, True),
    "fail-unexpected": (results(fail={"U104"}), 0, EXP_FIXED, False, True),
    "pass-unexpected-on-base": (results(fail=BASE_FAIL - {"U120"}), 0, EXP_BASE, False, True),
    "base-run-judged-as-fixed": (results(fail=BASE_FAIL), 0, EXP_FIXED, False, True),
    "asan-halt": (results(cut_after="U110", after=("U110", ASAN), harness_rc=1), 1, EXP_FIXED, False, True),
    "asan-at-exit-rc0": (results(extra=ASAN[:5]), 0, EXP_FIXED, False, True),
    "ubsan-line-rc0": (results(after=("U122", UBSAN)), 0, EXP_FIXED, False, True),
    "crash-segv": (results(cut_after="U117", harness_rc=139), 139, EXP_FIXED, False, True),
    "crash-before-any-result": ("BUILD OK\nharness exit 134\n", 134, EXP_FIXED, False, False),
    "missing-test": (results(drop={"U117"}), 0, EXP_FIXED, False, True),
    "count-mismatch": (results(summary="SUMMARY pass=35 fail=0", drop={"U117"}), 0, EXP_FIXED, False, True),
    "summary-disagrees": (results(summary="SUMMARY pass=34 fail=1"), 0, EXP_FIXED, False, True),
    "no-summary": (results(summary=""), 0, EXP_FIXED, False, True),
    "malformed-result": (results(malformed=("U105", "RESULT U105x PASS")), 0, EXP_FIXED, False, True),
    "duplicate-id": (results(dup="U106"), 0, EXP_FIXED, False, True),
    "unknown-id": (results(extra=["RESULT U199 PASS a test the plan does not list"]), 0, EXP_FIXED, False, True),
    "build-failure": (results(build=False), 90, EXP_FIXED, False, False),
    "docker-failure": ("docker: Error response from daemon: pull access denied\n", 125, EXP_FIXED, False, False),
    "harness-rc-nonzero-but-results-ok": (results(harness_rc=1), 1, EXP_FIXED, False, True),
}

rows = []
bad = 0
env = dict(os.environ, STUB_DIR=str(D))
for name, (out, rc, exp, v_ok, o_ok) in S.items():
    (D / f"{name}.out").write_text(out)
    (D / f"{name}.rc").write_text(f"{rc}\n")
    env["STUB_SCENARIO"] = name
    v = subprocess.run([str(RUN), "--verify", str(exp), "--docker", str(STUB), "/nonexistent-tree",
                        str(D / f"{name}.verify.log")], env=env, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, encoding="utf-8")
    (D / f"{name}.verify.stdout").write_text(v.stdout)
    o = subprocess.run([str(RUN), "--docker", str(STUB), "/nonexistent-tree",
                        str(D / f"{name}.observe.log")], env=env, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, encoding="utf-8")
    (D / f"{name}.observe.stdout").write_text(o.stdout)
    v_good = (v.returncode == 0) == v_ok
    o_good = (o.returncode == 0) == o_ok
    bad += (not v_good) + (not o_good)
    reasons = [l.strip()[2:] for l in v.stdout.splitlines() if l.startswith("  - ")]
    rows.append((name, rc, exp.name, v.returncode, "ok" if v_good else "WRONG",
                 o.returncode, "ok" if o_good else "WRONG", reasons[0] if reasons else "-"))

print("| scenario | container exit | expected file | verify exit | as required | observe exit | as required | first verify reason |")
print("|---|---|---|---|---|---|---|---|")
for r in rows:
    print("| " + " | ".join(str(x) for x in r) + " |")
print(f"\n{len(rows)} scenarios, {bad} wrong")
sys.exit(1 if bad else 0)
