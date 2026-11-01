#!/usr/bin/env python3
"""Judge one L1 harness log against an expected-results file.

Usage: verify-l1.py <expected file> <log file> <container exit status>

Expected file: one "<ID> PASS|FAIL" per line; "#" starts a comment.
Prints one VERDICT line and every reason; exit 0 only when all hold:
  - the container exited 0 and printed "BUILD OK" and "harness exit 0"
  - no sanitizer report (ASan, LSan, UBSan, "runtime error:")
  - every line starting with RESULT is "RESULT <Unnn> PASS|FAIL <title>"
  - no test ID twice, none that the expected file does not list
  - every expected ID present, with its expected outcome
  - exactly one "SUMMARY pass=<n> fail=<m>", and n, m equal the RESULT
    counts, and n + m equals the number of expected IDs
"""
import re
import sys

RESULT = re.compile(r"^RESULT (U\d{3}) (PASS|FAIL) (\S.*)$")
SUMMARY = re.compile(r"^SUMMARY pass=(\d+) fail=(\d+)$")
SANITIZER = re.compile(
    r"ERROR: AddressSanitizer|ERROR: LeakSanitizer|SUMMARY: AddressSanitizer"
    r"|SUMMARY: UndefinedBehaviorSanitizer|UndefinedBehaviorSanitizer|runtime error:")


def load_expected(path):
    exp = {}
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) != 2 or parts[1] not in ("PASS", "FAIL") \
                or not re.fullmatch(r"U\d{3}", parts[0]) or parts[0] in exp:
            sys.exit(f"bad expected-results line {n}: {line!r}")
        exp[parts[0]] = parts[1]
    if not exp:
        sys.exit("expected-results file lists no test")
    return exp


def main():
    exp_path, log_path, crc = sys.argv[1], sys.argv[2], int(sys.argv[3])
    exp = load_expected(exp_path)
    text = open(log_path, encoding="utf-8", errors="replace").read()
    lines = text.splitlines()
    reasons = []

    if crc != 0:
        reasons.append(f"container exit {crc}")
    if "BUILD OK" not in lines:
        bf = [l for l in lines if l.startswith("BUILD FAILED")]
        reasons.append(f"harness not built ({bf[0] if bf else 'no BUILD line'})")
    hx = [l for l in lines if l.startswith("harness exit ")]
    if not hx:
        reasons.append("no 'harness exit' line (harness never ran or the container died)")
    elif hx[-1] != "harness exit 0":
        reasons.append(f"{hx[-1]} (crash, abort or sanitizer halt)")

    san = [l for l in lines if SANITIZER.search(l)]
    if san:
        reasons.append(f"sanitizer report ({len(san)} lines), first: {san[0].strip()[:160]}")

    got = {}
    malformed = []
    for l in lines:
        if not l.startswith("RESULT"):
            continue
        m = RESULT.match(l)
        if not m:
            malformed.append(l)
            continue
        tid, outcome = m.group(1), m.group(2)
        if tid in got:
            reasons.append(f"duplicate RESULT for {tid}")
            continue
        got[tid] = outcome
    for l in malformed:
        reasons.append(f"malformed RESULT record: {l[:120]!r}")

    for tid in sorted(set(got) - set(exp)):
        reasons.append(f"unknown test ID {tid} ({got[tid]}), not in the expected results")
    for tid in sorted(exp):
        if tid not in got:
            reasons.append(f"missing expected test {tid} (expected {exp[tid]})")
        elif got[tid] != exp[tid]:
            kind = "unexpected FAIL" if got[tid] == "FAIL" else "unexpected PASS"
            reasons.append(f"{kind}: {tid} (expected {exp[tid]})")

    sums = [SUMMARY.match(l) for l in lines if l.startswith("SUMMARY pass=")]
    sums_ok = [s for s in sums if s]
    if len(sums_ok) != 1 or len(sums) != 1:
        reasons.append(f"SUMMARY records: {len(sums_ok)} well-formed of {len(sums)} (want exactly 1)")
    else:
        sp, sf = int(sums_ok[0].group(1)), int(sums_ok[0].group(2))
        np_ = sum(1 for o in got.values() if o == "PASS")
        nf = sum(1 for o in got.values() if o == "FAIL")
        if (sp, sf) != (np_, nf):
            reasons.append(f"count mismatch: SUMMARY pass={sp} fail={sf}, RESULT records pass={np_} fail={nf}")
        if sp + sf != len(exp):
            reasons.append(f"count mismatch: SUMMARY total {sp + sf}, expected {len(exp)} tests")

    n_exp_fail = sum(1 for o in exp.values() if o == "FAIL")
    print(f"expected: {len(exp)} tests, {n_exp_fail} expected to FAIL ({exp_path})")
    print(f"recorded: {len(got)} RESULT records, "
          f"{sum(1 for o in got.values() if o == 'PASS')} PASS, "
          f"{sum(1 for o in got.values() if o == 'FAIL')} FAIL")
    if reasons:
        print(f"VERDICT FAIL ({len(reasons)} reasons)")
        for r in reasons:
            print(f"  - {r}")
        return 1
    print("VERDICT OK: every expected outcome, no sanitizer report, clean exit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
