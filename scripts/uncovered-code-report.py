#!/usr/bin/env python3
"""uncovered-code-report.py <repo> <commit> <uncov-dir> <out.md> <stamp> — the uncovered-code report.

<uncov-dir> holds the six outputs, each run in <repo> at <commit>: bash-table.txt and bash-uncov.txt
(devtools/coverage, then with --uncovered), awk-table.txt and awk-uncov.txt (devtools/awk-coverage),
py-table.txt and py-uncov.txt (devtools/py-coverage). <stamp> is YYYYMMDD-HHMMSS (UTC). Its prose
states the suite and the figures as they were on 2026-11-08: read it before reusing it.

Every listing comes from the instruments' own output (devtools/coverage, awk-coverage,
py-coverage, each with --uncovered) and the files' contents at <commit>."""
import os, re, subprocess, sys
from collections import defaultdict, OrderedDict

REPO, COMMIT, U, OUT, STAMP = sys.argv[1:6]
BLOB = f"https://github.com/ivoitovych/qca9377-bt-hang/blob/{COMMIT}"


def show(path):
    r = subprocess.run(["git", "-C", REPO, "show", f"{COMMIT}:{path}"],
                       capture_output=True, text=True, errors="replace")
    return r.stdout.split("\n") if r.returncode == 0 else None


def rel(p):
    root = os.path.abspath(REPO) + "/"
    return p[len(root):] if p.startswith(root) else p


# ── bash: the per-file table and the uncovered lines ─────────────────────────
table = {}
for line in open(f"{U}/bash-table.txt", encoding="utf-8"):
    m = re.match(r"^\s+([0-9.]+)%\s+(\d+)/(\d+)\s+(\S+)", line)
    if m:
        table[m.group(4)] = (float(m.group(1)), int(m.group(2)), int(m.group(3)))
btotal = re.search(r"TOTAL: ([0-9.]+)% \((\d+) of (\d+)", open(f"{U}/bash-table.txt").read())

uncov = OrderedDict()
cur = None
for line in open(f"{U}/bash-uncov.txt", encoding="utf-8"):
    line = line.rstrip("\n")
    if not line or line.startswith(("out of scope", "running ")):
        continue
    m = re.match(r"^\s+(\d+)  ", line)
    if m and cur:
        uncov[cur].append(int(m.group(1)))
    elif not line.startswith(" "):
        cur = line.strip(); uncov.setdefault(cur, [])

# ── python ──────────────────────────────────────────────────────────────────
ptable, puncov, cur = {}, OrderedDict(), None
for line in open(f"{U}/py-table.txt", encoding="utf-8"):
    m = re.match(r"^\s+([0-9.]+)%\s+(\d+)/(\d+)\s+(\S+)", line)
    if m:
        ptable[rel(m.group(4))] = (float(m.group(1)), int(m.group(2)), int(m.group(3)))
ptotal = re.search(r"TOTAL: ([0-9.]+)% \((\d+) of (\d+)", open(f"{U}/py-table.txt").read())
for line in open(f"{U}/py-uncov.txt", encoding="utf-8"):
    line = line.rstrip("\n")
    if not line or line.startswith(("out of scope", "running ")):
        continue
    m = re.match(r"^\s+(\d+)  ", line)
    if m and cur:
        puncov[cur].append(int(m.group(1)))
    elif not line.startswith(" "):
        cur = rel(line.strip()); puncov.setdefault(cur, [])

# ── awk ─────────────────────────────────────────────────────────────────────
atotal = re.search(r"TOTAL: ([0-9.]+)% \((\d+) of (\d+)", open(f"{U}/awk-table.txt").read())
aprogs, cur = [], None
for line in open(f"{U}/awk-uncov.txt", encoding="utf-8"):
    line = line.rstrip("\n")
    if line.startswith("program "):
        cur = [line[len("program "):], []]; aprogs.append(cur)
    elif line.startswith("    ") and cur:
        cur[1].append(line[4:])

# ── bare case labels: counted by devtools/coverage, never traced by bash ──────
TOK = r"""(?:[^\s()|;&<>`$"']|"[^"]*"|'[^']*')+"""
LABEL = re.compile(r"^\s*\(?\s*" + TOK + r"(?:\s*\|\s*" + TOK + r")*\s*\)\s*(?:#.*)?$")
SRC = {}


def src_of(path):
    if path not in SRC:
        SRC[path] = show(path)
    return SRC[path]


def is_label(path, n):
    src = src_of(path)
    return bool(src) and 0 < n <= len(src) and bool(LABEL.match(src[n - 1]))


LABELS = defaultdict(list)
for p, l in uncov.items():
    for n in sorted(set(l)):
        if is_label(p, n):
            LABELS[p].append(n)
NLABEL = sum(len(v) for v in LABELS.values())

# ── the listing of one file ─────────────────────────────────────────────────
def blocks(lines, gap=3):
    out = []
    for n in sorted(set(lines)):
        if out and n - out[-1][-1] <= gap:
            out[-1].append(n)
        else:
            out.append([n])
    return out


def listing(path, lines, stats, kind="bash"):
    src = show(path)
    pct, cov, tot = stats if stats else (None, None, None)
    nl = len(LABELS.get(path, [])) if kind == "bash" else 0
    head = f"#### [`{path}`]({BLOB}/{path}) — {len(set(lines))} uncovered"
    if nl:
        head += f" ({nl} of them bare `case` labels, not shown)"
    if tot:
        head += f" of {tot} coverable lines ({pct:.1f}% run)"
    w = [head, ""]
    if src is None:
        return w + ["(file not readable at this commit)", ""]
    miss = set(lines)
    for b in blocks(lines):
        if kind == "bash" and all(is_label(path, n) for n in b):
            continue
        lo, hi = max(1, b[0] - 1), min(len(src), b[-1] + 1)
        w.append(f"[lines {b[0]}–{b[-1]}]({BLOB}/{path}#L{b[0]}-L{b[-1]})")
        w.append("```" + ("python" if kind == "python" else "bash"))
        for n in range(lo, hi + 1):
            mark = "»" if n in miss else " "
            w.append(f"{mark}{n:5d} │ {src[n - 1]}")
        w.append("```")
    w.append("")
    return w


def group(pred):
    return [(p, l) for p, l in uncov.items() if l and pred(p)
            and not all(is_label(p, n) for n in l)]


SHIPPED = lambda p: p.startswith(("bin/", "tools/")) or p in ("install.sh", "uninstall.sh")
DEVTOOLS = lambda p: p.startswith("devtools/")
SUITE = lambda p: p.startswith("tests/")
RECORDS = lambda p: p.startswith(("results/", "evidence/"))


def area_stats(pred):
    c = t = 0
    for p, (pct, cv, tt) in table.items():
        if pred(p):
            c += cv; t += tt
    return c, t


def nuncov(pred):
    return sum(len(set(l)) for p, l in uncov.items() if pred(p))


rows = []
for name, pred in (("Shipped tools: `bin/`, `tools/`, `install.sh`, `uninstall.sh`", SHIPPED),
                   ("`devtools/`: instruments, repository tools, standalone scripts", DEVTOOLS),
                   ("`tests/`: the suite's own file and its helpers", SUITE),
                   ("`results/`, `evidence/`: experiment records", RECORDS)):
    c, t = area_stats(pred)
    nlab = sum(len(v) for p, v in LABELS.items() if pred(p))
    rows.append(f"| {name} | {c} of {t} | {100 * c / t if t else 0:.1f}% | {nuncov(pred)} | {nlab} |")

L = []
A = L.append
A(f"""# Report: the code the test suite never runs, for outside reviewers' coverage ideas

```
date:     {STAMP[:4]}-{STAMP[4:6]}-{STAMP[6:8]}T{STAMP[9:11]}:{STAMP[11:13]}Z
commit:   {COMMIT} (every line number below is at this commit)
from:     the test-suite maintainer
purpose:  every uncovered line, statement and branch the three coverage instruments report,
          with the context a reviewer needs to propose a test for it, or to argue it should not
          be counted; the answers go into the suite test-first
source:   devtools/coverage, devtools/awk-coverage and devtools/py-coverage, each run twice
          on this commit: once for its table (all 1115 checks held in each of those runs), once
          with --uncovered for its list; the code shown is read from the commit itself
```

## 1. What we ask of you

For each block below, or for any group of blocks that one test would cover, tell us:

1. **Reachable?** Can the suite reach it at all, given the rules in section 2? If not, why not
   (dead code, a branch only the real machine can take, a defensive check that cannot fire).
2. **The test.** How to drive it: which seam (an environment variable the tool reads), which stub
   on `PATH`, which fixture or input, and what the tool must print or exit with.
3. **Red for the right reason.** What breaking the code would make the test fail, so that the
   test is shown failing before it is trusted.
4. **Or the exclusion.** If a line should not be counted, the reason, in the form of section 10.
5. **Or the bug.** If reading a block shows a defect, say so first: that matters more than the
   line.

A short form is enough:

```
<file>:<lines> — reachable: yes|no|only on the machine — test: <seam, stub, input> → <expected>
                — red if: <the change that must make it fail> — confidence: high|medium|low
```

Please quote file and line numbers as this commit has them. Ideas for whole families of lines
(section 3) are as welcome as single tests.

## 2. The suite, and what a test may and may not do

The project investigates a Bluetooth controller that hangs on one laptop: shell, awk and
Python tools that watch, record and classify what the controller and the kernel do, and a
"trial" opened at each boot and closed at shutdown, which writes one results row. The tools
run on that laptop, the investigation machine, while a live experiment runs on it.

`tests/run-tests` is the whole suite: one bash file of about 15,500 lines, a setup and about
fifty sections, run in parallel (one worker per core) or `--serial`. What a test may do:

- **Run a tool from the checkout**, with its seams set: environment variables naming every
  machine path a tool reads or writes (`BT_HEALTH_DIR`, `BT_TRIAL_STATE_DIR`, the sysfs and
  usbfs roots, `BT_JOURNAL_DIR` and about thirty more; `tests/system-resources.md` lists them).
  Every seam whose default is a machine path is declared into an empty "declared machine" for
  the whole run.
- **Stub a machine tool on `PATH`**: `journalctl`, `btmon`, `systemctl`, `bluetoothctl`,
  `btmgmt`, `hciconfig` and the rest (`tests/machine-tools`, 51 of them). Unstubbed, each
  resolves to a tripwire that records the call and fails the run.
- **Use fixtures**: captured journal shapes (`tests/journal/`), real `btmon` output
  (`tests/btmon/`), and a renderer that prints as the real `btmon` 5.72 does
  (`tests/btmon/render`).
- **Build a namespace world** where the host allows unprivileged user namespaces: one for
  `bt-ui-capture`'s shipped defaults, one for the checkout (`devtools/held`, `save`,
  `review-open` run in an overlay of the checkout with no network).

What a test may not do:

- **Touch the real machine**: no real journal, no real Bluetooth, no real `/sys`, `/etc` or
  `/usr/local`, no network. The run proves it: a tripwire on every machine tool, footprints of
  the system binaries, the project's installed files, the tracked files and the real trial
  state, before and after; an access audit (`devtools/access-audit`) traces every file access
  of the whole suite under `strace`.
- **Depend on the host**: it must give the same verdict in CI (GitHub's ubuntu-24.04 runners)
  and on the laptop. A branch only some hosts can take is reported NOT ASKED by name, never
  counted as a pass.
- **Be trusted before it has failed**: every new check is first seen red against the unfixed
  or broken code.

## 3. How coverage is measured, and what the figures hide

- **bash**: `devtools/coverage` runs the suite with `BASH_ENV` turning on `xtrace` with a
  tagged `PS4` in every bash it starts, and counts the lines that ran against the coverable
  lines of every shipped shell file. Floor 80% (CI).
- **awk**: `devtools/awk-coverage`, statement coverage under `gawk --profile`, for the awk
  libraries in `tools/lib/` and the inline awk programs in the tools. Floor 95%.
- **Python**: `devtools/py-coverage`, line coverage of the shipped Python. Floor 80%.

| | lines run | of | uncovered |
|---|---|---|---|
| bash | {btotal.group(2)} | {btotal.group(3)} ({btotal.group(1)}%) | {int(btotal.group(3)) - int(btotal.group(2))} |
| awk (statements) | {atotal.group(2)} | {atotal.group(3)} ({atotal.group(1)}%) | {int(atotal.group(3)) - int(atotal.group(2))} |
| Python | {ptotal.group(2)} | {ptotal.group(3)} ({ptotal.group(1)}%) | {int(ptotal.group(3)) - int(ptotal.group(2))} |

The bash total of {btotal.group(1)}% is an average over very different kinds of code:

| area | lines run | coverage | uncovered | of which bare `case` labels |
|---|---|---|---|---|""")
L.extend(rows)
A(f"""
What that table says, and the families of lines it points to:

- **Bare `case` labels are counted but can never run.** A line holding only a pattern, such as
  `start)` or `*"failed: -110"*)`, is never traced by bash, so `devtools/coverage` counts it
  uncovered whether its branch ran or not (it says so itself: its figures are a lower bound).
  There are {NLABEL} of them. The listings below leave them out: a branch that never ran shows
  through its body's lines, which are listed. Appendix A names every label left out. The
  instrument will stop counting them, test-first; you need not propose anything for them.
- **A command over several lines is traced at its first line only**, so the rest of a long
  quoted message or a multi-line condition shows uncovered when the command did run. Where a
  block's first line is unmarked and only its later lines are, that is the reason.

- **The shipped tools are at about 94.5%.** Section 4 lists their uncovered lines one block at a
  time; they are the most valuable to cover, since they run on the investigation machine.
- **The instruments cannot measure themselves from inside the suite.** `devtools/coverage`,
  `awk-coverage`, `py-coverage` and `test-comprehension` run the suite; the suite runs them
  only against a toy suite with a hand-counted answer, so their paths for the real suite, the
  floors and the failure reports, show as uncovered. Ideas for driving more of them against a
  toy suite are welcome.
- **Standalone scripts at 0%**: `devtools/test-bt-journal-files.sh`, `test-journal-fast.sh`,
  `hooks/test-pre-push.sh` and `journal-speed/bench*.sh` are run by hand, never by the suite.
  Whether each should move into the suite, leave coverage's scope or be retired is being asked
  of the project's maintainers; listing them here is for completeness.
- **`results/` and `evidence/`** hold the scripts of finished experiments, records rather than
  tools. Python coverage leaves `results/` out of scope; bash coverage still counts it. That
  inconsistency is ours to fix, not yours.
- **The suite's own uncovered lines** (`tests/run-tests`) are mostly paths a green run does not
  take: skip branches for hosts without a namespace or a tool, multi-line failure messages, and
  helpers used only on the laptop. Its single-line failure branches are already excluded
  (section 10). Ideas there are about which of those paths a test could drive on purpose.

Known gaps you need not spend time on (already found, being closed):

- `tools/lib/journal.sh` is sourced, not run, so bash coverage counts none of it at all, and
  its fast kernel path (`bt_journal_kernel_fast`) is switched off in the suite
  (`BT_JOURNAL_DIR` declared absent). A test against a journal built with
  `systemd-journal-remote` is planned.
- `devtools/hooks/pre-push`, the publish gate on every push, has no test in the suite.
- Without `zstd`, the `bt-journal-files` section runs only its refusal and says so inside a
  passing check, instead of reporting the copy cases NOT ASKED.

## 4. The shipped tools, block by block

`»` marks a line that never ran; the unmarked lines around it are context, and may have run.
""")
for p, l in group(SHIPPED):
    L.extend(listing(p, l, table.get(p)))


def collapsed(title, items, intro):
    A(f"<details><summary>{title}</summary>\n")
    A(intro + "\n")
    for p, l in items:
        L.extend(listing(p, l, table.get(p)))
    A("</details>\n")


A("## 5. `devtools/`: the instruments and the repository's own tools\n")
collapsed(f"{nuncov(DEVTOOLS)} uncovered lines in {len(group(DEVTOOLS))} files (expand)", group(DEVTOOLS),
          "The tools that run the suite (the instruments) show only what their toy-suite checks "
          "reach; the standalone scripts show at 0% (section 3).")
A("## 6. `tests/`: the suite's own file and its helpers\n")
collapsed(f"{nuncov(SUITE)} uncovered lines in {len(group(SUITE))} files (expand)", group(SUITE),
          "Paths a green run does not take (section 3). `tests/btmon/render` is the renderer the "
          "`btmon` stubs print through.")
A("## 7. `results/` and `evidence/`: experiment records\n")
collapsed(f"{nuncov(RECORDS)} uncovered lines in {len(group(RECORDS))} files (expand)", group(RECORDS),
          "Scripts of finished experiments; whether bash coverage should count them at all is "
          "the question here (section 3).")

A("## 8. awk: the statements that never ran\n")
A("Programs are named as `devtools/awk-coverage` names them: `lib:<file>:<function>` for the "
  "libraries in `tools/lib/`, `prog:<file>#<hash>` for an awk program written inline in that "
  "file (search the file for the statement to find it). Statements, not lines: gawk's profile "
  "does not keep line numbers.\n")
for name, stmts in aprogs:
    A(f"- `{name}`")
    for s in stmts:
        A(f"    - `{s.strip()}`")
A("")
A("## 9. Python: the lines that never ran\n")
A("| file | lines run | coverage |\n|---|---|---|")
for p, (pct, c, t) in ptable.items():
    A(f"| `{p}` | {c} of {t} | {pct:.1f}% |")
A("")
for p, l in puncov.items():
    if l:
        L.extend(listing(p, l, ptable.get(p), kind="python"))

A("## 10. What coverage does not count, and why (`devtools/coverage-exclude`)\n")
A("Each exclusion is derived by content and checked on every run: an exclusion that matches "
  "nothing, or hides a line that ran, fails the gate. Challenge any of them.\n")
A("```")
for line in show("devtools/coverage-exclude"):
    if line.strip() and not line.startswith("#"):
        A(line)
A("```")
A("")
A("Out of scope, as not shipped: for bash coverage `scripts/`, `retest/`, `patches/`, "
  "`docs/mesh-tester-ci/` and `contributions/`; for Python coverage `scripts/`, `retest/`, "
  "`patches/`, `contributions/` and `results/`.")
A("## Appendix A. The bare `case` labels left out of the listings\n")
A("File and line, at this commit; each is a pattern-only line that bash never traces.\n")
for p in sorted(LABELS):
    A(f"- `{p}`: " + ", ".join(str(n) for n in LABELS[p]))
A("")
open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print(OUT, len(L), "lines")
