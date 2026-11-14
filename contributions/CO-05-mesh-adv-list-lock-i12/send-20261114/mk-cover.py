import subprocess
# cover letter = body + shortlog + diffstat + base-commit, from the kernel-sp branch co05-next
T = "/root/exp/agent-work/lane3-mgmt-20261114/kernel-sp"
base = "da3cc02587c629420603df4395179ec82955c941"
body = open("/root/exp/agent-work/lane3-mgmt-20261114/CO-05-26/cover-body.txt").read()
def git(*a):
    return subprocess.run(["git", "-C", T] + list(a), capture_output=True, text=True, check=True).stdout
sl = git("log", "--reverse", "--format=%s", base + "..co05-next").strip().split("\n")
txt = body + "Iaroslav Voitovych (%d):\n" % len(sl) + "".join("  %s\n" % s for s in sl) + "\n" + git("diff", "--stat", base + "..co05-next") + "\n\nbase-commit: " + base + "\n--\n2.43.0\n"
open("/root/exp/agent-work/lane3-mgmt-20261114/CO-05-26/patch/0000-cover-letter.patch", "w").write(txt)
