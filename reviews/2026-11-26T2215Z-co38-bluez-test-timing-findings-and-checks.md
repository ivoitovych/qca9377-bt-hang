# CO-38 BlueZ test, timing recheck: findings and checks (2026-11-26)

The request was `2026-11-26T1900Z-co38-bluez-test-timing-recheck.md`: send the test now, or wait until the kernel
fix is in bluetooth-next? Reviewers 1, 2, 3 and 6 answered; reviewer 7's answer may follow. Their texts are kept
privately.

## Verdict

**All four: send now.** None found anything false or rejectable in the BlueZ patch. Each checked part of the
evidence himself:
- the maintainer's own dependent test series;
- BlueZ `bed6e3602`;
- the Wilken and Pepper pairs;
- the netdev guide on separate threads;
- the base and master copies of `tools/mgmt-tester.c` (the same blob, `18dbd3f89`);
- the expected bytes against `read_adv_features_rsp_2`;
- `command_generic_callback()`, which checks status, length and contents.

The earlier plan, to wait for bluetooth-next, is replaced: the test is posted now, and when to apply it stays the
maintainer's call. Reviewer 3 put it as "we were using submission timing to solve an integration-order problem".

## The notes below `---`

| Reviewer | Position |
|---|---|
| 1 | Fine as written. |
| 2 | Preference: say why the order matters ("to avoid failures in unrelated kernel CI runs"). |
| 3 | Change: state the fact and leave the order to the maintainer, as his own series and Wilken's do. Proposed "Without the kernel fix this case fails because instance 2 is omitted from the reply; with it the case passes". |
| 6 | Fine; "once the fix is in bluetooth-next" is plainer than "in the kernel the Bluetooth CI runs". |

**Done** (below `---` only; the diff and patch-id `70a48730` are unchanged):

```text
before:
This case fails on kernels that have the bug (6.1 and later) until
that fix is in. Please apply it once the fix is in the kernel the
Bluetooth CI runs.

after:
Without that fix this case fails, because the reply leaves out
instance 2 (kernels from 6.1 on); with it the case passes. Applying
it once the fix is in bluetooth-next keeps the kernel CI runs of
other patches green.
```

The fact comes first, in reviewer 3's terms. The consequence follows as information, not an instruction (reviewer
2's reason), with reviewer 6's plainer tree name.

## Other points

1. **Two-week CI closure** (reviewer 6). The BlueZ CI closes any series pull request open for over two weeks and
   mails "must be resent" (its `cleanup_pr.py`; the notice the sco-tester test got on 11-12). If the maintainer holds
   the test that long, it is resent once. Accepted as the cost; to be watched.
2. **A renamed fix** (reviewer 6): the test's message cites the kernel subject. If review renames the fix, the test
   needs a v2. Accepted.
3. **Overstatements in the request document** (reviewers 2 and 3). The document stays as asked; these are the exact
   forms:
   - "He reviews the pair together" → posting both lets him review them together;
   - "The test cannot be forgotten" → is less likely to be forgotten;
   - "BlueZ's own checks do not run the kernel testers" → its `make check` / `check-functional` path excludes them
     by design (they can be run with `-m tester`).
4. **Not added** (reviewer 2): no skip, expected-failure mark or version check for affected kernels. The test should
   fail where the bug is.
5. **The kernel patch's note** "being submitted to BlueZ separately" stays true by sending now (reviewer 6).

## Final recheck (the 22:30 UTC request): reviewers 1, 2, 3, 6

All four: send; nothing false or rejectable.

Two wording points were applied (below `---` only; patch-id unchanged):
- **"keeps the kernel CI runs of other patches green"** was too categorical (reviewers 2 and 3). The test only
  avoids adding a known failure.
- **"it" meant the fix in one sentence and the test in the next** (reviewer 6).

Final notes:

```text
Without that fix this case fails, because the reply leaves out
instance 2 (kernels from 6.1 on); with it the case passes. Applying
this test once the fix is in bluetooth-next avoids a known failure
in the kernel CI runs of other patches.
```

Reviewer 6 also saw the kernel patch mirrored by the CI as bluez/bluetooth-next pull 1233. Its checks are still
to report.

Checked again at 22:25 UTC:
- BlueZ master is still `79162c108`, and the test applies;
- bluetooth-next is still `f57f78086ab5`, so the fix is not applied and the notes describe the present state;
- dry run "Result: OK", to linux-bluetooth only.

## Checks after the change

- **Patch-id** `70a4873086000186e05d1bbe88d65a75bc3b9e18`, unchanged.
- **Line widths:** the note lines are within 72 columns; longer lines are the lore URL and code lines of the diff.
- **Dry run** (`git send-email --dry-run`, project checkout): "Result: OK", RCPT TO linux-bluetooth only.

## Last read of the text as it will be sent (the 22:35 UTC request): reviewers 1, 2, 3, 6, 7

All five: send. The final notes are fine, and nothing is false or rejectable. No change followed:
- **Reviewer 6's "an expected failure"** is a preference. Reviewer 3 calls "known failure" precise, because a
  kernel-tester failure counts as a CI failure unless it is marked as expected.
- **Reviewer 7 notes that the document's "checks still to report" is stale.** The kernel patch's CI reported all
  checks passing at 22:10 UTC (STATUS row); the patch text is not affected.
- **Reviewer 6 checked the tips:** BlueZ master `79162c108911` and bluetooth-next `f57f78086ab5` are unchanged, so
  the notes describe the present state.
