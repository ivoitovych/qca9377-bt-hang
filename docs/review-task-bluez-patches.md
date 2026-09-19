# Review task — two BlueZ patches, before they are mailed

*Written 2026-09-19 for an independent reviewer. Everything here is public; the
repository is the record and the patches are the deliverable.*

## 0. What is being asked

Review two small patches to BlueZ (`bluetoothd`), each fixing a NULL dereference
found on one laptop, before they go to `linux-bluetooth@vger.kernel.org`. We want
a reading we did not produce ourselves, by whatever method you would use for a
patch arriving on that list: read the code, read the message, check the claims,
try to break them.

**We are deliberately not handing you a checklist.** Section 4 says what *we*
would look at hardest, as context for where our confidence is thinnest; it is not
the scope. If your own list is different, use yours, and tell us what was on it.

A first independent review was done on 2026-09-18 and is in the repository
(`reviews/2026-09-18T0700Z-third-party-bluez-patch-review.md`, with our
verification of it). **Please form your own view before reading it**, so the two
readings are independent; then read it if you wish, and say where you agree,
disagree, or would add. That review changed one thing: it caught a wrong label in
our own evidence, which led to the crash being reconstructed from the daemon log.
It did not change either patch's code.

## 1. Where things are

Repository: **https://github.com/ivoitovych/qca9377-bt-hang** (branch `main`).
Please note the commit you read (`git rev-parse HEAD` after cloning, or the
"Latest commit" hash on the page) in your report — the repository changes daily.

The two patches, in `git format-patch` form, one file each:

| patch | file | raw |
|---|---|---|
| `0001` | [`patches/bluez/0001-adapter-Fix-crash-on-short-start-discovery-reply.patch`](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/patches/bluez/0001-adapter-Fix-crash-on-short-start-discovery-reply.patch) | [raw](https://raw.githubusercontent.com/ivoitovych/qca9377-bt-hang/main/patches/bluez/0001-adapter-Fix-crash-on-short-start-discovery-reply.patch) |
| `0002` | [`patches/bluez/0002-a2dp-Fix-crash-on-NULL-stream-in-transport_cb.patch`](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/patches/bluez/0002-a2dp-Fix-crash-on-NULL-stream-in-transport_cb.patch) | [raw](https://raw.githubusercontent.com/ivoitovych/qca9377-bt-hang/main/patches/bluez/0002-a2dp-Fix-crash-on-NULL-stream-in-transport_cb.patch) |

They apply to BlueZ `master` with `git am`, each alone and both in either order;
they are independent and will be sent as two separate mails, not a series.

The record behind them, in the order a reviewer probably wants it:

- [`patches/bluez/README.md`](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/patches/bluez/README.md)
  — environment, runtime evidence, what has been verified, BlueZ's conventions as
  measured from its tree, how the patches will be sent, and the notes a
  maintainer does not need. **Start here.**
- [`reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md`](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md)
  — how both crash sites were located in a stripped distribution binary and then
  checked against a retained core, with the prediction stated before the core was
  read.
- [`evidence/exhibits/041-patch-0002-prevented-four-crashes.md`](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/evidence/exhibits/041-patch-0002-prevented-four-crashes.md)
  — the four runtime firings of `0002`'s guard, and (in its correction block) the
  line-by-line reconstruction of `0001`'s crash from the archived daemon log.
- `evidence/sessions/20260814-212211-trial-stock-2-hang/bluetoothd.log` — the
  archived, sanitised daemon log of the day `0001`'s crash happened; the lines the
  patch message quotes are in it.
- Tools that re-run our checks, both tracked:
  `patches/bluez/git-am-check.sh <bluez-tree> [<commit>]` (apply alone/together/
  either order, no `Signed-off-by`, 50/72) and
  `patches/bluez/checkpatch-check.sh <bluez-tree>` (checkpatch under BlueZ's own
  `.checkpatch.conf`, from inside the tree).
- `patches/bluez/mail-notes/0001.txt`, `patches/bluez/mail-notes/0002.txt` — the text that goes *below* the
  `---` line of each mail, which `git am` discards.

The repository's front page (`README.md`) and `BRIEF.md` describe the larger
investigation these were found in — a controller that stops answering during
hands-free audio. **The patches do not address that**, and neither the messages
nor the README claim they do; if anything in the tree reads as though they do,
that is a finding.

## 2. Ground rules

Each of these has already cost this project something.

1. **Cite the version you read** — of BlueZ (a commit hash) and of this
   repository. The patches were last verified against BlueZ master `c73fa2f9a`;
   a later master may have moved the lines or fixed the defect, and either is
   worth knowing.
2. **If you cite a URL, open it.** Anything you did not open, mark as unopened.
3. **Absence of a log line is not absence of the event.** In `src/shared/mgmt.c`
   the two completion events print different strings; before concluding what did
   or did not arrive, check what each branch would have printed.
4. **Negative results are required.** "I tried to construct a case where the new
   check changes a valid reply's handling and could not" is a deliverable line.
5. **Say what would falsify each finding.**
6. **Check the message against the code, not only the code.** BlueZ's `HACKING`
   wants the message to carry the change and its evidence. A sentence the quoted
   log or disassembly does not support is a defect in the patch even when the
   diff is right.

## 3. What has been verified, so you need not repeat it unless you want to

| check | result | where |
|---|---|---|
| both defects present at BlueZ master `c73fa2f9a` (and, per the first reviewer, at `2401054`, 2026-09-17) | yes | `patches/bluez/README.md` |
| `git am` at `c73fa2f9a`: each alone, both, either order | clean, 6/6 | `git-am-check.sh` |
| `checkpatch` under BlueZ's `.checkpatch.conf` | 0 errors; 1 warning each (a quoted `segfault` line, exempt) | `checkpatch-check.sh` |
| builds (5.87 and the machine's 5.72) | no new warnings | README |
| crash sites in the stripped binary matched against a retained core | byte for byte as predicted | 2026-08-23T2340Z review |
| `0002`'s guard observed firing in the field | 4 times in 19 days, across two daemon lifetimes | `EX-041`, `tools/bt-guards` |
| `0001`'s guard observed firing | never; its crash is reconstructed from the daemon log, and its premise was logged five more times with clients present | `EX-041` correction block |
| BlueZ conventions (no `Signed-off-by`, 50/72, `[PATCH BlueZ]`, `Fixes:` usage) | measured from `HACKING` and the last 300 commits | README §Conventions |

## 4. Where our own confidence is thinnest — context, not scope

- **`0001`: the message now names the event.** It says the callback ran with a
  Command Status (status 0, length 0, NULL param) for a Start Discovery sent
  2.05 s earlier, with the client list empty, and quotes the daemon's last lines.
  Does every sentence follow from the quoted lines and from `src/shared/mgmt.c`?
  Is anything asserted that the log does not show?
- **`0001`: the residual.** After the guard returns, the no-clients branch cannot
  send Stop Discovery (it has no `type`). We think that is the right trade and
  say so in the README. Would you?
- **`0002`: dropping the transport.** The guard takes the existing `drop:` path.
  Alternatives we considered and rejected are in the README's notes. Is there a
  valid behaviour that is lost?
- **`0002`: no `Fixes:` tag, on purpose.** `git log -S` on the unchecked call finds
  a 2015 refactor, which is where the text last moved, not where the NULL became
  possible. Two prior hardenings of the same path are cited in prose instead.
  Right call?
- **Neither can be reproduced on demand.** Both were first seen as crashes. If
  you see a deterministic way to drive either callback into the guarded state in
  BlueZ's own `unit/` tests, that would be worth more than anything else here.
- **Format.** We have applied BlueZ's rules as we measured them. If you know the
  list's current habits better than a tree can show, say where we are off.

## 5. Deliverable

Any form you like, with these properties:

- Each finding says what was checked, at which version, and what would change
  your mind.
- Findings are graded (blocker / should fix / nit / note) in your own terms.
- Things you read and found nothing wrong with are listed, briefly — silence is
  not a result.
- Disagreements with the first review, if you read it, are kept as disagreements
  rather than resolved by you; we will resolve them.
- If something cannot be settled without the machine, say so and say what would
  settle it; the machine is available on request, within the limits the README
  describes (it is a family laptop and the controller can be destroyed).

We will store the review verbatim in `reviews/`, verify every claim against the
tree with the commands recorded beside it, and reply in the same file — as was
done for the first review. Nothing you write will be edited.
