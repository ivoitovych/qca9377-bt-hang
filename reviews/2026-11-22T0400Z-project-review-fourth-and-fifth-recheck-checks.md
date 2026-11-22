# The project review's fourth and fifth rechecks: each item checked and acted on (2026-11-22)

The pages: `20261116-142253-fourth-recheck-findings.md` and `20261122-025747-fifth-recheck-findings.md`
(findings-only copies). The fifth page repeats the fourth page's short list, unchanged at `e420203b`,
so the items are checked once here, on today's tree.

| Item (page) | Checked | Done |
|---|---|---|
| CO-23 `patch/send/send.sh` still works in a superseded directory (4, 5) | Since 2026-11-16 the script itself refuses `--send` with exit 2 and points at `../send-20261114/` (lines 13-18). Without arguments it only does a dry run, which sends nothing. | Nothing to change. The working-copy concern was already met. |
| `BRIEF.md:254`, the D1/D2 gloss (4, 5) | Right: in `contributions/review-2026-11-02/followups.md`, D1 is when to post v2 and its label; only D2 is the error code. | Rewritten: D1 and D2 are glossed separately. |
| `BRIEF.md:839`, a hash cut in the middle (4, 5) | `sha256sum tmp/runtime/bluetooth-patched.ko` gives `815e73781b0e15cf2b0c9a2697ab8c4aa37dc75f035d81e181808c2ee1b90b72`, matching both ends of the cut value. | The full value is written in, with the file it was read from. |
| `BRIEF.md:595`, the lessons pointer of §8a (4, 5) | Today's text already says the two lessons files hold the instances "up to 2026-08-27", and says where later rules' instances are. | Nothing to change. |
| `BRIEF.md`, a hand-off block of 11-14 (4, 5) | True. The file says so itself (`:148`). | Open: refreshing the hand-off is a larger task, and is recorded as such. |
| `docs/issues.md:1552`, "that test is next" (4, 5) | True. | Rewritten as the 10-01 state, with the answer (the 11-11 recordings) pointed to. |
| `docs/sent-mails.tsv` row 7, the path cell (4, 5) | The 2026-10-02 stable request is kept as `patches/diag/stable-request-dc16388d45ec.md` (body "byte for byte" inside a document). | The path cell now names it. The sha256 stays empty: there is no mail file to hash. `scripts/sent-mail-check.py` skips a row with an empty sha256. |
| `docs/sent-mails.tsv`, the three BT-9 stable hashes are of address-elided copies (4, 5) | True: the kept files read `<address elided>` where the sent mails had addresses. | Not re-hashed, because the sent files are not kept. `docs/tooling-index.md` (the `sent-mail-check.py` row) now says what a row's sha256 covers, naming both cases. |
| `patches/bluez/README.md`, UTC heading above a note that doubts it (4) | The 09-19 bot heading already says "time zone not settled". The 09-21 table is headed "UTC". | A note on the 09-21 table: read as CEST, the bot's 22:42 would come five minutes before v2 was mailed at 20:47 UTC (its Message-ID), so those two rows cannot be CEST. |
| `patches/diag/README.md`'s body (4) | The note said that later counts exist but did not give them. | The note now gives `BRIEF.md`'s settled counts: E1 58 links / 3 boots / 2 headsets (`EX-058`); E3 16 links / 2 headsets (`EX-057`). |
| `tools/bt-ui-capture:166`, the keeper checks three paths (4, 5) | On the machine, 2026-11-22: `scripts/bt-ui-atspi.py`, `tools/lib/` and everything under it, `tools/`, the checkout and `/root/exp` are owned by root with mode 755 or tighter. `find … -perm /022` and `find … -not -user root` both found nothing, and `/root` is 700. | Machine state: nothing to fix. Code: extending the check to those paths is a suite change for the next round. Open, Low. |
| `devtools/repo-scan:295`, "does not pass silently" (4, 5) | True: under `--quiet`, with no list, it prints nothing. | The comment now says what happens: the check is skipped, does not fail, and says so except under `--quiet`. |
| CO-46's data on another branch (4, 5) | True, and its README says so. | Unchanged: porting it is a choice. |
| `8b71499` and `a56141e` ancestors of `main`? (4, 5) | On a full clone, 2026-11-22: `git merge-base --is-ancestor 8b71499 main` and `… a56141e main` both exit 0. That is `8b7149929fbb…` (2026-10-14, comms) and `a56141ef44bc…` (2026-10-16, results and comms). | **Confirmed: both are ancestors.** This closes the High finding that needed this command. |
| `scripts/sco-ledger.sh` on a boot without a call (4, 5) | Not run. The script names headsets with `bluetoothctl devices` (line 48), a query to the running bluetoothd, and that is not run on the laptop without the operator's word. | Open: it waits for the operator's word, or for a variant that skips the name lookup. |
| The older wording: the work-area path, the CO-25 log line, the 10-28 review row, the local home path, history (5) | Counts as the page gives them. | The author's decision, as the page says. Not acted on here. |
| The reviewer's branch (5) | `main` holds the review, the rechecks and, from this commit, findings-only copies of the fourth and fifth pages. The full pages are kept outside the repository. | Deleting the branch is the author's call. |
