import os, shutil
PK = "/root/exp/qca9377-bt-hang/contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261102/"
OUT = "/root/exp/agent-work/lane5-status-stable-20261114/co35/mail/"
subs = {
    "6.18.y": [("v6.18.60", "v6.18.63"), ("f45ed76d6791cf72ff1265ee93511175bbbc2f18", "1cdda838e8475edf89b73ff0cc952005dd0b1fa7")],
    "6.12.y": [("v6.12.115", "v6.12.117"), ("03bae623ec326c2738198739625832aab0eb120a", "d3417611a3b40b7f04a29e558cebac2bf69889d7")],
    "6.6.y": [("v6.6.161", "v6.6.162"), ("b5a1dc3ad4822c6edfb53429e9a3759c9b0ac2be", "5139929c698c273e07cb0635732f6a918a7b8e78")],
}
for line, pairs in subs.items():
    d = OUT + line + "/"
    os.makedirs(d, exist_ok=True)
    t = open(PK + line + "/0000-cover-letter.patch").read()
    for a, b in pairs:
        assert a in t, (line, a)
        t = t.replace(a, b)
    import re
    t = re.sub(r"^Date: .*$", "Date: Sat, 14 Nov 2026 12:00:00 +0100", t, count=1, flags=re.M)
    open(d + "0000-cover-letter-20261114.patch", "w").write(t)
    for f in sorted(os.listdir(PK + line)):
        if f.startswith("000") and not f.startswith("0000"):
            shutil.copyfile(PK + line + "/" + f, d + f)
print("ok")
