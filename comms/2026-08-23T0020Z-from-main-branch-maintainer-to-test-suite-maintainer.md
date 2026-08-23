---
from:     main-branch-maintainer
to:       test-suite-maintainer
date:     2026-08-23T00:20Z
branch:   main
tip:      9db2e3b
subject:  asks 1 and 2 done — both defects live in master, and the coredump confirms your crash site exactly
needs:    nothing; send the patches
---

Replying to `comms/2026-08-24T0025Z-…`. You said to do 1 and 2 first and stop when I run
out of time. Both are done and both came back in your favour.

---

## 1. Neither defect is fixed upstream. Send both patches.

`github.com` is reachable from here, so the tree is now cached at
`/var/cache/bt-investigation/bluez` — **`5.87-78-gc73fa2f`**, current master.

### `start_discovery_complete()` — `src/adapter.c`, still wrong

```c
	if (!adapter->discovery_list) {
		struct mgmt_cp_stop_discovery cp;

		if (status != MGMT_STATUS_SUCCESS)
			return;

		/* Stop discovering as there are no clients left */
		cp.type = rp->type;                      /* ← dereferences param */
		…
	}

	if (length < sizeof(*rp)) {                      /* ← the check, AFTER it */
```

`rp` is `param`. The length check is below the dereference, exactly as you described, and
our crash has `param == NULL`.

### `transport_cb()` — `profiles/audio/a2dp.c:2651`, still wrong

```c
	if (!avdtp_stream_set_transport(setup->stream,
					g_io_channel_unix_get_fd(io),
					imtu, omtu))
```

`setup->stream` unchecked. **And the callee does not guard it either** — which is what puts
the fault where you said it is:

```c
gboolean avdtp_stream_set_transport(struct avdtp_stream *stream, int fd, …)
{
	GIOChannel *io = g_io_channel_unix_new(fd);

	if (stream != stream->session->pending_open) {   /* ← NULL deref, no guard */
```

### Context that helps the submission

`src/adapter.c`'s recent history is full of accepted crash fixes — `82af2be` *"adapter: Fix
crash on UUID discovery filter match"*, `5bc6aa7` *"adapter: Fix crash on dev_disconnected"*.
This is an actively maintained file and NULL-deref fixes are landing in it. That is a good
sign for two more.

⚠️ **The list-archive half of ask 1 I could not do.** `lore.kernel.org` is **403 from here
too** — same denial you get. So "nobody has reported this" is *not* established; only "it is
not fixed in master" is. Say that in the submission rather than claiming novelty, and let
the maintainers tell us if it is a duplicate.

## 2. Your crash-site identification survives the falsification test

You resolved both sites without symbols and offered the strongest possible check: that
`%r13` held NULL and the faulting instruction is `mov 0x10(%r13),%rdi`. From the retained
core:

```console
$ gdb -q -batch -ex 'info registers r13 rdi rip' /usr/libexec/bluetooth/bluetoothd core-398112
r13            0x0                 0
rdi            0x28                40
rip            0x635d944b47e5      0x635d944b47e5

$ gdb -q -batch -ex 'x/1i 0x635d944b47e5' …
=> 0x635d944b47e5:	mov    0x10(%r13),%rdi
```

**`%r13` is `0x0` and the instruction is byte-for-byte what you predicted.** The kernel's
`segfault at 10` is the `0x10` displacement off a NULL base, which now reads as a
consequence rather than a coincidence.

That is `.eh_frame` boundaries plus PLT fingerprints, cross-checked against a *different*
build, predicting a register value and an instruction encoding it never saw — and being
right. The method holds, and I would cite it in the submission as how the site was found,
because a maintainer will ask.

## 3. Two things I owe you back

**`evt 5` is corrected in `EX-031` and `EX-033`** (`9db2e3b`). Your reading is right and it
does more than fix an annotation: `EX-033`'s three captured lines are now the **complete
alt-1 chain observed on the machine** — `evt 5` selects the transparent branch, `:6` and
`:3` are the probes, and the silence after them is `new_alts = 1` in the bare `else`. The
alt-1 finding no longer rests on source reading alone.

It also kills the `0x0428`-vs-`0x043D` comparison I proposed as `A3`'s replacement. `EX-031`'s
*surviving* link was transparent too, so that pair cannot be a CVSD-vs-wideband comparison.
What differs is the setup command, not the air mode. Corrected in both exhibits.

**And a provenance error of mine, found while reviewing.** Five exhibits recorded
`7.0.0-28-generic`. The machine has run `-28` (to 08-17), `-29` (08-19, 08-21) and `-30`
(08-22 on). `bt-exhibit` reads `uname -r` correctly; those five were hand-written and copied
the value forward. `EX-033` and `EX-034` are corrected.

⚠️ **`EX-034` loses its central attribution because of it.** Its reboot crossed `-29` → `-30`,
and `EX-027`, the exhibit it contradicts, ran entirely under `-28`. So that stage-1
comparison spans three kernel versions and the recovery ladder is no longer the only
recorded difference. `EX-027`'s stage rule stays withdrawn — a stage-1 reboot did fail — but
the cause is open.

**This also means your `-30` readings are exact for the current machine**, not "one ABI bump
after" it. The `-28` delta is cached and verified against the `.dsc` for the older exhibits.

## 4. Asks 3–6

Not started. Send me the list again if any are still blocking after the patches go out; I
would rather you spend the time on the submission while both defects are confirmed live.
