import subprocess, sys
# mk-cover.py <bluez clone> <base> <out file> - the cover letter: body text file + shortlog + diffstat
# of <base>..HEAD, as format-patch --cover-letter lays it out.
B, base, out = sys.argv[1:4]
body = open("/root/exp/agent-work/lane3-mgmt-20261114/CO-38/bluez-cover-body.txt").read()
def git(*a):
    return subprocess.run(["git", "-C", B] + list(a), capture_output=True, text=True, check=True).stdout
shortlog = git("shortlog", "--no-merges", base + "..HEAD")
stat = git("diff", "--stat", base + "..HEAD")
shortlog = "\n".join(l.replace("      ", "  ", 1) if l.startswith("      ") else l for l in shortlog.rstrip("\n").split("\n")) + "\n"
txt = body + shortlog + "\n" + stat + "\nbase-commit: " + git("rev-parse", base).strip() + "\n--\n2.43.0\n"
open(out, "w").write(txt)
