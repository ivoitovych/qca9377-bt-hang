import hashlib, os
W = "/root/exp/agent-work/laptop-evidence-mining-20261111"
keep = []
for n in sorted(os.listdir(W)):
    p = W + "/" + n
    if os.path.isfile(p) and n not in ("SHA256SUMS", "addrmap.private"):
        keep.append(n)
for d in sorted(os.listdir(W)):
    if d.startswith("s3") or d == "results":
        for n in sorted(os.listdir(W + "/" + d)):
            keep.append(d + "/" + n)
with open(W + "/SHA256SUMS", "w") as f:
    for n in keep:
        f.write(hashlib.sha256(open(W + "/" + n, "rb").read()).hexdigest() + "  " + n + "\n")
print(len(keep), "files")
