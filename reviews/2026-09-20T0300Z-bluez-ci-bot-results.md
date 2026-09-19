# The BlueZ CI bot on both patches — 2026-09-20T03:00Z

The list's CI bot (`bluez.test.bot`, patchwork) answered both mails within ninety
minutes of receipt (0001 at 2026-09-19 22:05 UTC, 0002 at 22:10 UTC). The two
mails were saved from the operator's mailbox as HTML and reduced to text with
`scripts/mail-html-to-text.sh`; everything quoted below is from that text.

## Verdicts

| test | 0001 (`14831546`, series 1169362) | 0002 (`14831547`, series 1169363) |
|---|---|---|
| pre-ci_am | success | success |
| CheckPatch | FAIL — 0 errors, 1 warning | FAIL — 0 errors, 1 warning |
| GitLint | FAIL — B3 hard tabs ×16 | FAIL — B3 hard tabs ×11 |
| BuildEll, BluezMake, bluezmakeextell, IncrementalBuild, ScanBuild, CheckSmatch | PASS | PASS |
| MakeCheck, MakeDistcheck, CheckValgrind | not run for this patch | PASS |
| TestFunctional | FAIL | FAIL |

Patchwork's check states for the same two patches
(`scripts/patchwork-checks.sh --patch 14831546` / `14831547`):

```
CheckPatch:warning GitLint:fail TestFunctional:fail   every other check success
```

## CheckPatch — the known quoted line

```
WARNING:COMMIT_LOG_LONG_LINE: Prefer a maximum 75 chars per line (possible unwrapped commit description?)
#153:
  a6986:  41 0f b6 45 00    movzbl 0x0(%r13),%eax     <-- cp.type = rp->type
/home/runner/work/bluez/bluez/src/patch/14831546.patch total: 0 errors, 1 warnings, 12 lines checked
```

```
WARNING:COMMIT_LOG_LONG_LINE: Prefer a maximum 75 chars per line (possible unwrapped commit description?)
#126:
  bluetoothd[398112]: segfault at 10 ip 0000635d944b47e5 sp 00007ffefcba28d0 \
/home/runner/work/bluez/bluez/src/patch/14831547.patch total: 0 errors, 1 warnings, 11 lines checked
```

The same single warning `patches/bluez/checkpatch-check.sh` produced on 09-18:
quoted tool output, exempt under `HACKING` §5. The bot reports only the first
long line per patch; 0001 has a second (the `segfault at 0 …` line, 77 chars).

## GitLint — hard tabs in the quoted code

Every B3 line is a line of C quoted from the tree in the commit message, indented
with the tree's own tabs. 0001, lines 6–36 of the message (16 lines); 0002,
lines 6–28 (11 lines). One of each:

```
6: B3 Line contains hard tab characters (\t): "	if (length < sizeof(*rp)) {"
```

```
18: B3 Line contains hard tab characters (\t): "	if (!avdtp_stream_set_transport(setup->stream,"
```

Nothing in BlueZ's `.gitlint` (read at `c73fa2f9a`) relaxes B3. Quoted code
indented with spaces would clear it; nothing else in either message is flagged.
Whether that is worth a v2 before a maintainer has answered is the operator's
decision, recorded in `patches/bluez/README.md` §Sent.

## TestFunctional — the bot's failure, not the patch's

Both bots failed inside `functional.test_bap`, on two tests, and nowhere else:

```
0001:
FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-sc]      teardown  CoredumpWarning
FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  setup     RemoteTimeoutError
FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  teardown  CoredumpWarning
FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts8-vm3]         teardown  CoredumpWarning
0002:
FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  setup     RemoteTimeoutError
FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  teardown  CoredumpWarning
FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts8-vm3]         teardown  CoredumpWarning
```

The coredumps are AddressSanitizer reports at `bluetoothd` teardown in BAP/GATT
device code. 0001's: `memcmp` in `bacmp` ← `device_addr_type_cmp` ←
`btd_adapter_find_device` ← `att_disconnected` ← `gatt_server_cleanup` ←
`device_free` ← `adapter_remove` ← `adapter_cleanup` ← `main`. 0002's: 8-byte
heap-use-after-free read in `device_get_adapter` ← `find_cig_session` ←
`queue_find` ← `find_cig_enumerate` ← `bap_update_cigs_cb` ← `g_main_loop_run`.
Neither backtrace passes through `start_discovery_complete()`,
`transport_cb()` or `avdtp_stream_set_transport()`.

That the two independent one-file patches fail the same test was suggestive;
patchwork settles it. `scripts/patchwork-checks.sh --failed-functional 60`
(2026-09-20 ~03:00 UTC) — every BlueZ patch among the 60 most recent whose
TestFunctional check failed, with the failing tests taken from the bot's own
comment on patchwork:

```
== 2026-09-19T18:44  14831547  [BlueZ] a2dp: Fix crash on NULL stream in transport_cb
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  on setup  RemoteTimeoutError
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  on teardown  CoredumpWarning
   FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts8-vm3]  on teardown  CoredumpWarning
== 2026-09-19T18:44  14831546  [BlueZ] adapter: Fix crash on short start discovery reply
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-sc]  on teardown  CoredumpWarning
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  on setup  RemoteTimeoutError
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  on teardown  CoredumpWarning
   FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts8-vm3]  on teardown  CoredumpWarning
== 2026-09-19T00:14  14830663  [BlueZ] bap: Fix use-after-free of device referenced by session
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-sc]  on teardown  CoredumpWarning
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  on teardown  CoredumpWarning
   FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts8-vm3]  on teardown  CoredumpWarning
== 2026-09-18T21:59  14830498  [BlueZ,v1] adapter: remove the devices from the list before freeing them
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  on setup  RemoteTimeoutError
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  on teardown  CoredumpWarning
== 2026-09-18T20:21  14830424  [BlueZ,1/3] transport: Preserve Release on late BAP ready
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-sc]  on teardown  CoredumpWarning
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  on setup  RemoteTimeoutError
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  on teardown  CoredumpWarning
== 2026-09-18T16:14  14829898  [BlueZ,v2,1/9] monitor/analyze: Free the channel latency plots
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-sc]  on teardown  CoredumpWarning
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  on setup  RemoteTimeoutError
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3-legacy]  on teardown  CoredumpWarning
   FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts8-vm3]  on teardown  CoredumpWarning
== 2026-09-18T13:27  14829190  [BlueZ] adapter: Set Audio service class bit for A2DP sink
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts7-vm3]  on teardown  CoredumpWarning
   FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts7-vm3]  on setup  RemoteTimeoutError
   FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts7-vm3]  on teardown  CoredumpWarning
== 2026-09-18T00:02  14827448  [BlueZ,1/4] mgmt: Add defines for the long term key types
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts7-vm3-sc]  on teardown  CoredumpWarning
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts7-vm3-legacy]  on setup  RemoteTimeoutError
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts7-vm3-legacy]  on teardown  CoredumpWarning
   FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts7-vm3]  on teardown  CoredumpWarning
== 2026-09-17T20:45  14826833  [BlueZ,v1,1/6] monitor: Route the decoding output through a single function
   FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts7-vm3]  on setup  RemoteTimeoutError
   FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts7-vm3]  on teardown  CoredumpWarning
== 2026-09-17T19:12  14826706  [BlueZ,v5,1/3] shared/bap: Skip local metadata Config callbacks
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3]  on teardown  CoredumpWarning
   FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts8-vm3]  on setup  RemoteTimeoutError
   FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts8-vm3]  on teardown  CoredumpWarning
== 2026-09-17T15:28  14825757  [BlueZ,v3,1/2] shared/bap: Skip local metadata Config callbacks
   FAIL functional.test_bap::test_bap_unicast_set_transport_created[hosts8-vm3]  on teardown  CoredumpWarning
   FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts8-vm3]  on setup  RemoteTimeoutError
   FAIL functional.test_bap::test_bap_unicast_set_transport_acquire[hosts8-vm3]  on teardown  CoredumpWarning
```

Twelve patches from ten unrelated series over three days, one of them touching
only `monitor/`, all failing the same two `test_bap_unicast_set_transport_*`
tests and nothing else. The failure is the bot's baseline this week, not a
property of either patch. Two of the series in the list — the `bap:`
use-after-free fix of 09-19 and the `adapter:` device-list fix of 09-18 — read
like attempts at the very crash the bot's coredumps show; whether they land is
the BAP maintainers' business, not ours.

No reply to the bot is owed: the list's convention is that a submitter answers
a bot failure only when it is theirs.

## What this changes

- Nothing in the code of either patch.
- The only actionable item is B3: quoted code in the commit messages carries
  tabs. A v2 with spaces would clear GitLint; whether to send one before a
  maintainer replies is the operator's call (`patches/bluez/README.md` §Sent).
- `scripts/patchwork-checks.sh` exists now, so the next "is this failure ours?"
  is one read-only command rather than an argument.
