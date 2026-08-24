# BlueZ patches — two NULL dereferences, ready to send

Two crashes recorded as `EX-032` on this machine, resolved to source in
[`reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md`](../../reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md)
and fixed here.

| patch | file | defect |
|---|---|---|
| `0001` | `src/adapter.c` | `start_discovery_complete()` dereferences the mgmt reply above its own length check |
| `0002` | `profiles/audio/a2dp.c` | `transport_cb()` passes `setup->stream` unchecked into a function that dereferences it |

**Why these two are worth sending, when the rest of this investigation is not
ready.** They carry none of the contested material. No hardware, no reproducer,
no argument about whether the controller wedge causes the daemon crash or the
crash is a symptom of it. `0001` in particular is an ordering bug a reader can
confirm in half a minute, and the mechanism is fully determined from BlueZ's own
source — `src/shared/mgmt.c` dispatches a Command Status event as

```c
request_complete(mgmt, cs->status, opcode, index, 0, NULL);
```

so a Command Status carrying status `0` reaches the callback with `length == 0`
and `param == NULL`, passes the `status != MGMT_STATUS_SUCCESS` guard, and
faults on a one-byte read at offset 0. That is exactly the `segfault at 0` on
record.

## What has been verified

| check | result |
|---|---|
| applies to pristine 5.87 with `git apply --check` | ✅ both, clean |
| applies with `patch -p1` | ✅ both, clean |
| `src/adapter.c` and `profiles/audio/a2dp.c` compile | ✅ both objects build |
| compiler warnings introduced | ✅ none |
| defects still present in current upstream 5.87 | ✅ both, unchanged since 5.72 |

Built against BlueZ 5.87 configured with
`--disable-systemd --disable-obex --disable-cups --disable-manpages
--disable-testing --disable-tools --disable-monitor --disable-client`.

### The crash site survived falsification

The identification was made **without symbols** — `.eh_frame` function boundaries
and PLT call fingerprints matched against a *different* build. That method could
easily have produced a confident wrong answer, so it was published with a
prediction attached: `%r13` holds NULL, and the faulting instruction is
`mov 0x10(%r13),%rdi`.

Checked against a retained core on the investigation machine:

```
r13   0x0
rip   0x635d944b47e5
=> 0x635d944b47e5:  mov 0x10(%r13),%rdi
```

Byte for byte as predicted. The kernel's `segfault at 10` is the `0x10`
displacement off a NULL base, not an address in its own right.

**Worth citing in the submission** — a maintainer will reasonably ask how a crash
site was located in a stripped binary whose debug symbols were never published.

⚠️ **Not verified: runtime.** Neither NULL condition can be triggered on demand —
both were observed as crashes in the wild, not reproduced deliberately. The
patches are argued from source and from the disassembly of the binary that
crashed. They prevent a fault that is demonstrably reachable; they have not been
watched preventing it.

⚠️ **`0002` treats the symptom.** It stops the crash without explaining why
`setup->stream` is cleared while the setup is still on the `setups` list. The
patch says so in its own commit message rather than implying a complete fix.

## Upstream status — checked twice, independently, and both are still needed

Verified a second time by cloning master directly and applying the patches to it:

```console
$ git clone --depth 50 https://github.com/bluez/bluez.git      # HEAD c73fa2f
$ git am 0001-*.patch 0002-*.patch
Applying: adapter: Fix crash on zero-length start discovery reply
Applying: a2dp: Check setup->stream before setting the transport
```

Both defects present at `c73fa2f`, both patches `git am` clean **against real
master**, not just the 5.87 tarball.

Master was also checked independently from the investigation machine at
**`5.87-78-gc73fa2f`**:

- `start_discovery_complete()` still does `cp.type = rp->type;` **above** the
  `length < sizeof(*rp)` check;
- `transport_cb()` still passes `setup->stream` unchecked, **and the callee does
  not guard it either**.

Helpful context for the submission: `src/adapter.c`'s recent history carries
accepted crash fixes of the same shape — *"Fix crash on UUID discovery filter
match"*, *"Fix crash on dev_disconnected"*. NULL-deref fixes land in this file.

### Prior art — settled, no longer a caveat

An earlier revision of this file said the list archives could not be searched
from either environment. **That was wrong, and it was wrong the same way twice**
— see the four failure modes in [`docs/source-access.md`](../../docs/source-access.md).
`lore.kernel.org` returns 403 to `curl` because of a user-agent block fronting a
JavaScript anti-bot page; a browser passes it in seconds. The operator opened it
himself and settled the question in under a minute.

| query | results | reporting these defects |
|---|---|---|
| `start_discovery_complete` | ~300 hits, 207 distinct subjects | **none** — the only NULL-deref threads are kernel-side `hdev->discovery.uuids` patches, a different layer and pointer |
| `avdtp_stream_set_transport` | 32 hits | **none** reporting this call path |

**The nearest prior work, verified here against full history** rather than taken
on trust:

```console
$ git log -1 --stat 90a600895
Luiz Augusto von Dentz   2020-09-22
avdtp: Handle case where remote send L2CAP connect ahead of Open
 profiles/audio/avdtp.c | 75 ++++++---     <- ONE FILE
```

It is the *same* code path, not merely a similar one: that commit introduced
`stream_set_pending_open()`, which is the function `avdtp_stream_set_transport()`
calls. It added no NULL guard on `stream`, and at master `transport_cb()` in
`a2dp.c:2680` still hands `setup->stream` over unchecked.

So the maintainer has already accepted a fix for **this scenario** in the
neighbouring file, and the gap patch `0002` closes is one that fix left open.

⚠️ *Checking this needs the full history.* A `--depth 50` clone cannot see a 2020
commit and answers `unknown revision` — which reads like "no such commit" rather
than "not in my clone". Unshallowed to 29242 commits before checking.

## How to send

BlueZ takes patches by mail on `linux-bluetooth@vger.kernel.org`. The files are in
`git format-patch` shape and can go straight to `git send-email`, or be applied to
a checkout with `git am` and resent from there:

```console
$ git am 0001-*.patch 0002-*.patch
$ git send-email --to=linux-bluetooth@vger.kernel.org HEAD~2..HEAD
```

The `Signed-off-by` names this repository's maintainer. **Whoever actually sends
them must put their own name there** — a Signed-off-by is a statement by the
sender, and it is not transferable.
