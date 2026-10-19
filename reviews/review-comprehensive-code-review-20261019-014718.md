# Comprehensive code review — 2026-10-19 01:47 UTC

**Tree:** `main` at `91ce9b2` (2026-10-18 17:33 +02:00), read in the main checkout. Nothing was run
except reading and line counts; no tool, test or service was executed and nothing on the laptop was
touched.

**How this file is written.** Findings are appended while the review proceeds, file by file, so
nothing found is lost before the end. The summary and the ranked list come last. Each finding names
the file and line, what goes wrong in which situation, and the fix. Severity:

- **HIGH**: can lose evidence, publish something that must not be published, or act on the controller in a way the
  project's own rules forbid;
- **MED**: a wrong record, a misleading result, or an operational trap;
- **LOW**: robustness, clarity, small inconsistencies;
- **INFO**: observations, no change needed.

"Latent" means the defective path is not used on the laptop today, by rule, but nothing in the code
stops it.

**Size.** About 40,000 lines of code: `tools/` 8,758, `tools/lib/` 1,491, `devtools/` ~4,990,
`scripts/` 6,429, `bin/` 1,802, `install.sh` 764, `uninstall.sh` 332, `tests/run-tests` 14,195,
`tests/system-*` 483, CI 418. Coverage of this review is stated per section ("read in full" or
"skimmed").

---

## 1. `tools/bt-trial` (1,247 lines, read in full)

**T1 — MED. An interrupted close leaves the trial open after its row is written, and the next close
writes a second row.** `hang|ok` appends the results row at 1031, then runs `bt-state`, `bt-mark`
and the whole-capture SCO decode, and removes `$CUR` only at 1126. If the close stops anywhere after
the row, `/run/bt-trial/current` survives with its row already written:
- Ctrl-C during a manual `bt-trial ok`;
- `systemctl stop` or `restart` of `bt-trial-auto` without a reboot;
- `scripts/trial-close-now.sh` killed mid-run.

The next `autostop` or `ok` then appends a second row with the same trial number, counted twice in
every denominator. A shutdown is safe only because `/run` goes with the boot. This came in with the
row-first reorder of 2026-10-16/18.
*Fix:* remove (or rename) `$CUR` immediately after the row is appended. Nothing after 1031 reads it;
`$start`, `$dir`, `$build` and `$n` are already in variables.

**T2 — MED (known, still open on `main`). The closer's SCO decode can never match, and it still reads
every capture whole.** Line 1084 runs `COLUMNS=200 btmon -T -r`. `COLUMNS` is ignored when stdout is
a pipe, so the header is shortened to `< HCI Comman..` and `/HCI Command: Setup Synchronous
Connection/` never matches. Every closed trial that saw SCO setups gets the "(no Setup Synchronous
Connection …)" line, a false negative. The loop also decodes every file in both capture directories
(about 48 GB), so after any call each shutdown runs until the stop timeout kills it (30 s with
`main`'s unit). It is harmless to the row since the reorder, but it wastes the shutdown.
*Fix:* use what `scripts/trial-sco-decode.py` already does: `--columns=200`, and decode only the
files whose mtime follows each kernel-logged setup.

**T3 — LOW-MED. A manual `start` reuses a lost-row trial number and overwrites that trial's files.**
Lines 352-359: `next_trial_no` counts rows, so a trial whose row was lost gets its number reused.
`start` then runs `mkdir -p` on the existing directory, rewrites `state-before.txt` and truncates
`steps.log` (`: > "$dir/steps.log"`). `autostart` got the set-aside fix at 411-415; `start` did not.
*Fix:* move the same set-aside block into a function and call it from both paths.

**T4 — LOW. `autostop` counts timeouts with an unchecked pipeline.** Line 457 uses `journalctl … |
grep -c … || true`, the pattern the file itself condemns at 495-500. The effect is limited: the count
only chooses `hang` or `ok`, and the `ok` path re-reads the journal with a checked read. But a failed
read on a boot that did have timeouts produces `trial_result=ended_unprobed` beside
`bt1_status=confirmed`.
*Fix:* call `jread` here too, and pass a third state ("unreadable") to the classifier.

**T5 — LOW. A trial spanning the DST change can pick the wrong SCO setup.**
- At 849-850, setup and timeout times in `short-iso-precise` form are compared as strings. The UTC
  offset changes on 2026-10-25 (+02:00 to +01:00), so a trial spanning it can take a later setup as
  the "nearest preceding" one.
- The decode filter at 1091 compares `btmon -T` local times, which carry no offset, and the repeated
  hour is ambiguous.

*Fix:* compare epoch seconds (`date -d`, or `-o short-unix`).

**T6 — LOW. `bt-trial status` reads the trial's whole window unfiltered and with no time limit.**
Line 1220. On a five-day trial with dynamic debug this takes minutes. The operator runs it by hand,
so nothing is lost, but it looks hung.
*Fix:* take the timeout count from `-p err`, and read the descriptive counts under
`BT_TRIAL_SCAN_BUDGET` with `--grep`, as the closer does.

**T7 — INFO.** `start` and a hand-typed `ok` still probe the controller with `hci_alive` (HCI Read
Local Name). This is documented and deliberate. `abort` on `main` is safe: it renames the directory
and writes `ABORTED`, and `--discard` refuses tracked files. The copy installed on the laptop (the
2026-08-16 version) still runs `rm -rf "$dir"` (STATUS, "The investigation machine").

## 2. `tools/lib/trial-summary.awk`, `trial-reclass.awk`, `journal.sh` (read in full)

**L1 — LOW. Nothing detects a duplicate row.** `trial-summary.awk` would count T1's duplicate twice.
*Fix:* key rows on `build` plus `trial` and refuse (or flag) a repeated pair. That is cheap
insurance whatever the writer does.

**L2 — INFO. Report row order depends on the awk implementation.** `for (k in tot)` iterates in an
order the implementation chooses, and mawk and gawk differ. The fixtures pass in CI, but the order
is not part of any contract. Sort the keys if the report is ever compared across machines.

`journal.sh` is a clean seam. `bt_journal_count` and `bt_journal_lines` carry the counted form
everywhere.

## 3. `bin/bt-mark`, `tools/bt-state`, `scripts/trial-close-now.sh` (read in full)

**M1 — MED. The probe-free tools still crash the capture.** `bt-mark` (line 44) and `bt-state` (line
78) run `bluetoothctl devices Connected`. `bluetoothctl` opens a management socket when it starts.
That MGMT open is a BT-4 trigger: it crashed the capture's `btmon` on three of six opens on
2026-10-18 (STATUS, BT-4 row). `bt-trial` calls `bt-mark` at start, at every `step` and at close, and
`bt-state` at open and close. So every operator step mark costs about one second of HCI trace at
exactly the moment being marked.
*Fix:* count connected devices without a MGMT open: either `busctl` over D-Bus (`org.bluez`
`Device1.Connected`), or the `hci0:<handle>` connection entries in sysfs.

**M2 — LOW. `bt-state` reads a whole boot with no budget, and one read is unchecked.**
`bt_journal_count … -k -b 0` reads the whole boot with no time limit. The `-u bt-hang-watchdog …
| grep -c … || true` read at line 77 is unchecked, so a failed read reports 0.

`trial-close-now.sh` is sound. Its check that `$CUR` is gone (line 54) is what would surface T1. It
leaves an empty `tmp/trial-close-nocapture.*` directory per run (clutter only).

## 4. `install.sh` (764 lines, read in full)

**I1 — HIGH (latent: the `--apply` path). The installer still reloads btusb live.** Lines 698-729
run `modprobe -r btusb; modprobe btusb` when the use count is 0 and the boot has logged no command
timeout. EX-046 shows that a reload kills even a **healthy** controller on this machine. The guard
encodes EX-016 (a wedged controller) but not EX-046. `--apply` is forbidden on the laptop only by
documentation.
*Fix:* delete the live reload. Always print "the autosuspend setting applies at the next boot".

**I2 — MED, matters on deploy day. `--tools-only` still reads the whole boot's kernel log.** Under
`--tools-only`, `APPLY=1`. So lines 715-716 still run `journalctl -k -b 0 | grep -c` over the whole
boot, unfiltered and with no time limit, only to decide on a reload that `run()` then refuses. On the
laptop the boot began 2026-10-13 20:29 and has run with dynamic debug since. The project's own
measurements say this read takes many minutes:
- 180 s for a filtered read of one 24-hour boot;
- unfiltered multi-day reads "do not finish in ten minutes".

The deploy will look hung at `[7/7] activate`. Every file is installed before that point, so an
interrupt there loses only the closing summary.
*Fix:* skip the whole block under `TOOLS_ONLY`, and use the `-p err` priority index (as `bt-trial`
does) where a timeout check is still needed. The same unfiltered read sits at 274, on the forced
experiment-mode path.

**I3 — LOW (wording). The watchdog-reset citation should be checked against the exhibits.** Lines 11
and 35-36 cite "three controlled demonstrations of driving an already-wedged controller off the USB
bus" (EX-023, the 2026-08-15 test, EX-026). EX-026's own table should be re-read before this sentence
is repeated. The rule it supports (never `--apply`) stands on EX-005 and on EX-023's
watchdog-ended windows.

**I4 — INFO. Two things `--tools-only` does that are worth knowing:**
- It still writes the generated udev rules and the modprobe override wherever no `.disabled` sibling
  exists. By design these are files that apply at the next boot.
- Running daemons keep their old code until restarted. `install` unlinks the destination first, so a
  running bash script is not corrupted.

## 5. `uninstall.sh` (332 lines, read in full)

**UN1 — HIGH (latent). The uninstaller reloads btusb live with no guard at all.** Step [5/5], lines
296-299: `modprobe -r btusb; modprobe btusb` when the use count is 0. There is no failed-this-boot
check, no open-trial check, and no knowledge of EX-046.
*Fix:* same as I1.

**UN2 — MED. `--purge-metrics` deletes every raw capture, unarchived ones included.**
`--purge-metrics` runs `rm -rf /var/log/bt-health`. That includes captures that exist nowhere else
(today the U10 captures and the two BT-9 correction captures). This contradicts "evidence is never
deleted".
*Fix:* refuse while any capture is missing from `archive/bt-trace/MANIFEST.tsv`, or remove the flag.

**UN3 — INFO. The "complete restoration" summary leaves the E3 module out.** It does not mention
`updates/btusb.ko`, placed by `scripts/module-updates.sh`, or the depmod state. Say so in the closing
text.

## 6. `systemd/*`, `etc/*` (units and configs read)

- **SD1 — LOW. The shutdown close waits on a `bluetoothd` that is already stopped.**
  `bt-trial-auto.service` is `Before=bluetooth.service`, so at shutdown it stops *after* bluetoothd.
  The close's `bt-state` and `bt-mark` then wait out their 8 s `bluetoothctl` timeouts each. This is
  after the row, so harmless to it, but it spends most of the 30 s stop budget. M1's fix removes the
  wait as well.
- **SD2 — INFO (latent). The watchdog's own row write is unverified.** `bt-hang-watchdog.service`
  sets `ProtectHome=yes`. The watchdog's device-absent path writes a trial row into the checkout
  under `/root`. The unit's comment asks for this to be verified; it is not recorded as done. The unit
  is not enabled on the laptop.
- `bt-trace.service` sets no `UMask`, but `bin/bt-trace` sets `umask 077` and `chmod 0700` on its
  directory. Captures are readable by root only. OK.

## 7. `bin/bt-trace`, `bin/bt-capture` (read in full)

**CAP1 — HIGH, time-sensitive. Both capture daemons will delete captures that exist nowhere else.**
Both prune oldest-first by count (400) and by the free-space floor, with no knowledge of the
archive. The archiver (`scripts/bt-trace-archive.py`) has been paused since 2026-10-11, and its
timer was lost at the 10-13 reboot. Its manifest ends at `bt-20261009-063545`. So rotation will
delete the U10 captures (2026-10-11) and the two BT-9 correction captures (2026-10-10), which exist
nowhere else. STATUS (2026-10-17) estimates about 8 days at the 10-13 rate and about 3 weeks at the
10-17 rate.
*Fix, now:* restart the archiver, or copy those captures to the keep directory. Restarting it is the
operator's decision.
*Fix, in code:* `prune` should set aside (not unlink) any capture absent from the manifest, unless the
free-space floor forces it, and say so in its log.

**CAP2 — LOW. When `bt-trace` stops for lack of space, it deletes the file it was writing.**
`disk_guard` runs `rm -f "$CURRENT"` (line 125), and that file holds the most recent moments.
*Fix:* keep it, close it and stop.

`bt-capture` is careful code:
- it checks the return value of `prune()`;
- capture names are collision-free;
- its timestamps are userspace receive time, as documented.

## 8. `tools/bt-mode` (202 lines, read in full)

**MODE1 — HIGH (latent, laptop). `bt-mode mitigation` arms the watchdog, and the installer tells the
operator to run it.** `set_mitigation` (line 187) runs `systemctl enable --now bt-hang-watchdog` and
re-enables the probe timer. That arms the watchdog the Foundation forbids, for the same reason as
`--apply`. `install.sh`'s own messages tell the operator to run it:
- line 175: "leave experiment mode with 'bt-mode mitigation' to reinstall it";
- line 252.

The laptop is in experiment mode today (STATUS: the modprobe file is `.disabled`).
*Fix:* have `mitigation` restore the power policy only, and put the watchdog behind an explicit
`--with-watchdog` that cites EX-005 and EX-023. Reword `install.sh`'s hints.

**MODE2 — LOW. `bt-mode status` prints "inactive" twice for each inactive unit.** Line 129 has
`systemctl is-active "$u" 2>/dev/null || echo inactive`, the bug `bt-trial` fixed at 198-202. This
is the command the deploy checklist ends with.

`experiment` and `mitigation` write sysfs live, which is documented ("check `bt-window` first").

## 9. `scripts/module-updates.sh`, `scripts/btusb-has-device.py` (read in full)

**MU1 — LOW. Installing or removing a module discards the E3 module with no copy.** `install`
overwrites an existing `updates/<mod>.ko` with no copy kept; `remove` deletes it. E3 is reproducible
from its build branch (`diag/…`), but after a replace the identity of what ran survives only in the
documents.
*Fix:* keep `<mod>.ko.prev-<srcversion>` beside it.

**HD1 — LOW-MED. FOUND proves the table entry exists, not that it carries `BTUSB_QCA_ROME`.**
`btusb-has-device.py` searches for a `USB_DEVICE(vid,pid)` entry. A kernel whose entry carried
different flags would also read FOUND, and the Foundation's kernel-update rule rests on this check.
*Fix:*
- read the `driver_info` (`kernel_ulong_t`, offset 24 of `struct usb_device_id` on x86-64) after
  the match;
- compare it with the `0cf3:e300` control's `driver_info` in the same binary (both are
  `BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH` upstream). That comparison holds across kernel versions.

The whole file is searched, not just the table; a stray 6-byte match is unlikely but possible.

## 10. `scripts/bt-trace-archive.py` (read in full)

**AR1 — MED. Even when running, the archiver keeps only one of the two capture paths.** It archives
only `bt-*.btsnoop` from the trace directory (and the keep directory). The decode-free capture path
(`/var/log/bt-health/capture`, `hci-*.btsnoop`, written by `bt-capture`) is never archived. That is
the path that exists because `btmon` loses data, and it rotates away unarchived even while the
archiver runs. `trial-sco-decode.py` reads both paths.
*Fix:* add the capture directory as a third source, with prefix `hci-`.

Otherwise the archiver is careful:
- it verifies each archive by decompressing it;
- it renames into place only after that check;
- it never deletes anything.

## 11. `scripts/trial-sco-decode.py`, `scripts/trial-snapshot.sh` (read in full)

Both are sound:
- `--columns=200`;
- addresses redacted;
- files chosen by mtime;
- the snapshot runs the closer sandboxed, on a PATH without `/usr/local/bin`.

Two small points:
- **SD-1 — LOW.** `captures(d)` raises if a capture directory is missing.
- **SD-2 — LOW.** `btmon -T` local times are ambiguous in the repeated hour on 2026-10-25.

## 12. `devtools/save`, `devtools/repo-save` (read in full)

**RS1 — HIGH (privacy, fails open). `repo-save` pushes every branch to `origin` unless its name is
on a short list.** It sends to the `private` remote only for `kernel/*`, `plan/*`, `diag/*`,
`review/*`, `attribution/*`, `postponed/*` and `config/*` (line 204); every other branch goes to
`origin`. Branch families that must never reach `origin` but are missing from the list would be
pushed there by a `devtools/save` run while checked out here:
- `research/*`;
- `backup/*`;
- the pseudonym-table branch.

Today that is prevented only by a working rule ("never check those out in the project checkout").
*Fix:* invert the rule. Push to `origin` only for an allowlist (`main`, `tests/*`, `ci/*`, …) and
send everything else to `private`. Refuse when no `private` remote exists.

**RS2 — LOW. Pseudonymized addresses look like real ones to the message scan.** The scan for real
MACs in the commit message (line 133) exempts a fixed prefix list. Addresses rewritten by the
pseudonym tool keep the manufacturer prefix by design, so a pseudonymized address in a message reads
as "real" (false positive). A real address under an exempted prefix passes (false negative).
*Fix:* check against the pseudonym table's known substitutes, not prefixes.

**RS3 — LOW. `devtools/save --full` passes an empty argument down.** `set -- "${@/--full/}"` (line
138) leaves an empty argument, which `repo-save` takes as its (unused) message. It is harmless today.
Filter the argument out instead of blanking it.

The push itself is verified properly: the remote hash is compared with the local one after a fetch,
so a failed push cannot report success even though its exit status is lost in `| tail -3` (line
209).

## 13. `devtools/repo-scan`, `devtools/held` (read in full)

**SC1 — MED (privacy). The publishing gate misses addresses in raw byte form.** The MAC detector
(line 84) finds addresses written with `:`, `-` or `_`. It does not find them as raw bytes. A `btmon`
decode with hex-dump lines carries every address as six space-separated bytes in reverse order
(`55 44 33 22 11 00`). A capture decode committed with its hex lines passes this gate. The project
has a checker that knows every form and both byte orders (`addr-pseudonym.py check`), but it is
kept outside this checkout with its table, and the gate never calls it.
*Fix:* when that checker is present at a configured path, `repo-save` runs it on the staged
additions and fails on any hit. Absent, `repo-save` prints that the strong check did not run.

**SC2 — LOW. The scan is lighter than its contract.** Device names are not scanned: the
neutral-naming rule is not mechanical. The IPv4 pattern can flag four-part version strings. These are
known limits of a pattern scan; list them in the header so nobody reads "scan clean" as more than it
is.

**HE1 — LOW. `held sync` does not check that its push landed.** It pushes with `git push -q private
"$HELD" | tail -1` (line 56) and checks nothing, unlike `repo-save`, which compares the remote with
the local commit.
*Fix:* fetch `private` and compare, as `repo-save` does.

Good:
- `held status` fails if `origin` carries any `kernel/*` branch;
- `sync` refuses a dirty tree;
- `repo-scan` refuses to report clean on an empty read;
- `repo-scan` detects tracked binaries by content, not by extension.

## 14. `devtools/repo-validate`, `.github/workflows/checks.yml` (read in full)

**RV1 — LOW-MED. Python files without a `.py` extension are never syntax-checked.** The validator
finds shell by shebang or `.sh`, but Python only by `.py` (line 125). So `bin/bt-capture`, the
decode-free capture daemon, is never parsed by the validator. That covers every Python file without
the extension (worth checking which of the devtools are Python). The suite and the Python coverage
job do execute `bt-capture`, so a syntax error would still surface, but as a test failure far from
its cause.
*Fix:* also treat `^#!.*python` shebangs as Python.

**CI1 — LOW. Shell code has no static analysis.** About 30,000 lines of bash and no `shellcheck`
pass. It is listed as an open decision. A first run in warning-only mode, kept to the classes that
have bitten this project, would be cheap:
- unquoted expansions;
- `grep -q` under `pipefail`;
- `|| echo` after a command that prints;
- `cd` without `||`.

**CI2 — LOW. The deploy rehearsal checks correctness, not time.** It cannot see I2: its journal is
seconds old, while the laptop's is days of dynamic debug. One assertion would catch it: under
`--tools-only`, `install.sh` must issue no whole-boot journal read, checked through the call log the
sandbox already keeps.

**CI3 — INFO. The workflow's permissions and pins.**
- `permissions: contents: read` — good.
- Actions are pinned by tag (`actions/checkout@v4`), not by commit; acceptable for a first-party
  action.
- The eight jobs repeat one 20-line preamble verbatim; a composite action in
  `.github/actions/preamble` would keep them from drifting apart.

## 15. `tools/sanitize-logs.sh` (231 lines, read in full)

The awk capability gate (probing each pattern both ways) and the build-verify-rename path are
exemplary. Four gaps, all on what it does not cover:

**SAN1 — MED (privacy). IPv6 addresses are not handled, and the common kind carries a hardware
address.** A SLAAC/EUI-64 address (`fe80::1234:56ff:fe78:9abc`) embeds the interface's MAC with
`ff:fe` in the middle, so publishing it publishes the Wi-Fi or Ethernet MAC. Kernel and
NetworkManager lines carry such addresses. `repo-scan` does not catch them either.
*Fix:* add an IPv6 pass (at least `fe80::` and any address with `ff:fe` at bytes 11-12) to both
the sanitiser and the scan.

**SAN2 — LOW here, MED in general (privacy). The journal's host name is left in place.** Every
short-format `journalctl` line carries the host name (`<host> kernel: …`). The tool promises to
"strip identifying data" but covers only MAC, UUID and IPv4. On the laptop the host name is a single
letter, so nothing personal leaks today. On another machine (Ubuntu's default host name is often
built from the owner's name) every incident log would carry it.
*Fix:* replace the running host's name (`hostname`, `/etc/hostname`) and the login names under
`/home` with fixed placeholders. Verify none remain.

**SAN3 — LOW-MED. The same device gets a different placeholder in each file.** Placeholders are
numbered per run, so the same address becomes `AA:BB:CC:00:00:01` in one file and `…:03` in the
next. `-i` sanitises each file in its own run. Two logs of one incident then disagree on which device
is which, and a reader can draw a wrong conclusion.
*Fix:* number across all files of one `-i` call (one awk over all inputs, a mapping file per
batch). The pseudonym table kept outside this checkout already does this; say in the header that it is the
tool to use for anything published as a set.

**SAN4 — INFO.** Raw byte-form addresses in hex dumps are out of scope, as with SC1. Say so in the
header ("text forms only; not hex dumps").

## 16. `tools/bt-verify-install`, `tools/bt-incident` (read in full)

**VI1 — MED, matters on deploy day. On any drift the verifier recommends the forbidden command.** The
last step of the deploy checklist (`install.sh --tools-only`, `daemon-reload`,
`bt-verify-install`, `bt-mode status`) ends on line 166: `Run: sudo ./install.sh --apply`. The
file's own comment (44-48) says the tools must not push the reader toward `--apply`, yet any
remaining drift prints exactly that. And on this laptop drift is likely:
- every unit `install.sh` *would* enable is expected active and enabled;
- `--tools-only` enables none;
- the watchdog is off by rule.

*Fix:* print `sudo ./install.sh --tools-only` and the reason for the drift. Never suggest
`--apply` from a tool that runs on the investigation machine. Treat a stopped `bt-hang-watchdog` as
expected whenever the mode stamp or a local policy file says so, not only in experiment mode.

**INC1 — LOW. `bt-incident`'s journal reads are unchecked.** All five reads are `… || true`, so an
unreadable journal yields empty logs and a manifest of zeros that reads like a quiet window. Record
each read's exit status in `MANIFEST.txt`.

**INC2 — INFO.** `bt-incident` writes sanitised logs into `evidence/sessions/`, which is tracked and
pushed to `origin`. It is therefore exactly as safe as `sanitize-logs.sh` (§15). Its refusal path (sanitiser
missing or failed → non-zero exit and a manifest that says so) is right.

## 17. `bin/bt-hang-watchdog` (454 lines, read in full; not enabled on the laptop)

**WD1 — MED (design out of date). The watchdog's premise no longer holds under E3.** Its header
(5-13) justifies it as a stand-in for a reset handler the device lacked: "13d3:3503 appears not to
be matched by btusb's vendor quirks table … never receives `hdev->reset = btusb_qca_reset()`". That
was true of the stock driver. Under E3, and on every kernel that carries `dc16388d45ec`, the device
is matched with `BTUSB_QCA_ROME`, and that path sets the kernel's own reset on the first command
timeout. An armed watchdog would then add a userspace reset (and an unbind/bind) on top of the
kernel's, on a controller the project has shown is harmed by exactly that.
*Fix:*
- refuse to act, or log only, when the loaded btusb carries the entry (`/sys/module/btusb/version`
  or `scripts/btusb-has-device.py` on the module);
- update the header to say the tool belongs to the stock-driver era.

**WD2 — LOW. Once the watchdog gives up, a `systemctl stop` takes up to 90 s.** On give-up it idles
with `while :; do sleep 3600; done` in the foreground (446). bash defers SIGTERM until the `sleep`
returns, so the stop hangs until `TimeoutStopSec` expires and SIGKILL follows. `bin/bt-trace` fixed
the same pattern with `sleep 3600 & wait $!` (line 132).
*Fix:* do the same here.

**WD3 — INFO.** The trigger is deliberately broader than the counting pattern (it accepts `link tx
timeout`), and the comment owns that trade-off.

*(§18 follows the watchdog's last note below.)* The unbind and bind go through the generic USB
driver (`/sys/bus/usb/drivers/usb`), so the whole device re-enumerates; this is documented as the
escalation step.

## 18. `tools/bt-snapshot` (406 lines, read in full)

Its passivity contract (no HCI, no D-Bus; BlueZ state from the journal) is honoured, and it refuses
a destination inside the repository using `pwd -P`. Three points:

**SN1 — MED. Presence is read from a fixed port, and the adapter name from whichever adapter comes
first.**
- `PRESENT` checks `[[ -e "$SYSFS/3-3" ]]` (line 225), a fixed bus path, and the `f-usb` cut greps
  `usb 3-3` (line 129). Every other tool resolves the device by VID:PID, because "after a reset it
  can re-enumerate at a different address" (`bt-trial`, 938-940). So in exactly the situation this
  tool is run for, it can print `controller on bus no` while the radio sits on another port, or
  `yes` for whatever device holds 3-3.
- `HCI` is the first `hci*` of any adapter (226). The watchdog notes "a spare dongle is frequently
  hci0".

*Fix:* resolve both through VID:PID, as `bt-trial`'s `hci_alive` does (without the probe).

**SN2 — LOW. The snapshot directory grows without bound.** `/var/tmp/bt-snapshots` has no
retention, and each cut is a whole boot, unfiltered (by design). On a multi-day dynamic-debug boot
`all.log` runs to gigabytes on the root filesystem the capture daemons protect with a 15 GB floor.
*Fix:* print the cut's size, and add a `--prune N` mode.

**SN3 — INFO.** "mtu 9 = alt 1" (line 220) is right for this controller under both the stock driver
and E3. It is worth one line saying it is a property of this device's endpoint table, not of
btusb.

## 19. Small operator scripts: `smtp-login-check.sh`, `stop-own-process.sh`, `copy-tree.sh`, `pre-send-check.sh`, `export-local-work.py` (read in full)

**SM1 — MED. A connection failure exits with the same status as REVOKED.** The header promises
exit 1 = REVOKED, 3 = INCONCLUSIVE, and the code says a dropped connection is "never read as
revoked". But only `SMTPAuthenticationError` and `SMTPServerDisconnected` are caught. Every other
failure ends in a traceback and exit status 1, the REVOKED code:
- a connect timeout (exactly what port 587 did from this network on 2026-10-18);
- connection refused;
- a TLS error;
- a DNS failure.

A person reading the output sees the traceback, but anything keying on the exit status reads
"revoked" — the one wrong answer this tool exists to rule out.
*Fix:* catch `OSError` (which covers `socket.timeout`) and `smtplib.SMTPException` around connect,
STARTTLS and login, then print INCONCLUSIVE and exit 3.

**SM2 — MED (secret handling). The documented usage puts the app password on the command line.**
`BT_SMTP_PASS='xxxx …' scripts/smtp-login-check.sh` leaves the password wherever command lines are
kept (shell history, any command log).
*Fix:* read the password with `getpass` from the terminal, or from a file descriptor (`--pass-fd 3`),
and drop the environment variable from the usage line.

**PS1 — INFO. `pre-send-check.sh` can only err toward not sending.** `git log -F --grep="$subj"`
matches the subject anywhere in a message, including a later commit's `Fixes: … ("subject")` line.
A false "ALREADY APPLIED" stops a send, which is the safe direction. Anchor on the subject line
(`--grep="^$subj$"` without `-F`, escaped) if it ever misfires.

**EL1 — LOW. `export-local-work.py` can report patches it never wrote.**
- The `format-patch` exit status is ignored (line 44), so a failure leaves a directory with no
  patches while the summary prints "N commit(s)".
- `format-patch` drops merge commits, so local work that contains a merge loses its resolution
  without saying so.

*Fix:* check the exit status, and count the `.patch` files written against `len(local)`.

**SO1 — LOW. `stop-own-process.sh` matches its own project path anywhere in the command line.** The
check is a substring match (`*"$REPO"*`), so any process with a project path in its arguments
qualifies: an editor, a pager, `tail -f` on a log. That is acceptable for a tool the operator runs
by hand, but say so. The refusal list covers the host's Bluetooth and audio daemons. Line 9 still
uses the older wording for the laptop (see the wording note in §22).

`copy-tree.sh` is sound:
- it never overwrites;
- the destination must be inside the project;
- a raw capture copied from `/var/log/bt-health` into an unignored path is still stopped at commit
  time by `repo-scan`'s binary checks.

## 20. `tools/bt-window`, `tools/bt-status` (read in full)

**BS1 — LOW-MED. `bt-status` can call the controller up while it is down.** Its verdict decides
"controller is down right now" from `ls -A /sys/class/bluetooth | head -1` (line 90): any adapter at
all. With a spare dongle plugged in, it reports a working controller while the QCA9377 has no hci
node.
*Fix:* resolve the hci node under the VID:PID device, as `bt-mark` and `bt-state` do.

**BS2 — LOW-MED. `bt-status` holds the whole boot's bluetoothd log in memory.** It captures
`journalctl -u bluetooth -b 0` into a shell variable (line 57) on the assumption that "a unit
journal is small". This project runs `bluetoothd -d` (`etc/systemd/bluetooth.service.d/10-debug.conf`),
so on a multi-day boot that unit's journal is large: the same memory and time problem the comment
fixed for the kernel log.
*Fix:* count through `bt_journal_count`, as it already does for the kernel.

**BS3 — LOW. Part of the verdict text predates the cause.** The early-intervention branch (111-117)
still discusses whether "the kernel patch" (a reset handler) would help, with references to
`docs/fix-proposal.md` and BT-3. That is the stock-driver framing, now superseded by BT-1's cause.
Point it at BT-1 and E3.

**BW1 — INFO. `bt-window` checks presence through `lsusb`.** `lsusb` without `-v` reads sysfs
and the hwdb. A plain sysfs VID:PID loop, as in the other tools, would keep the passivity argument
free of a dependency on how `lsusb` is built. The window logic itself is sound: it counts from the
first timeout forward and takes the intervention patterns from the seam.

## 21. `tests/system-upgrade` (274 lines, read in full)

A strong test. It installs the 2026-09-18 tree for real, opens a trial with the old `bt-trial`,
deploys `--tools-only` from the checkout and then checks:
- only file operations ran;
- exactly the changed destinations changed;
- no `.pre` copies were made;
- unit states and the mode baseline are untouched;
- the stop closes the old trial with the new closer inside its timeout;
- the uninstall restores the machine.

**SU1 — LOW-MED. The rehearsal stops one step short of the real checklist.** The checklist is
`--tools-only`, `daemon-reload`, `bt-verify-install`, `bt-mode status`. The rehearsal runs the
first two and never the last two. Running them would have shown VI1 (the verifier's `--apply`
advice) and MODE2 (the doubled "inactive") in CI. Its journal is also seconds old, so I2 (the
whole-boot read under `--tools-only`) cannot show.
*Fix:*
- run both commands and assert that the output names no `--apply` and has one line per unit;
- assert from the sandbox call log that `--tools-only` made no whole-boot `journalctl` read.

**SU2 — INFO.** The gate refuses on the investigation machine's checkout path, and the final
`rm -rf "$EVREPO"` removes only a directory the test created after checking it did not exist. That
is safe as written; keep the two together if the file is ever edited.

## 22. `tests/run-tests` (first 140 lines), `tools/bt-ui-capture` (first 260 lines), and a wording note

**RT1 — LOW. The suite is one 14,195-line file.** Its own header still says "9,700 lines" (line 46).
The guards against its own escapes are excellent:
- it refuses while a trial is open;
- it builds the PATH guard before anything else runs;
- its self-scans read a derived file set, ready for the planned split (UT-12).

The size itself is the risk: one file this large is reviewed by search, not by reading. The split
is already planned; the stale line count is a one-word fix.

**UI1 — LOW-MED (operational). Settings from the 2026-10-05 session are still live on the desktop.**
`bt-ui-capture` keeps one mutation path, so `plan` cannot drift from `start`, and every change has a
recorded revert. But per STATUS, these remain in effect today:
- the PipeWire log level;
- WirePlumber's and pipewire-pulse's debug;
- the GNOME Settings launcher overrides under the desktop user's `~/.local/share`.

Its manifest still says "active" while all four recorders are stopped. The overrides are full copies
of system `.desktop` and D-Bus service files, so a `gnome-control-center` update will be shadowed by
the stale copies until `stop` runs.
*Fix:*
- `status` should derive "active" from the units, not from the manifest;
- `status` should flag override files older than the installed package's.

Also, `mark()` uses `bt-mark`, so `start` and `stop` each pay M1 (a `btmon` crash).

**WO1 — INFO (wording).** A few files still use the older wording for the laptop, not "the
laptop":
- `scripts/stop-own-process.sh:9`;
- `systemd/bt-journal-backup.service` (the Nice comment);
- `tools/bt-trial:438`.

New text says "the laptop"; these belong to the pending sweep of older text.

## 23. `tools/bt-backup-journal` (176 lines, read in full)

**BJ1 — MED. The live boot is the one most at risk, and it is never archived.** The skip-boot-0 rule
(26-39) rests on "a live boot cannot rotate off the ring — it is the one boot in no danger". The
project's own record contradicts this:
- STATUS ("The investigation machine", the 10-01 boot): journald discarded that boot's entries
  before 2026-10-06 20:23 *while the boot was still running*;
- the tooling index warns that `SystemKeepFree=20G` can discard a long boot's start.

The laptop's current boot has run since 2026-10-13 20:29 with dynamic debug, which is exactly that
case.
*Fix:* keep the live-boot skip for the *complete* archive. Add a daily segment export of the live
boot (`-b 0 --until <now>`), named as a dated segment, never as the boot. A segment cannot be
mistaken for a whole boot, so the 2026-08-31 prefix problem does not return, and the start of a long
boot survives.

Otherwise sound:
- per-boot failures keep the failing tool's own words;
- a marked prefix is re-archived with `--replace`;
- a plain archive is never replaced.

---

## Summary (written 2026-10-19 01:52 UTC, after §1-§23)

### What was read

About 9,000 of ~40,000 lines (≈22%) were read line by line. They were chosen to cover everything
that, on the laptop:
- runs at boot and at shutdown (trial open and close, capture daemons, units);
- deploys or removes tools (`install.sh`, `uninstall.sh`, `bt-mode`, `module-updates.sh`, the
  rehearsal);
- decides what is kept as evidence (capture retention, the HCI archive, the journal backup,
  `bt-incident`);
- decides what may be published (`repo-save`, `repo-scan`, `sanitize-logs.sh`);
- is the first thing an operator runs in a fault (`bt-snapshot`, `bt-window`, `bt-status`).

**Not yet read:**
- the analysis tools: `bt-actions`, `bt-archive`, `bt-capdiff`, `bt-crash`, `bt-diagnose`,
  `bt-exhibit`, `bt-phase`, `bt-postmortem`, `bt-retention`, `bt-sco`, `bt-stage2`, `bt-trial-audit`
  and others;
- most of `tools/lib/*.awk`;
- `bin/bt-usbmon`, `bt-dyndbg`, `bt-evidence`, `bt-health-snapshot`;
- the measurement instruments in `devtools/` (coverage, mutate, sandbox);
- the upstream-workflow scripts (`ci-local.sh` and its siblings);
- all but the head of `tests/run-tests`.

Findings from later passes will be appended below this summary as addenda.

### Overall judgement

The code is unusually self-aware. Almost every defect class it ever had is written into a comment
at the place it was fixed, and the counted-not-`grep -q` and refuse-on-empty-read patterns are
applied consistently. The deny-by-default `run()` in the installers and the build-verify-rename
paths are good engineering.

The defects found cluster in four places:
1. code paths the project has forbidden in documentation but not in code;
2. safety logic that is complete for one direction or one format but not the other;
3. retention that runs ahead of an archive that is paused;
4. operator-facing hints that point at the forbidden command.

### Ranked list

| # | id | severity | one line |
|---|---|---|---|
| 1 | CAP1 | HIGH, time-sensitive | the capture daemons will delete the unarchived U10 and BT-9 captures within days to weeks; the archiver is paused |
| 2 | RS1 | HIGH (privacy) | `repo-save` pushes every branch not on a short list to `origin` (fails open) |
| 3 | MODE1 | HIGH (latent) | `bt-mode mitigation` arms the forbidden watchdog, and `install.sh` tells the operator to run it |
| 4 | I1, UN1 | HIGH (latent) | `install.sh --apply` and `uninstall.sh` still reload btusb live; EX-046 says that kills a healthy controller |
| 5 | VI1 | MED, deploy day | `bt-verify-install` ends any drift report with "Run: sudo ./install.sh --apply" |
| 6 | I2 | MED, deploy day | `--tools-only` still reads the whole boot's kernel log, unfiltered, before finishing (minutes on the laptop) |
| 7 | T1 | MED | a close interrupted after its row leaves the trial open; the next close writes a duplicate row |
| 8 | AR1 | MED | the HCI archive never keeps the decode-free capture directory |
| 9 | BJ1 | MED | the live boot is never archived, yet a long boot's start is what journald discards |
| 10 | M1 | MED | `bt-mark`/`bt-state` open MGMT through `bluetoothctl`, crashing the capture's btmon at every marked step |
| 11 | T2 | MED (known) | the closer's SCO decode never matches (COLUMNS) and reads every capture whole |
| 12 | UN2 | MED | `uninstall.sh --purge-metrics` deletes every raw capture, unarchived ones included |
| 13 | SC1, SAN1 | MED (privacy) | the publishing gate misses raw byte-form addresses and IPv6 EUI-64 addresses (which embed a MAC) |
| 14 | SM1 | MED | the SMTP check exits with the REVOKED code on a connect timeout or TLS error |
| 15 | SM2 | MED | the SMTP check's documented usage puts the app password on the command line |
| 16 | WD1 | MED (latent) | the watchdog's premise (no kernel reset handler) is false under E3 and every kernel with the entry |
| 17 | SN1 | MED | `bt-snapshot` reads presence from fixed port 3-3 and takes the first adapter of any kind |
| 18 | HD1, T3, BS1, BS2, RV1, UI1, SU1, SAN3 | LOW-MED | see their sections |
| — | the rest | LOW / INFO | see their sections |

### Before the deploy of `main`'s tools (an open operator decision)

None of these blocks the deploy, but each changes what the operator will see:
1. `[7/7] activate` will sit for a long time on the whole-boot journal read (I2). It is not hung,
   and every file is already in place by then.
2. `bt-verify-install` may end with "Run: sudo ./install.sh --apply" (VI1). Do not follow it.
3. `bt-mode status` prints "inactive" twice for stopped units (MODE2). This is cosmetic.
4. Never run `bt-mode mitigation` on the laptop (MODE1).

Fixing I2, VI1 and MODE2 first is small, and SU1 would make CI catch all three.

### Suggested order of work

1. **Now, operational:** restart the HCI archive, or copy the U10 and BT-9 captures into the keep
   directory (CAP1). Operator's decision.
2. **Small code fixes, before the deploy:** I2, VI1, MODE2, T1. Extend the rehearsal (SU1) so CI
   proves them.
3. **The publishing gate:** RS1 (invert to an allowlist), SC1 and SAN1.
4. **Latent hazards:** remove the live reloads (I1, UN1); `bt-mode mitigation` without the watchdog
   (MODE1); the watchdog stands down when the entry is present (WD1).
5. **Evidence retention:** AR1, BJ1, UN2, and capture pruning that respects the manifest (CAP1's
   code fix).
6. **The rest,** by section.

---

# Addendum — second pass (from 2026-10-19, after the first pass was committed as `13fe869`)

Same method: each file is read, and its findings are appended before the next file is opened.

## 24. `tools/bt-archive` (405 lines, read in full)

The read-back design is excellent:
- the record count comes from the same bytes the compressor received (`tee` into a FIFO, with an
  explicit `wait`);
- every pipeline stage's exit status is checked;
- superseded copies are removed only after the new one is verified.

**AJ1 — MED. Re-archiving a prefix can delete the only copy of a boot's start.**
`bt-backup-journal` re-archives every boot that carries a `.prefix` marker with `--replace`, and
`bt-archive` then removes the old file (374-377). Neither compares the old archive with the new
export. The failure goes like this:
1. A long boot is archived by hand while live, at a fault (the documented use of `bt-archive 0`).
2. journald discards that boot's oldest records before the boot ends, as BJ1 shows it does.
3. At the next run the full re-archive no longer contains the boot's start.
4. The prefix, the only copy of that start, is deleted.

*Fix:* on `--replace`, keep the old archive unless the new one contains its first cursor and at
least as many records. Otherwise keep both, renaming the old one to `…superseded-<date>`, and say so.

**AJ2 — INFO.** `--check` decompresses every archive and exports every retained boot in full to
count records, so on this machine it takes hours. It is operator-run only; print that estimate
before starting.

## 25. `tools/bt-exhibit` (329 lines, read in full)

Sound design:
- the command and its output are captured in one pass;
- a command that did not run (126/127) is refused;
- a missing sanitiser is treated exactly like a failing one;
- an address in the claim, relevance or command is refused rather than redacted, because those are
  published verbatim;
- the evidence boots are kept apart from the capture boot.

**EXH1 — LOW. Exhibit numbers are allocated per checkout, not per project.** `cmd_new` takes the
next number from the highest file in the local directory (122-128). Two branches can therefore
allocate the same number (the held `kernel/*` branch carries its own exhibits; three were ported to
`main` on 2026-10-18).
*Fix:* refuse a new number if any remote branch already uses it. Alternatively, reserve the numbers
in one place (BRIEF already records "the next exhibit on `main` is EX-063").

**EXH2 — LOW. The redaction notice promises more than the sanitiser does.** The notice says "The
same real value always maps to the same placeholder", but placeholders are numbered per run (SAN3),
so this holds within one exhibit, not across exhibits. Exhibit output also inherits SAN1's and SAN2's
gaps (IPv6 addresses carrying a MAC, host names).
*Fix:* say "within this exhibit" in the notice. The SAN fixes then cover exhibits automatically.

**EXH3 — INFO.** `bash -c "$cmd"` runs whatever it is given, and runs it on the laptop. A command
that probes the controller (`bt-state --probe`, `hciconfig`, `bluetoothctl`) would run inside
whatever window is open. The passivity rule lives with the person typing. A refusal list
(`hciconfig`, `btmgmt`, `bluetoothctl`, `--probe`, `rfkill`, `modprobe`) unless `--allow-active`
is given would make it mechanical.

## 26. `tools/bt-trial-audit` (311 lines, read in full)

Its independence from `bt-trial`'s detectors and its positive control are the right ideas. Boots
are resolved by containment from the `--list-boots` index, never by reading them.

**TA1 — MED. An unreadable window reads as clean.** The positive control proves the patterns match.
It does not prove the journal read worked. `bt_journal_lines` (journal.sh:194) pipes `journalctl …
2>/dev/null | grep -E`, so any failure behaves exactly like an empty window:
- a permission error;
- a boot whose files are present but whose window has rotated;
- `--grep`'s exit 1.

The result: zero resets and zero timeouts, so `perturbed=none` and `not_observed` rows "agree". That
is the confident zero the header warns about, arriving through the read instead of the regex.
*Fix:* check the read the way `bt-trial`'s `jread` does (exit 0, or 1 with an empty stderr). Also
confirm the window is non-empty with a one-line read (`-n 1` inside `--since/--until`). Either
failure is UNRESOLVED.

**TA2 — LOW. The audit's window starts five seconds later than the trial's.** The audit uses
`[close − duration, close]`; `bt-trial` counts from `start − 5`. A reset in those five seconds is in
the row but not in the audit, so it reports a disagreement that is the audit's own.
*Fix:* use the same five-second lead.

**TA3 — LOW. A known-unknown row is counted as a disagreement.** `perturbed=unknown` (the closer
could not read the journal) is compared with the audit's `none` or `usb_reset` and reported as
DISAGREES. Report it as "unknown at close; journal now says X", a separate count.

## 27. `bin/bt-usbmon` (221 lines, read in full)

Supervise-and-rotate is right, given that `tcpdump -C -W 1` is a ring. The idle loops are
interruptible (`sleep & wait`), and the gap log survives fractional intervals.

**UM1 — LOW-MED (latent, privacy). Nothing in the code keeps the USB captures root-only.** The
comment at 170-172 says "the capture directory must stay root-only, because USB traffic to a
Bluetooth controller carries link keys". But:
- the script only runs `mkdir -p "$DIR"` (53), with no `chmod 0700` and no `umask 077`;
- `bt-usbmon.service` sets no `UMask`.

On a fresh install the directory is created with the service's default umask (0755), and each pcap
is 0644. On the laptop the directory happens to be `drwx------` (checked read-only on 2026-10-19),
so nothing is exposed today.
*Fix:* `umask 077` and `chmod 0700 "$DIR"`, as `bin/bt-trace` does (lines 71-77), and `UMask=0077`
in the unit, as `bt-capture.service` has.

**UM2 — INFO.** USB captures are retained by count (60 files) and are never archived, the same
retention-without-archive shape as CAP1. They matter only for a stage-2 window, but a rotated-away
window cannot be re-read.

## 28. `bin/bt-health-snapshot`, `bin/bt-dyndbg` (read in full)

**HS1 — INFO (by design, recorded for completeness). Every snapshot is an intervention.** Each run
sends HCI Read Local Name (`hciconfig name`, line 90) and, when that answers, opens MGMT through
`bluetoothctl` (124; M1's `btmon` crash). Its event-driven twin fires on every Bluetooth add and
remove, that is, at the controller's own transitions (EX-012). All of this is why
`bt-mode experiment` stops the timer and moves the udev rule aside. MODE1 matters partly because
`bt-mode mitigation` brings this back as well as the watchdog.

**HS2 — LOW. Each run reads the whole boot's kernel log twice.** Two `bt_journal_count … -k -b 0`
reads run every 15 minutes, filtered by `--grep` but each traversing the whole boot. That cost grows
for the life of the boot (`journal.sh` names this shape). Count from the previous row's timestamp
forward and add, or take timeouts from `-p err`.

**DD1 — LOW. `bt-dyndbg off` silently undoes `bt-ui-capture`'s debug settings.** At shutdown,
`bt-dyndbg off` disables every site in its `ALL_FILES`, which includes `sco.c`.
`bt-ui-capture start` enables selected `sco.c` functions and records their previous flags. A
`bt-dyndbg off` (its unit's `ExecStop`) therefore resets them. `bt-ui-capture`'s manifest then still
believes they are on, and its `stop` restores flags that are no longer in effect.
*Fix:* have `bt-dyndbg off` leave alone the functions `bt-ui-capture` owns, or have the two share
one state file.

The `NOISY_FUNCS` selection is a model of measuring before deciding: the 98% from four functions
was found by counting, not by reading their names.

## 29. Publishing and mail helpers: `ci-local-publish.sh`, `build-mails.sh`, `mail-lint.sh` (read in full)

**CP1 — MED (privacy). A refused sanitisation still reports success, with the file in a tracked
directory.** `elide()` writes the address-elided copy straight into the tracked destination, then runs
`sanitize-logs.sh "$2" "$2"`. When the sanitiser refuses (its awk capability gate, or addresses left
after substitution), it leaves the file as it was. The script then:
- prints only a stderr line;
- leaves that copy in the tracked directory with its MACs, UUIDs and IPv4 addresses intact;
- counts it as copied and exits 0.

When the sanitiser is missing, the step is skipped without a word. `repo-scan` would stop the
colon, dash and underscore forms at commit, but nothing else would.
*Fix:* write to a temporary file; move it into the destination only after the sanitiser succeeds.
Otherwise delete it, count it as refused and exit non-zero. Treat a missing sanitiser as a refusal,
as `bt-exhibit` and `bt-incident` do.

**ML1 — LOW. `mail-lint.sh` checks three headers, not four.** Its header says "the four headers
present" but it checks `From:`, `To:` and `Subject:`. Either add the fourth (presumably `Date:` or
`Message-ID:`, whichever was meant) or say three.

**BM1 — INFO.** `build-mails.sh` hard-codes the two BlueZ patches of the 2026-09-19 send (`0001`,
`0002`). It is a record of that send, not a general tool; its header could say so, since the
tooling index lists it as current.

## 30. `tools/bt-retention` (306 lines, read in full)

It handles time correctly:
- boot ranges come from the `--list-boots` index, whose first entry moves forward when a boot's
  start is discarded, so partial rotation is seen;
- only offset-carrying timestamps are used, ordered by instant;
- the provenance block is cut off before the scan;
- a declared evidence window is preferred to the scan.

**RET1 — LOW-MED. GONE and AT RISK ignore the journal archive.** An exhibit whose boot has left the
ring is reported GONE ("can no longer be re-derived"), even when that boot is archived under
`~/bt-journal-archive` and replays with `journalctl --file`. AT RISK likewise names exhibits whose
boot is already archived, and the advice "Archive their source now" then sends the operator to
re-archive something that exists.
*Fix:* look each boot id up among the `boot-<id>.export.*` files, as `bt-backup-journal` does. Then
report "gone from the ring — archived (complete / prefix)" or "gone", and count AT RISK only for
unarchived boots.

## 31. Pattern sweep over the tools not yet read line by line, then `bin/bt-evidence` and `tools/bt-diagnose` (first 145 and 110 lines)

The sweep searched every unread tool for controller probes (`hciconfig`, `btmgmt`, `bluetoothctl`),
live module actions (`modprobe -r`, `unbind`), deletions (`rm -rf`), the `COLUMNS=` width
defect and the fixed `3-3` path. Hits:

**EV1 — MED (laptop). `bt-evidence` still probes the controller on every start and stop.**
`snapshot_state` (lines 69-71) runs `hciconfig <hci> name` (HCI Read Local Name) with no opt-in, at
`start` and at `stop`. Those are the two edges of a reproduction session, the moments being
recorded. The probe-free reform of 2026-09-18/19 (R2-78, R2-94) reached `bt-state`, `bt-mark`,
`bt-diagnose` and `bt-status`, but not this file. `bt-evidence` is installed on the laptop. It also
lists connected devices through `bluetoothctl` (line 87): M1's `btmon` crash.
*Fix:*
- make the probe opt-in (`--probe`), as in `bt-state`;
- use the MGMT-free connection count proposed in M1.

**EV2 — MED (privacy). `bt-evidence` claims its sessions are always sanitised, and they are not.**
Its header says "Everything written here is passed through the log sanitiser, so sessions are safe
to commit". But `sanitize_inplace` (90-94):
- returns success when no sanitiser exists;
- only warns when the sanitiser refuses, leaving the raw file in `evidence/sessions/`, which is
  tracked.

`bt-incident` fixed exactly this on 2026-09-19 (DR-06: name the failures in the manifest, exit
non-zero).
*Fix:* port that fix here.

**EV3 — LOW. A machine path is still hard-coded.** Line 32 falls back to a hard-coded
`/root/exp/qca9377-bt-hang`, the pattern `bt-incident`'s header records removing ("shipped one
machine's home-directory layout").

**SW1 — MED (known, still open). Three tools still set `COLUMNS=200`, which `btmon` ignores.**
`tools/bt-actions:287`, `tools/bt-sco:69` and `tools/bt-capdiff:86` pipe `btmon` with
`COLUMNS=200`. This is the same defect as T2. STATUS records the fix as asked of the test-suite
maintainer. Listed here so the review's ranked list holds every site.

**SW2 — LOW-MED. `verify-restored.sh` advises deleting the capture directory.** It prints
"`$HEALTH_DIR` still present … — rm -rf to clear" (line 159). That directory holds the raw captures
as well as the metrics, so the advice deletes unarchived evidence, as UN2 does.
*Fix:* name the archive check first, or advise deleting `metrics.tsv` only.

`bt-diagnose`'s probe is opt-in (`--probe`, line 125) and documented; no finding.

## 32. Pattern sweep over `devtools/` and the remaining `scripts/`, then `scripts/runtime-mgmt-test.sh` (first 60 lines)

The devtools instruments' `rm -rf` calls are all `trap`s on their own `mktemp -d` work directories.
The build and check scripts' `rm -rf "$OUT"` calls wipe their own output directories under `tmp/`,
which the tooling index documents. No pushes or sends outside `devtools/save`, `repo-save` and
`held`. Two hits matter:

**RM1 — MED (latent, laptop). `runtime-mgmt-test.sh` is retired only in a comment.** Its header
says `load`/`restore` "WEDGED THE CONTROLLER (EX-046) … Do not run load/restore on a live system
here". The tooling index says "Retired; never run `load` or `restore`". Yet the code still performs
the live `modprobe -r` sequence (lines ~100-165). Two things stand between it and the laptop:
- root;
- `guard()`, which refuses only while a trial or an untreated window is open.

Between a hand close and a reopen, or on a boot whose trial failed to open, nothing stops it.
*Fix:* make `load` and `restore` refuse unconditionally with the EX-046 reference. The record
survives in git history.

**SW3 — LOW. `scripts/sco-ledger.sh` opens MGMT on every run.** It names headsets from
`bluetoothctl devices` (line 28). Every ledger run, and every `boot-bt-summary.sh` run that calls it
(including `trial-snapshot.sh`), is therefore M1's `btmon` crash trigger. The names can come from
bluetoothd's store under `/var/lib/bluetooth/<adapter>/<device>/info` (`Name=`), read as files.

`capture-window.sh` and `supported-commands-survey.sh` use `COLUMNS=160`. The STATUS audit of
2026-10-18 found the first fails in part and the second works; they belong with SW1.

## 33. `tools/lib/trial-sco-table.awk`, `timestamp.awk`, `interval.awk` (read in full)

`timestamp.awk` is correct: proleptic-Gregorian day arithmetic, the ±HH:MM offset applied, and an
interval-free regex so it parses under mawk. `interval.awk` refuses rather than printing a zero.
The cross-tab refuses an unknown schema and is careful that the END block cannot print after a
refusal.

**XT1 — LOW. The cross-tab's "survived" column includes trials whose liveness was never
measured.** It labels its right column "survived", but every non-confirmed row lands there,
including `trial_result=ended_unprobed`, the passive shutdown close that "measured nothing about
liveness" (`bt-trial` 780-786). Since 2026-09-19 that is every observational row. `trial-summary.awk`
is careful with this word; this table is not.
*Fix:* label the column "no BT-1" (or "not hung") and add a footnote counting the `ended_unprobed`
rows in it.

**T5, refined.** `iso_secs` handles the DST change correctly. The `bt-trial` defect is that line
850 compares the raw timestamp strings (`$1 < lim`) instead of calling `iso_secs`. The fix is to
use the library that already exists.

## 34. `tools/bt-crash` (150 lines, read in full)

**CR1 — LOW-MED. `bt-crash` can hide the bluetoothd crash it exists to find.** It lists "Crashes in
the journal" by matching `segfault|core-dump|Failed with result` against the whole boot (70-71). It
does not scope the match to the Bluetooth stack, and it then prints only the last 12 lines
(`tail -12`, line 76). On 2026-08-31 `bt-snapshot` learned that `Failed with result` matches every
unit on a desktop (gnome-keyring, portals, snapd, the project's own backup) and scoped its filter to
`bluetoothd|bluetooth.service|btmon|bluez|obexd`. Here, a dozen unrelated desktop failures after a
bluetoothd segfault push the segfault out of the printed lines. The header criticises exactly this:
"a `tail -4` that CUT OFF THE ANSWER".
*Fix:* reuse `bt-snapshot`'s two-stage filter (crash-shaped AND about the BT stack). Print the
Bluetooth lines in full and count the rest. Read through `bt_journal_lines` with `--grep`, as the
unfiltered whole-boot read is slow on a long boot.

**CR2 — INFO.** The note about mismatched debug symbols names `5.72-0ubuntu5.5`; the installed
package is now `5.72-0ubuntu5.8` (STATUS, 2026-10-17). Derive the version with `dpkg-query` at run
time rather than writing it into the text.

## Second-pass summary (after §24-§34)

**Read so far:** about 12,000 of ~40,000 lines, line by line, plus a pattern sweep of every
remaining file in `tools/`, `bin/`, `devtools/` and `scripts/` for controller probes, live module
actions, deletions, pushes and the `btmon` width defect.

**Still not read line by line:**
- the remaining analysis tools: `bt-actions`, `bt-capdiff`, `bt-sco`, `bt-phase`, `bt-stage2`,
  `bt-postmortem`, `bt-context`, `bt-env-history`, `bt-fault-window`, `bt-guards`,
  `bt-health-report.sh`, `bt-logvolume`, `bt-timeline.sh`, `bt-usbstate`,
  `bt-verify-kernel-mechanism`, `bt-boot-*`, `verify-restored.sh`;
- `tools/lib/stage2.awk`, `phase.awk` and the small awk files;
- the `devtools/` instruments (coverage, mutate, sandbox, test-comprehension);
- the upstream-workflow scripts (`ci-local.sh` and siblings);
- `tests/run-tests` beyond its head.

**Added to the ranked list by the second pass:**

| id | severity | one line |
|---|---|---|
| EV1 | MED (laptop) | `bt-evidence` probes the controller at every session start and stop; the probe-free reform missed it |
| EV2 | MED (privacy) | `bt-evidence` leaves raw text in `evidence/sessions/` when the sanitiser is missing or refuses |
| CP1 | MED (privacy) | `ci-local-publish.sh` reports success with an unsanitised file left in the tracked directory |
| AJ1 | MED | re-archiving a prefix can delete the only copy of a long boot's start |
| TA1 | MED | `bt-trial-audit` reads an unreadable window as clean |
| RM1 | MED (latent) | `runtime-mgmt-test.sh load/restore` (EX-046) is retired only by comment |
| SW1 | MED (known) | `bt-actions`, `bt-sco`, `bt-capdiff` still use `COLUMNS=200` |
| UM1 | LOW-MED (latent) | `bt-usbmon` does not enforce a root-only capture directory |
| RET1, CR1, SW2, DD1 | LOW-MED | see their sections |
| EXH1, EXH2, EXH3, TA2, TA3, HS2, ML1, BM1, EV3, SW3, XT1, CR2, AJ2, UM2 | LOW / INFO | see their sections |

**Two patterns across both passes**, each worth fixing once rather than per file:
1. **A fix that reaches some siblings but not all.** The examples so far:
   - the probe-free reform skipped `bt-evidence`;
   - the sanitiser-failure fix (DR-06) skipped `bt-evidence` and `ci-local-publish.sh`;
   - the BT-scoped crash filter skipped `bt-crash`;
   - the `sleep & wait` fix skipped the watchdog;
   - the root-only capture rule skipped `bt-usbmon`;
   - the `COLUMNS` finding is still open in three tools.

   The suite already pins several such rules as invariants over the whole tree; each of these
   belongs there too: "no unconditional `hciconfig`/`bluetoothctl` outside `--probe`", "every
   sanitiser call's failure is fatal or named", "no `COLUMNS=` before `btmon`", "every capture
   daemon sets `umask 077`".
2. **Rules held in prose, not code.** Never `--apply` (I1, VI1), never arm the watchdog (MODE1),
   never reload btusb live (UN1, RM1), never push private families to `origin` (RS1). The tools
   already refuse in many places; these are the places they still do not.

---

# Addendum — third pass (from 2026-10-19, after `a77a11c`)

## 35. `devtools/sandbox` (first 320 of 631 lines)

The decoy world gives the suite strong isolation:
- fresh user, pid, mount, net and UTS namespaces;
- every real tree under a throwaway overlay, with `/` read-only;
- every machine tool replaced by a decoy that logs its calls;
- decoy `/sys`, `/proc`, `/run`, `/var/log`;
- a per-run marker that turns a silent leak into a visible one.

Its four detectors (CALL, DATA, READ, WRITE) watch the world rather than a process, so parallel
workers are covered. It refuses with exit 3 ("NOTHING WAS MEASURED") rather than passing where
namespaces are unavailable, and `--self-test` proves each detector on planted leaks.

**SB1 — INFO. On the laptop the suite has only one layer of isolation.** The sandbox cannot run
there (AppArmor's namespace restriction; exit 3 by design), so the suite's PATH tripwire is the
only isolation layer on the one machine where a leak would cost evidence. That is stated in the
header and in `tests/run-tests`. Together with the open-trial refusal, the suite never runs on the
laptop while a trial is open, which is always. Worth keeping in mind whenever someone sets
`BT_ALLOW_OPEN_TRIAL=1` there: the override exists for a stale state file after a crash, and it
removes the stronger of the two remaining guards.

No defects in the part read. The remaining 311 lines (decoy staging, judging, `--self-test`) are not
yet read.

**Continued: lines 321-631, read in full.** The staging is careful:
- decoys are bound over every real copy of each machine tool;
- the installed set is parsed from `install.sh` (with a refusal if fewer than 40 entries parse);
- `/proc` entries are bind-mounted decoys;
- every isolation probe has a positive control run on the host first. A probe the host itself could
  not reach is "not verifiable here", never "caught".

**SB2 — LOW-MED. If isolation is broken, the self-test damages the real working tree.** Three of
its WRITE probes act on a real tracked file: `echo probe >> "$REPO/README.md"` and
`rm "$REPO/README.md"` (528-529), plus the create probe. They depend on the very isolation under
test. If the overlay is silently absent (the case the self-test exists to catch), the probes append
to and then delete the real `README.md`. The after-check (564) reports this but restores nothing. A
README with uncommitted edits would lose them.
*Fix:* probe against a sentinel created for the purpose (e.g. `$REPO/tmp/.sandbox-sentinel-<nonce>`
with known content, written before the run). Compare and remove it afterwards. The tracked tree is
then never the test object.

## 36. `tests/system-roundtrip` (209 lines, read in full)

The gating is good:
- an explicit variable;
- refusal on any existing installation, open trial or experiment mode;
- `required` turns a skip into a failure;
- a bounded wait for a runner still booting.

The direct "no destination survives" check is derived from `install.sh`, never hand-listed.

**SR1 — LOW-MED, strengthens VI1. `bt-verify-install` reports conditional files as missing.**
The test records (138-145) that `bt-verify-install` expects every `install_file` destination
unconditionally. `install.sh` installs the `btmon`- and `tcpdump`-dependent ones only when those
tools exist. So on a host missing either, the verifier reports correctly-skipped artifacts as "NOT
INSTALLED". It then ends with VI1's "Run: sudo ./install.sh --apply". The note calls this "worth
fixing in bt-verify-install, recorded rather than papered over", but it is not on any register.
*Fix:* apply the same `command -v` conditions as `install.sh`, or have `install.sh` write the list
of what it actually installed for the verifier to read.

**SR2 — INFO. One refusal check can never run.** The experiment-mode refusal (86-89) reads
`/usr/local/share/qca9377-bt-hang/mode`, but line 76 already refused if that directory exists at
all. Harmless; drop it or move it first, so the message names the more specific reason.

## 37. `tools/bt-phase`, `tools/lib/phase.awk` (read in full), checked against systemd's real wording

The analysis is careful:
- probes classed by provenance (unit name), not by spacing;
- both gap boundaries exogenous;
- timeout lines collapsed into clusters, explicitly not called incidents;
- nothing compared across a reboot;
- dates through the shared `iso_secs`.

**The wording systemd 255 uses on this machine**, read from the journal (2026-10-19, a oneshot unit
of this project):

```
… systemd[1]: Finished bt-journal-backup.service - Archive every retained journal boot, so evidence stops evaporating.
```

Each oneshot run logs `Starting <unit> - <Description>...` and `Finished <unit> - <Description>.`,
with the unit name between the verb and the description.

**PH1 — MED (latent). On this systemd, `bt-phase` would skip every boot, giving the wrong reason.**
`collect()` keeps every line containing "Snapshot Bluetooth health metrics" (103-108). That matches
both the `Starting` and the `Finished` line of one run, so each timer probe becomes two EXO
records seconds apart. The provenance self-check (phase.awk 60-62) treats any gap under half the
timer period as proof of udev contamination. Every boot is then SKIPPED, with the message "Those
boots predate the split of bt-health-snapshot.service from -event.service", which is false.
- The fixture (`tests/journal/phase/unit-bt-health-snapshot.service.b0.log`) has one bare
  `systemd[1]: Snapshot Bluetooth health metrics` line per probe. That is a shape systemd does not
  print, against the suite's own rule that fixtures come from real log text. So the test passes.
- `bt-trial` met the same double-count and fixed it for its own counter (`bt-trial` 891-897,
  review 2026-08-15T1752Z §4.6); the fix did not reach `bt-phase`.
- No probe-timer data is in the retained journal now (the timer has been off), so no report was
  wrong today. The next mitigation-mode boot would give one.

*Fix:*
- take `Finished` lines only, matched on the unit name;
- regenerate the fixture from a real `journalctl -u bt-health-snapshot.service -o short-iso-precise`;
- let `devtools/journal-contract` cover this fixture.

**T9 — MED (latent). `bt-trial`'s probe counter can never match on this systemd.** `bt-trial`'s
`probes` column counts `^Finished Snapshot Bluetooth health metrics` in `-o cat` output (line 902),
and `probe_to_timeout_s` greps `Finished Snapshot Bluetooth health` (925). On systemd 255 the line
reads `Finished bt-health-snapshot.service - Snapshot Bluetooth health metrics.`, so neither pattern
matches: the column is 0 and the interval `?` whatever ran. Every row in `results.tsv` records
`probes=off` in its treatment and `0` in `probes`. That is probably true for the timer, but the
udev-driven `-event` unit's runs (counted by the same pattern) would also read 0. The comment at
896-897 asks for exactly this check after a systemd upgrade.
*Fix:* match `Finished bt-health-snapshot(-event)?\.service`. Add a fixture built from the real line,
so the next wording change fails a test instead of zeroing a column.

**EH1 — MED (latent). `bt-env-history` reports "none" in its PROBES column for every boot.** A sweep
for other matchers of systemd's own messages found this third copy at line 104: `grep -c "^Finished
Snapshot Bluetooth health"` over `-o cat`, with the same comment ("re-verify against the live
journal after a systemd upgrade"). On systemd 255 it never matches. This tool answers "which
workarounds were active during which boot", and "none" here claims no HCI probe ran. A boot with the
timer or the udev unit active would be listed as untouched, which is the treatment-history error the
tool exists to prevent.
*Fix:* as T9, with one shared pattern in `tools/lib/journal.sh` (e.g.
`BT_RE_SNAPSHOT_RUN='Finished bt-health-snapshot(-event)?\.service'`), so three copies cannot drift
apart again.

The rest of the sweep: `bt-boot-provenance` and `bt-trial` match `Reached target (reboot|poweroff|halt)`,
which still matches systemd 255's `Reached target reboot.target - System Reboot.`. `bt-actions`
matches `Started` on GNOME scope units, and systemd still words those that way. `bt-context` lists
the verbs as background noise only. No other instance.

## 38. `tools/bt-stage2`, `tools/lib/stage2.awk` (read in full), and who says "Resetting usb device"

`bt-stage2` writes its cache under a temporary name and renames it only on success. It reads
`-b all` explicitly. `stage2.awk` classifies what ended each window by positive provenance, keeps
unknown-origin resets apart, anchors USB lines to the device's own path, and never averages unlike
terminators.

**Who prints the message, from the kernel source** (`cache/ubuntu-7.0.0-38/drivers/bluetooth/btusb.c`,
the kernel running E3):
- line 4336: `if (id->driver_info & BTUSB_QCA_ROME) { … hdev->reset = btusb_qca_reset;`
- line 1155: `btusb_qca_reset()` with no reset GPIO (the laptop's case) calls `btusb_reset(hdev);`
- line 998: `btusb_reset()` prints `bt_dev_err(hdev, "Resetting usb device.");`, then
  `usb_queue_reset_device(data->intf);`

So `Bluetooth: hci0: Resetting usb device.` is the **kernel's own** command-timeout reset. Under E3,
and on every kernel with the device-table entry, it is part of the treatment. `bin/bt-hang-watchdog`
never prints it: its lines are "Recovering Bluetooth controller…", "USBDEVFS_RESET issued" and
"escalating to USB unbind/bind". `stage2.awk` (153) gets this right and calls it "kernel
command-timeout reset callback … TREATMENT". Two other places get it wrong.

**KR1 — MED-HIGH (latent, the main experiment's rate). Under E3, a real failure would drop out of
the E3 failure rate.**
- `tools/lib/journal.sh:83-84` states "`Resetting usb device`, which is bt-hang-watchdog's wording"
  and puts it in `BT_RE_INTERVENTION_TOOL` (106).
- `bt-trial`'s interior scan (697) counts it, and the kernel's following `reset full-speed USB
  device`, as `usb_reset`.

What follows if BT-1 recurred on E3:
1. The kernel itself resets the device at the first command timeout.
2. The row is written `PERTURBED:usb_reset:…`.
3. `trial-summary.awk` (75) excludes every PERTURBED row from every rate. A confirmed E3 failure
   then disappears from the E3 denominator, which moves the rate in the direction that makes the
   build look better, the one direction the summary's own comments say an error must never take.
4. `bt-window` would also call that window "CENSORED — tooling".

No E3 trial has had a timeout yet (every row 0), so nothing recorded is wrong. The link ledger
(`sco-ledger.sh`) that carries the 74/0 result is unaffected.
*Fix:*
- correct `journal.sh`'s comment;
- move `hci[0-9]+: Resetting usb device` (and the kernel `reset … USB device` line that follows it
  within seconds) into a `BT_RE_KERNEL_RESET` class;
- record it in the row as its own field (e.g. `kernel_reset=N`), not as a perturbation;
- have the rate count such rows as confirmed failures.

Keep "unknown-origin reset" for a bare `reset … USB device` with no kernel line before it, as
`stage2.awk` does.

