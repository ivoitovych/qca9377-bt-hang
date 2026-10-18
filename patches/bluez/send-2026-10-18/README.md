# Two BlueZ patches, final form of 2026-10-18. SENT 2026-10-18

They replace the 2026-10-13 set in [`../send-2026-10-13/`](../send-2026-10-13/README.md).
Both are on BlueZ master `fa6ba5502` (2026-10-14; re-fetched 2026-10-18, unmoved), one
mail each, unrelated to each other.

## Sent

On the operator's word, 2026-10-18, the two files below as they are, each with
`git send-email --suppress-cc=all --to=linux-bluetooth@vger.kernel.org`:

| patch | sent (+0200) | Message-ID | server | patchwork |
|---|---|---|---|---|
| A1 | 06:39:02 | [`<20261018043903.1756818-1-yaroslav.voytovych@gmail.com>`](https://lore.kernel.org/r/20261018043903.1756818-1-yaroslav.voytovych@gmail.com) | 250 | [14897668](https://patchwork.kernel.org/project/bluetooth/patch/20261018043903.1756818-1-yaroslav.voytovych@gmail.com/) |
| A2 | 06:39:11 | [`<20261018043911.1756937-1-yaroslav.voytovych@gmail.com>`](https://lore.kernel.org/r/20261018043911.1756937-1-yaroslav.voytovych@gmail.com) | 250 | [14897669](https://patchwork.kernel.org/project/bluetooth/patch/20261018043911.1756937-1-yaroslav.voytovych@gmail.com/) |

Checked just before: `scripts/pre-send-check.sh cache/bluez-upstream` fetched master,
still `fa6ba5502`; A1 then A2 as a series, and A2 alone, "OK to send". Patchwork's
Bluetooth project had no other pending patch on either change (searched by name for
`transport_cb`, `send_cmd` and `emulator`). The dry runs showed one recipient, the list,
and no Cc.

| file | what | commit |
|---|---|---|
| `0001-a2dp-Remove-duplicate-check-in-transport_cb.patch` | **A1.** `transport_cb()` checks `setup->stream` twice in a row, because our `0bed9886cff3` and the redundant v2 `d84171e6cd68` were both applied. Removes the second copy (5 lines) | `9963bb547`, branch `send/a1-a2dp-cleanup-20261018` in `cache/bluez-send-20261018` |
| `0001-emulator-Avoid-variable-length-array-in-send_cmd.patch` | **A2, to send.** `send_cmd()` declares `struct iovec iov2[2 + iovlen]`, which smatch reports on every patch touching `btdev.c` (`emulator/btdev.c:479:29: warning: Variable length array is used.`). One line: `newa()`, BlueZ's `alloca()` wrapper, as `shared/gatt-client` uses it for the same warning (`c18e3bf92`) | `50b231ceb`, branch `send/a2-btdev-vla-newa-20261018` |
| `alternative-assert/…` | the 10-13 design: a fixed array of `2 + SEND_CMD_IOV_MAX` and `assert(iovlen > 0 && iovlen <= SEND_CMD_IOV_MAX)`. Kept as the record; not to send | `37b76b9be`, branch `send/a2-btdev-vla-assert-20261018` |
| `TEST-REPORT.md` | the re-test on `fa6ba5502` of all three, against base | — |

## What changed since 2026-10-13, and why

Four outside reviews of the 10-13 set (2026-10-18) found no defect in A1 and agreed on the
changes below. Each was checked against BlueZ master before it was made.

- **A1's title** was 53 characters; BlueZ's `HACKING` asks for 50. It is now 44 and keeps
  the function name: `a2dp: Remove duplicate check in transport_cb`.
- **A1 has no `Fixes:` tag.** The removed check could never fire, and BlueZ's dead-code
  removals carry none (`28cfa9313`, `a82606b8e`). The body names both commits.
- **A2 uses `newa()` instead of the fixed array and `assert()`.**
  - The fixed array caps the count at two. Under `-DNDEBUG` the assert disappears, so a
    future third caller would overflow it.
  - `newa()` sizes the array from `iovlen` as the original did, is the maintainer's own
    fix for this warning, and needs no new include, macro or `assert()`. Nothing under
    `emulator/` uses `assert()`.
  - What it does not do: `newa()` is `alloca()`. The compiled `send_cmd()` still makes a
    variable-size stack allocation, as before (`sub %rax,%rsp` in `btdev.o`). The patch
    clears the warning; it is not a stack-safety change, and its message claims only the
    warning. Zero entries make `iov[i - 1]` invalid, as before; no caller passes zero.
- **A2's subject names the change.** "emulator: Fix smatch warning in send_cmd" drew
  checkpatch's `EMAIL_SUBJECT` warning ("describe the change not the tool that found
  it"), which BlueZ's bot posts.
- **A2's message quotes the exact smatch line**, as `c18e3bf92` does.
- The VLA is from `a7b600b45` (2014), not from our patches; A2's message does not say
  otherwise.

## Checks on the final files

Run 2026-10-18 by `tmp/bluez-a1a2-20261018/final-mails.sh` (outputs there):
- `scripts/pre-send-check.sh` against `fa6ba5502`: each alone and A1 then A2 as a series,
  "OK to send".
- checkpatch with BlueZ's `.checkpatch.conf`: 0 errors, 0 warnings, 0 checks, all three.
- gitlint with BlueZ's `.gitlint`: PASS, all three.
- Subjects without the prefix: A1 44, A2 49 characters; the longest message line 70.
- The diffs are identical to the commits tested in `TEST-REPORT.md` (`git diff --stat`
  between each final and its tested commit prints nothing); only messages changed.

## The send rules (followed 2026-10-18), and after

- rerun `pre-send-check.sh` on the day (master moves);
- send each mail separately to linux-bluetooth@vger.kernel.org, `git send-email`;
- no `Signed-off-by` (BlueZ), no cover letter, nothing under the `---` cut;
- no reply on the old a2dp threads;
- after the send, judge each patch on its own. The bot's pull request is no verdict: it
  closed PR #2559 on 2026-10-07 with "it must be resent", and the maintainer applied that
  patch later the same day (`d84171e6c`, [`../README.md`](../README.md)). Look at BlueZ
  master, the patch's patchwork state and any reply on the list. Resend one unchanged as
  v2, with "v2: resend, no changes" under the cut, only if it is not in master, is still
  `new` on patchwork and has no reply, and not before 14 days.
