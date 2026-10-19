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

## 39. `tools/bt-verify-kernel-mechanism` (161 lines, read in full)

The tool settles from the binary whether btusb uses `hdev->reset` (first timeout) or the older
5-timeout `cmd_timeout`. It searches for IDs byte-aligned and falls back from `hexdump` to `od`, and
it reports UNKNOWN rather than ABSENT when the binary cannot be read. Its supporting-strings check
already lists "Resetting usb device" as a string inside `btusb.ko`, which is KR1's point from the
other side.

**KM1 — MED. The tool reports the laptop's device as missing from upstream and from the module.**
`check_id 3503 "not in upstream  <-- THIS DEVICE"` (154) has been false since `dc16388d45ec` (the
entry is upstream and in 7.2.10, 6.18.56 and 6.12.113). The tool also reads only
`/lib/modules/<krel>/kernel/drivers/bluetooth/btusb.ko`, the stock module, never
`updates/btusb.ko`. That is not the module that loads on the laptop (E3 in `updates/`). On the
laptop it therefore prints `✗ 13d3:3503 ABSENT … not in upstream <-- THIS DEVICE` about a module
that is not loaded, under a label that is no longer true.
*Fix:*
- resolve the module the way the kernel does (`modinfo -k <krel> -n btusb`, which prefers
  `updates/`) and print which file was read;
- relabel 3503 "upstream since `dc16388d45ec` (not in older stock modules)";
- for the presence question, defer to `scripts/btusb-has-device.py`, which matches the
  `match_flags` as well.

**KM2 — INFO.** The temporary file goes to `/tmp` (`mktemp /tmp/btusb-verify.XXXXXX.ko`) rather than
the project's `tmp/`. It is removed on exit, so this is only the house rule.

## 40. `tools/bt-health-report.sh` (first 120 of 256 lines)

The baseline and the change time are found through seams, and the change time comes from the
install stamp that is written once (a unit file's mtime moves on reinstall).

**HR1 — LOW-MED. The before/after split credits E3's effect to the mitigations.** The report has
one change point: `installed-at`, when the mitigations (autosuspend off, power pinned, watchdog,
probes) first went in. Every boot after it is "AFTER". Since 2026-10-01 (E1/E3 on `-34`) and
2026-10-11 (E3 on `-38`), the AFTER boots run a different driver, the treatment that actually fixed
BT-1. A reader of "are the mitigations working?" would see the E3 boots' zero timeouts as the
mitigations working. The installed-at date also predates E3's experiment-mode boots, which have no
mitigations at all.
*Fix:* split the AFTER boots by the build actually loaded (the trial rows' `build`, or
`/sys/module/btusb/srcversion` per boot from `metrics.tsv` if added). Name E3 boots as their own
group, or state at the top that the report predates E3 and must not be read for it.

## 41. `tools/bt-capdiff` (first 140 of 290 lines)

Its header is a model of stating what a redundancy does and does not buy (same socket, same offline
decoder). It drops monitor-session bookkeeping that would only count `btmon`'s restarts, and it
compares only the overlap of the two paths.

**CD1 — LOW-MED. The time window is applied after decoding everything.** `extract()` (78-110) runs
`btmon -r` over every file in both directories, about 800 files and 48 GB on the laptop, before the
`--since/--until` window is applied (135-136). One `btmon` pass over the trace directory alone
took over ten minutes on 2026-09-24 (`bt-trial`'s comment). On the laptop
`bt-capdiff --since …` therefore costs a decode of everything retained. It looks hung, and it
would compete with the machine for an hour.
*Fix:* choose the files whose name-start/mtime range overlaps the window first, as
`scripts/trial-sco-decode.py` does, and decode only those. This is SW1 too (`COLUMNS=200`,
line 86).

## 42. `tools/bt-sco` (142 lines, read in full)

**SC-1 — MED. Run on the laptop, `bt-sco` can set off the deletion of captures.** It decodes every
retained capture (`btmon -T -r` over all of `/var/log/bt-health/trace/*.btsnoop`, lines 68-70) into
one temporary file under `/tmp`, on the root filesystem, before filtering anything. The trace
directory holds about 400 files. `btmon`'s text decode is several times larger than the binary
capture, and the two capture directories hold 48 GB together. So the temporary file can run to
tens of gigabytes. As it grows past the capture daemons' free-space floor (15 GB), both daemons
start deleting the oldest captures (`bt-trace` `disk_guard`, `bt-capture` `prune`), unarchived ones
included (CAP1). A read-only analysis tool would then destroy evidence by filling the disk. Its
results are empty anyway while SW1 stands (`COLUMNS=200`: the shortened header never matches
"HCI Command: Setup Synchronous Connection", so `setup requests 0`).
*Fix:*
- stream instead of buffering (pipe the decode straight into the awk filter);
- decode only the files a window needs;
- write any buffer under the project's `tmp/` with a size check against the floor;
- `--columns=200`.

The tool should also refuse to start when free space minus the expected decode would cross the
capture floor.

**SC-2 — INFO.** The header is honest that the default mode does not pair requests with completions,
and points to `--window`. Keep it so.

## 43. `tools/bt-actions` (lines 1-100 by search, 276-316 read)

**AC1 — MED. The capture pass puts other boots' MGMT commands into a single boot's timeline.** The
journal pass is scoped by `-b <boot>` and `--since/--until` (79-81). The HCI-capture pass (283-296)
is not: it decodes every retained `.btsnoop` in the trace directory, about three weeks of captures,
and appends every matching `MGMT Command:` to the same stream. All of it is rendered under
"Reconstructed action timeline — boot N", labelled USER, the label the header calls "the closest
thing to a record of operator intent". A reader of boot −1's timeline is shown, as operator actions:
- Set Powered, Disconnect and Pair Device commands from other boots;
- commands from outside the requested window.

That is a fabricated record in a tool whose header line is "reconstruct what actually happened, from
the logs rather than from memory". While SW1 stands, the shortened header lines may hide some of
these lines, which only masks the defect.
*Fix:* take the boot's first and last timestamps from `--list-boots` (or the window's
`--since/--until`). Decode only the capture files that overlap that range, and drop records outside
it before they reach the stream.

## 44. `tools/bt-usbstate`, `tools/bt-boot-list` (read in full)

`bt-usbstate` is sound:
- sysfs reads only;
- the device found by VID:PID, refusing when two devices match;
- stage 2 and a configuration error kept apart;
- the padded `bAlternateSetting` trimmed before comparing;
- one timestamp for the screen and the saved copy.

**BL1 — LOW-MED. When boot enumeration fails, `bt-boot-list` warns where nobody reads and returns
success.** If every rung fails, it prints "WARNING: could not enumerate boots; assuming current boot
only" to stderr and exits 0 with `0` (89-94). Its callers capture stdout and discard stderr
(`bt-trial-audit` line 107, `bt-phase` line 115, `bt-diagnose`, `bt-health-report`). Each then
analyses boot 0 alone, reporting on one boot as if it were the whole retained history. The header
names exactly this as the failure the tool exists to prevent ("a caller that silently assumes more
history than exists draws false conclusions").
*Fix:* exit with a distinct status (e.g. 3) on that path and keep the `0` on stdout, so callers can
refuse or label their output.

## 45. `scripts/ci-local.sh` (first 110 of 743 lines, plus a search of it and its two siblings)

The base-versus-patched classification (PASS / NEW / PRE-EXISTING / FIXED) is the right design: it
tells our findings from upstream's, which is what the 2026-10-10 smatch episode needed.

**CL1 — LOW. The header overstates its isolation.** It ends "nothing here talks to anything but the
local trees" (67). `--fetch` runs `git fetch origin`, and the kernel path fetches stable tags from
`git.kernel.org` (`STABLE_URL`, 95). Both are reads, and nothing is posted. Say "posts nothing; it
fetches only with --fetch / --kernel".

**CL2 — INFO, to verify before first use on the laptop.** `--functional` (and `functional-repeat.sh`)
run BlueZ's `test/test-functional` through its pytest harness. The tooling index records that the
harness needs a *host* kernel with `AF_ALG` because "the host-side `btvirt` creates no LE-capable
controller without it". If `btvirt` runs on the host, it creates virtual controllers through
`/dev/vhci` in the laptop's own kernel, where `bluetoothd` and the desktop will see and use them.
That contradicts the project's practice of running BlueZ testers inside QEMU only. Neither script
refuses on the investigation machine (no open-trial or device check; a search finds none). These
scripts have never completed a run, so nothing has happened.
*Fix:* establish where `btvirt` runs. If on the host, refuse on any machine that has
`/run/bt-trial/current` or the 13d3:3503 device, as the system tests do.

## Third-pass summary (after §35-§45)

**Read so far:** about 15,500 of ~40,000 lines line by line, plus the pattern sweeps.

**Not read line by line:**
- `bt-postmortem`, `bt-context`, `bt-fault-window`, `bt-guards`, `bt-logvolume`, `bt-timeline.sh`,
  `bt-boot-provenance`, `bt-boot-stats`, `bt-boots`, `bt-interval`, `bt-ctrl-window`;
- `verify-restored.sh` (searched only);
- the rest of `bt-capdiff`, `bt-health-report.sh`, `bt-ui-capture` and `ci-local.sh`;
- the small awk libraries;
- the `devtools/` measurement tools;
- most upstream-workflow scripts;
- `tests/run-tests` beyond its head.

**Added to the ranked list by the third pass:**

| id | severity | one line |
|---|---|---|
| KR1 | MED-HIGH (latent, E3's rate) | the kernel's own `Resetting usb device.` (E3's `hdev->reset`) is taken for a tool intervention: an E3 failure would be marked PERTURBED and dropped from every rate |
| SC-1 | MED | `bt-sco` buffers a decode of every capture on the root filesystem; crossing the 15 GB floor makes the capture daemons delete captures |
| AC1 | MED | `bt-actions` shows other boots' MGMT commands as operator actions in a boot's timeline |
| PH1, T9, EH1 | MED (latent) | three probe counters cannot match systemd 255's `Finished <unit> - <description>.`; their fixtures use a shape systemd does not print |
| KM1 | MED | `bt-verify-kernel-mechanism` reads only the stock module and still says 3503 is "not in upstream" |
| SR1 | LOW-MED | `bt-verify-install` reports conditionally skipped files as missing (then VI1's `--apply` advice) |
| SB2 | LOW-MED | the sandbox self-test writes to and deletes the real `README.md` if isolation is broken |
| HR1, CD1, BL1 | LOW-MED | see their sections |
| CL1, CL2, SR2, KM2 | LOW / INFO | see their sections |

**The third pass adds a third pattern to the two in the second-pass summary:**
3. **Fixtures that encode an assumption instead of the machine.** PH1 and T9 pass their tests on a
   journal line systemd does not write. KR1's misattribution sits in a comment that every reset
   pattern was built on, and the kernel source says otherwise. The suite already has
   `devtools/journal-contract` to compare fixtures with real `journalctl` output. Extending it to
   every fixture that encodes a systemd or kernel message, and citing the kernel source for each
   kernel message the tools classify, turns the next such divergence into a test failure.

---

# Addendum — fourth pass (from 2026-10-19, after `98b3f32`)

## 46. `tools/bt-ctrl-window`, `tools/bt-fault-window` (read in full)

`bt-fault-window`:
- anchors on the first timeout;
- counts the alt-1 traffic instead of printing it;
- refuses an empty window;
- measures setup to fault from the answered `0x0428`.

`bt-ctrl-window` decodes the management records `btmon` leaves as `Control Event: 0xffff`, which
is the layer EX-044 needed.

**CW1 — LOW-MED. `bt-ctrl-window`'s time window ignores the date.** It compares bare `HH:MM:SS`
strings (`t >= from && t <= to`, line 50). A `bt-capture` file rotates at 64 MB and on a quiet
system spans hours to days. A capture that crosses midnight, or spans several days, matches the same
clock window on every day it covers. The output is described as fit to go "straight into an
exhibit", so records from another day would be published as one window.
*Fix:* accept full `YYYY-MM-DD HH:MM:SS` bounds (as `capture-window.sh` and `trial-sco-decode.py`
do), or refuse when the capture's first and last records fall on different dates and only times
were given.

**CW2 — LOW. Its address filter knows only the colon form.** It drops lines with a colon-form
address (52) and prints `= bluetoothd` lines (72). bluetoothd's monitor log lines carry device
object paths in the underscore form (`dev_XX_XX_…`), which that filter does not catch. Run through
`bt-exhibit`, the sanitiser handles them. Used alone, as the header invites, they go out raw.
*Fix:* drop the underscore form too, or say "run through `bt-exhibit`".

**FW1 — LOW. The anchor read can traverse the whole boot.** The anchor is found by reading the boot
unfiltered and taking the first match (`bt_journal -k -b … | grep | head -1`, 76-77). On a long
dynamic-debug boot with no timeout, that reads the whole boot before refusing. `bt_journal_first`
exists for exactly this, with `--grep` (journal.sh 201), and `bt-window` uses it.

## 47. `tools/verify-restored.sh` (186 lines, read in full)

Its file list is derived from `install.sh` (with a refusal if implausibly short). It catches
`.disabled` move-asides and checks `dpkg --verify bluez`.

**VR1 — MED. "Pre-investigation state" leaves out two changes made outside `install.sh`.** The tool
ends "System matches its pre-investigation state" after checking only what `install.sh` installs,
plus the packaged BlueZ files. Two kinds of change this project made on the laptop outside
`install.sh` are invisible to it:
1. **Self-built kernel modules in `updates/`.** These are E3's `btusb.ko` (STATUS: the laptop runs
   it), and any `bluetooth.ko` placed by `scripts/module-updates.sh`. They are loaded at every boot,
   in front of the stock modules. `dpkg --verify` does not see them, because they are not package
   files.
2. **The self-built `bluetoothd`.** STATUS (2026-10-17) records that "the running `bluetoothd` is
   still the patched `/usr/local` rebuild". It is started through a drop-in under
   `/etc/systemd/system/bluetooth.service.d/` (`runtime-mgmt-test.sh` names
   `20-patched-bluetoothd.conf`). `dpkg --verify bluez` passes because the packaged binary is
   untouched, and the check's own heading says "Untouched by design — confirming still true".

On the laptop as it stands, after `uninstall.sh` the tool would declare a machine restored while it
still boots a self-built btusb and a self-built bluetoothd.
*Fix:*
- list every `.ko` under `/lib/modules/*/updates/` (with srcversion);
- list every drop-in under `bluetooth.service.d/`;
- name `ExecStart`'s binary (`systemctl show -p ExecStart bluetooth`);
- fail on any of them not packaged.

`uninstall.sh` (UN3) and `docs/restore-original-state.md` should name the same items.

**VR2 — INFO.** Section 6 still says "if this is still the 2026-08-10 boot, 3 of them are synthetic
test lines". That boot is long gone; drop the line or date it.

## 48. `tools/bt-guards`, `tools/lib/evidence-window.sh` (read in full)

No defects. Both are examples of the project's method at its best:
- **`bt-guards`** selects on the indexed `_COMM=bluetoothd` field, not a whole-journal grep (the
  EX-041 lesson). It refuses a zero without a positive control, and it says plainly that a 0001 hit
  is ambiguous (the same text exists at a pre-existing site).
- **`evidence-window.sh`** keeps one grammar for writer and reader. It orders by instant rather than
  by spelling, voids the answer when a stamp does not parse rather than taking the minimum of what
  survived, and checks `not placeable` before looking for instants in the reason's prose.

One note for later: the BT-7 patches are now upstream (`a734b06059cb`, `0bed9886cff3`). Once a
distribution BlueZ carries them, the "new text, unique to the patch" in `bt-guards`' header will
also come from the packaged daemon. The meaning of a hit (a crash prevented) does not change, but
the default `--since 2026-08-25` ("the patched daemon was first installed") stops being the
boundary that matters.

## 49. `devtools/doc-main-hashes`, `devtools/review-open` (read in full)

`doc-main-hashes` is solid:
- it judges against the main of the remote whose URL is the public repository, never `HEAD`;
- a port's origin is accepted only beside its port;
- a commit only on the current branch is PENDING;
- a shallow clone or a missing reference is INCONCLUSIVE, never clean.

**RO1 — LOW-MED. "Confirmed" and "verified" count as closed, but they also mean "real, not yet
fixed".** `review-open` treats a status beginning with `confirmed` or `verified` as CLOSED (line 29).
In a findings register those words are as likely to mean the opposite: "confirmed — fix pending",
"verified on the machine, open". Such a row disappears from the gate the operator uses "before
anything is submitted".
*Fix:* count `confirmed`/`verified` as closed only together with a closing word (`fixed`, `done`);
otherwise list them. Alternatively, list every status word the register uses with its open/closed
reading, so a new phrasing is a visible decision.

**RO2 — INFO, about this review. Its findings are invisible to `review-open`.** It reads only the
action registers in `reviews/README.md`, matching ids of the form `AB-12` / `R2-12`. This report's
ids (`T1`, `RS1`, `CAP1` and the rest) are neither in the register nor in that form. For them to
count in the gate, they need register rows in the README's format (e.g. a `CR2-nn` prefix). That
is a separate edit of `reviews/README.md`, not made here.

## 50. `devtools/check`, `devtools/status` (read in full)

**DS1 — MED (VI1 again, a third site).** `devtools/status`, the "is everything updated, deployed,
committed?" report, prints on any drift: "the checkout is AHEAD of what is running —
`sudo ./install.sh --apply`" (line 107). That makes three tools that send the operator to the
forbidden command:
- `bt-verify-install`, line 166 (VI1);
- `devtools/status`, line 107;
- `bt-mode`'s companion hints in `install.sh` (MODE1).

`devtools/check` (line 65) prints the verifier's last three lines, which include VI1's.
*Fix:* one wording everywhere: "`sudo ./install.sh --tools-only`, then `daemon-reload`,
`bt-verify-install`, `bt-mode status`" (the checklist in `docs/install.md`).

**CK1 — LOW-MED. On the laptop, `devtools/check` always says NOT READY TO COMMIT.** Its first step
runs `devtools/repo-validate` with the suite. A trial is open on every boot there, so the suite
refuses (`run-tests` exit 2), the step fails, and the command always ends NOT READY.
`repo-save` already handles this case: it passes `--no-suite` and says so.
*Fix:* do the same here when `/run/bt-trial/current` exists.

**DS2 — LOW-MED. `devtools/status` waits minutes for a line it throws away.** It takes the trial
line from `tools/bt-trial status | head -1` (119). `bt-trial status` prints "trial OPEN" and then
reads the whole trial window unfiltered (T6), minutes on a multi-day trial with dynamic debug.
`head -1` already has its line, but the read runs to completion before the next write fails, so
`devtools/status` waits on every run.
*Fix:* read `/run/bt-trial/current` directly for this row, or fix T6.

**DS3 — LOW. `devtools/status` checks only `origin`.** The "pushed?" row uses
`git ls-remote origin <branch>` (58). On a held branch, which `repo-save` pushes to `private`, it
reports "could not reach origin" or "ahead" for a branch that is fully pushed. Use the same branch
rule as `repo-save`.

## 51. `devtools/journal-contract` (192 lines, read in full)

Phase 2 is a strong idea: it builds a real journal from export text with
`systemd-journal-remote`, runs the real `journalctl` over it, and diffs the output byte for byte
against the fixture grammar. That check already caught the leading boot separator the stage2
fixtures carry and the real tool does not print.

**JC1 — MED. The contract checks the format of a message it made up itself; that is how PH1, T9
and EH1 got through.** Phase 2 writes the snapshot unit's record with
`MESSAGE=Snapshot Bluetooth health metrics` (line 156) and then confirms that `journalctl` prints
that message back in the fixtures' line grammar. That verifies the timestamp, host and identifier
layout. It does not verify what systemd actually writes for a unit run, which on systemd 255 is
`Finished bt-health-snapshot.service - Snapshot Bluetooth health metrics.` (§37). The fixture's
assumption is copied into the contract, so the contract cannot see it fail.
*Fix:* add a phase-1 claim against the host journal for every systemd-generated message a tool
matches. Read the last `Finished`/`Starting` line of any oneshot unit on the host
(`journalctl -u <unit> -o cat`) and check the shape the tools grep for
(`Finished <unit> - <Description>.`). Then generate the phase-2 export's `MESSAGE` from that shape
rather than from the fixture.

## 52. `devtools/ci` (first 120 lines), `scripts/installed-vs-commit.py`, `scripts/unpushed-survey.py` (read in full)

`devtools/ci` is sound:
- it changes into the checkout so `gh` resolves the right repository;
- a failing `gh` is not read as "no run";
- an in-progress run's empty conclusion is handled.

**IV1 — LOW-MED. The pre-deploy comparison can only see files the old commit installed.**
`installed-vs-commit.py` parses only the *installed* commit's `install.sh`, so its "deploy: changes"
column covers only those destinations. Files the candidate installs and the old commit did not are
not listed at all:
- new tools;
- new libraries (e.g. anything added to `tools/lib/` since `cccf0fe`).

The 2026-10-18 reading, "a deploy of `main` changes 17 of the 68", is therefore a lower bound on
what the deploy writes.
*Fix:* parse the candidate's `install.sh` as well, and list destinations only in the candidate as
"new" (and only in the old as "no longer installed").

**UP1 — LOW-MED. `unpushed-survey.py` checks only the checked-out branch.** It counts unpushed
commits with `git rev-list --count HEAD --not --remotes` (38). Local commits on any *other* branch
that no remote holds are invisible, and on the project checkout several branch families are in
play. The tool exists to answer "what exists only on this disk?", and it can answer "nothing" while
a branch holds unpushed work.
*Fix:* `git rev-list --count --branches --not --remotes`, and list the branches it finds.

## 53. `tools/bt-boot-provenance`, `tools/lib/coredump.sh` (read in full)

`coredump.sh` is a faithful seam: a missing fixture answers like an empty core store (exit 1), and
the header requires fixtures to carry `coredumpctl list`'s header row. `bt-boot-provenance` takes
both boundary times from `--list-boots` and bounds its enumeration read to three minutes. It also
says plainly that a shutdown target is not electrical evidence.

**BP1 — LOW-MED. "Recovered across a reboot target" is printed after every ordinary reboot.** The
mark (132) is printed whenever the previous boot reached `reboot.target` and the device enumerated
in this one. A healthy controller enumerates at every boot, so ordinary reboots are marked
"recovered" too. The column exists to gather evidence on the one open hardware question (EX-017,
EX-019: can a warm reboot recover a wedged controller?). Marking every reboot as a recovery makes
that evidence look plentiful when it is not.
*Fix:* print the mark only when the previous boot ended wedged: an HCI command timeout or a USB
loss of the device in its last minutes (`stage2.awk` already classifies that), with no recovery
before it ended.

## 54. `tools/bt-boot-stats` (120 lines, read in full)

The table's purpose is right: it keeps correlations honest by showing false positives and false
negatives of a signature. It also says plainly that its totals are not the frozen baseline's.

**BS-1 — MED (on the laptop). It holds every boot's whole kernel log in memory.** Line 63 reads
each boot's entire kernel log into a shell variable (`log=$(bt_journal -k -b "$b" …)`). It then
copies it into here-strings four times (66-75). With dynamic debug a boot carries millions of
kernel lines; `journal-contract`'s header records one boot of 1,586,655 lines. Per boot this
costs hundreds of megabytes of memory and minutes, the exact shape `bt-status` removed
("held the entire boot's kernel journal in memory … hundreds of megabytes in a shell string").
*Fix:*
- count through `bt_journal_lines` with the union of the three patterns (`--grep`), as
  `bt-trial-audit` does;
- take the boot's first and last instants from `--list-boots -o json`, as `bt-retention` does.

**BS-2 — LOW-MED. BUSLOST counts every USB device, not the controller.** BUSLOST is documented as
"controller USB disconnects", the column that means "the controller died and needed a cold boot".
It counts every `USB disconnect, device number` line in the boot (72), whatever device is named:
a mouse, a phone, a headset dongle. `stage2.awk` anchors the same line to the controller's own
USB path learned from its enumeration line; this tool does not.
*Fix:* reuse that anchoring.

**BS-3 — LOW. It prefers the installed copy of `bt-boot-list`.** It takes `/usr/local/bin`'s copy
before its own sibling (47-50). That is the order `bt-phase` reversed on 2026-09-29, after the
checkout's tool ran whatever was last deployed. Sibling first.

## 55. `tools/bt-timeline.sh` (116 lines, read in full)

**TL1 — LOW-MED. With no argument, on the laptop's current boot it would run for hours.** The default
selection is the whole current boot (`-b 0`, line 52). The kernel stream is read unfiltered and
grepped afterwards (70), and bluetoothd's stream is read whole (it runs with `-d`). Then every
merged line goes through a `while read` loop that forks `date` once per line (89-90). With dynamic
debug on, the kernel filter `hci|btusb|bluetooth` keeps hundreds of thousands of lines on a
multi-day boot, so the default call forks hundreds of thousands of `date` processes. `bt-incident`
calls it with a 15-minute window and is unaffected.
*Fix:*
- default to a recent window (e.g. `-1h`) and say so in the header;
- pass the kernel filter as `--grep`;
- format all timestamps in the one `awk` that already tags them (`strftime` under gawk, which CI
  installs), not with a fork per line.

## 56. `tests/run-tests` — section headings searched, and the section behind T9 read (8855-8885)

The suite has 169 sections. A search of their headings for the subjects of this review's findings
finds sections on:
- the watchdog's capability probe and thresholds;
- `bt-phase`'s incident and probe definitions;
- `bt-env-history`'s watchdog states;
- `bt-exhibit`'s and `bt-incident`'s failing sanitiser;
- the guards on `--apply`;
- the coredump fixture as a claim;
- "probes and aborts count events, not lifecycle noise".

**T9, confirmed in the test itself.** The last of these feeds the probe counter this journal:

```
Starting Snapshot Bluetooth health metrics...
Finished Snapshot Bluetooth health metrics.
Starting Snapshot Bluetooth health metrics...
```

and requires a count of 1. This is the wording of systemd before the unit name was added to these
messages. This machine's systemd writes `Finished bt-health-snapshot.service - Snapshot Bluetooth
health metrics.` (§37). The test therefore passes on lines the machine no longer produces, while the
same counter reads 0 on real input. The fix for T9, PH1 and EH1 must change this fixture (to the
real line) in the same commit, or the test will start failing on the corrected code.

**What the headings do not show:** no section is named for these classes:
- "no tool sends an HCI command without `--probe`" (EV1);
- "every capture daemon is root-only" (UM1);
- "no `COLUMNS=` before `btmon`" (SW1);
- "no tool advises `--apply`" (VI1, DS1).

These are the tree-wide invariants proposed in the second-pass summary. Section bodies were not
read beyond this one, so an invariant filed under another heading is possible.

---

## Consolidated ranked list — all passes (written after §56)

About 18,500 of ~40,000 lines read line by line, plus pattern sweeps of every tool and script. For
fixing, by urgency, with the sections that hold the details.

**1. Act now (operational, the operator's decision)**
- **CAP1** (§7): the capture daemons will rotate away the unarchived U10 and BT-9 captures. Restart
  the archive or copy them to the keep directory. AR1 (§10) means the decode-free capture
  directory is never archived even then.

**2. Hazards that bypass rules held only in prose (HIGH, latent)**
- **KR1** (§38): under E3 a real failure would be marked PERTURBED and dropped from the E3 rate. The
  kernel's own reset is misattributed to the watchdog.
- **RS1** (§12): `repo-save` pushes every branch not on a short list to `origin`.
- **MODE1** (§8): `bt-mode mitigation` arms the watchdog; `install.sh` suggests it.
- **I1, UN1, RM1** (§4, §5, §32): live btusb reloads in `install.sh --apply`, `uninstall.sh` and
  `runtime-mgmt-test.sh`, against EX-046.
- **VI1, DS1, SR1** (§16, §50, §36): three places advise `install.sh --apply`. SR1 makes the
  verifier's advice likely on the laptop.

**3. Deploy-day traps (MED; small fixes, worth doing before the deploy)**
- **I2** (§4): `--tools-only` reads the whole boot's kernel log at its last step.
- **MODE2** (§8): `bt-mode status` prints "inactive" twice.
- **CK1** (§50): `devtools/check` always fails on the laptop.
- **SU1** (§21): extend the rehearsal so CI catches I2, VI1 and MODE2.

**4. Records and evidence (MED)**
- **T1** (§1): an interrupted close writes a duplicate row.
- **AJ1, BJ1** (§24, §23): journal archive gaps.
- **UN2, SW2** (§5, §31): advice and flags that delete unarchived captures.
- **SC-1** (§42): `bt-sco` can fill the disk and trigger capture pruning.
- **EV2, CP1** (§31, §29): unsanitised text left in tracked directories.
- **SC1, SAN1** (§13, §15): raw-byte and IPv6/EUI-64 addresses pass the publishing gate.
- **VR1** (§47): the restoration check is blind to `updates/` modules and the self-built
  bluetoothd.

**5. Measurement correctness (MED)**
- **PH1, T9, EH1** (§37), with **JC1** (§51) and the test fixture in §56: the probe counters cannot
  match this systemd's wording.
- **AC1** (§43): other boots' commands are shown as operator actions.
- **TA1** (§26): an unreadable window audits as clean.
- **KM1** (§39): the kernel-mechanism tool reads the stock module, not E3.
- **T2, SW1** (§1, §31): `COLUMNS=` is ignored by `btmon`.
- **M1, EV1, SW3** (§3, §31, §32): tools still open MGMT or send HCI by default.
- **BS-1, BS-2, BP1, HR1** (§54, §53, §40).
- **WD1** (§17): the watchdog's premise no longer holds under E3.

**6. Other MED**
- **SM1, SM2** (§19): the SMTP check reads a connect failure as REVOKED; the password goes on the
  command line.
- **SN1** (§18): `bt-snapshot` reads a fixed port and the first adapter of any kind.
- **CL2** (§45): before `--functional` runs on the laptop, establish where the harness runs
  `btvirt`.

**7. Everything else:** LOW and INFO items in their sections.

**Three recurring patterns** (second- and third-pass summaries). Fixing each once covers many
findings:
1. A fix that reached some sibling tools but not all.
2. Rules held in prose instead of code.
3. Fixtures and comments that encode an assumption instead of the machine.

The suite already pins several tree-wide rules as invariants; the list above names the ones
missing.

---

# Addendum — fifth pass (from 2026-10-19, after `74d7338`)

Same method. Findings below the consolidated list are added to it at the end of this pass.

## 57. `tools/bt-postmortem` (200 lines, read in full), checked against the watchdog's own messages

The incident scoping is right: timeouts are clustered by a gap, every event is searched only inside
the incident's window, and live state is read before log inference. The canonical timeout spelling
(EX-015) keeps `link tx timeout` out.

**PM1 — MED (latent; the first tool run after a failure). On the laptop its verdict reads the
watchdog's silence as evidence.** Every interpretive line is taken from the watchdog's journal
(`-u bt-hang-watchdog`, 96-103). The watchdog is off on the laptop by rule, so after an incident
there:
- "**The watchdog never intervened in this incident** despite N timeout(s). Check the
  threshold/cooldown" (161-167) sends the operator to tune a unit that is off on purpose.
- "**No early signal at all in this incident** — bluetoothd gave no audio-teardown warning" (191-192)
  is a claim about bluetoothd taken from the watchdog's log. The watchdog writes `early signal:`
  only through `vlog` (watchdog line 363), so only with `BT_VERBOSE=1` *and* `BT_EARLY=1`, and both
  default to 0 (74-75). With the watchdog running in its default configuration the sentence is
  false as well.
- The kernel's own reset under E3 (`Resetting usb device.`, KR1) is not on the timeline at all,
  so the one intervention that does happen on the laptop is missing from the account.
- "It left the bus after an intervention" (149) is printed whenever the device is off the bus,
  without checking that any intervention happened.

The header says this tool's output "is a CONCLUSION … and conclusions are what this project must not
get wrong". The first E3 failure, the most important event the experiment could record, would get
these conclusions.
*Fix:*
- read the early signals from bluetoothd's own journal (`-u bluetooth`), using the watchdog's
  patterns (342-346) moved into `journal.sh`;
- add a "kernel reset" row from `BT_RE_KERNEL_RESET` (KR1's fix);
- when the watchdog unit has no journal in the window, print "watchdog not running" and skip
  every watchdog-based line.

**PM2 — LOW-MED. Two unfiltered whole-boot reads, and a failed read prints a green all-clear.**
- The timeout scan (64-65) and `KLOG` (95) each read the boot's whole kernel log, and `KLOG` is held
  in a shell variable: BS-1's shape, on a tool run at the worst moment.
- Both reads discard stderr and are unchecked. A failed first read gives "No controller timeouts
  in range — nothing to analyse." in green and exit 0: TA1's confident zero.

*Fix:* take timeouts from `-p err` (as `bt-trial` does) through a checked read; select `KLOG` with
`--grep` on the union of the patterns used; refuse on a failed read.

**PM3 — LOW-MED. Any adapter and any USB device stand for the controller.**
- `hci_now` is the first entry of `/sys/class/bluetooth` (136), so a spare dongle hides "CONTROLLER
  IS DOWN RIGHT NOW" (BS1's defect, here in the verdict).
- `t_usb` (`descriptor read`) and `t_gone` (`USB disconnect`) match any USB device (100-101), so a
  phone unplugged within ten minutes of the first timeout becomes "device left the bus" (BS-2's
  defect).

*Fix:* resolve the hci node under the VID:PID device; anchor USB lines to the controller's path, as
`stage2.awk` does.

**PM4 — INFO.** `hm()` prints times without dates (51), so `--all` with a `--since` spanning
several days lists incidents by clock time only.

## 58. `tools/bt-logvolume` (126 lines, read in full)

The rate split (boot average beside the last 60 s) and the explicit rebuild of the 60-second
arguments are right; the header's "counting, not reading names" is the method that found
`NOISY_FUNCS`.

**LV1 — LOW-MED. With `-b -1` the rates describe the current boot.**
- The boot average divides boot −1's line count by the current boot's uptime (`/proc/uptime`,
  74).
- "Last 60 s" reads boot −1 with `--since -60s` (87), which is always empty, so the report prints
  `0 lines/min` and "Projected at the current rate: 0.00 GB/day".

A reader checking whether a past boot's debug load was under control is told it was silent.
*Fix:* for any boot but 0, take the span from `--list-boots` (first and last entry) and omit the
"last 60 s" and projection lines.

**LV2 — LOW. The fix for `-- No entries --` reached the rate line but not the total.** Line 91
filters it; the total (62-63) counts it, so an empty window reports `total lines 1` and lists one
shape at 100%, instead of the "no lines" message at 65. The same pattern as the first one in the
second-pass summary, inside one file.
*Fix:* filter the total the same way.

**LV3 — LOW. The default reads the whole boot into `/tmp`.** With no `--since`, the boot's whole
kernel log is written to `mktemp` (59-62) and sorted. On the laptop's current boot, with dynamic
debug since 2026-10-13, that is minutes of reading and gigabytes in `/tmp`. The free space on the
root filesystem on 2026-10-19 was 102 GB, so one boot's kernel text cannot reach the capture
daemons' 15 GB floor today.
*Fix:* default to `--since -1h` and say so, or warn with the boot's age before a whole-boot read.

**LV4 — INFO.** `/[0-9a-f]{8,}/` (112) needs interval support. The laptop's `awk` is gawk (checked
2026-10-19) and CI installs gawk; under an old mawk the pattern would never match and pointer-like
values would not collapse. `sanitize-logs.sh`'s capability gate is the house pattern if this ever
matters.

**A measurement for SC-1 (§42).** The same `df` reading bounds SC-1: with 102 GB free, `bt-sco`'s
buffer would have to pass about 87 GB before the floor is reached. Whether a decode of the 48 GB of
captures reaches that depends on the text-to-binary ratio, which has not been measured. SC-1 stands
as a possibility on a fuller disk, not as a certainty today.

## 59. `tools/bt-context` (122 lines, read in full)

Inverting the filter (show what is near a failure and *not* already understood) is the right
complement to the classifying tools.

**CX1 — LOW-MED. Its four anchors can come from four different incidents, or from no incident.**
Each anchor is the first match in the whole boot, taken independently (68-71):
- `USB disconnect, device number` and `device descriptor read/64, error` match any USB device, so
  "device left the USB bus" can be a phone unplugged days before the failure (BS-2's defect);
- the first timeout, the first USB failure and the first desync are each the boot's first, not the
  first of one incident.

The windows are then merged into one "unclassified near a failure" list. That is the mixing
`bt-postmortem`'s header records as a past defect ("Timestamps must come from ONE incident"). A
shape near an unrelated USB event is presented as a candidate explanation of the failure.
*Fix:* anchor the USB lines to the controller's path (as `stage2.awk` does), and take the USB and
desync anchors from inside the first timeout's incident (the gap clustering of `bt-postmortem`).

**CX2 — LOW. It copies the whole boot's journal, every unit, to `/tmp`.** Line 60 has no `-k` and no
filter. On the laptop's current boot (dynamic debug and `bluetoothd -d` since 2026-10-13) that is
hours of reading and many gigabytes, before the anchors (which need only four lines) are known.
*Fix:* find the anchors first with filtered reads (`--grep`, `-n 1`), then read only `±CTX` lines'
worth of time around each (`--since/--until` around the anchor's instant).

**CX3 — LOW (privacy). Address redaction knows only upper-case colon form.** Lines 90 and 113 replace
`[0-9A-F]{2}(:…){5}`. Lower-case addresses (NetworkManager and `wpa_supplicant` print them) and
bluetoothd's `dev_XX_XX_…` object paths pass through, under `--all` and `--full` in particular.
The output is for the terminal, but it is the kind people paste.
*Fix:* case-insensitive, plus the underscore form; or pipe through `sanitize-logs.sh`.

The KNOWN list does not contain `Resetting usb device`, so under E3 the kernel's reset (KR1) would
show up as unclassified, which is the right outcome for this tool.

## 60. `tools/bt-boots` (47 lines), `tools/bt-interval` (72 lines) (read in full)

`bt-interval` is sound: the shared arithmetic, `</dev/null` so awk cannot block on the caller's
stdin, a refusal on parse failure that names both arguments, and a refusal on a negative interval.

**BB1 — LOW-MED. `bt-boots` reads every boot twice, whole, and an unreadable boot shows zero
timeouts.** For each boot, the timeout and desync counts (41-42) each read the whole kernel log
unfiltered, with `|| true`. On the laptop that is two multi-day dynamic-debug reads for the current
boot alone. A failed read prints `0`, the same as a quiet boot (TA1's confident zero). The banner
column already shows `?` when it cannot read the kernel version; the counts do not.
*Fix:* count through `bt_journal_count` with `--grep` (timeouts from `-p err`); print `?` on a failed
read.

**BB2 — INFO.** `WD-ACTS` counts only watchdog interventions; under E3 the kernel's own reset (KR1)
has no column. Add `K-RESET` with KR1's fix. Sibling order (the checkout's `bt-boot-list` before
`/usr/local/bin`) is right here, unlike BS-3.

## 61. `tools/bt-env-history` (128 lines, read in full; EH1 in §37)

The method is right: every column comes from what the machine recorded at the time, and what cannot
be recovered is printed `?`, never guessed.

**EH2 — MED. The treatment that fixed BT-1 has no column.** The tool exists so that "34 boots, 287
timeouts" is not read as one system, and its footer says "Rows differing in any column are
DIFFERENT EXPERIMENTS". But it records only the mitigations: watchdog, autosuspend, power control,
probes. Which btusb ran is not recorded:
- stock (ROM firmware);
- E1;
- E3.

That is the treatment that ended the failures (74 links, 0 timeouts). Today a stock-driver boot and
an E3 boot, both with the watchdog off and no probes, print identical rows, and the footer reads
that as "the same experiment". So the tool invites the cross-treatment denominator it was written
to prevent.
*Fix:* add a FIRMWARE column from the boot's own kernel log: `using rampatch file:` and
`QCA: patch rome …` (`btusb.c` 3536 and 3549 in the `-38` source) are positive evidence that the
QCA setup ran. E1 and E3 both load it; to tell them apart, take `build` from the trial row of that
boot. The kernel release (from the `Linux version` banner, as `bt-boots` does) belongs beside it.

**EH3 — LOW-MED. A boot whose start has rotated away reads as "watchdog off".** `wd=off` is decided
by the absence of the startup banner (64), and the header says "No banner at all means it was not
running". The banner is logged at the start of the boot, which is exactly what journald discards
first from a long boot (BJ1). Such a boot, and also one whose watchdog read failed (stderr is
discarded), is shown as `off`, a confident claim in a column the header promises shows `?` when
unknown.
*Fix:* treat any watchdog line in the boot as proof it ran (state unknown without the banner). Print
`?` when the boot's first retained entry is not its start (the `Linux version` banner missing) or
when the read fails.

**EH4 — INFO.** The AUTOSUSP and POWER sets are joined with `for (k in a)` (89-90), so a boot with
both values prints `Y/N` or `N/Y` depending on the awk (L2).

## 62. `tools/bt-diagnose` (196 lines, read in full; the probe was noted in §31)

The probe is opt-in, the verdict says plainly that aggregate counts establish no cause, and the
firmware patterns (`using rampatch`, `nvm_usb`) match the strings in `btusb.c` (3536, 3595).

**DG1 — LOW-MED. The public entry point does not tell a 13d3:3503 owner that the fix exists, and
sends them to a tool that says it does not.** This is "the tool people clone the repo to run". For
`13d3:3503` with the phenotype, it ends by sending the reader to `bt-verify-kernel-mechanism`, which
prints `13d3:3503 ABSENT … not in upstream` (KM1). The cause is settled (BT-1): a kernel without
`dc16388d45ec` runs the ROM firmware. The useful answer for that reader is:
- run `scripts/btusb-has-device.py` on the running kernel's btusb;
- if ABSENT, a kernel carrying `dc16388d45ec` fixes it (in 7.2.10, 6.18.56 and 6.12.113).

*Fix:* print that for `13d3:3503`, and fix KM1 before pointing anyone at that tool.

**DG2 — LOW-MED. Four whole-boot reads per boot, all unchecked.** For each retained boot, line 157
reads the whole kernel log to `/dev/null` only to see that it exists. Lines 163-165 then read it
three more times, unfiltered, each with `|| true`. On a stranger's machine that is quick. On the
laptop it is hours, and a read that fails after the existence check adds `0` to every count.
*Fix:* one `--grep` read per boot with the union of the three patterns, counted in awk; skip the
existence read (`--list-boots` already says the boot exists); count failed reads and print them.

**DG3 — LOW.** With two controllers attached, the VID:PID advice uses whichever enumerated first
(`DEVS[0]`, 115). Loop the advice over `DEVS`.

## 63. `tools/lib/actions-render.awk`, `boot-hours.awk`, `capdiff-match.awk`, `sco-window.awk` (read in full)

All four are extractions that replaced private copies of the date arithmetic with the shared
`iso_secs()`. `boot-hours.awk` refuses an unparseable timestamp. `capdiff-match.awk`'s header
records the `-f` plus inline-program trap that once made the matcher report perfect agreement, and
its two-pointer pairing consumes matches on both sides. An unparseable time becomes -1 and lands
unmatched, which errs toward disagreement.

**AW1 — LOW. `actions-render.awk` does not use the guard it was extracted to get.** Its header says
`iso_secs()` "brings its guards: an unparseable timestamp yields -1". `flush()` (24-25) subtracts
the two values without checking for -1, so a collapsed run with one unparseable stamp prints a
cadence that is negative or tens of years long.
*Fix:* if either value is negative, print the run without a cadence.

**AW2 — LOW. The timeline has no dates.** `disp()` (18) keeps `HH:MM:SS.mmm` only. On a multi-day
boot, and with AC1's other-boot records mixed in, "x5 until 10:02:11" does not say which day. Print
the date when it changes, as a separator line.

**`sco-window.awk`** is correct as written, but it is one of the matchers SW1 disables: under
`COLUMNS=200` the header reads `HCI Comman..`, so `bt-sco --window` collects no marks and prints
nothing.

## 64. `tools/bt-ui-capture` (lines 255-698, read in full; the head was read in §22)

The design is careful throughout:
- every file it writes carries a marker, and only marked files are ever removed;
- runtime changes record their previous value before changing it;
- monitor output is capped by rotation;
- `collect` copies raw text into a `0700` directory and publishes only what the sanitiser accepts;
- nothing is restarted behind the operator's back.

**UC1 — LOW-MED (latent, privacy). The sanitiser's error output, which lists the addresses it could
not replace, is saved outside the protected directory.** On a refusal `sanitize-logs.sh` prints the
leftover MAC-like strings, UUIDs and IPv4 addresses themselves to stderr (its lines 200-216).
`collect` sends that stderr to `$out/sanitize-errors.txt` (662). That file is in the collect
directory, not in the `0700` `raw/`, and is created with mode `0644` under directories that are
`0755` down from `/var/log/bt-health`. It is also truncated for every file in the loop, so after a
refusal it holds only the last file's messages, and "see sanitize-errors.txt" can point at an empty
file.
Checked on the laptop (2026-10-19): the only collect run (2026-10-10) published all eight files; its
error file is empty. Nothing was exposed.
*Fix:* write the errors inside `raw/`, appending (`2>>`) under a per-file header.

**UC2 — LOW-MED. A bare `collect` covers the whole session, and the open session started on
2026-10-05.** With no `--since`, the window starts at the session's `started_at` (604). The
2026-10-05 session is still recorded as active (UI1), so a plain `collect` today reads two weeks of:
- the kernel log (dynamic debug);
- `bluetoothd -d`;
- PipeWire and WirePlumber at debug level.

It writes all of it to `raw/timeline.log` on the root filesystem, then a sanitised copy beside it.
That is hours of reading and many gigabytes. The one past collect (2026-10-10) wrote about 11 MB of
raw text; the window it was given is not recorded in its directory, so it does not bound this.
*Fix:* refuse a window longer than a set limit (e.g. 24 h) unless `--since` is given.

**UC3 — LOW.** `status` counts every PipeWire and GNOME Settings line since `started_at` (585-588)
to print four numbers: with the 2026-10-05 session still open, each `status` reads two weeks of
debug logs (T6's and DS2's shape). Count from `-n`-bounded reads, or since the last `status`.

**UC4 — INFO.** The dry-run plan falls back to one machine's account (`U=i`, uid 1000, `/home/i`,
385 and 466): the hard-coded-layout pattern of EV3, limited to `plan`. Print `<user>` instead.

## 65. `tools/bt-capdiff` (lines 138-290 read in full; the head was read in §41), checked against real `btmon` output

The rest of the tool is careful:
- the window is widened by the tolerance, so a pair straddling an edge is not counted as a loss;
- matching is one-to-one;
- an empty overlap is refused rather than reported as agreement;
- one-sided and two-sided loss are reported apart;
- the disagreement output carries a plain warning against reading it as a statement about the
  controller.

**CD2 — MED. The match key keeps `btmon`'s frame number, so on real captures the same event almost
never matches across the two paths.** `extract()` (101-108) removes only the trailing date and time
from each header line. A real `btmon -T -r` header line carries the frame number and index before
the time, as in the E3 trial's own decode (`evidence/trials/E3/trial-01/sco-params.txt`):

```
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17   …   #84078 [hci0] 2026-10-14 03:13:31.064881
```

So the key is `… plen 17   #84078 [hci0]`. `btmon` numbers frames from 1 in each file it reads, and
`extract()` runs one `btmon` per file. The two paths rotate at different points: `bt-trace` at each
`btmon` restart (about 74 attaches), `bt-capture` at 64 MB. The same event therefore carries
different numbers in the two paths, and nearly every record is reported unmatched in both
directions.
- The fixtures hide it. `tests/btmon/capdiff-a.txt` and `capdiff-b.txt` give the same event the
  same frame number in both paths (`#10`, `#11`), which two real captures do not do (the third
  recurring pattern).
- The caveat block (265-281) lists three reasons the paths can differ without loss, but not this
  one, which alone accounts for nearly all of the differences.
- With SW1 (`COLUMNS=200` ignored at line 86) the event text is also shortened (T2), so what
  distinguishes one key from another is mostly the frame number.

The "~1400 unmatched" reading quoted in the header (208) may be largely this defect and should not
be cited as a measurement of capture loss until it is re-run.
*Fix:*
- remove `#[0-9]+ \[hci[0-9]+\]` from the key (keep the index as its own field);
- decode with `--columns=200` (SW1);
- give `capdiff-b.txt` different frame numbers from `capdiff-a.txt`, so the test fails on the
  current code and passes on the fix.

**CD3 — LOW.** `--since`/`--until` replace the overlap bounds as given (135-136), and the window
program (166) does not check `iso_secs()` for -1. An unparseable `--since` therefore silently means
"from the beginning". An unparseable `--until` means "nothing", which is refused as an empty overlap.
Refuse a bound that does not parse.

## 66. `tools/bt-health-report.sh` (lines 121-256 read in full; the head was read in §40)

The watchdog section keeps confirmed recovery, early-action answers and legacy markers apart, and
live state outranks every counter. The closing advice ("keep four quantities separate") is the
project's method stated in the report.

**HR2 — LOW-MED. A boot whose start has rotated away is dropped from the per-boot table.** Line 127
skips any boot without a `Linux version` banner (`continue`). `bt-boots` fixed exactly this: "A boot
whose 'Linux version' banner rotated away is still a boot; a row of ?s keeps it visible instead of
silently shrinking the table". The fix did not reach this copy of the loop. The boots most likely to
lose their start are the long dynamic-debug ones, including the laptop's current boot (BJ1), so the
table silently omits the boots with the most exposure.
*Fix:* print the row with `?` for the kernel, as `bt-boots` does. Better, share one per-boot
counting function between the two tools, since `bt-boots` and this loop are the same code (BB1's
reads included).

**HR3 — LOW-MED. Live state is checked against any adapter.** "CONTROLLER IS DOWN RIGHT NOW" is
decided by the first entry of `/sys/class/bluetooth` (180). That makes this the fourth site of the
any-adapter check (BS1 in `bt-status`, PM3 in `bt-postmortem`, `bt-snapshot`'s SN1). The comment
above it records the masking flaw being fixed in three tools, but the VID:PID half of the fix
reached none of them.
*Fix:* one helper in `tools/lib/` that resolves the hci node under the VID:PID device, used by all
four.

**HR4 — INFO.** Sections 4 and 5 format TSV with `col` (221, 233), a reverse-line-feed filter that
passes tabs through. `column -t -s $'\t'` aligns columns, which looks like the intent.

## 67. `tools/bt-actions` (lines 1-275 read in full; the capture pass was read in §43)

One awk program holds every classification rule, so a new signal is one rule. A fixture-driven run
cannot reach the real captures (64-66, after two incidents recorded in the comment). The watchdog
patterns match the watchdog's actual messages (checked against `bin/bt-hang-watchdog` 240 and 420).
The timeout rules are ordered so that `command tx timeout` without an opcode reaches its own rule.

**AX1 — LOW-MED. Every USB-core line about any device is shown as the controller's action.** The
CTRL class is "what the controller did". It includes:
- `usb .*: USB disconnect` → "\*\*\* DEVICE LEFT THE USB BUS \*\*\*" (263);
- `new full-speed USB device number` → "USB re-enumeration attempt" (266). Mice and keyboards are
  full-speed devices too.
- descriptor-read and address errors (254-258).

None of these is anchored to the controller's USB path. Plugging in a mouse during a session puts a
re-enumeration in the controller's timeline. Unplugging a phone puts "DEVICE LEFT THE USB BUS" in
capitals into a timeline the header offers to a maintainer as the sequence of events. This is
BS-2's and PM3's defect, in the tool whose output is most likely to be quoted.
*Fix:* learn the controller's USB path from its enumeration line and match only that path, as
`stage2.awk` does (one shared helper, with BS-2 and PM3).

**AX2 — LOW-MED. The kernel's own reset appears as an unattributed port reset.** Under E3 the
kernel's command-timeout reset prints `Resetting usb device.` (KR1), which no rule matches. The USB
core's following `reset full-speed USB device` is labelled "USB port reset performed" in CTRL, so
the timeline does not say who reset the controller. On the stock driver the same label stood
beside the watchdog's WDOG rows, which made the attribution clear. Under E3 nothing does.
*Fix:* a rule for `hci[0-9]+: Resetting usb device` labelled "kernel command-timeout reset
(btusb_qca_reset)", from KR1's shared `BT_RE_KERNEL_RESET`.

**AX3 — LOW.** The default is the whole current boot, every unit, unfiltered (79, 92). On the
laptop's current boot that is hours, as with TL1, before AC1's capture pass adds a decode of every
capture. Default to a recent window and pass the classifier's anchors as `--grep` where they are
kernel-only.

