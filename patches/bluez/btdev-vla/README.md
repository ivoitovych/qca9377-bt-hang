# emulator: Avoid variable length array in send_cmd — prepared, NOT sent

**State 2026-10-10: a file for the operator's review. Nothing has been mailed.**

| path | what |
|---|---|
| `0001-emulator-Avoid-variable-length-array-in-send_cmd.patch` | one patch on BlueZ master `7428ca2df9356363079db0f48412c20cbdb9471f` (its `base-commit` line), `git format-patch --subject-prefix="PATCH BlueZ"`; no `Signed-off-by` (BlueZ) |

## Why

The list's CI bot runs smatch on every BlueZ series and posts every smatch line on the
files the series touches, whether the series caused it or not. `emulator/btdev.c` carries
one such line in master:

```
emulator/btdev.c:479:29: warning: Variable length array is used.
```

so every patch to `btdev.c` — our leak fix (patchwork 14878779) and our test series
(14878780) on 2026-10-10 among them — comes back `CheckSmatch WARNING`. The array is the
`struct iovec iov2[2 + iovlen]` of `send_cmd()`.

## What the patch does

`send_cmd()` has two callers: `cmd_complete()` passes two iovec entries (the Command
Complete parameters and the return parameters), `cmd_status()` one. The array becomes
`struct iovec iov2[2 + SEND_CMD_IOV_MAX]` with `SEND_CMD_IOV_MAX` defined as 2, and a call
with more entries returns instead of writing past the array. Nothing changes for the two
callers. `malloc()`/`free()`, the form `1b9a0eca8` used in `src/shared/gatt-server.c`,
would add a failure path to the emulator's most-used send function for a bound that is a
compile-time constant.

## Precedent

`1b9a0eca8` "gatt-server: Fix integer overflow and 3 CI VLA wanings" (2026-09-10) was
written for the same bot output ("Fix CI warnings: Variable length array is used") and
applied without a human comment on the list; details and the smatch history in
[`results/ci-local-2026-10-10.md`](../../../results/ci-local-2026-10-10.md) §T4.

## Tests

See `results/ci-local-2026-10-10.md` §T4: `scripts/ci-local.sh` on master and master plus
this patch (the smatch line must come out FIXED, nothing NEW anywhere), and
`scripts/bluez-tester-compare.sh` for the emulator-based testers, every case compared by
name between master and master plus the patch.
