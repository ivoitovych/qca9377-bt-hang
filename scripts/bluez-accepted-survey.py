#!/usr/bin/env python3
"""bluez-accepted-survey.py — how BlueZ's patch workflow treats CI-bot failures.

Question (operator, 2026-09-21): when the bot reports CheckPatch / GitLint /
test failures, who reacts — the contributor on their own, or only after the
maintainer speaks — and does the maintainer apply patches whose bot run failed?

Method, all from patchwork's public API (read-only, cached under
tmp/patchwork/survey/ so the claim ships with its data):

  1. the most recent PAGES x 100 patches of project "bluetooth", any state;
     BlueZ (userspace) patches are those whose checks include BluezMake, or
     whose name carries "BlueZ".
  2. for every ACCEPTED BlueZ series (first patch of each series): the bot's
     check states at the accepted version, and every comment with its author
     class — bot / maintainer / submitter / other.
  3. for accepted series at version >= 2: the previous version (same submitter,
     same normalised title) — its check states and whether a human commented on
     it before the respin. "lint failed, nobody said anything, a new version
     appeared with lint fixed" is a contributor reacting to the bot alone.

  scripts/bluez-accepted-survey.py [PAGES]      default 10 (1000 patches)

Output: one line per accepted series, then the aggregates.
"""
import json, os, re, sys, time, urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "tmp", "patchwork", "survey")
API = "https://patchwork.kernel.org/api/1.3"
UA = "qca9377-bt-hang/bluez-accepted-survey (urllib)"
MAINTAINERS = ("luiz", "dentz", "marcel holtmann", "johan hedberg", "patchwork-bot")
BOTS = ("bluez.test.bot", "bluez test bot", "patchwork-bot", "kernel test robot")
LINT = ("CheckPatch", "GitLint")

os.makedirs(OUT, exist_ok=True)


def get(url, name):
    path = os.path.join(OUT, name)
    if os.path.exists(path):
        return json.load(open(path))
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            data = json.load(urllib.request.urlopen(req, timeout=60))
            json.dump(data, open(path + ".tmp", "w"))
            os.replace(path + ".tmp", path)
            return data
        except Exception as e:  # transient: retry, then give up loudly
            err = e
            time.sleep(3 * (attempt + 1))
    sys.exit(f"cannot fetch {url}: {err}")


def norm(name):
    """title without any [..] prefixes, lower-cased"""
    return re.sub(r"^(\s*\[[^\]]*\]\s*)+", "", name).strip().lower()


def version(p):
    m = re.search(r"\bv(\d+)\b", re.match(r"^((\s*\[[^\]]*\]\s*)*)", p["name"]).group(1))
    return int(m.group(1)) if m else 1


def checks(pid):
    seen = {}
    for c in get(f"{API}/patches/{pid}/checks/", f"checks-{pid}.json"):
        seen[c["context"]] = c["state"]
    return seen


def who(c, submitter_email):
    name = (c["submitter"].get("name") or "").lower()
    mail = (c["submitter"].get("email") or "").lower()
    if any(b in name or b in mail for b in BOTS):
        return "patchwork-bot" if "patchwork-bot" in mail else "bot"
    if any(m in name for m in MAINTAINERS):
        return "maintainer"
    if mail == submitter_email:
        return "submitter"
    return "other"


def comments(p):
    sub = (p["submitter"].get("email") or "").lower()
    return [(who(c, sub), c["date"][:16]) for c in
            get(f"{API}/patches/{p['id']}/comments/", f"comments-{p['id']}.json")]


pages = int(sys.argv[1]) if len(sys.argv) > 1 else 10
allp = []
for n in range(1, pages + 1):
    allp += get(f"{API}/patches/?project=bluetooth&order=-date&per_page=100&page={n}",
                f"patches-p{n}.json")
print(f"patches read: {len(allp)}  ({allp[-1]['date'][:10]} .. {allp[0]['date'][:10]})")

# first patch of each series only: the bot runs the full build on patch 1
first = {}
for p in allp:
    sid = p["series"][0]["id"] if p.get("series") else p["id"]
    if sid not in first or p["id"] < first[sid]["id"]:
        first[sid] = p
series = sorted(first.values(), key=lambda p: p["date"], reverse=True)

states = {}
bluez = []
for p in series:
    if "bluez" not in p["name"].lower():
        continue
    bluez.append(p)
    states[p["state"]] = states.get(p["state"], 0) + 1
print(f"BlueZ series among them: {len(bluez)}   by state: {states}\n")

accepted = [p for p in bluez if p["state"] == "accepted"]
agg = {"n": 0, "lint_fail": 0, "func_fail": 0, "clean": 0,
       "maint_comment_before_accept": 0, "respin": 0,
       "respin_prev_lint_fail": 0, "respin_prev_lint_fail_no_human": 0,
       "respin_lint_fixed": 0}
print("ACCEPTED BlueZ series — date, id, vN, lint states, TestFunctional, commenters, submitter")
for p in accepted:
    ck = checks(p["id"])
    if not ck:
        continue
    agg["n"] += 1
    lint = {k: ck.get(k, "-") for k in LINT}
    lint_bad = any(v in ("fail", "warning") for v in lint.values())
    func = ck.get("TestFunctional", "-")
    cm = comments(p)
    humans = [w for w, _ in cm if w in ("maintainer", "other", "submitter")]
    agg["lint_fail"] += lint_bad
    agg["func_fail"] += func == "fail"
    agg["clean"] += (not lint_bad and func != "fail")
    agg["maint_comment_before_accept"] += "maintainer" in humans
    v = version(p)
    line = (f"{p['date'][:10]} {p['id']} v{v} "
            f"CheckPatch:{lint['CheckPatch']:<8} GitLint:{lint['GitLint']:<8} Func:{func:<8} "
            f"comments[{','.join(w for w, _ in cm) or '-'}]  {p['submitter']['name']}")
    print(line)
    if v >= 2:
        agg["respin"] += 1
        prevs = [q for q in bluez if q["id"] < p["id"] and version(q) == v - 1
                 and norm(q["name"]) == norm(p["name"])
                 and q["submitter"]["id"] == p["submitter"]["id"]]
        if prevs:
            q = max(prevs, key=lambda x: x["id"])
            qck = checks(q["id"])
            qlint_bad = any(qck.get(k) in ("fail", "warning") for k in LINT)
            qcm = comments(q)
            qhum = [w for w, _ in qcm if w in ("maintainer", "other")]
            print(f"           └ prev v{v-1} {q['id']} state={q['state']} "
                  f"CheckPatch:{qck.get('CheckPatch','-')} GitLint:{qck.get('GitLint','-')} "
                  f"Func:{qck.get('TestFunctional','-')} comments[{','.join(w for w, _ in qcm) or '-'}]")
            if qlint_bad:
                agg["respin_prev_lint_fail"] += 1
                agg["respin_prev_lint_fail_no_human"] += not qhum
                agg["respin_lint_fixed"] += not lint_bad

print("\nAGGREGATES over accepted BlueZ series with bot checks")
for k, v in agg.items():
    print(f"  {k:<36} {v}")

# What triggers a respin: for every SUPERSEDED BlueZ series whose bot run had a
# lint fail/warning — did a human comment on it, and did the next version fix lint?
print("\nSUPERSEDED BlueZ series with a lint fail/warning — who spoke, and what the next version did")
tally = {"n": 0, "human_commented": 0, "bot_only": 0, "bot_only_next_lint_clean": 0,
         "bot_only_next_lint_still_bad": 0, "bot_only_next_not_found": 0}
for p in bluez:
    if p["state"] != "superseded":
        continue
    ck = checks(p["id"])
    if not any(ck.get(k) in ("fail", "warning") for k in LINT):
        continue
    tally["n"] += 1
    cm = comments(p)
    hum = [w for w, _ in cm if w in ("maintainer", "other")]
    nxt = [q for q in bluez if q["id"] > p["id"] and norm(q["name"]) == norm(p["name"])
           and q["submitter"]["id"] == p["submitter"]["id"]]
    nline = "next: not found in window"
    nbad = None
    if nxt:
        q = min(nxt, key=lambda x: x["id"])
        qck = checks(q["id"])
        nbad = any(qck.get(k) in ("fail", "warning") for k in LINT)
        nline = (f"next v{version(q)} {q['id']} state={q['state']} "
                 f"CheckPatch:{qck.get('CheckPatch','-')} GitLint:{qck.get('GitLint','-')}")
    if hum:
        tally["human_commented"] += 1
    else:
        tally["bot_only"] += 1
        if nbad is None:
            tally["bot_only_next_not_found"] += 1
        elif nbad:
            tally["bot_only_next_lint_still_bad"] += 1
        else:
            tally["bot_only_next_lint_clean"] += 1
    print(f"{p['date'][:10]} {p['id']} v{version(p)} CheckPatch:{ck.get('CheckPatch','-'):<8} "
          f"GitLint:{ck.get('GitLint','-'):<8} comments[{','.join(w for w, _ in cm) or '-'}]  "
          f"{p['submitter']['name']}\n           └ {nline}")
for k, v in tally.items():
    print(f"  {k:<36} {v}")

# The other side: series NOT accepted whose only blemish was lint — what became of them
print("\nBlueZ series with a lint fail/warning, by final state:")
by = {}
for p in bluez:
    ck = checks(p["id"])
    if any(ck.get(k) in ("fail", "warning") for k in LINT):
        by[p["state"]] = by.get(p["state"], 0) + 1
print(f"  {by}")
