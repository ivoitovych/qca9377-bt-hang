# EX-032 resolved — both `bluetoothd` crash sites named, from the shipped binary

**Date:** 2026-08-23T2340Z
**Author:** test-suite maintainer, branch `claude/unit-testing-intro-0jlol1`
**Status:** two crash sites identified to file and line. Method below; falsifiers stated.
**Supersedes the "BuildID dead end"** recorded against `§4.2` — no rebuild was needed.

---

## Summary

The two `bluetoothd` segfaults in `EX-032` are now resolved to source lines:

| incident | crash | function | source |
|---|---|---|---|
| Aug 18 | `segfault at 10` | `avdtp_stream_set_transport()`, inlined into `transport_cb()` | `profiles/audio/avdtp.c:3225` (caller `profiles/audio/a2dp.c:2448`, via `btio/btio.c:202`) |
| Aug 14 | `segfault at 0` | `start_discovery_complete()` | `src/adapter.c:1845` |

The `+0x367e5` crash is the one seen **three times**; `+0x8304a` from the coredump
backtrace is its caller and resolves to `accept_cb`, `btio/btio.c`.

Both are **NULL pointer dereferences on a value BlueZ never checks**. Both are
reachable from a controller that answers abnormally — which is what this whole
record is about.

---

## 1. What made this solvable

The blocker was believed to be the BuildID: the crashed binary is
`bluez 5.72-0ubuntu5.5`, and no debug symbols for it could be found. That is
still true — Ubuntu **did not publish an amd64 dbgsym for `-0ubuntu5.5`**:

```console
$ zcat Packages.gz | grep -A6 '^Package: bluez-dbgsym$' | grep Version
Version: 5.72-0ubuntu5          # noble          — amd64 exists
                                # noble-updates  — NOTHING for amd64
```

`5.72-0ubuntu5.5` dbgsyms exist for arm64, armhf, ppc64el, riscv64 and s390x.
The one architecture we need is the one that is missing.

**The dead end was real but not fatal**, because three things survive stripping
and were enough on their own:

1. the exact **binary** that crashed is downloadable (`bluez_5.72-0ubuntu5.5_amd64.deb`);
2. `.eh_frame` survives stripping and gives **exact function boundaries**;
3. `.dynsym` + `.rela.plt` still name every **PLT call target**.

## 2. Reading the crash line correctly

The kernel line is:

```
bluetoothd[313564]: segfault at 10 ip 000060ff12be87e5 sp 00007fff35b2f190 error 4 \
    in bluetoothd[367e5,60ff12bd7000+f3000]
```

The three-value form `[A,B+C]` is `print_vma_addr()`: **`A` is the file offset of
the faulting instruction**, `B` is the mapping start, `C` the mapping size. It is
*not* `ip - base`, and reading it that way was the trap:

```
ip - vm_start        = 0x60ff12be87e5 - 0x60ff12bd7000 = 0x117e5
vm_pgoff << PAGE_SHIFT                                 = 0x25000
                                                   sum = 0x367e5   ✓ matches A
```

That arithmetic also **confirms the downloaded binary is the build that
crashed**: its executable `LOAD` segment starts at file offset `0x25000` and its
size rounds to `0xf3000`, exactly the `+f3000` the kernel reported.

Because this binary's exec segment has `p_offset == p_vaddr == 0x25000`, the file
offset is also the virtual address. So `0x367e5` and `0xa6986` are directly
disassemblable.

## 3. Recovering function boundaries without symbols

```console
$ readelf --debug-dump=frames bluetoothd | grep -oE 'pc=[0-9a-f]+\.\.[0-9a-f]+'
3239 FDEs
```

| crash | enclosing function | size | fault offset |
|---|---|---|---|
| Aug 18 `0x367e5` | `0x366b0 .. 0x36999` | 745 bytes | `+0x135` |
| Aug 14 `0xa6986` | `0xa68a0 .. 0xa6ab5` | 533 bytes | `+0xe6` |

## 4. Naming them — and why the naming is trustworthy

`-0ubuntu5` **does** have amd64 symbols. It is a different build, so addresses do
not transfer — and that was checked rather than assumed:

```
first differing byte in exec segment: 0x28286
differing bytes: 927682 of 991277 (93.585%)
```

**93.6% of the executable segment differs.** Any attempt to carry an address
across would have been wrong. So the match was made on *shape*, not address:

- take every named function in `-0ubuntu5` of **exactly** the same byte size;
- compare the **multiset of call targets**, which are still named in both.

**Aug 14, 533 bytes** — three candidates of that exact size:

| candidate | call fingerprint |
|---|---|
| **`start_discovery_complete`** | `btd_adapter_unblock_address`×2, `g_dbus_client_unref`, `btd_error`, `btd_debug`, `__stack_chk_fail` |
| `store_adapter_info` | 15 calls, mostly `g_key_file_*` — no match |
| `media_folder_create_item` | 13 calls, `g_hash_table_*`/`g_strdup_printf` — no match |

The crashed binary's function at `0xa68a0` has **exactly** the first fingerprint,
element for element. The other two are not close.

**Aug 18, 745 bytes** — two candidates: `bap_probe` (9 calls, `g_dbus_client_new`×4)
and `transport_cb` (18 calls). The crashed function at `0x366b0` matches
`transport_cb` element for element, including the distinctive
`btd_assertion_message_expr` and `g_main_context_find_source_by_id`.

## 5. The decisive confirmation — the instructions themselves

Symbol matching is inference. The disassembly is not, and it agrees.

### Aug 18 — `avdtp.c:3223-3225`

```asm
367e0:  e8 0b 12 ff ff    call   279f0 <g_io_channel_unix_new@plt>
367e5:  49 8b 7d 10       mov    0x10(%r13),%rdi      <-- FAULTS, r13 == NULL
367e9:  49 89 c1          mov    %rax,%r9
367ec:  48 8b 47 50       mov    0x50(%rdi),%rax
367f0:  49 39 c5          cmp    %rax,%r13
```

against the source:

```c
GIOChannel *io = g_io_channel_unix_new(fd);          /* 3223 */

if (stream != stream->session->pending_open) {       /* 3225 */
```

and the struct:

```c
struct avdtp_stream {
        GIOChannel *io;          /* 0x00 */
        uint16_t imtu;           /* 0x08 */
        uint16_t omtu;           /* 0x0a */
        struct avdtp *session;   /* 0x10  <-- the read that faulted */
```

`stream->session` is at offset **`0x10`**, and the kernel said **`segfault at 10`**.
`stream` (in `%r13`) was **NULL**. The next two instructions load
`session->pending_open` and compare it against `stream` — literally
`stream != stream->session->pending_open`.

The caller is `transport_cb()` at `a2dp.c:2448`, which does:

```c
if (!avdtp_stream_set_transport(setup->stream, ...))
```

with **no NULL check on `setup->stream`**, and the callee dereferences it in its
second statement.

### The caller frame — `+0x8304a` resolves too

The coredump backtrace recorded in `comms/2026-08-19T1620Z` has
`#1 bluetoothd + 0x8304a`. Same method: the FDE at `0x82fc0..0x830e0` (288 bytes,
fault return at `+0x8a`), and exactly one size-288 candidate matches its call
fingerprint element for element — **`accept_cb`**, `btio/btio.c:179`:

```
strerror, getsockopt, g_set_error, g_quark_from_static_string,
g_io_channel_unix_get_fd, g_clear_error, __errno_location, __stack_chk_fail
```

`+0x8a` lands on its last statement:

```c
accept->connect(io, gerr, accept->user_data);   /* btio.c:202 */
```

which is the indirect call to `transport_cb`. So the whole stack is:

```
#0  avdtp_stream_set_transport()   avdtp.c:3225    <- stream == NULL
      (inlined)
#1  transport_cb()                 a2dp.c:2448     bluetoothd+0x367e5
#2  accept_cb()                    btio/btio.c:202 bluetoothd+0x8304a
#3  glib main loop dispatch
```

**This is independent corroboration of the method**, not just of the result: the
maintainer's coredump gave `+0x367e5 ← +0x8304a ← glib dispatch` from a machine
this session cannot reach, and the reconstruction produces a caller/callee pair
that is genuinely a caller/callee pair in the source, with the call site landing
on the right instruction.

The mechanism in one sentence: **the A2DP transport socket completes its accept,
and `setup->stream` is NULL by the time the callback runs.**

### Aug 14 — `adapter.c:1845`

```asm
a6986:  41 0f b6 45 00    movzbl 0x0(%r13),%eax       <-- FAULTS, r13 == NULL
a698b:  0f b7 53 04       movzwl 0x4(%rbx),%edx
a698f:  45 31 c9          xor    %r9d,%r9d
a6992:  4c 8d 45 d7       lea    -0x29(%rbp),%r8
```

against the source:

```c
const struct mgmt_cp_start_discovery *rp = param;
...
if (!adapter->discovery_list) {
        struct mgmt_cp_stop_discovery cp;
        if (status != MGMT_STATUS_SUCCESS)
                return;
        cp.type = rp->type;                          /* 1845  <-- FAULTS */
        mgmt_send(adapter->mgmt, MGMT_OP_STOP_DISCOVERY,
                  adapter->dev_id, sizeof(cp), &cp, NULL, NULL, NULL);
```

`struct mgmt_cp_start_discovery` is a single `uint8_t type` — **offset 0**, and the
kernel said **`segfault at 0`**. The byte load is `rp->type`; the `movzwl 0x4(%rbx)`
is `adapter->dev_id`; the `lea` is `&cp`. That is the `mgmt_send` call being set up.

**`param` was NULL.**

## 6. What these two say about BlueZ, stated conservatively

Both are missing checks on data that arrives from outside `bluetoothd`.

`adapter.c:1845` is the sharper of the two. The function does validate the
parameter length —

```c
if (length < sizeof(*rp)) { btd_error(...); ... return; }
```

— but that check sits **below** the `!adapter->discovery_list` branch that already
dereferenced `rp`. So a `MGMT_OP_START_DISCOVERY` completion carrying no
parameters crashes `bluetoothd` **iff** the discovery client list has emptied in
the meantime. That is an ordering bug, visible by reading, and it does not depend
on anything specific to this device.

⚠️ **What is not claimed.** That these crashes *cause* the controller wedge. The
ordering is the other way round in this record: `EX-032`'s warning fires when the
crash follows discovery. A daemon crash is a consequence of a controller
behaving abnormally at least as easily as a cause, and nothing here settles
which. It is also not claimed that this is the only path to either line.

## 6a. Both defects are still present in current BlueZ

Checked against **5.87**, the newest release in the Ubuntu archive:

| defect | 5.72 (`Jan 12 2024`) | 5.87 (`Jul 3`) |
|---|---|---|
| `start_discovery_complete()` dereferences `rp->type` above its own `length` check | present | **unchanged** |
| `transport_cb()` passes `setup->stream` unchecked to `avdtp_stream_set_transport()`, which dereferences it immediately | present | **unchanged** |

All three files (`src/adapter.c`, `profiles/audio/a2dp.c`, `profiles/audio/avdtp.c`)
**do** differ between the two releases — they have been actively maintained across
eighteen months and fifteen releases. These two functions were not touched.

That makes both of them live upstream defects rather than historical ones, and it
makes them **submittable without any of this project's contested material**: no
hardware, no reproducer, no argument about whether the controller wedge causes the
crash or the other way round. The `adapter.c` one in particular is an ordering bug
that a reader can confirm in thirty seconds.

⚠️ **Before submitting, check `bluez/bluez` master and the linux-bluetooth list** —
5.87 is a release tarball, and a fix may exist in git or in a posted patch that has
not shipped. Neither is reachable from this environment.

## 6b. The falsifier was run, and the identification survived

§7 below offered the strongest check available: that `%r13` held NULL and the
faulting instruction is `mov 0x10(%r13),%rdi`. Neither the register value nor the
instruction encoding was visible to the method that produced the claim — it worked
from `.eh_frame` boundaries and PLT fingerprints in a *different* build.

The main branch maintainer ran it against a retained core:

```
r13   0x0
rip   0x635d944b47e5
=> 0x635d944b47e5:  mov 0x10(%r13),%rdi
```

**Byte for byte as predicted.** The kernel's `segfault at 10` is the `0x10`
displacement off a NULL base — a consequence, not a coincidence.

They also confirmed both defects are live in master at **`5.87-78-gc73fa2f`**,
including that `avdtp_stream_set_transport()` has no guard of its own.

⚠️ **One thing this does not establish.** `lore.kernel.org` is 403 from both
environments, so the list archives are unsearched. "Not fixed in master" is the
claim; "never reported" is not.

## 7. Falsifiers

- Resolve either address on the machine with the real `-0ubuntu5.5` symbols (or a
  reproducible rebuild) and get a different function → §4 is wrong.
- Show `struct avdtp_stream` has different padding under this build's flags, so
  `session` is not at `0x10` → §5 is wrong.
- Show `mgmt_cp_start_discovery` is not the type at `%r13` → the Aug 14 reading is
  wrong.

The `-0ubuntu5` amd64 dbgsym, the `-0ubuntu5.5` binary and the verified source
are all in the archive, so any of these can be rechecked by anyone.

## 8. Exactly how to reproduce this

Everything is in [`docs/source-access.md`](../docs/source-access.md).
No hardware, no rebuild, no privileged access — only `archive.ubuntu.com` and
`ddebs.ubuntu.com`, plus `readelf`, `objdump` and `nm`.
