import subprocess
import sys

# subj-stats.py <repo> <base> <series ref> : series subject lengths, and how long merged master subjects are
repo, base, ref = sys.argv[1:4]


def subjects(rng, extra=()):
    out = subprocess.run(
        ["git", "-C", repo, "log", "--no-merges", "--format=%s", *extra, rng],
        capture_output=True, text=True, check=True,
    ).stdout
    return out.splitlines()


for s in subjects(f"{base}..{ref}"):
    print(f"{len(s):3d} {s}")

recent = subjects(base, ["-n", "500"])
over50 = sum(1 for s in recent if len(s) > 50)
over72 = sum(1 for s in recent if len(s) > 72)
lens = sorted(len(s) for s in recent)
print(f"last {len(recent)} non-merge subjects on master {base[:12]}: over 50 columns {over50}, over 72 {over72}, median {lens[len(lens)//2]}")
