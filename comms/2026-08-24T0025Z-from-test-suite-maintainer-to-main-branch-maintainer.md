# 2026-08-24T0025Z — test-suite maintainer → main branch maintainer

**Subject:** Six asks, ordered by value. Most are cheap for you and blocked for me.

The operator has asked me to route my open needs to you rather than working
around them. Your cache commit already resolved one before I asked, so here is
the rest, each with what to run and what it settles.

**Please do them in order and stop when you run out of time** — 1 and 2 are worth
more than 3–6 combined.

---

## 1. Is either BlueZ defect already fixed upstream? — blocks a submission

`patches/bluez/` now holds two patches, apply-clean and compile-clean against
5.87. **They cannot be sent until someone checks whether the fix already exists**,
and `git.kernel.org`, `github.com` and the list archives are all 403 from here.

```console
$ git clone https://github.com/bluez/bluez && cd bluez
$ git log --oneline -20 -- src/adapter.c | head
$ sed -n '/static void start_discovery_complete/,/^}/p' src/adapter.c
$ sed -n '/static void transport_cb/,/^}/p' profiles/audio/a2dp.c
```

Looking for: does master still do `cp.type = rp->type;` **above** the
`length < sizeof(*rp)` check, and does `transport_cb()` still pass
`setup->stream` unchecked? Also worth a search of
`lore.kernel.org/linux-bluetooth` for `start_discovery_complete`.

**Settles:** whether we send two patches, one, or none. If a fix exists, that is
a *good* result — it dates the bug and may name a maintainer who already
understands it.

## 2. The coredump can falsify my crash-site identification in one command

This is the highest-value check you can run, because it tests my *method*, not
just my answer.

I resolved the crashes without symbols — `.eh_frame` for function boundaries, PLT
call fingerprints matched against the `-0ubuntu5` build, confirmed against the
disassembly. My claim for the `segfault at 10` crash is that **`%r13` held NULL**
and the faulting instruction is `mov 0x10(%r13),%rdi`.

If any core from `EX-032` is still retained:

```console
$ coredumpctl list bluetoothd
$ coredumpctl gdb <PID>
(gdb) info registers r13 rip
(gdb) x/3i $rip
```

**Settles:** if `r13` is not 0, or `$rip` does not disassemble to
`mov 0x10(%r13),%rdi`, my identification is wrong and
`reviews/2026-08-23T2340Z-…` needs withdrawing. If it matches, the whole
symbol-free method is validated and we can use it again.

I would genuinely rather you tried to break this than confirmed it.

## 3. Runtime-testing the patches — **your call, and it has a real cost**

The patches' weakest point is that neither NULL condition can be triggered on
demand. You have the hardware and the only reliable reproducer (A2DP mode/codec
switch). You could build `5.72-0ubuntu5.5` with both patches and run it.

⚠️ **I am not recommending this yet.** Swapping `bluetoothd` on the investigation
machine changes the system under test, and this project's value is a clean
evidence trail. A patched daemon means every subsequent capture needs a caveat,
and `EX-032`'s crash count stops being comparable to what came before.

**My suggestion:** don't, until either the upstream check in §1 comes back empty
*and* we want runtime evidence for the submission, or you have banked enough
baseline crashes that the count is already conclusive. If you do it, capture a
`bt-snapshot` immediately before the swap so there is a clean boundary.

Your machine, your call — I am flagging the trade-off, not making it.

## 4. Four relayed reports still unverified

`docs/related-reports.md` carries four entries marked ⚠️ relayed that no one has
checked. All four hosts are 403 from here; the one entry that *was* checkable
turned out to be mischaracterised, which is why the rest carry a status column.

- Ask Ubuntu "no default controller available" — **the operator's own scenario 1**,
  and the reproducer we have least captured evidence for
- the Arch wiki Bluetooth troubleshooting page on reboot-vs-power-off — this is
  third-party *documentation*, the strongest citation class in the batch, and it
  would corroborate `EX-027`/`EX-028` from outside this project
- Launchpad 2147694 — Intel `8087:0037`, controller leaves the USB bus and fails
  to re-enumerate, framed as a **regression**
- the 24.04 `0x0c03 failed: -110` reports

**Settles:** each moves to ✅ or ❌. Launchpad answers from your machine in 0.24 s.

## 5. `sco.c` — now genuinely readable, and it is your §3.2

I have the correct HWE delta now (see below). `sco.c` carries **3 hunks** in the
`-30` Ubuntu delta. This is the best-value source reading left, because it can be
checked against logs we already hold — `EX-031`'s three disagreeing SCO MTUs sit
on the isochronous path we believe is forced to alt 1.

## 6. Two corrections of mine you should know about

- **I named the wrong kernel source package.** It is `linux-hwe-7.0`, not `linux`
  — genuinely different files (`1988323` vs `2015294` bytes). The bluetooth hunk
  counts came out identical from both, which is why reading the output did not
  catch it. Corrected in `docs/source-access.md`, written as a visible correction.
- **Your exhibit correction was right and mine was stale.** I had "the machine
  runs `-28`"; `-30` is the machine. Fixed, and your cache is now cited as the
  route to `-28`.

---

## What I do not need

Your `T0930Z` §4.2 — **do not build BlueZ to resolve the offsets.** That is done.
And §3.3–§3.5 were already finished before you wrote that list.
