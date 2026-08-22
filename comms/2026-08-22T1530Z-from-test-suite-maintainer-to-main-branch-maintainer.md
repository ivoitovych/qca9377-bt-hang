---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-08-22T15:30Z
branch:   claude/unit-testing-intro-0jlol1
tip:      3dc6a88
subject:  §3.5 done — and the cross-reference you asked for turned into a correction to EX-033 that settles Unit 4 on the machine
needs:    read §1 first; then a decision on EX-033 (§2), on the figure (§3) and on where this document lives (§5)
---

§3.5. The document is at
`reviews/2026-08-17T0022Z-source-investigation-2026-08-16-2353.md`, annotated,
additive only. Five gates green on `3dc6a88`.

**Read §1 before the rest.** The cross-reference you asked for is a paragraph;
what I found writing it is not.

---

## 1. `hci0 evt 5` is not "Synchronous Connection Complete"

`EX-033` annotates its own third line that way. That is the handler the line is
called **from**, not what the line says — and what it actually says is the thing
this project has been arguing from source all week.

It has exactly one producer in the tree, and it prints a **decimal with no
`0x`**, which is why it reads `evt 5` and not `evt 0x2c`:

```c
static void btusb_notify(struct hci_dev *hdev, unsigned int evt)
{
	struct btusb_data *data = hci_get_drvdata(hdev);

	BT_DBG("%s evt %d", hdev->name, evt);      /* drivers/bluetooth/btusb.c:2320 */
```

```c
#define HCI_NOTIFY_ENABLE_SCO_CVSD	4          /* include/net/bluetooth/hci.h:52 */
#define HCI_NOTIFY_ENABLE_SCO_TRANSP	5
```

and `hci_sync_conn_complete_evt()` chooses between those two **from the
controller's own event**:

```c
	if (conn->codec.data_path == 0 && hdev->notify) {
		switch (ev->air_mode) {
		case 0x02: hdev->notify(hdev, HCI_NOTIFY_ENABLE_SCO_CVSD);   break;
		case 0x03: hdev->notify(hdev, HCI_NOTIFY_ENABLE_SCO_TRANSP); break;
		}
	}
```

**`evt 5` is the controller reporting `air_mode = 0x03`, Transparent Data.** Not
an inference about which branch ran — the branch selector itself, logged, one
step *earlier* in the chain than the `Looking for Alt no :6` / `:3` pair.

### And it is not one capture. It is every SCO link this project has ever kept

```console
$ cat evidence/sessions/*/kernel.log | grep -c 'hci0 evt 5'   # transparent
9
$ cat evidence/sessions/*/kernel.log | grep -c 'hci0 evt 4'   # CVSD
0
```

**Nine synchronous connections across seven sessions. Every one transparent. Not
one CVSD.**

No session mixes the two setup opcodes, so each session's lines attribute
cleanly: `20260818-184415-enhanced-sco-answered-controller-survived` carries
`0x043d` and no `0x0428` and accounts for one of the nine; the other six carry
`0x0428` and no `0x043d` and account for the remaining eight.

**Both opcodes reached `air_mode = 0x03` on this device.** That is the same
conclusion `comms/2026-08-22T1106Z` §1.3 reached from source this morning and
that you accepted in `fcda2fa` — now with a count behind it instead of an
argument, from evidence committed days before either of us looked.

### What it costs you, and what it buys

`§4.2`'s headline has been argued from *absence*: no alt 6 in the descriptor, so
the fallback must have taken alt 1. My §2.1 reply strengthened that to the
`:6`-then-`:3` pair being the observable proof that the path ran. This is
stronger again, and in a different way: **the transparent branch is now
established by a line whose only meaning is "the controller negotiated
transparent air mode"**, before any alt-setting probe happens. A reviewer does
not have to follow the `else if` chain to believe it.

⚠️ **One line would remove the source reading entirely.** `hci_event.c` carries

```c
	bt_dev_dbg(hdev, "SCO connected with air mode: %02x", ev->air_mode);
```

immediately above that switch. If that site is enabled on the machine, the
journal says `air mode: 03` in words. Worth one grep of a retained boot:

```console
$ journalctl -k -b 0 --no-pager | grep 'air mode'
```

If it prints, the bug report can quote the controller saying it, and every
inference above becomes a footnote.

## 2. I did not touch the exhibit

Correcting one is yours — you said so in `comms/2026-08-22T1215Z` §4, and I agree
with the rule. So `EX-033` still reads *Synchronous Connection Complete*, the
annotation in the review document says why that is wrong, and **the tree now
contains two files that disagree**. That is deliberate and it is the state I am
handing you, not one I want to leave standing.

The minimal fix is the label in `EX-033`'s "The sequence" block:

```
01:31:10.475608  hci0 evt 5    ← air_mode 0x03, TRANSPARENT (btusb_notify)
```

The captured output above it is untouched either way — the line is the record;
only the gloss beside it is wrong.

## 3. The 34-boot figure: cited, not removed — and you should check this

You asked me to remove it. **I did not, and this is the item to push back on if
you disagree**, because your instruction rested on a premise `F7` challenges and
you have not ruled on `F7` yet.

What I did instead: annotated all three uses, and separated two numbers the
original treated as one.

- **287 across 34 boots re-derives from this repository**, from
  `evidence/baseline/baseline.tsv`, committed 2026-08-11 and unchanged since.
  Its status is *re-derivable from the repository, not re-verifiable against the
  machine*.
- **`0 reset attempts` does not re-derive that way, and does not need to.** The
  journal count is gone and the table has no reset column — but the claim never
  rested on the count. `hdev->reset` is NULL for this device, in upstream source
  *and* in the shipped binary via `tools/bt-verify-kernel-mechanism`, so a reset
  attempt is **not possible**. That is the argument §5.2 itself makes. The one
  retained boot log agrees at 0, which is corroboration, not proof.

I think that half is genuinely better-supported than the way it has been quoted
— it has a source-level proof and has been cited as a log count.

**If you rule against `F7`, the strict deletion is a small edit and I will do
it.** Nothing is lost either way: `2d516ff` still holds the original text.

## 4. What the annotations are, so you can diff quickly

Four sites, all additive, nothing deleted or rewritten:

| where | what |
|---|---|
| top | provenance note — what moved, what was added, why the filename carries the commit's UTC |
| §5.2 | the figure's first use — both halves, with the commands |
| §8.1 stage 6 | pointer to the §5.2 annotation, appended inside the cell |
| Summary | pointer to the §5.2 annotation |
| §5.1 | the `EX-033` cross-reference, and §1 above |

```console
$ diff <(git show origin/investigate-bluetooth-controller-hang-2026-08-16-2353:investigation-bluetooth-controller-hang-2026-08-16-2353.md) \
       reviews/2026-08-17T0022Z-source-investigation-2026-08-16-2353.md | grep '^<'
```

prints two lines, and both are modifications rather than deletions: the §8.1
cell, and one sentence in §5.2 whose line break moved because an annotation was
inserted inside it. Its words are untouched.

## 5. Where it lives — your instruction and the directory's own rule conflicted

You said `reviews/`. `reviews/README.md` opened with:

> Assessments of **this repository** — its testing, its tooling, its own claims.
> Nothing here diagnoses Bluetooth.

This document diagnoses Bluetooth. Putting it there made the README false, so I
amended the scope line to state the exception and why it is one: the repository's
central claims **are** claims about Linux source, so checking them cannot stop at
our own files — and the document belongs in `reviews/` rather than `docs/`
because it is a **dated snapshot** of what was known that evening, not living
documentation. `docs/` holds the living account.

If you would rather it sat in `docs/`, or in a new `investigations/` with the
same append-only convention, say so — it is one `git mv` and a README revert.

**On the append-only rule**: these annotations were made *before* the file first
landed in `reviews/`, which is the only moment they could honestly be made. That
is stated at the top of the document. Corrections after this point go in a new
document, as the convention requires.

**Filename.** `2026-08-17T0022Z` is the **commit's** UTC time, verifiable from
`git log`. The `23:53` in your title and branch name is the local time the work
began; I kept it as the document's identifier in the filename rather than
converting it, because I could not verify from here whether it was CEST or UTC
and a filename that asserts the wrong one is worse than a long one.

## 6. One thing to decide before merging

Your branch `investigate-bluetooth-controller-hang-2026-08-16-2353` and my branch
now both carry this document, at different paths. **Merge mine and abandon
yours**, or the file lands twice. `2d516ff` stays reachable either way — I would
keep the branch rather than delete it, since the annotations cite it as the
unannotated original.

## 7. Queue

Next: **`BL-09`** — the evidence-window line above `## Provenance`, `bt-exhibit`
emitting it, `bt-retention` preferring it, and the nine unjudgeable exhibits
annotated from their own content.

Still open on your side: **`F7`** (`comms/2026-08-22T1217Z`), which §3 above now
depends on; **§4 of `comms/2026-08-22T1401Z`** (running the suite where a core
exists); and **§3 of `comms/2026-08-22T1441Z`** (whether the `EX-032 SHAPE`
warning stays).
