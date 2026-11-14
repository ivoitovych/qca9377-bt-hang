import re, sys, glob, os
# extract-active.py <logdir> - for the case "Mesh - Send queue - cancel active" (legacy and "- Ext Adv"):
# did request 2 (B) get a start ("Mesh set started for request 2") before its Mesh Packet Complete?
ansi = re.compile(r"\x1b\[[0-9;]*m")
rows = []
for f in sorted(glob.glob(os.path.join(sys.argv[1], "active-*.log"))):
    txt = ansi.sub("", open(f, errors="replace").read()).split("\n")
    for case in ("Mesh - Send queue - cancel active", "Mesh - Send queue - cancel active - Ext Adv"):
        sec, on = [], False
        for l in txt:
            if l.startswith(case + " - run"):
                on = True
                continue
            if on and l.startswith(case + " - test "):
                sec.append(l)
                break
            if on:
                sec.append(l)
        started2 = sum(1 for l in sec if "set started for request 2" in l)
        started1 = sum(1 for l in sec if "set started for request 1" in l)
        comp2 = [l.strip() for l in sec if "Packet Complete handle 2" in l]
        verdict = sec[-1].split(" - ")[-1] if sec else "?"
        rows.append((os.path.basename(f)[:-4], case.replace("Mesh - Send queue - ", ""), started1, started2, comp2[0][:60] if comp2 else "no completion for 2", verdict))
for r in rows:
    print("%-14s %-26s started1=%d started2=%d | %s | %s" % r)
