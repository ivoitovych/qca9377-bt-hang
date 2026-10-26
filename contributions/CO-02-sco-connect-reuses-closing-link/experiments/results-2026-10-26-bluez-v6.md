# CO-02 — the BlueZ test v6 (teardown closes the first socket), 2026-10-26

Evidence for the BlueZ test after the reviews of `ee52148`. QEMU/KVM with BlueZ's emulator; no
hardware. Raw logs on the development host: `tmp/co02-v6bluez/runs/`; scripts
`tmp/co02-v6bluez/run.sh` and `run-exp2.sh`; tree `cache/co02-v5-bluez-timeout`, branches
`co02-bluez/v5-as-sent` (the v5 mail applied to `7bc9684dc9e4`), `co02-bluez/v6` (`8bf439ce2`) and the
experiments `exp/v5-withheld`, `exp/v6-withheld` (not for submission).

## The finding (reviewer 4), checked
The reviewer's claim, from reading the code: on a framework timeout `reconnect_end()` does not run,
`test_post_teardown()` closes only `sk2`, and `test_data_free()` only removes the first socket's watch,
whose channel does not close it (`g_io_channel_set_close_on_unref(io, FALSE)`). So "a timeout while
waiting for the first connection can leave that descriptor open".

Checked by experiment, two cases, each on v5 and on v6, kernel `bzImage-v4-smp` (v5's kernel code is
v4's), the first socket's descriptor tested after teardown (`getsockopt(SO_PROTOCOL)`):
- **First completion withheld** (the reviewer's example): the emulator drops the first Synchronous
  Connection Complete, so only the framework timeout ends the case.
  **v5 does not leak here.** At teardown the emulated controller goes away, the kernel aborts the
  pending connect ("The first socket failed: condition 0x1c, Software caused connection abort"), the
  first socket's watch is still armed, fires, and `reconnect_end()` closes the socket. So the
  reviewer's example is wrong in practice.
- **Connect Twice stalled after the refused second connect** (no quiet timer, so the framework
  timeout ends the case while the first socket is connected and its watch already gone): **v5
  leaks, 2 of 2** ("EXP-RESULT: first socket fd 13 still OPEN after teardown"); **v6 closes it, 2 of
  2** ("fd 13 closed"). In the real test this window lasts from the first socket's connection until the
  500 ms quiet timer closes both sockets; a framework timeout (8 s) inside it means the emulator
  stalled. So the leak is real but narrower than the reviewer's example. In the stalled case the
  teardown also cancels the timer that would have closed the socket.
- First completion withheld, rerun with the second experiment's build: v5 2 of 2 closed, v6 2 of 2
  closed (as above).
- Each run also prints "fd 0 closed (Socket operation on non-socket)": the destroy hook runs for every
  registered case at exit, including the experiment case not selected by `-s`, whose descriptor field
  was never set. Noise of the experiment, not a result.

| case | v5 | v6 |
|---|---|---|
| first completion withheld | closed 4/4 | closed 4/4 |
| Connect Twice stalled | **OPEN 2/2** | closed 2/2 |

## The change (v5 → v6)
`test_post_teardown()` closes the first socket of a reconnect test if it is still open, after
removing its watch; for the other tests the socket belongs to its channel and is left alone (closing
it there would close it twice). 15 lines; no other change; the commit message is unchanged.

## Regression, v6 test
| kernel | result |
|---|---|
| bluetooth-next + series (v4 code), UP / SMP / KCSAN SMP | Reconnect (2 cases) and Connect Twice, 3 times each on all three: 18/18 runs pass; full sco-tester 33/33 on UP and on SMP |
| bluetooth-next base, UP and SMP (negative control) | full sco-tester 31/33: "Reconnect During Disconnect" and "Connect Twice" fail, as with v4/v5 |
| bluetooth-next **today's head `47d4d9f67e92`** + series (v5 mails, `git am` clean, range-diff identical), SMP | Reconnect and Connect Twice 3 times: 6/6 runs pass; full sco-tester 33/33 |
| bluetooth-next `47d4d9f67e92` alone, SMP (negative control) | full sco-tester 31/33: "Reconnect During Disconnect" and "Connect Twice" fail |

`scripts/kernel-report-scan.py` on the full runs and the stalled experiment: every guest booted the
intended kernel (`g3d71b97faa98` head + series, `g47d4d9f67e92` head, `g4a828a5e0cfe` v4) and has
no report (oops, BUG, WARNING, KASAN, KCSAN, lockdep, …). The v6 test passes am/checkpatch/gitlint
(the bot's config) on BlueZ master `a0580dad5655`: `scripts/ci-local.sh`, "no NEW finding".
Images and the freshness check: `tmp/co02-fresh/`, `tmp/co02-w2c/img/bzImage-fresh-btnext-*-smp`.
