# fault-window — fixtures for `tools/bt-fault-window`

| boot | what it is | drawn from |
|---|---|---|
| `b0` | an alt-1 transparent SCO stream, a `link tx timeout` decoy, then the BT-1 fault | EX-036: the `0x0428` setup at `17:08:08.550995` and the bare `command tx timeout` at `17:08:10.702854` are its lines verbatim, so setup → fault is its 2.152 s |
| `b-1` | a CVSD stream at mtu 17 ending in an opcode-carrying timeout | the `0x0428` line of the 2026-08-15 fixture; the timeout wording of `tests/journal/` |
| `b-2` | a boot with a `link tx timeout` and **no** command timeout | the timeout wording of `tests/journal/` — the anchor must refuse, not settle on the link line |
| `b-3` | empty | the rotated-off-the-ring case |

⚠️ **One line shape is derived, not copied:** the SCO packet lines `kernel: len N mtu M`.
No raw sample of them is retained in this repository — exhibits quote them without their
prefix. The shape follows from `btusb`'s `BT_DBG("len %d mtu %d", …)` in
`__fill_isoc_descriptor()` under the `+p` flag `bin/bt-dyndbg` sets (no function
prefix), and it is the shape `bt-fault-window` and `scripts/sco-ledger.sh` both filter on.
Replace with a verbatim line when one is captured.
