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

