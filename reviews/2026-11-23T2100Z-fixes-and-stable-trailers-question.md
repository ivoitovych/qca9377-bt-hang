# The `Fixes:` and `Cc: stable` question (2026-11-23 evening): outside answers, checked

**The question.** The operator put one focused question to the reviewers, who answered from their earlier
reviews:
- what `Fixes:` is meant to express, and whether it may be left off a correct fix whose effect is internal;
- how it interacts with automatic stable selection when there is no `Cc: stable`;
- keep, add or drop each trailer on the four packages;
- what to do with CO-26's neighbouring `MGMT_STATUS_BUSY` return.

Answers came from reviewers 1, 2, 3 and 7. Reviewer 3's first reply repeated their earlier intermediate recheck;
their analysis followed and is included. Reviewer 6 is still working. Full texts are kept privately; only the findings are
here.

## Checked facts

In `Documentation/process/stable-kernel-rules.rst` on bluetooth-next `5063a0717aa2`:
- the stable team takes the appropriate versions from `Fixes:` tags (l.122);
- AUTOSEL and "scripts that look for commits containing a 'Fixes:' tag" select changes on their own;
- the documented way to keep a change out is `Cc: <stable+noautosel@kernel.org> # reason`, and the reason must
  be present (l.133–136).

So a `Fixes:` without `Cc: stable` still makes a commit a candidate. All four reviewers say so.

Bluetooth practice. Reviewer 3 counted 6 of the latest 50 November `Fixes:` commits in bluetooth-next that also
carry `Cc: stable`, and the count holds. This is `git log --since=2026-11-01 --grep='^Fixes:'`, with and
without `--grep='^Cc: stable' --all-match`, on `net/bluetooth`, `drivers/bluetooth` and
`include/net/bluetooth`. Over the whole month it is 14 of about 100. A `Fixes:` with no stable tag is the
usual form.

The `MGMT_STATUS_BUSY` return was already in `mesh_send_sync()` in `b338d91703fa` (`mgmt.c` l.2266 there),
as reviewer 3 says.

In the source, `mesh_send_sync()` returns `MGMT_STATUS_BUSY` from its capacity check (l.2460–2463), before
`hci_add_adv_instance()` (l.2467). So CO-26's injected add failure never reaches that return (reviewer 7).

## Positions

| package | `Fixes:` | `Cc: stable` |
|---|---|---|
| CO-38 | keep (1, 2, 3, 7) | **keep** (1, 2, 3, 7) |
| CO-44 | keep (1, 2, 3, 7). Reviewer 3: `161510ccf91c` is right even though the mapping is older, because that commit routed the synchronous commands through it | **omit** (1, 2, 3, 7). Reviewer 7 adds that it changes a numeric status MGMT clients may branch on, so mainline first, as with `7eac806143005` |
| CO-43 1/3 | keep (1, 2, 3, 7) | **add** (2, 3, 7), subject to the affected-line checks; reviewer 1 is neutral |
| CO-43 2/3, 3/3 | keep (1, 2, 3, 7) | **omit** for this posting (1, 2, 3, 7). If ever requested, 3/3 goes only with 2/3 |
| CO-26 | **variant A, with `Fixes: b338d91703fa`** (2, 3, 7); variant B (1) | **omit** (1, 2, 3, 7). `noautosel` is optional for reviewer 2; reviewers 3 and 7 would not use it without a positive reason against a backport |

**The `MGMT_STATUS_BUSY` return.** All four keep it out of CO-26. Reviewers 1, 2 and 7 would leave it for later,
because nothing visible changes and CO-26's test does not reach it. Reviewer 3 would send it after CO-26 as its
own one-liner, "Bluetooth: MGMT: Return -EBUSY from mesh_send_sync()", with `Fixes: b338d91703fa` and no stable
tag. Reviewer 7 notes that the command handler's own `mgmt_cmd_status(..., MGMT_STATUS_BUSY)` is in the right
status domain and stays as written.

## Reviewer 6's answer, and the measurement it rests on

Reviewer 6 answered last and reversed their earlier vote for variant B. Their reason was a measurement: of the
mainline Bluetooth commits after v7.3, the 21 with `Cc: stable` gave 13 backports in 7.3.5, the 87 with
`Fixes:` only gave 2, and the 79 with neither gave 1. They concluded that `Fixes:` alone almost never leads to
a backport in this subsystem. They also noted that AUTOSEL can lag by weeks.

**Rechecked** with `tmp/kernel-queue-20261123/fixes-only-backports.py` on the same set:
- mainline `v7.3..origin/master`, Bluetooth paths, committer date 2026-10-01 to 2026-11-23, no merges: 21, 87 and
  79 commits;
- a backport counts if a stable commit names the upstream SHA in either form, "commit … upstream" or
  "[ Upstream commit … ]".

| line | `Cc: stable` (21) | `Fixes:` only (87) | neither (79) |
|---|---|---|---|
| 7.3.5 (`988117cc1bb1`) | 13 | 2 | 1 |
| 7.3.6 (released 2026-11-23) | 14 | **36** | 12 |
| 6.18.65 | 14 | **24** | 4 |

Their numbers are exact for 7.3.5, but the conclusion does not hold once 7.3.6 is in. That release took a
batch the stable team chose itself, for example `878dd63b2828`, from `32d86e048d8e`, a `Fixes:`-only commit
carrying Sasha Levin's sign-off. So in this subsystem `Fixes:` alone does lead to backports, weeks later.

**For the packages:**
- CO-44 and CO-26 without `Cc: stable` can still reach stable through this selection.
- Only `Cc: <stable+noautosel@kernel.org> # reason` keeps a commit out. Whether to use it on CO-44 is the
  operator's decision.
- Since the stable team may take both anyway, testing them on the affected lines is worth having.

Reviewer 6's other points:
- CO-38 keep both trailers; CO-44 `Fixes:` only; CO-26 variant A. These agree with the others.
- CO-43: `Fixes:` on all three and no `Cc: stable` on any at submission. 1/3 qualifies on merit, but they
  would send tested backports after it lands, because the stable lines still have `btusb.c`.
  - Checked: 1/3 applies on all seven stable tips with the rename handled as a cherry-pick does.
  - 7.3.6 already has `btusb_main.c`.
  - So it is three for `Cc: stable` on 1/3 against one for a later backport mail, with one neutral.
- CO-26 message: "cleanup" contradicts a `Fixes:` tag. **Fixed** in variant A, which now reads "this fixes the
  error path without changing what a client sees". checkpatch is unchanged.
- The BUSY return: fold it into CO-26 as a second hunk, under a title such as "Fix the error returns of
  mesh_send_sync()". The other four keep it out. Folding would also need a run of the busy path, which no
  evidence covers yet.

## Outcome

- **CO-38, CO-44 and CO-43 2/3, 3/3:** the packages already carry what all answers recommend. Nothing changes.
- **CO-43 1/3:** three of five answers favour `Cc: stable`, one a backport mail after it lands, one is neutral. Under the operator's rule it waits for the build and tests on
  all seven affected lines, which are queued.
- **CO-26:** variant A is the view of four of five (reviewer 6 changed sides). Choosing A or B stays the operator's call.
- **`MGMT_STATUS_BUSY`:** left out of CO-26, as recorded in its package.
