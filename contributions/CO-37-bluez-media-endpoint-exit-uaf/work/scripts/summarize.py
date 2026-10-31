#!/usr/bin/env python3
"""
summarize.py <run dir> <label>

For each <label>-<i>.log in the run directory (pytest -rA output), print
the test verdicts and the distinct sanitizer SUMMARY lines it carries
(reported through SanitizerWarning), then totals: runs, runs with a
non-passing verdict, runs with a sanitizer SUMMARY, and the count per
SUMMARY text.
"""
import collections
import re
import sys
from pathlib import Path

verdict_re = re.compile(r"^(PASSED|FAILED|ERROR|SKIPPED|XFAIL|XPASS) (\S+)")
summary_re = re.compile(r"SUMMARY: (\w+Sanitizer: .*)$")


def run_key(path, label):
    m = re.match(re.escape(label) + r"-(\d+)\.log$", path.name)
    return int(m.group(1)) if m else None


def main():
    run_dir, label = Path(sys.argv[1]), sys.argv[2]
    runs = []
    for p in run_dir.iterdir():
        k = run_key(p, label)
        if k is not None:
            runs.append((k, p))
    runs.sort()

    bad = 0
    with_summary = 0
    per_summary = collections.Counter()

    for k, p in runs:
        verdicts = []
        summaries = []
        with open(p, errors="replace") as f:
            for line in f:
                m = verdict_re.match(line)
                if m:
                    verdicts.append(f"{m.group(1)} {m.group(2).split('::')[-1]}")
                m = summary_re.search(line)
                if m and m.group(1) not in summaries:
                    summaries.append(m.group(1))
        if any(not v.startswith("PASSED") for v in verdicts) or not verdicts:
            bad += 1
        if summaries:
            with_summary += 1
        per_summary.update(summaries)
        print(f"run {k}: {'; '.join(verdicts) or 'NO VERDICT'}")
        for s in summaries:
            print(f"    {s}")

    print(f"{label}: {len(runs)} runs, {bad} not passed, {with_summary} with a sanitizer SUMMARY")
    for s, n in per_summary.most_common():
        print(f"  {n} x {s}")


if __name__ == "__main__":
    main()
