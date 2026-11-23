# The `Fixes:` and `Cc: stable` question (2026-11-23 evening): outside answers, checked

**The question.** The operator put one focused question to the reviewers, who answered from their earlier
reviews:
- what `Fixes:` is meant to express, and whether it may be left off a correct fix whose effect is internal;
- how it interacts with automatic stable selection when there is no `Cc: stable`;
- keep, add or drop each trailer on the four packages;
- what to do with CO-26's neighbouring `MGMT_STATUS_BUSY` return.

Answers came from reviewers 1, 2 and 7. Reviewer 3's reply repeated their earlier intermediate recheck and holds
no analysis of the question. Reviewer 6 is still working. Full texts are kept privately; only the findings are
here.

## Checked facts

In `Documentation/process/stable-kernel-rules.rst` on bluetooth-next `5063a0717aa2`:
- the stable team takes the appropriate versions from `Fixes:` tags (l.122);
- AUTOSEL and "scripts that look for commits containing a 'Fixes:' tag" select changes on their own;
- the documented way to keep a change out is `Cc: <stable+noautosel@kernel.org> # reason`, and the reason must
  be present (l.133–136).

So a `Fixes:` without `Cc: stable` still makes a commit a candidate. All three reviewers say so.

In the source, `mesh_send_sync()` returns `MGMT_STATUS_BUSY` from its capacity check (l.2460–2463), before
`hci_add_adv_instance()` (l.2467). So CO-26's injected add failure never reaches that return (reviewer 7).

## Positions

| package | `Fixes:` | `Cc: stable` |
|---|---|---|
| CO-38 | keep (1, 2, 7) | **keep** (1, 2, 7) |
| CO-44 | keep (1, 2, 7) | **omit** (1, 2, 7). Reviewer 7 adds that it changes a numeric status MGMT clients may branch on, so mainline first, as with `7eac806143005` |
| CO-43 1/3 | keep (1, 2, 7) | **add** (2, 7, and 3 earlier), subject to the affected-line checks; reviewer 1 is neutral |
| CO-43 2/3, 3/3 | keep (1, 2, 7) | **omit** for this posting (1, 2, 7). If ever requested, 3/3 goes only with 2/3 |
| CO-26 | **variant A, with `Fixes: b338d91703fa`** (2, 7, and 3 earlier); variant B (1) | **omit** (1, 2, 7). `noautosel` is optional for reviewer 2; reviewer 7 sees no reason to veto a later backport |

**The `MGMT_STATUS_BUSY` return.** All three keep it out of CO-26 and leave it for later, possibly as its own
`-EBUSY` one-liner. The reason is little value now: nothing visible changes, and CO-26's test does not reach
it. Reviewer 7 notes that the command handler's own `mgmt_cmd_status(..., MGMT_STATUS_BUSY)` is in the right
status domain and stays as written.

## Outcome

- **CO-38, CO-44 and CO-43 2/3, 3/3:** the packages already carry what all answers recommend. Nothing changes.
- **CO-43 1/3:** most answers favour `Cc: stable`. Under the operator's rule it waits for the build and tests on
  all seven affected lines, which are queued.
- **CO-26:** variant A is the majority view. Choosing A or B stays the operator's call.
- **`MGMT_STATUS_BUSY`:** left out of CO-26, as recorded in its package.
