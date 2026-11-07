#!/usr/bin/env python3
"""check-submission.py — report the live state of the X1 gvfs submission from GNOME GitLab's
public API: issues 893/894 and MRs 368/369 (state, labels, commits, pipeline, description
against the frozen drafts with the placeholders filled in, notes by others, and the uploaded
test program's SHA-256). Read-only; no login needed."""
import hashlib
import json
import sys
import urllib.request
from pathlib import Path

API = "https://gitlab.gnome.org/api/v4/projects/1618"
DRAFTS = Path("/root/exp/qca9377-bt-hang/contributions/X1-gvfs-cdda-readahead/submission-drafts.md")
UPLOAD = "/uploads/fc2a0287cabeeca50d0265b12f442889/gvfs-cdda-track-test.py"
PROGRAM_SHA = "3e52485addf56cc80d9cee923d79de84dc6f1b361b54dc9da56b4ab0f7b6e520"
ME = "ivoitovych"


def get(url, raw=False):
    # Python's default User-Agent: GNOME's GitLab answers 406 to unknown agent strings.
    with urllib.request.urlopen(url) as r:
        data = r.read()
    return data if raw else json.loads(data)


def section(heading):
    lines = DRAFTS.read_text().split("\n")
    start = lines.index(heading)
    title = next(l for l in lines[start:] if l.startswith("**Title:** "))[len("**Title:** "):]
    first = lines.index("---", start)
    second = lines.index("---", first + 1)
    return title, "\n".join(lines[first + 1:second]).strip("\n")


def fill(text):
    return (text.replace("#A", "#893").replace("#B", "#894").replace("!M1", "!368")
            .replace("(UPLOAD)", f"({UPLOAD})"))


def notes(kind, iid):
    """Comments, from the public web endpoint (the notes API needs a login)."""
    path = {"issues": "issues", "merge_requests": "merge_requests"}[kind]
    try:
        discussions = get(f"https://gitlab.gnome.org/GNOME/gvfs/-/{path}/{iid}/discussions.json")
    except Exception as e:  # report, do not hide
        return [f"    notes not readable: {e}"]
    out = []
    for d in discussions:
        for n in d.get("notes", []):
            who = (n.get("author") or {}).get("username", "?")
            body = n.get("note") or n.get("body") or ""
            when = (n.get("created_at") or "")[:16]
            if n.get("system"):
                out.append(f"    system {when}: {body[:110]}")
            elif who != ME:
                out.append(f"    COMMENT by {who} {when}: {body[:300]!r}")
            else:
                out.append(f"    own note {when}: {body[:110]!r}")
    return out


ok = True
for iid, heading in ((893, "## Issue A — playback stall"), (894, "## Issue B — invalid track names")):
    i = get(f"{API}/issues/{iid}")
    title, body = section(heading)
    same = i["title"] == title and i["description"] == fill(body)
    ok &= same and i["state"] == "opened"
    print(f"issue #{iid}: {i['state']}, confidential={i['confidential']}, labels={i['labels']}, "
          f"assignees={[a['username'] for a in i['assignees']]}, text as draft: {same}")
    print("\n".join(notes("issues", iid)) or "    no notes")

MR_QUERY = """{project(fullPath:"GNOME/gvfs"){mergeRequest(iid:"%d"){
  state draft title description sourceBranch targetBranch diffHeadSha commitCount
  detailedMergeStatus labels{nodes{title}} reviewers{nodes{username}} assignees{nodes{username}}
  headPipeline{status iid}
  notes(first:100){nodes{system body createdAt author{username}}}}}}"""


def graphql(query):
    req = urllib.request.Request("https://gitlab.gnome.org/api/graphql",
                                 data=json.dumps({"query": query}).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())["data"]


# The REST API answers anonymous MR requests with 406; GraphQL serves the public data.
for iid, heading, commit in ((368, "## MR 1 — patch 1", "98dc71aa4a7395f9568c852485ac9371f4490826"),
                             (369, "## MR 2 — patch 2", "610794dcad68b1ab61ab49d8439663e1cc091cb4")):
    m = graphql(MR_QUERY % iid)["project"]["mergeRequest"]
    title, body = section(heading)
    same = m["title"] == title and m["description"] == fill(body)
    commits_ok = m["diffHeadSha"] == commit and m["commitCount"] == 1
    pipe = m["headPipeline"]
    ok &= same and m["state"] == "opened" and commits_ok
    print(f"MR !{iid}: {m['state']}, draft={m['draft']}, {m['sourceBranch']} -> {m['targetBranch']}, "
          f"merge status={m['detailedMergeStatus']}, "
          f"labels={[l['title'] for l in m['labels']['nodes']]}, "
          f"reviewers={[r['username'] for r in m['reviewers']['nodes']]}, "
          f"assignees={[a['username'] for a in m['assignees']['nodes']]}")
    print(f"    head {m['diffHeadSha'][:7]}, {m['commitCount']} commit(s), as pushed: {commits_ok}; "
          f"pipeline {pipe['status'] + ' #' + str(pipe['iid']) if pipe else 'none'}; "
          f"text as draft: {same}")
    for n in sorted(m["notes"]["nodes"], key=lambda n: n["createdAt"]):
        who = n["author"]["username"]
        kind = "system" if n["system"] else ("own note" if who == ME else f"COMMENT by {who}")
        print(f"    {kind} {n['createdAt'][:16]}: {n['body'][:300 if kind.startswith('COMMENT') else 110]!r}")

data = get(f"https://gitlab.gnome.org/-/project/1618{UPLOAD}", raw=True)
same = hashlib.sha256(data).hexdigest() == PROGRAM_SHA
ok &= same
print(f"uploaded test program: {len(data)} bytes, identical to the tested file: {same}")
sys.exit(0 if ok else 1)
