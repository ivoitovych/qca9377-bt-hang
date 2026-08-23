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

⚠️ **Not verified: runtime.** Neither NULL condition can be triggered on demand
here — both were observed as crashes in the wild, not reproduced deliberately. The
patches are argued from source and from the disassembly of the binary that
crashed. They prevent a fault that is demonstrably reachable; they have not been
watched preventing it.

⚠️ **`0002` treats the symptom.** It stops the crash without explaining why
`setup->stream` is cleared while the setup is still on the `setups` list. The
patch says so in its own commit message rather than implying a complete fix.

## Before sending — the one open check

**5.87 is a release tarball.** A fix may already exist in `bluez/bluez` master or
as a patch posted to `linux-bluetooth@vger.kernel.org` that has not shipped.
Neither is reachable from the environment these were prepared in.

Check both, and if either defect is already addressed, drop that patch rather than
sending it.

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
