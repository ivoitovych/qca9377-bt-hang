# CO-34 — BT-12: ioctl-tester registers two cases under one name

**State:** ready to send (2026-10-28: still applies to master `b0bf49270d44`, "OK to send"; no
competing patch). Not sent; the send is the operator's decision, and it goes alone, not with
CO-02.

**Target:** BlueZ (`tools/ioctl-tester.c`).

**Comes from:** `BT-12` (`docs/STATUS.md`), found 2026-10-27 while running the list's CI bot on
CO-02 v7: `scripts/compare-tester-verdicts.py` refused the ioctl-tester pair because of a
duplicate case name.

## The finding

BlueZ master `b0bf49270d44`, `tools/ioctl-tester.c` lines 918 and 921:

```c
	test_ioctl("Set Pkt Type - 2-DH", &set_pkt_type_2dh,
				NULL, test_ioctl_common);

	test_ioctl("Set Pkt Type - 2-DH", &set_pkt_type_3dh,
				NULL, test_ioctl_common);
```

The second case tests the 3-DH packet types (`HCI_3DH1 | HCI_3DH3 | HCI_3DH5`) under the 2-DH
case's name. Since the tool was added in `0da759f1a36d` ("tools/ioctl-tester - Add
ioctl-tester", 2022-09-21).

Not reported or fixed elsewhere: patchwork's bluetooth project has four ioctl-tester patches,
none about this (`tmp/co02-v7ci/pw-ioctl-tester.json`, fetched 2026-10-27).

## The patch

`patch/send/0001-ioctl-tester-Fix-name-of-the-3-DH-packet-type-test.patch`: the second name
becomes "Set Pkt Type - 3-DH". Built from the worktree `cache/bt12-ioctl-tester`, branch
`bt12/ioctl-tester-3dh-name`, on `b0bf49270d44`.

Checks (`log.md`): the list bot's BlueZ checks all PASS. ioctl-tester was built from the patch
and run in the bot's VM on bluetooth-next `47d4d9f67e92`: 28 of 28 passed, with "2-DH" and
"3-DH" now listed as separate cases. The kernel log is clean.

## Next

The operator's decision on the send: `git send-email` to linux-bluetooth@vger.kernel.org, with a
dry run first. It can go before or after CO-02; the two do not depend on each other.
