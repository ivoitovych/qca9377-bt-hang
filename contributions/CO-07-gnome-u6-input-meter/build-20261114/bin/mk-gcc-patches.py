import os, re, subprocess
G = "/root/exp/qca9377-bt-hang/cache/gnome-control-center-upstream"
OUT = "/root/exp/agent-work/lane5-status-stable-20261114/task5/patches-gcc/"
os.makedirs(OUT, exist_ok=True)
# the upstream order (git log --reverse --topo-order on panels/sound), which is also the README's
order = ["21528993549a7575456ddd8e1902e2e88dec8476", "a74bc5a84d4510ec1479d215db783a482a2afdad", "bf6f72278e5b6168ab13b774d4e20ca2cc3fadee",
         "afec106a8b6690ea04475a8bb27232b118dd69b3", "3aeb837cb0936cfa448923b479e658477e7ed512", "0da10f03ad27d5f1822ac1a15fcc8de9faead595"]
series = []
for c in order:
    t = subprocess.run(["git", "-C", G, "format-patch", "-1", "--stdout", "--no-signature", c], capture_output=True, text=True, check=True).stdout
    author = re.search(r"^From: (.*)$", t, re.M).group(1)
    subj = re.search(r"^Subject: \[PATCH\] (.*(?:\n .*)*)", t, re.M).group(1).replace("\n ", " ")
    body, diff = t.split("\n---\n", 1)
    body = body.split("\n\n", 1)[1].strip()
    # drop trailers of the upstream commit message that are not DEP-3 (Part-of, Fixes/Closes URLs stay in the text)
    desc = [subj] + [" " + (l if l.strip() else ".") for l in body.splitlines()]
    name = re.sub(r"[^A-Za-z0-9._-]+", "-", subj).strip("-")[:70] + ".patch"
    n = "%02d-%s" % (len(series) + 1, name)
    hdr = ("Description: " + "\n".join(desc) + "\n"
           "Author: " + author + "\n"
           "Origin: upstream, https://gitlab.gnome.org/GNOME/gnome-control-center/-/commit/" + c + "\n"
           "Applied-Upstream: 47.0, commit:" + c + "\n"
           "Bug-Ubuntu: https://bugs.launchpad.net/ubuntu/+source/gnome-control-center/+bug/<LP-GCC-METER>\n"
           "Forwarded: not-needed\n"
           "Last-Update: 2026-11-14\n---\n")
    # keep the diff only (drop the diffstat lines up to the first diff header)
    diff = diff[diff.index("diff --git"):]
    open(OUT + n, "w").write(hdr + diff.rstrip("\n") + "\n")
    series.append(n)
    print(n)
open(OUT + "series.fragment", "w").write("\n".join(series) + "\n")
