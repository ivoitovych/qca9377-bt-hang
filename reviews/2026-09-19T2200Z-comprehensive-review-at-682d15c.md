# Comprehensive review at `682d15c` — verification and disposition, 2026-09-19T22:00Z

**Source.** An independent reviewer's source-and-evidence review of the whole repository at
`682d15c`, with local execution of the suite and isolated reproductions, against BlueZ
`ebbb4ee3` and Linux master `40288c92` plus `v7.0`. Verbatim copy:
[`2026-09-19T2200Z-comprehensive-review-at-682d15c-verbatim.md`](2026-09-19T2200Z-comprehensive-review-at-682d15c-verbatim.md).
Eleven findings `DR-01`…`DR-11` and a §5 on tests. Register: `reviews/README.md` §DR.

**Verdict as given.** The two BlueZ changes remain credible, narrowly scoped fixes (they had
been mailed two hours before the review arrived). The controller investigation's causal
narrative "is stronger than the evidence establishes", its upstream baseline "is stale in a
consequential way", and several tools "can still corrupt the interpretation, preservation, or
publication status of evidence".

**What this side did with it.** The two high-priority narrative findings were verified
against the kernel source and are **correct**; the record is corrected in every place that
carried the wrong statements. Five of the seven tooling findings are fixed with behavioural
tests, each proven standalone (`scripts/prove-dr-review.sh`) because an open trial keeps the
suite closed on this machine; CI runs the suite. Two tooling findings (DR-10, DR-11) are open
with their shape recorded. One closure in the R2 disposition (R2-88) was wrong and is
reopened here.

## DR-01 — the quirks entry exists upstream: confirmed, record corrected

```console
$ gh api repos/torvalds/linux/commits/dc16388d45ecbd3be0d8c9424dbbaa2c81806578 --jq '.sha[0:12] + "  author " + .commit.author.date + "  committed " + .commit.committer.date'
dc16388d45ec  author 2026-06-29T20:34:20Z  committed 2026-08-07T16:33:20Z
$ gh api -H 'Accept: application/vnd.github.raw' repos/torvalds/linux/contents/drivers/bluetooth/btusb.c | grep -n -A1 "0x13d3, 0x3503"
311:	{ USB_DEVICE(0x13d3, 0x3503), .driver_info = BTUSB_QCA_ROME |
312-						     BTUSB_WIDEBAND_SPEECH },
$ grep -c "0x13d3, 0x3503" cache/linux/drivers/bluetooth/btusb.c        # v7.0
0
$ for r in linux-6.12.y linux-6.6.y; do gh api … "contents/drivers/bluetooth/btusb.c?ref=$r" | grep -c "0x13d3, 0x3503"; done
0
0
```

"Bluetooth: btusb: Add IMC Networks QCA9377 to quirks table" (Tibor Harcsa), for a BLE
scanning failure; its descriptor dump lists alternate settings 1–5 (9/17/25/33/49 bytes) and
no 6 — this device's shape. In master; absent from `v7.0` (the running kernel's base) and
from the 6.6 and 6.12 stable heads. Every present-tense "matches no quirks entry" in the
record is now version-qualified and names the commit: BRIEF §1/§3, README, `docs/bug-report.md`,
`docs/issues.md` BT-3 (retitled "was absent … added upstream 2026-08-07"),
`docs/missing-quirks-entry.md` (superseded banner). The setup/reset path the entry installs is
recorded as **untested here**; testing a build that carries it is the review's item 5 and is
the operator's call (it means a kernel build on the family laptop).

## DR-02 — `len 27 mtu 9` is a split, not an overflow: confirmed, record corrected

```console
$ grep -n -A9 "^static inline void __fill_isoc_descriptor(" cache/linux/drivers/bluetooth/btusb.c
1734:static inline void __fill_isoc_descriptor(struct urb *urb, int len, int mtu)
1736-	int i, offset = 0;
1738-	BT_DBG("len %d mtu %d", len, mtu);
1740-	for (i = 0; i < BTUSB_MAX_ISOC_FRAMES && len >= mtu;
1741-					i++, offset += mtu, len -= mtu) {
1742-		urb->iso_frame_desc[i].offset = offset;
1743-		urb->iso_frame_desc[i].length = mtu;
```

A 27-byte buffer becomes three 9-byte isochronous packets; nothing oversized reaches the
endpoint, and the debug line is that split, logged once per buffer. The observation
(alternate setting 1, 9-byte endpoint, sustained traffic before every death) stands; the
"do not fit" inference is withdrawn in BRIEF §1/§2, README, the bug report, `docs/issues.md`,
`tools/bt-fault-window`, `tools/bt-usbstate`, `tools/bt-snapshot`, and by correction blocks
on `EX-033` and `EX-037` (exhibits are not edited). BRIEF §5 gains no row because the
retraction is carried inline where each statement was; the review file is the record.

## DR-03 / DR-04 — causal wording: adopted

"The first HCI command into a running alt-1 stream is never answered … a command into it
does [wedge the controller]" → "the first HCI command observed after the stream starts gets
no response; whether it wedges the controller or discovers one the stream already wedged is
not established; both named dying commands are Disconnect". "No software recovery exists" →
"every tested recovery failed". The claim that `517b693351a2`'s author's sentence is
"falsified" by this hardware → the fallback *applies* to this hardware (alts 1–5, no 6);
compatibility is the question. In BRIEF, README, the bug report, `docs/issues.md`.

## DR-05 … DR-09 — tooling: fixed, with tests

| ID | fix | test |
|---|---|---|
| DR-05 | `bin/bt-capture`: rotation checks `prune()`'s result and stops with an error instead of opening the next file; `AF_BLUETOOTH` absent → `OSError`, not `AttributeError` | `run-tests` drives `main()` with `prune()` answering `[True, False]` via a file-fed monitor: rc 1, one capture, the error logged; and `open_monitor()` on a Python with the attribute removed |
| DR-06 | `tools/bt-incident`: per-file sanitiser exit status tracked; manifest `sanitised=FAILED:<files>`; exit non-zero; `BT_SANITIZER` seam | failing stub → `FAILED:` and rc ≠ 0; passing stub → `yes` and rc 0 |
| DR-07 | `tools/bt-trial`: `autostop` classifies from the journal (any command timeout since the trial opened → hang) and sends nothing; the closer skips its liveness probe **and** its "responds afterwards" probe under `BT_TRIAL_PASSIVE` (recorded `unprobed`); `BT_TRIAL_PROBE=1` restores the probe as a deliberate act. `abort` refuses when the directory holds tracked files. `systemd/bt-trial-auto.service`: `TimeoutStopSec=30`. **And `bin/bt-mark`**, which the closer calls, probed on every mark — the spy found it as the last command leaving at shutdown; now `responds=unprobed` by default, `--probe` opt-in | hciconfig spy: zero calls on both passive paths; probe mode calls it; tracked abort refused with the trial kept open, then discards once untracked; `bt-mark` default vs `--probe`. The two tests that pinned the old behaviour are replaced and say why. The trial harness now puts the checkout's `bt-mark`/`bt-state` first on PATH, so the suite tests the chain it ships rather than the machine's deployment |
| DR-08 | `uninstall.sh`: removes each file's `.disabled` sibling | staged root with the three `.disabled` files → all gone, `UNINSTALL COMPLETE` |
| DR-09 | `tools/bt-usbstate`: resolves by `BT_VID:BT_PID` over the sysfs root, as `bt-mode` does; `BT_USB_PATH` is an explicit override; two matches refused; a wrong configured path is rc 2 and says so, distinct from stage 2 | device at `1-2` found; none → stage 2 by VID:PID; `BT_USB_PATH=9-9` → rc 2; two matches → rc 2 |

**Deployment note.** These are tool changes in the checkout. The machine runs the installed
copies until `sudo ./install.sh --tools-only` is run; for `bt-trial` that changes what happens
at every shutdown (no probe), which is the operator's decision BL-08 of 2026-08-22 finally
reaching the code. Not deployed by this commit.

## DR-09, and a wrong closure

The R2 disposition of 2026-09-19T15:00Z marked R2-88 (`bt-usbstate` port baked in) **done**
on the evidence `grep -c 'idVendor|BT_VID' tools/bt-usbstate` → 1. That counted a printed
attribute, not target resolution; the review's alternate-port fixture showed the tool still
read `3-3`. The disposition file is a baseline and is not edited; the register carries the
reopen and the real fix. The review's process point — *close findings with behaviour-based
tests, not token counts* — is the lesson, and every fix above has one.

## DR-10 — the committed EX-043 session cannot regenerate the counts: confirmed, open

The session's `kernel.log` is the keyword-filtered cut (`hci|btusb|bluetooth|usb …`); the
`len 27 mtu 9` and `Looking for Alt` lines are dynamic-debug output without those keywords
and were dropped, so the 910 count in `EX-043` is re-runnable only from the live journal (now
archived under `/root/bt-journal-archive`, uncommitted). **Open.** The shape of the fix: have
`bt-incident` also write a sanitised, *unfiltered* kernel window bounded around the first
timeout (say −120 s / +30 s), and regenerate the per-instance counts from that committed
input. Then a supplementary exhibit for EX-043 from the archived export of boot `eddd1961`.

## DR-11 — capture timestamps and completeness: confirmed, open

`bin/bt-capture` stamps records with `time.time()` at receive, ignores the declared payload
length, and writes a constant zero in the btsnoop drops field. The review does not claim
loss occurred, and neither does this side; the finding is that absence claims from the
capture rest on an uninstrumented completeness. **Open.** Shape: enable `SO_TIMESTAMP` and
read `SCM_TIMESTAMP` via `recvmsg()` as BlueZ's monitor does; check the header's length
against the received payload and flag truncation; count discontinuities and mark the drops
field unavailable rather than zero.

## §5 — tests and CI

- The capture no-socket test's `AttributeError` on a Python without `AF_BLUETOOTH`: fixed
  (DR-05 row).
- The five sanitiser assertions failing on a `mawk` host: the test-suite maintainer's item,
  known since 2026-09-18; unchanged here.
- `repo-scan` deriving the allowed address from the invoking git identity: **open**. The
  reviewer's point stands — a repository-maintained allowlist is reproducible where a derived
  one is not. Shape: a tracked file naming the public identities `repo-scan` allows.

## §6 and the closing paragraph

The review's ordered list is adopted as the order of remaining work (items 1–3 done above,
4 = DR-10, 5–6 = machine experiments that are the operator's call, 7 = TP-06/TP2-06). Its
closing paragraph on the practice of holding a kernel report until a patch is ready notes,
correctly, that this is a project policy. It is, and it stands; the practice is stated in
BRIEF §7 and applied to the kernel finding held on its branch.

## Recorded and not re-run

The reviewer's local suite run (6 of 759, environment-specific), the `patch -p1` offsets at
`ebbb4ee3`, the isolated reproductions for DR-05/06/08/09 (each independently reproduced here
by the standalone proof), and the `checkpatch` warning counts under a shallow BlueZ clone.
