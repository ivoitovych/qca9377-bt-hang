# CO-06 — Review reply on Jiale Yao's mesh power-off fix

**State:** blocked (2026-10-28). The comparison behind the reply dates from 2026-10-05, before
`87a49b610708` changed the mesh timing; it must be re-run on today's bluetooth-next before any
reply. Sending is the operator's decision.

**Target:** the Linux kernel. Another author's patch; ours would be a review reply, with no
Tested-by.

**Comes from:** `M-1` and the mesh v3 series' power-off patch (4/5), which overlaps his.

## What it is

Jiale Yao's "Bluetooth: mgmt: handle mesh send completion queue failure" (patchwork 14864878,
2026-10-03):
- **State:** `new`. The only reply is the CI bot's, whose mesh-tester "Send cancel" timeouts
  predate `87a49b610708`. No newer version on 2026-10-18.
- **Our comparison of 2026-10-05,** on the same base and cases:
  - his fallback runs the completion without `req_lock`/`hdev->lock`;
  - a backlog of three strands a request with his fix and with our adapted minimal fix alike;
    only our v3 1/5 drains it;
  - at device removal, his fallback completes two of three requests unlocked, while the
    control and our variants complete none.

**An outside review recommended a reply framed as one shared problem.**

The comparison itself is held until the reply is decided (STATUS, "Held").

## Next

The operator decides whether to reply. Checked 2026-10-28: 14864878 still `new`, no newer
version; 14888791 and 14880941 still `new` too (`log.md`). Before any send:
1. re-run the comparison on today's bluetooth-next;
2. re-check the patch's state on the send day.
