import sys

# compare-patch-bodies.py <old dir> <new dir>: for each of the six patches, are the +/- lines identical
# (ignoring hunk offsets, index lines and the From/Date headers)?
old, new = sys.argv[1:3]
names = [
    "0001-a2dp-Fix-use-after-free-when-switching-endpoints-dur.patch",
    "0002-test-Cover-A2DP-endpoint-switch-while-Close-is-pendi.patch",
    "0003-media-Fix-use-after-free-of-app-removing-a-locked-A2.patch",
    "0004-media-Fix-sending-Release-twice-to-A2DP-endpoints.patch",
    "0005-media-Fix-use-after-free-releasing-endpoints-on-adap.patch",
    "0006-test-Cover-A2DP-endpoint-release-with-an-acquired-tr.patch",
]


def body(path):
    out = []
    msg = []
    in_diff = False
    for line in open(path, encoding="utf-8").read().split("\n"):
        if line.startswith("diff --git"):
            in_diff = True
        if in_diff:
            if line[:1] in "+-" and not line.startswith(("+++", "---")):
                out.append(line)
        elif not line.startswith(("From ", "From:", "Date:")):
            msg.append(line)
    return msg, out


for n in names:
    om, ob = body(f"{old}/{n}")
    nm, nb = body(f"{new}/{n}")
    print(f"{n[:4]} message identical: {om == nm}; changed lines identical: {ob == nb} ({len(ob)} vs {len(nb)})")
