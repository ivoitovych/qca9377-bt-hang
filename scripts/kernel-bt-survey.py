#!/usr/bin/env python3
"""kernel-bt-survey.py — how the kernel Bluetooth tree's patch workflow runs, from
the same patchwork project ("bluetooth") the BlueZ survey used, restricted to
KERNEL patches (the bot runs BuildKernel on them, not BluezMake).

For every kernel series (first patch) in the most recent PAGES x 100 entries:
state, version, the bot's check states, who commented (bot / maintainer /
submitter / other), and for accepted ones whether a maintainer commented before
acceptance. Then: every non-bot comment on a kernel patch that mentions the
rules (CI, checkpatch, Fixes, stable, sign-off, subject, tree, resend, v2…),
quoted — what maintainers actually say. Cached under tmp/patchwork/survey/.

  scripts/kernel-bt-survey.py [PAGES]      default 10
"""
import json, os, re, sys, time, urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "tmp", "patchwork", "survey")
API = "https://patchwork.kernel.org/api/1.3"
UA = "qca9377-bt-hang/kernel-bt-survey (urllib)"
MAINT = ("luiz", "dentz", "marcel holtmann", "johan hedberg")
os.makedirs(OUT, exist_ok=True)


def get(url, name):
    path = os.path.join(OUT, name)
    if os.path.exists(path):
        return json.load(open(path))
    err = None
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            data = json.load(urllib.request.urlopen(req, timeout=60))
            json.dump(data, open(path + ".tmp", "w")); os.replace(path + ".tmp", path)
            return data
        except Exception as e:
            err = e; time.sleep(3 * (attempt + 1))
    sys.exit(f"cannot fetch {url}: {err}")


def version(p):
    m = re.search(r"\bv(\d+)\b", re.match(r"^((\s*\[[^\]]*\]\s*)*)", p["name"]).group(1))
    return int(m.group(1)) if m else 1


def checks(pid):
    seen = {}
    for c in get(f"{API}/patches/{pid}/checks/", f"checks-{pid}.json"):
        seen[c["context"]] = c["state"]
    return seen


def who(c, sub_mail):
    name = (c["submitter"].get("name") or "").lower()
    mail = (c["submitter"].get("email") or "").lower()
    if "bot" in mail or "bot" in name:
        return "patchwork-bot" if "patchwork-bot" in mail else "bot"
    if any(m in name for m in MAINT):
        return "maintainer"
    return "submitter" if mail == sub_mail else "other"


def comments(p):
    sub = (p["submitter"].get("email") or "").lower()
    return [(who(c, sub), c) for c in get(f"{API}/patches/{p['id']}/comments/", f"comments-{p['id']}.json")]


pages = int(sys.argv[1]) if len(sys.argv) > 1 else 10
allp = []
for n in range(1, pages + 1):
    allp += get(f"{API}/patches/?project=bluetooth&order=-date&per_page=100&page={n}", f"patches-p{n}.json")
print(f"patches read: {len(allp)}  ({allp[-1]['date'][:10]} .. {allp[0]['date'][:10]})")

first = {}
for p in allp:
    sid = p["series"][0]["id"] if p.get("series") else p["id"]
    if sid not in first or p["id"] < first[sid]["id"]:
        first[sid] = p
series = sorted(first.values(), key=lambda p: p["date"], reverse=True)

kernel = []
for p in series:
    if "bluez" in p["name"].lower():
        continue
    ck = checks(p["id"])
    if not ck or "BuildKernel" not in ck and "SubjectPrefix" not in ck:
        continue
    kernel.append((p, ck))
states = {}
for p, _ in kernel:
    states[p["state"]] = states.get(p["state"], 0) + 1
print(f"kernel series with bot checks: {len(kernel)}   by state: {states}\n")

KEYS = ["CheckPatch", "GitLint", "SubjectPrefix", "VerifyFixes", "VerifySignedOff", "TestRunner", "BuildKernel"]
agg = {"accepted": 0, "acc_any_fail": 0, "acc_checkpatch_bad": 0, "acc_gitlint_bad": 0,
       "acc_testrunner_bad": 0, "acc_maint_commented": 0, "acc_v2plus": 0}
print("KERNEL series — date id state vN | check states | commenters | submitter")
for p, ck in kernel:
    cm = comments(p)
    ws = [w for w, _ in cm]
    line = " ".join(f"{k}:{ck[k]}" for k in KEYS if k in ck)
    print(f"{p['date'][:10]} {p['id']} {p['state']:<10} v{version(p)} | {line} | [{','.join(ws) or '-'}] {p['submitter']['name']}")
    if p["state"] == "accepted":
        agg["accepted"] += 1
        agg["acc_any_fail"] += any(v in ("fail", "warning") for v in ck.values())
        agg["acc_checkpatch_bad"] += ck.get("CheckPatch") in ("fail", "warning")
        agg["acc_gitlint_bad"] += ck.get("GitLint") in ("fail", "warning")
        agg["acc_testrunner_bad"] += any(k.startswith("TestRunner") and v == "fail" for k, v in ck.items())
        agg["acc_maint_commented"] += "maintainer" in ws
        agg["acc_v2plus"] += version(p) >= 2
print("\nAGGREGATES, accepted kernel series")
for k, v in agg.items():
    print(f"  {k:<24} {v}")

KEY = re.compile(r"checkpatch|gitlint|\bCI\b|test ?bot|Fixes:|stable|Signed-off|subject|prefix|bluetooth-next|resend|please send|v[0-9]\b|applied|thanks", re.I)
print("\nWHAT HUMANS SAID on kernel patches (non-bot comments matching the rule words)")
n = 0
for p, _ in kernel:
    for w, c in comments(p):
        if w in ("bot", "patchwork-bot"):
            continue
        body = "\n".join(l for l in c.get("content", "").splitlines() if not l.startswith(">")).strip()
        if not KEY.search(body):
            continue
        n += 1
        excerpt = re.sub(r"\s+", " ", body)[:420]
        print(f"\n[{w}] {c['submitter'].get('name')}  {c['date'][:16]}  on {p['id']} ({p['state']}) {p['name'][:70]}\n    {excerpt}")
print(f"\nhuman rule-related comments: {n}")
