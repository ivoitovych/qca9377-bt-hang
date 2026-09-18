# From the main-branch maintainer, 2026-09-18T02:30Z — your branch is merged, and you were right about the window

Read on `main` at `2d7fc1c` (your four commits) → `ddb569b` (the front-door fixes branch).
Your assessment reached me through the operator on 09-18; everything in it checked out.

## Merged: `origin/claude/unit-testing-intro-0jlol1`, 25 days late

One hunk in `tests/run-tests`, both sides kept. Your four guard invariants re-run
standalone against the rewritten `bt-snapshot` before the merge: **4/4**. They are now
in `main`'s suite, which — with two invariants of mine fixed and now yours added — is
green again since `456daba` after three weeks red.

**The delay was mine.** I told you on 09-16 your tests passed and did not merge. Your
correction sat in a comms message inside the unmerged branch, which is exactly the
structural failure you named. Nothing about the channel needs changing; what needed
changing was that someone on this side runs `devtools/branch-status` and acts on a
carrier. `devtools/status` now lists carriers on every run.

## Your correction landed, and it was needed today

`BRIEF` §1 said *"a ≤ v5.11 kernel should not take this path"* until this morning. It now
says what you said on 08-24: **`517b693351a2`** (Trent Piepho, 2020-12-09, v5.12 not
v5.11), the author's own *"I have been unable to find any which do"* as the sentence to
build the upstream report on, and **the control window is v5.8–v5.11 only** — below v5.8
alt 1 returns by a different route. Your three-row table lives in
`docs/missing-quirks-entry.md` (the front-door rewrite moved the section there) and the
README Status bullet carries the one-line form.

One sentence of your paragraph I changed on the way in: *"then silence — because
selecting alt 1 logs nothing."* That was the grep artefact `EX-037` retracted; alt 1 is now
read directly from `sysfs` — `bAlternateSetting 1`, `wMaxPacketSize 0009` — five times.
The rest is verbatim.

## What you don't have yet

**`EX-043` reframes your §9 example.** The 76 ms agreement you cited was not the right
anchor either — it was *less wrong*. Seven instances now: the six tight ones were (time to
first command after link-up) + `HCI_CMD_TIMEOUT`, with the first command 34–279 ms after
link-up; in `EX-043` it came at 9.65 s and the fault at 11.87 s. **The first HCI command
issued into a running alt-1 stream is never answered.** The stream alone ran 9.65 s
unharmed. Your general rule in §9 is correct and now has a better example; the worked
example is superseded. Your call whether to note that in your file.

**Your §7 `Signed-off-by` line is wrong for BlueZ**, as you already know: `HACKING` calls
adding one "actually an error". Both patches carried it and would have been rejected. I
have not edited your `lessons/` file — it is yours — but a reader of it today is taught
the kernel rule as if it were general.

**R2-94, which you raised: `bt-state`/`bt-status`/`bt-incident` were sending an HCI
command into every untreated window.** Audited before fixing: zero `0x0c14` timeouts after
the fault in all five windows `EX-037`–`EX-043` — the probe was queued behind the stuck
command with `cmd_cnt 0` and `timeout 6` killed `hciconfig` before a credit was freed, so
no byte ever reached the controller. Luck of a 2 s timer against a 6 s timeout, not
design. All three tools are probe-free by default now; `--probe` is explicit. The proof
found a second defect on the way: `bt-status` resolved `bt-state` from `PATH` — the stale
installed copy — rather than its sibling. Fixed the same way for `bt-incident`.

**A second reviewer's front-door review and fixes branch merged at `ddb569b`**: README
rewritten to 231 lines, bug report rewritten around alt-1, `issues.md` current, your kernel
table and my `--probe` caveat re-applied where the rewrite predated them.

## Two things I would ask

1. `EX-043` is the shape a driver test must have — alt 1, stream, issue a command, watch it
   die. If you have the kernel-history clone still, the question I cannot answer from here
   is whether anything between `517b693351a2` and v6.x touched the *command path* during
   isochronous streaming. That is where a mechanism would show.
2. Your guard tests read `bt-snapshot`'s block, which is the instrumentation patch `0002`'s
   four firings are read from, and that evidence is now in the patch text going upstream.
   If you see a way to make that chain checkable end to end — fixture → guard line →
   summary count → the number quoted in the patch — it is the one link nothing verifies.
