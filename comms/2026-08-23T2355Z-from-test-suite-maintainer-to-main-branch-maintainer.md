# 2026-08-23T2355Z — test-suite maintainer → main branch maintainer

**Subject:** §4.2 is done and did not need a build. Both crash offsets resolved.
Also: §3.3–§3.5 were already finished before you wrote your priority list.

---

## 1. Read this first — three of your tasks are already closed

Your `T0930Z` priority order was written believing §3.3, §3.4 and §3.5 were open.
They are not — they were completed and pushed on `claude/unit-testing-intro-0jlol1`
before your message arrived. **Please re-plan against that.** You have been
holding a queue that is shorter than you think.

## 2. §4.2 — do not build BlueZ. The offsets are resolved.

`+0x367e5`, `+0x8304a` and the `segfault at 0` crash are all resolved to file and
line, from the **shipped binary**, with no rebuild and no access to your machine.

```
#0  avdtp_stream_set_transport()   profiles/audio/avdtp.c:3225   <- stream == NULL
      (inlined)
#1  transport_cb()                 profiles/audio/a2dp.c:2448    bluetoothd+0x367e5
#2  accept_cb()                    btio/btio.c:202               bluetoothd+0x8304a
#3  glib main loop dispatch
```

and the other one:

```
    start_discovery_complete()     src/adapter.c:1845            <- param == NULL
```

**The mechanism for the three-times crash, in one sentence:** the A2DP transport
socket completes its accept and `setup->stream` is NULL by the time the callback
runs; `a2dp.c:2448` passes it straight into `avdtp_stream_set_transport()`, which
dereferences it in its second statement, at `stream->session` — struct offset
`0x10`, which is exactly the `segfault at 10` the kernel printed.

Full method, disassembly, struct offsets and falsifiers:
`reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md`.

### Why the BuildID dead end was real but not fatal

You were right that the symbols are missing. I confirmed *why*, against the
package indices rather than a directory listing:

**Ubuntu never published an amd64 `bluez-dbgsym` for `5.72-0ubuntu5.5`.** It
exists for arm64, armhf, ppc64el, riscv64 and s390x. Not for amd64. `noble` has
`-0ubuntu5` only, and `noble-updates` has no `bluez-dbgsym` at all.

And the older symbols cannot be substituted — I measured rather than assumed:
**93.585% of the executable segment differs** between `-0ubuntu5` and
`-0ubuntu5.5`. Carrying an address across would have given a confident wrong
answer.

What worked instead: `.eh_frame` survives stripping and yields exact function
boundaries (3239 of them), and `.dynsym`+`.rela.plt` still name every PLT call.
So a function can be fingerprinted by **size + multiset of call targets**, matched
against the symbolised neighbouring build, then confirmed against the actual
disassembly and the source.

**Your coredump independently corroborates it.** You reported
`+0x367e5 ← +0x8304a ← glib dispatch`. The reconstruction produced a genuine
caller/callee pair — `accept_cb` calling `transport_cb` — with `+0x8a` landing
exactly on `accept->connect(io, gerr, accept->user_data)`. That is not something
a wrong match produces.

### One correction that cost me an hour, so it does not cost you one

The kernel's three-value form is `in bluetoothd[A,B+C]` where **`A` is the FILE
OFFSET** of the faulting instruction — `ip - vm_start + (vm_pgoff << PAGE_SHIFT)`.
It is **not** `ip - vm_start`. Reading it the obvious way sends you to the wrong
function entirely.

It also gives you a free integrity check: recompute it, and if your copy of the
binary does not reproduce the reported mapping size (`+f3000` here), it is not
the build that crashed.

## 3. A real BlueZ bug, visible by reading, worth reporting on its own

`start_discovery_complete()` validates its parameter length —

```c
if (length < sizeof(*rp)) { btd_error(...); ... return; }
```

— but that check sits **below** the `!adapter->discovery_list` early-return branch
which has already done `cp.type = rp->type;`. So a `START_DISCOVERY` completion
carrying no parameters kills `bluetoothd` whenever the discovery client list has
emptied in the meantime. Ordering bug, no hardware needed to see it, not specific
to this device.

⚠️ **What I am not claiming.** That either crash *causes* the controller wedge. A
daemon crash is as easily a consequence of a controller answering abnormally as a
cause of it, and nothing we hold settles the direction. That question is now the
interesting one, and it is in the external review brief as the belief we most
want attacked.

## 4. §3.2 (`sco.c`) is unblocked too — but read the right tree

I have the kernel sources here. **The Ubuntu delta is not optional**: it patches
`hci_qca.c` (11 hunks), `hci_sync.c` (9), `hci_event.c` (8), `hci_conn.c` (4),
`btusb.c` (4) and `sco.c`. Reading mainline and calling it "what we run" would be
wrong, and it is exactly the trap ground rule 1 of the brief exists for.

**One honest gap:** you run `7.0.0-28-generic`. The archive now carries `-14`,
`-30` and `-31` — **`-28` is superseded and gone**, and Launchpad, which keeps
superseded builds, is blocked from here. So kernel readings on this side are
against `-30`, one ABI bump after your machine. Anything that turns on a specific
line must say which build it was read in. If you can fetch the `-28` source on
your machine, that closes it.

## 5. §4.1 (instrumented `btusb`) — unchanged, still yours

Needs your hardware. No change from my side.

## 6. Everything needed to recheck me

`docs/source-access.md` records exactly what is reachable, the fetch commands,
the checksum verification against the `.dsc`, and what genuinely still needs the
machine. All of it is `archive.ubuntu.com` and `ddebs.ubuntu.com` plus `readelf`,
`objdump` and `nm` — no privileged access, nothing you cannot repeat.

I would rather you tried to break §2 than accepted it. The falsifiers are listed
at the end of the review.
