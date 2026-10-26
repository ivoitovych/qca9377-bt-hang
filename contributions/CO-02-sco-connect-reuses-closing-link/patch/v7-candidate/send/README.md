# CO-02 — v7 candidate: the same code as v6, the prose reworked for tired eyes (2026-10-26)

**A candidate, not the package to send.** `../../v6/send/` stays the package until the operator
picks this one, after reading it. The code is byte-identical to v6: `git diff` of the trees is
empty for the kernel commits and the BlueZ commit. Only the five messages changed.

**The code is the tested code, checked by tool (2026-10-26, the operator's request).**
`scripts/patch-code-compare.py` compares each mail's diff text and `git patch-id`;
`scripts/change-code-compare.sh` compares a whole change across trees.
- Positive control: v5 → v6 BlueZ is reported as differing, by exactly the 15-line block (`EX-078`).
- v6 → v7 kernel: identical (`EX-079`). v6 BlueZ commit (the one built and run) → v7: identical
  (`EX-080`).
- v4 → v7 kernel: identical (`EX-081`). v4 is where the emulator matrix ran; v5 to v7 changed only
  messages.
- The laptop's module (the series as one commit on Ubuntu 7.0.0-38's sources) → v7: the same
  change, with the same patch-id and the same 36 changed lines (`EX-082`). The hardware runs,
  including the patch 1 test, ran this code.

**Why:** the operator asked whether the mails read well for a tired maintainer (2026-10-26). They
were accurate, but the cover opened with the mechanism and had two 15- to 18-line paragraphs. The
six reviewers then each proposed a full rewrite. The texts here are a combination of theirs, each
sentence checked against the evidence before it was taken:
- **Cover:** reviewer 3's structure. Symptom first, one short paragraph per patch, then headed
  sections: Testing, Hardware testing, Remaining codec-switch delay, Related work, Stable and
  downstream kernels. 1,091 words against v6's 986; most of the extra length is headings and
  white space.
- **Patches 1 to 3:** reviewer 4's wording, which states the failure first. Patch 3 keeps v6's
  locking argument nearly word for word.
- **BlueZ:** v6's message plus one paragraph from reviewers 4 and 6. A new link is told apart by its
  own setup and completion even when the controller reuses the handle; true per `sco-tester.c`
  l.1674–1683. The notes below `---` are v5's, verbatim.

**Not taken, with the reason:**
- "mgmt-tester also had intermittent failures in the control runs" (reviewers 2, 4) is wrong. The
  one mgmt-tester flake was on a patched kernel: 1 in 7 full runs, 5/5 in isolation, 0 in 6 on the
  base (`../../experiments/results-2026-10-21.md`), and not in SCO code. The sentence stays v6's,
  "otherwise give the same results".
- The Shure brand in the cover (reviewers 3, 5): the mails name no headset brand.
- The `Signed-off-by` in the BlueZ message (reviewer 1): BlueZ does not use it, and v5/v6 had none.
- The 36 links now carry their dates (reviewers 4, 6). This boot has more links since: the
  Hands-free switching of 26 October and the patch 1 test. "The HCI capture of that boot" would no
  longer have been exactly true, so the sentence is scoped to 23 to 25 October, which is
  `EX-074`'s window.

**Checks on these exact files:**
- checkpatch `--strict` on patches 1 to 3, in the tree: 0/0/0. The first build had one error,
  "commit" and its hash on separate lines in patch 1; fixed by rewrapping.
- The BlueZ mail through `scripts/ci-local.sh` (am, checkpatch, gitlint) on `a0580dad5655`: PASS.
- `tmp/co02-v7prose/dry-run.sh kernel|bluez`: the same threading and recipients as v6.

Built by `tmp/co02-v7prose/make.sh` and `redo-kernel.sh`, from v6's commits in new worktrees
`cache/co02-v7-kernel` (branch `co02-send/v7-prose`) and `cache/co02-v7-bluez`
(`co02-bluez/v7-prose`). Not sent.
