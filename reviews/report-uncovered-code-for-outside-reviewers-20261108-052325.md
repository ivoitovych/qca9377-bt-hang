# Report: the code the test suite never runs, for outside reviewers' coverage ideas

```
date:     2026-11-08T05:23Z
commit:   c5defd7d94b75daa693ca44947c3c629822ed8c9 (every line number below is at this commit)
from:     the test-suite maintainer
purpose:  every uncovered line, statement and branch the three coverage instruments report,
          with the context a reviewer needs to propose a test for it, or to argue it should not
          be counted; the answers go into the suite test-first
source:   devtools/coverage, devtools/awk-coverage and devtools/py-coverage, each run twice
          on this commit: once for its table (all 1115 checks held in each of those runs), once
          with --uncovered for its list; the code shown is read from the commit itself
```

## 1. What we ask of you

For each block below, or for any group of blocks that one test would cover, tell us:

1. **Reachable?** Can the suite reach it at all, given the rules in section 2? If not, why not
   (dead code, a branch only the real machine can take, a defensive check that cannot fire).
2. **The test.** How to drive it: which seam (an environment variable the tool reads), which stub
   on `PATH`, which fixture or input, and what the tool must print or exit with.
3. **Red for the right reason.** What breaking the code would make the test fail, so that the
   test is shown failing before it is trusted.
4. **Or the exclusion.** If a line should not be counted, the reason, in the form of section 10.
5. **Or the bug.** If reading a block shows a defect, say so first: that matters more than the
   line.

A short form is enough:

```
<file>:<lines> — reachable: yes|no|only on the machine — test: <seam, stub, input> → <expected>
                — red if: <the change that must make it fail> — confidence: high|medium|low
```

Please quote file and line numbers as this commit has them. Ideas for whole families of lines
(section 3) are as welcome as single tests.

## 2. The suite, and what a test may and may not do

The project investigates a Bluetooth controller that hangs on one laptop: shell, awk and
Python tools that watch, record and classify what the controller and the kernel do, and a
"trial" opened at each boot and closed at shutdown, which writes one results row. The tools
run on that laptop, the investigation machine, while a live experiment runs on it.

`tests/run-tests` is the whole suite: one bash file of about 15,500 lines, a setup and about
fifty sections, run in parallel (one worker per core) or `--serial`. What a test may do:

- **Run a tool from the checkout**, with its seams set: environment variables naming every
  machine path a tool reads or writes (`BT_HEALTH_DIR`, `BT_TRIAL_STATE_DIR`, the sysfs and
  usbfs roots, `BT_JOURNAL_DIR` and about thirty more; `tests/system-resources.md` lists them).
  Every seam whose default is a machine path is declared into an empty "declared machine" for
  the whole run.
- **Stub a machine tool on `PATH`**: `journalctl`, `btmon`, `systemctl`, `bluetoothctl`,
  `btmgmt`, `hciconfig` and the rest (`tests/machine-tools`, 51 of them). Unstubbed, each
  resolves to a tripwire that records the call and fails the run.
- **Use fixtures**: captured journal shapes (`tests/journal/`), real `btmon` output
  (`tests/btmon/`), and a renderer that prints as the real `btmon` 5.72 does
  (`tests/btmon/render`).
- **Build a namespace world** where the host allows unprivileged user namespaces: one for
  `bt-ui-capture`'s shipped defaults, one for the checkout (`devtools/held`, `save`,
  `review-open` run in an overlay of the checkout with no network).

What a test may not do:

- **Touch the real machine**: no real journal, no real Bluetooth, no real `/sys`, `/etc` or
  `/usr/local`, no network. The run proves it: a tripwire on every machine tool, footprints of
  the system binaries, the project's installed files, the tracked files and the real trial
  state, before and after; an access audit (`devtools/access-audit`) traces every file access
  of the whole suite under `strace`.
- **Depend on the host**: it must give the same verdict in CI (GitHub's ubuntu-24.04 runners)
  and on the laptop. A branch only some hosts can take is reported NOT ASKED by name, never
  counted as a pass.
- **Be trusted before it has failed**: every new check is first seen red against the unfixed
  or broken code.

## 3. How coverage is measured, and what the figures hide

- **bash**: `devtools/coverage` runs the suite with `BASH_ENV` turning on `xtrace` with a
  tagged `PS4` in every bash it starts, and counts the lines that ran against the coverable
  lines of every shipped shell file. Floor 80% (CI).
- **awk**: `devtools/awk-coverage`, statement coverage under `gawk --profile`, for the awk
  libraries in `tools/lib/` and the inline awk programs in the tools. Floor 95%.
- **Python**: `devtools/py-coverage`, line coverage of the shipped Python. Floor 80%.

| | lines run | of | uncovered |
|---|---|---|---|
| bash | 9588 | 11269 (85.1%) | 1681 |
| awk (statements) | 1502 | 1536 (97.8%) | 34 |
| Python | 698 | 777 (89.8%) | 79 |

The bash total of 85.1% is an average over very different kinds of code:

| area | lines run | coverage | uncovered | of which bare `case` labels |
|---|---|---|---|---|
| Shipped tools: `bin/`, `tools/`, `install.sh`, `uninstall.sh` | 4437 of 4695 | 94.5% | 258 | 28 |
| `devtools/`: instruments, repository tools, standalone scripts | 780 of 1389 | 56.2% | 609 | 9 |
| `tests/`: the suite's own file and its helpers | 4371 of 4979 | 87.8% | 608 | 3 |
| `results/`, `evidence/`: experiment records | 0 of 206 | 0.0% | 206 | 0 |

What that table says, and the families of lines it points to:

- **Bare `case` labels are counted but can never run.** A line holding only a pattern, such as
  `start)` or `*"failed: -110"*)`, is never traced by bash, so `devtools/coverage` counts it
  uncovered whether its branch ran or not (it says so itself: its figures are a lower bound).
  There are 40 of them. The listings below leave them out: a branch that never ran shows
  through its body's lines, which are listed. Appendix A names every label left out. The
  instrument will stop counting them, test-first; you need not propose anything for them.
- **A command over several lines is traced at its first line only**, so the rest of a long
  quoted message or a multi-line condition shows uncovered when the command did run. Where a
  block's first line is unmarked and only its later lines are, that is the reason.

- **The shipped tools are at about 94.5%.** Section 4 lists their uncovered lines one block at a
  time; they are the most valuable to cover, since they run on the investigation machine.
- **The instruments cannot measure themselves from inside the suite.** `devtools/coverage`,
  `awk-coverage`, `py-coverage` and `test-comprehension` run the suite; the suite runs them
  only against a toy suite with a hand-counted answer, so their paths for the real suite, the
  floors and the failure reports, show as uncovered. Ideas for driving more of them against a
  toy suite are welcome.
- **Standalone scripts at 0%**: `devtools/test-bt-journal-files.sh`, `test-journal-fast.sh`,
  `hooks/test-pre-push.sh` and `journal-speed/bench*.sh` are run by hand, never by the suite.
  Whether each should move into the suite, leave coverage's scope or be retired is being asked
  of the project's maintainers; listing them here is for completeness.
- **`results/` and `evidence/`** hold the scripts of finished experiments, records rather than
  tools. Python coverage leaves `results/` out of scope; bash coverage still counts it. That
  inconsistency is ours to fix, not yours.
- **The suite's own uncovered lines** (`tests/run-tests`) are mostly paths a green run does not
  take: skip branches for hosts without a namespace or a tool, multi-line failure messages, and
  helpers used only on the laptop. Its single-line failure branches are already excluded
  (section 10). Ideas there are about which of those paths a test could drive on purpose.

Known gaps you need not spend time on (already found, being closed):

- `tools/lib/journal.sh` is sourced, not run, so bash coverage counts none of it at all, and
  its fast kernel path (`bt_journal_kernel_fast`) is switched off in the suite
  (`BT_JOURNAL_DIR` declared absent). A test against a journal built with
  `systemd-journal-remote` is planned.
- `devtools/hooks/pre-push`, the publish gate on every push, has no test in the suite.
- Without `zstd`, the `bt-journal-files` section runs only its refusal and says so inside a
  passing check, instead of reporting the copy cases NOT ASKED.

## 4. The shipped tools, block by block

`»` marks a line that never ran; the unmarked lines around it are context, and may have run.

#### [`bin/bt-hang-watchdog`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-hang-watchdog) — 16 uncovered of 202 coverable lines (92.1% run)

[lines 125–125](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-hang-watchdog#L125-L125)
```bash
   124 │     done
»  125 │     return 1
   126 │ }
```
[lines 179–179](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-hang-watchdog#L179-L179)
```bash
   178 │             notify-send -u critical "Bluetooth" "$msg" >/dev/null 2>&1
»  179 │     done < <(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $3}' | sort -u)
   180 │     return 0
```
[lines 281–281](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-hang-watchdog#L281-L281)
```bash
   280 │     else
»  281 │         log "device present at $dev (no hci node yet)"
   282 │     fi
```
[lines 320–321](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-hang-watchdog#L320-L321)
```bash
   319 │         *hci*"tx timeout"*)               class=late ;;
»  320 │         *hci*"failed: -110"*)             class=late ;;
»  321 │         *hci*"setting interface failed"*) class=late ;;
   322 │     esac
```
[lines 344–346](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-hang-watchdog#L344-L346)
```bash
   343 │             *"cancel_request() Abort"*)    class=early ;;
»  344 │             *avdtp_connect_cb*)            class=early ;;
»  345 │             *"avdtp_close failed"*)        class=early ;;
»  346 │             *"SDP record: Host is down"*)  class=early ;;
   347 │         esac
```
[lines 368–369](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-hang-watchdog#L368-L369)
```bash
   367 │         if (( now - last_recover < COOLDOWN )); then
»  368 │             log "EARLY threshold reached ($en/$EARLY_THRESHOLD) but suppressed by cooldown ($(( COOLDOWN - (now - last_recover) ))s remaining)"
»  369 │             continue
   370 │         fi
```
[lines 384–384](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-hang-watchdog#L384-L384)
```bash
   383 │             0) log "  EARLY action completed — no claim that BT-1 was imminent"; fails=0 ;;
»  384 │             2) ;;
   385 │             *) ((fails++)); log "consecutive failed recoveries: $fails/$MAX_FAILS" ;;
```
[lines 427–427](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-hang-watchdog#L427-L427)
```bash
   426 │         0) fails=0 ;;
»  427 │         2) ;;   # unverifiable: do not count as failure, do not reset either
   428 │         *) ((fails++))
```
[lines 431–432](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-hang-watchdog#L431-L432)
```bash
   430 │     esac
»  431 │ done < <(
»  432 │     if (( EARLY )); then
   433 │         # Follow the kernel AND bluetoothd. journalctl ORs separate matches with
```
[lines 436–439](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-hang-watchdog#L436-L439)
```bash
   435 │         # bluetoothd, the late ones in the kernel.
»  436 │         bt_journal -f -n0 --output=cat \
   437 │             _TRANSPORT=kernel + _SYSTEMD_UNIT=bluetooth.service 2>/dev/null
   438 │     else
»  439 │         bt_journal -k -f -n0 --output=cat 2>/dev/null
   440 │     fi
```

#### [`bin/bt-trace`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-trace) — 1 uncovered of 103 coverable lines (99.0% run)

[lines 65–65](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-trace#L65-L65)
```bash
    64 │     --check) CHECK=1 ;;
»   65 │     "") ;;
    66 │     *) log "bt-trace: unknown argument: $1"; exit 1 ;;
```

#### [`bin/bt-usbmon`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-usbmon) — 6 uncovered of 98 coverable lines (93.9% run)

[lines 49–49](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-usbmon#L49-L49)
```bash
    48 │     --check) CHECK=1 ;;
»   49 │     "") ;;
    50 │     *) log "bt-usbmon: unknown argument: $1"; exit 1 ;;
```
[lines 126–127](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-usbmon#L126-L127)
```bash
   125 │         if [[ "$oldest" == "${CURRENT:-}" ]]; then
»  126 │             log "ERROR: only the live capture remains and the floor is still breached"
»  127 │             break
   128 │         fi
```
[lines 214–216](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-usbmon#L214-L216)
```bash
   213 │         sleep 5 & wait $!
»  214 │         prune
»  215 │         start_capture
»  216 │         continue
   217 │     fi
```

#### [`install.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/install.sh) — 22 uncovered of 345 coverable lines (93.6% run)

[lines 52–53](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/install.sh#L52-L53)
```bash
    51 │         --tools-only)  APPLY=1; TOOLS_ONLY=1 ;;
»   52 │         --no-metrics)  METRICS=0 ;;
»   53 │         -h|--help)     sed -n '2,15p' "$0"; exit 0 ;;
    54 │         *) echo "unknown option: $a" >&2; exit 1 ;;
```
[lines 139–139](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/install.sh#L139-L139)
```bash
   138 │         case "${1:-}" in
»  139 │             install|rm|rmdir|mkdir) ;;
   140 │             *) echo "  tools-only: NOT executed (would arm or touch the system): $*"; return 0 ;;
```
[lines 152–154](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/install.sh#L152-L154)
```bash
   151 │         if ! "$@"; then
»  152 │             echo "    ERROR: command failed: $*" >&2
»  153 │             FAILED=1
»  154 │             return 1
   155 │         fi
```
[lines 211–211](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/install.sh#L211-L211)
```bash
   210 │         if [[ -e "$DESTDIR$dst.pre-qca9377-bt-hang" ]]; then
»  211 │             echo "  ! $dst differs from the source — replaced; the earlier pre-install copy is kept"
   212 │         elif [[ -s "$DESTDIR/usr/local/share/qca9377-bt-hang/installed-at" ]]; then
```
[lines 281–281](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/install.sh#L281-L281)
```bash
   280 │     # Counted, not `grep -q` — see the note at the btusb reload below.
»  281 │     n_tmo_warn=$(journalctl -k -b 0 --no-pager 2>/dev/null \
   282 │                  | grep -cE 'command( 0x[0-9a-f]+)? tx timeout' || true)
```
[lines 319–325](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/install.sh#L319-L325)
```bash
   318 │         # this guard, which is worse than not printing it.
»  319 │         echo "   --tools-only does NOT reload btusb and does not touch the device,"
»  320 │         echo "   so this trial is not perturbed. It DOES change the measurement"
»  321 │         echo "   revision mid-trial; the row records that as mrev_start..mrev_end."
»  322 │         echo
»  323 │         echo "   Note it if you want it legible:  bt-trial step \"tools-only deploy\""
»  324 │         echo "   Continuing in 3 s — Ctrl-C to stop."
»  325 │         sleep 3
   326 │     else
```
[lines 438–438](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/install.sh#L438-L438)
```bash
   437 │     else
»  438 │         echo "    ERROR: could not write $UDEV" >&2; FAILED=1
   439 │     fi
```
[lines 554–555](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/install.sh#L554-L555)
```bash
   553 │ else
»  554 │     echo "  WARNING: tcpdump not found — USB transport capture not installed"
»  555 │     USBMON=0
   556 │ fi
```
[lines 612–612](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/install.sh#L612-L612)
```bash
   611 │ else
»  612 │     echo "  skipped (--no-metrics)"
   613 │ fi
```
[lines 730–730](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/install.sh#L730-L730)
```bash
   729 │     # to be repo-wide.
»  730 │     n_tmo=$(journalctl -k -b 0 --no-pager 2>/dev/null \
   731 │             | grep -cE 'command( 0x[0-9a-f]+)? tx timeout' || true)
```
[lines 746–746](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/install.sh#L746-L746)
```bash
   745 │     elif [[ -n "${uc:-}" ]]; then
»  746 │         echo "  btusb in use (usecount=$uc) — autosuspend setting applies at next boot"
   747 │     fi
```
[lines 757–757](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/install.sh#L757-L757)
```bash
   756 │ if (( FAILED )); then
»  757 │     echo "=== INSTALL FAILED ===" >&2
   758 │     echo "One or more steps did not complete (see ERROR lines above)." >&2
```

#### [`tools/bt-actions`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-actions) — 1 uncovered of 40 coverable lines (97.5% run)

[lines 275–275](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-actions#L275-L275)
```bash
   274 │ }
»  275 │ ' >> "$STREAM"
   276 │ 
```

#### [`tools/bt-archive`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-archive) — 16 uncovered of 159 coverable lines (89.9% run)

[lines 99–102](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-archive#L99-L102)
```bash
    98 │         --replace)   FORCE=1 ;;
»   99 │         -h|--help)   sed -n '2,8p' "$0"; exit 0 ;;
   100 │         -[0-9]*|[0-9]*) BOOT="$1" ;;
   101 │         -*)          refuse "unknown option: $1" ;;
»  102 │         *)           refuse "not a boot index: $1" ;;
   103 │     esac
```
[lines 143–146](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-archive#L143-L146)
```bash
   142 │         *.zst) command -v zstd >/dev/null 2>&1 && { echo "zstd -dc"; return 0; } ;;
»  143 │         *.xz)  command -v xz   >/dev/null 2>&1 && { echo "xz -dc";   return 0; } ;;
   144 │         *.gz)  command -v gzip >/dev/null 2>&1 && { echo "gzip -dc"; return 0; } ;;
   145 │     esac
»  146 │     return 1
   147 │ }
```
[lines 185–191](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-archive#L185-L191)
```bash
   184 │         if (( ${#cand[@]} > 1 )); then
»  185 │             printf '  %-4s %-10s %10s %10s  %s\n' "$idx" "$sid" '?' '?' \
   186 │                    "AMBIGUOUS — ${#cand[@]} archives for one boot; remove all but the newest"
»  187 │             continue
   188 │         fi
   189 │         d=$(decomp_for "${cand[0]}") || {
»  190 │             printf '  %-4s %-10s %10s %10s  %s\n' "$idx" "$sid" '?' '?' 'UNREADABLE — no decompressor'
»  191 │             continue
   192 │         }
```
[lines 196–196](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-archive#L196-L196)
```bash
   195 │         if (( ${ln:-0} == 0 )); then
»  196 │             printf '  %-4s %-10s %10s %10s  %s\n' "$idx" "$sid" "${an:-0}" '0' 'boot unreadable — NOT verified'
   197 │         elif [[ "$idx" == "0" ]]; then
```
[lines 217–218](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-archive#L217-L218)
```bash
   216 │                 else
»  217 │                     printf '  %-4s %-10s %10s %10s  %s\n' '' '' '' '' '↳ REPAIR FAILED — run by hand'
»  218 │                     unfixed_n=$((unfixed_n + 1))
   219 │                 fi
```
[lines 274–275](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-archive#L274-L275)
```bash
   273 │             zstd) COMP="zstd -q -T0"; EXT="zst"; DECOMP="zstd -dc" ;;
»  274 │             xz)   COMP="xz -T0";      EXT="xz";  DECOMP="xz -dc" ;;
»  275 │             gzip) COMP="gzip";        EXT="gz";  DECOMP="gzip -dc" ;;
   276 │         esac
```
[lines 284–284](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-archive#L284-L284)
```bash
   283 │ # reboot. An archive called boot--4 would name a different boot tomorrow.
»  284 │ BID=$(bt_journal --list-boots --no-pager 2>/dev/null \
   285 │       | awk -v b="$BOOT" '$1 == b { print $2; exit }')
```
[lines 290–290](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-archive#L290-L290)
```bash
   289 │ if [[ -e "$OUT" ]] && (( ! FORCE )); then
»  290 │     refuse "$OUT already exists — remove it deliberately, or pass --replace to repair a SHORT archive (see --check)"
   291 │ fi
```
[lines 347–347](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-archive#L347-L347)
```bash
   346 │ if (( ${SRC_N:-0} == 0 )); then
»  347 │     refuse "the source boot yielded no records — refusing to call an empty archive a backup"
   348 │ fi
```

#### [`tools/bt-boot-provenance`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-boot-provenance) — 4 uncovered of 39 coverable lines (89.7% run)

[lines 89–89](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-boot-provenance#L89-L89)
```bash
    88 │     # messages, so a bounded tail is both correct and fast.
»   89 │     pe=$(bt_journal -b "$((off - 1))" -n 400 --no-pager 2>/dev/null \
    90 │          | grep -oE 'Reached target (reboot|poweroff|halt)' | tail -1 | awk '{print $3}')
```
[lines 95–95](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-boot-provenance#L95-L95)
```bash
    94 │     # takes minutes on a journal this size.
»   95 │     fw=$(bt_journal -b "$off" -t systemd --no-pager 2>/dev/null \
    96 │          | grep -m1 -oE '[0-9.]+m?s \(firmware\)' | awk '{print $1}')
```
[lines 119–121](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-boot-provenance#L119-L121)
```bash
   118 │     else
»  119 │         until_t=""
   120 │     fi
»  121 │     nhci=$(bt_journal -k -b "$off" ${until_t:+--until "$until_t"} --no-pager 2>/dev/null \
   122 │            | grep -c "idVendor=$VID, idProduct=$PID" || true)
```

#### [`tools/bt-boot-stats`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-boot-stats) — 3 uncovered of 54 coverable lines (94.4% run)

[lines 57–57](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-boot-stats#L57-L57)
```bash
    56 │ if (( TSV )); then
»   57 │     printf 'boot\tdate\thours\tdesync\ttimeout\tbuslost\ttmo\n'
    58 │ else
```
[lines 86–86](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-boot-stats#L86-L86)
```bash
    85 │     # plausible number.
»   86 │     hours=$(awk -f "$LIBDIR/timestamp.awk" -f "$LIBDIR/boot-hours.awk" \
    87 │                 -v a="$first" -v b="$last" </dev/null) || hours="?"
```
[lines 100–100](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-boot-stats#L100-L100)
```bash
    99 │     if (( TSV )); then
»  100 │         printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$b" "$d" "$hours" "$nd" "$nt" "$nb" "$h"
   101 │     else
```

#### [`tools/bt-boots`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-boots) — 1 uncovered of 22 coverable lines (95.5% run)

[lines 27–27](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-boots#L27-L27)
```bash
    26 │     if [[ -n "$BOOTLIST" ]]; then "$BOOTLIST" ${1:+-n "$1"}
»   27 │     else bt_journal --list-boots 2>/dev/null | awk '$1 ~ /^-?[0-9]+$/ {print $1}' | sort -n; fi
    28 │ }
```

#### [`tools/bt-capdiff`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-capdiff) — 2 uncovered of 110 coverable lines (98.2% run)

[lines 87–87](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-capdiff#L87-L87)
```bash
    86 │         btmon --columns=200 -T -r "$f" 2>/dev/null   # --columns: COLUMNS is not read when piped
»   87 │     done | awk '
    88 │         # Keep the FULL date and millisecond precision. An earlier version cut
```
[lines 262–262](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-capdiff#L262-L262)
```bash
   261 │ else
»  262 │     echo "  ⚠ Unmatched records in the decode-free path only — btmon did not record them."
   263 │ fi
```

#### [`tools/bt-context`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-context) — 5 uncovered of 62 coverable lines (91.9% run)

[lines 45–45](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-context#L45-L45)
```bash
    44 │         -C)     CTX="${2:-12}"; shift 2 ;;
»   45 │         --all)  SHOW_ALL=1; shift ;;
    46 │         --full) FULL=1; shift ;;
```
[lines 111–114](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-context#L111-L114)
```bash
   110 │ } | sed -E "
»  111 │     s/^[^ ]+ [^ ]+ //;                                   # drop timestamp+host
»  112 │     s/\[[0-9]+\]/[]/g;                                   # collapse PIDs
»  113 │     s/[0-9A-F]{2}(:[0-9A-F]{2}){5}/<MAC>/g;
»  114 │     s/\b[0-9]+\b/N/g;                                    # collapse numbers
   115 │ " | sort | uniq -c | sort -rn | head -40
```

#### [`tools/bt-crash`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-crash) — 3 uncovered of 64 coverable lines (95.3% run)

[lines 70–70](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-crash#L70-L70)
```bash
    69 │ if bt_journal_available; then
»   70 │     CRASH=$(bt_journal -b "$BOOT" --no-pager -o short-iso 2>/dev/null \
    71 │             | grep -E 'segfault|core-dump|Failed with result' || true)
```
[lines 101–101](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-crash#L101-L101)
```bash
   100 │ # capture group and makes the line say what it means.
»  101 │ OFF=$(grep -oE 'in [A-Za-z0-9_.+-]+\[[0-9a-f]+,' <<<"${CRASH:-}" 2>/dev/null \
   102 │       | sed -E 's/^in (.+)\[([0-9a-f]+),$/\2 \1/' \
```
[lines 127–127](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-crash#L127-L127)
```bash
   126 │ else
»  127 │     LIST=$(bt_coredumpctl list --no-pager 2>/dev/null | tail -n +2 \
   128 │            | grep -iE 'bluetoothd|btmon|btusb|bt-' || true)
```

#### [`tools/bt-diagnose`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-diagnose) — 11 uncovered of 114 coverable lines (90.4% run)

[lines 39–39](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-diagnose#L39-L39)
```bash
    38 │     if [[ -n "$BOOTLIST" ]]; then "$BOOTLIST" ${1:+-n "$1"}
»   39 │     else bt_journal --list-boots 2>/dev/null | awk '$1 ~ /^-?[0-9]+$/ {print $1}' | sort -n; fi
    40 │ }
```
[lines 128–132](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-diagnose#L128-L132)
```bash
   127 │ if (( PROBE )); then
»  128 │     alive=unknown
»  129 │     if command -v hciconfig >/dev/null 2>&1; then
»  130 │         timeout 6 hciconfig "$HCI" name >/dev/null 2>&1 && alive=yes || alive=no
»  131 │     elif command -v btmgmt >/dev/null 2>&1; then
»  132 │         timeout 6 btmgmt --index "${HCI#hci}" info >/dev/null 2>&1 && alive=yes || alive=no
   133 │     fi
```
[lines 136–140](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-diagnose#L136-L140)
```bash
   135 │ case "$alive" in
»  136 │     yes)      echo "  ${G}✓${O} controller responds to HCI commands" ;;
»  137 │     no)       echo "  ${R}✗${O} controller does NOT respond — it is stalled right now" ;;
   138 │     unprobed) echo "  ${Y}•${O} liveness not probed — a probe is an HCI command into the controller;"
   139 │               echo "    pass --probe to send one (never inside a hang you mean to observe)" ;;
»  140 │     *)        echo "  ${Y}•${O} cannot probe (install 'bluez' for hciconfig/btmgmt)" ;;
   141 │ esac
```
[lines 186–187](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-diagnose#L186-L187)
```bash
   185 │     else
»  186 │         echo "For $VID:$PID, inspect the matching btusb device-table entry and the"
»  187 │         echo "running module before drawing a driver-mechanism conclusion."
   188 │     fi
```

#### [`tools/bt-env-history`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-env-history) — 4 uncovered of 32 coverable lines (87.5% run)

[lines 92–94](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-env-history#L92-L94)
```bash
    91 │                 print (as == "" ? "?" : as), (pw == "" ? "?" : pw)
»   92 │             }' "$METRICS")
»   93 │         autos=$(cut -d' ' -f1 <<<"$vals")
»   94 │         power=$(cut -d' ' -f2 <<<"$vals")
    95 │     fi
```
[lines 102–102](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-env-history#L102-L102)
```bash
   101 │     # re-verify against the live journal after a systemd upgrade.
»  102 │     probes=$(bt_journal -u bt-health-snapshot.service -u bt-health-snapshot-event.service \
   103 │              -b "$idx" --no-pager -o cat 2>/dev/null \
```

#### [`tools/bt-exhibit`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-exhibit) — 11 uncovered of 166 coverable lines (93.4% run)

[lines 72–73](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-exhibit#L72-L73)
```bash
    71 │             --cmd)   cmd="${2:-}";   shift 2 ;;
»   72 │             --boots) boots="${2:-}"; shift 2 ;;
»   73 │             *) die "unknown argument: $1" ;;
    74 │         esac
```
[lines 185–188](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-exhibit#L185-L188)
```bash
   184 │     else
»  185 │         rm -f "$clean"
»  186 │         echo "bt-exhibit: REFUSING — the sanitiser failed; exhibit NOT written" >&2
»  187 │         rm -f "$raw"
»  188 │         exit 1
   189 │     fi
```
[lines 271–274](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-exhibit#L271-L274)
```bash
   270 │ exhibit_claim() {
»  271 │     awk '
»  272 │         /^\*\*(Historical )?[Cc]laim[^*]*\*\*/ { inclaim = 1 }
»  273 │         inclaim && /^[[:space:]]*$/            { exit }
»  274 │         inclaim                                { printf "%s ", $0 }
   275 │     ' "$1" \
```
[lines 327–327](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-exhibit#L327-L327)
```bash
   326 │     index) cmd_index ;;
»  327 │     -h|--help|"") sed -n '2,30p' "$0" ;;
   328 │     *) die "unknown subcommand: $1" ;;
```

#### [`tools/bt-fault-window`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-fault-window) — 1 uncovered of 60 coverable lines (98.3% run)

[lines 76–76](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-fault-window#L76-L76)
```bash
    75 │ if [[ -z "$AT" ]]; then
»   76 │     AT=$(bt_journal -k -b "$BOOT" --no-pager -o short-iso-precise 2>/dev/null \
    77 │          | grep -E "$TMO_RE" | head -1 | awk '{print $1}')
```

#### [`tools/bt-incident`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-incident) — 1 uncovered of 93 coverable lines (98.9% run)

[lines 151–151](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-incident#L151-L151)
```bash
   150 │     if [[ -f "$TRACE_DIR/gaps.log" ]]; then
»  151 │         awk -v since="$(date -d "$SINCE" -Iseconds 2>/dev/null)" \
   152 │             'since=="" || $1 >= since' "$TRACE_DIR/gaps.log" \
```

#### [`tools/bt-interval`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-interval) — 1 uncovered of 19 coverable lines (94.7% run)

[lines 56–56](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-interval#L56-L56)
```bash
    55 │ # pipe still open, blocks instead of answering.
»   56 │ if ! out=$(awk -f "$LIBDIR/timestamp.awk" -f "$LIBDIR/interval.awk" \
    57 │                 -v a="$a" -v b="$b" </dev/null); then
```

#### [`tools/bt-journal-files`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-journal-files) — 1 uncovered of 60 coverable lines (98.3% run)

[lines 90–90](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-journal-files#L90-L90)
```bash
    89 │ 			if [[ ! -e "$f" ]]; then
»   90 │ 				echo "  VANISHED before it was copied: $mid/$name"; vanished=$((vanished + 1))
    91 │ 			else
```

#### [`tools/bt-logvolume`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-logvolume) — 2 uncovered of 50 coverable lines (96.0% run)

[lines 66–67](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-logvolume#L66-L67)
```bash
    65 │ if (( total == 0 )); then
»   66 │     echo "bt-logvolume: no lines for boot $BOOT${SINCE:+ since $SINCE}"
»   67 │     exit 0
    68 │ fi
```

#### [`tools/bt-mode`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-mode) — 3 uncovered of 100 coverable lines (97.0% run)

[lines 98–98](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-mode#L98-L98)
```bash
    97 │     done
»   98 │     return 1
    99 │ }
```
[lines 108–108](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-mode#L108-L108)
```bash
   107 │         # which would report the watchdog as late-only whenever BT_EARLY=1.
»  108 │         n_early=$(systemctl show bt-hang-watchdog -p Environment --value 2>/dev/null \
   109 │                   | grep -c 'BT_EARLY=1' || true)
```
[lines 112–112](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-mode#L112-L112)
```bash
   111 │         then wd="on (early+late)"; else wd="on (late only)"; fi
»  112 │     else wd="off"; fi
   113 │     systemctl is-active --quiet bt-health-snapshot.timer 2>/dev/null && probes=on || probes=off
```

#### [`tools/bt-retention`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-retention) — 2 uncovered of 124 coverable lines (98.4% run)

[lines 195–196](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-retention#L195-L196)
```bash
   194 │         elif [[ "$ewb" == "$OLDEST" ]]; then
»  195 │             kept=$((kept + 1)); risk=$((risk + 1)); declared=$((declared + 1))
»  196 │             printf '  %-58s AT RISK   declared window in boot %s, the next to rotate\n' "$base" "$ewb"
   197 │         else
```

#### [`tools/bt-snapshot`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-snapshot) — 3 uncovered of 158 coverable lines (98.1% run)

[lines 340–341](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-snapshot#L340-L341)
```bash
   339 │ if [[ "${SCONARROW:-0}" -gt 0 ]]; then
»  340 │     printf '  ⚠️  SCO pkts on alt-1 (mtu 9): %s — THIS is the condition both recorded\n' "$SCONARROW"
»  341 │     printf '      deaths needed (835 before EX-033, 87 before EX-036).\n'
   342 │ elif [[ "${SCO:-0}" -gt 0 ]]; then
```
[lines 390–390](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-snapshot#L390-L390)
```bash
   389 │     if [[ -n "$SD_AT" ]]; then printf '    last discovery OK  %s\n' "$SD_AT"
»  390 │     else                       printf '    last discovery OK  none this boot\n'; fi
   391 │ fi
```

#### [`tools/bt-stage2`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-stage2) — 1 uncovered of 35 coverable lines (97.1% run)

[lines 73–73](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-stage2#L73-L73)
```bash
    72 │     fi
»   73 │     mv -f "$TMP" "$DUMP" || { echo "bt-stage2: could not finalise $DUMP" >&2; exit 1; }
    74 │ fi
```

#### [`tools/bt-status`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-status) — 3 uncovered of 111 coverable lines (97.3% run)

[lines 24–24](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-status#L24-L24)
```bash
    23 │         # first command run in an untreated window, and it must not send one.
»   24 │         --probe) PROBE="--probe" ;;
    25 │     esac
```
[lines 37–38](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-status#L37-L38)
```bash
    36 │ if [[ -z "$REPO" ]]; then
»   37 │     for c in "$HERE/.." /root/exp/qca9377-bt-hang "$HOME/qca9377-bt-hang" "$PWD"; do
»   38 │         [[ -e "$c/.git" && -e "$c/tools/bt-status" ]] && { REPO=$(cd "$c" && pwd); break; }
    39 │     done
```

#### [`tools/bt-timeline.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-timeline.sh) — 5 uncovered of 48 coverable lines (89.6% run)

[lines 94–101](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-timeline.sh#L94-L101)
```bash
    93 │     case "$tag" in
»   94 │         MARK)  col="$C_MARK" ;;
»   95 │         WDOG)  col="$C_WDOG" ;;
    96 │         KERN)  col="$C_KERN" ;;
»   97 │         BLUED) col="$C_BLUE" ;;
»   98 │         *)     col="$C_TRC"  ;;
    99 │     esac
   100 │     # Highlight the signatures that matter, whatever stream they came from.
»  101 │     if [[ "$msg" == *"tx timeout"* || "$msg" == *"RECOVERED"* \
   102 │        || "$msg" == *"CONTROLLER RESPONDS AFTER EARLY INTERVENTION"* || "$msg" == *"FATAL"* \
```

#### [`tools/bt-trial`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial) — 30 uncovered (11 of them bare `case` labels, not shown) of 405 coverable lines (92.6% run)

[lines 33–34](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L33-L34)
```bash
    32 │ if [[ -z "$REPO" ]]; then
»   33 │     for c in "$HERE/.." /root/exp/qca9377-bt-hang "$PWD"; do
»   34 │         [[ -e "$c/.git" && -e "$c/install.sh" ]] && { REPO=$(cd "$c" && pwd); break; }
    35 │     done
```
[lines 167–167](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L167-L167)
```bash
   166 │     done
»  167 │     return 0
   168 │ }
```
[lines 189–191](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L189-L191)
```bash
   188 │     if systemctl is-active --quiet bt-hang-watchdog >/dev/null 2>&1; then
»  189 │         early=$(systemctl show bt-hang-watchdog -p Environment --value 2>/dev/null \
   190 │                 | tr ' ' '\n' | grep -m1 '^BT_EARLY=' | cut -d= -f2)
»  191 │         thr=$(systemctl show bt-hang-watchdog -p Environment --value 2>/dev/null \
   192 │               | tr ' ' '\n' | grep -m1 '^BT_THRESHOLD=' | cut -d= -f2)
```
[lines 244–244](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L244-L244)
```bash
   243 │     else
»  244 │         printf 'stock'
   245 │     fi
```
[lines 457–457](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L457-L457)
```bash
   456 │     kgrep_init
»  457 │     tmo=$(journalctl -k -p err --since "@$(( start - 5 ))" --no-pager -o cat "${KGREP[@]}" 2>/dev/null \
   458 │           | grep -cE "command( 0x[0-9a-f]+)? tx timeout" || true)
```
[lines 635–635](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L635-L635)
```bash
   634 │     if [[ -z "$treat_start" ]]; then
»  635 │         treatment="$treat_end"           # trial opened before this was recorded
   636 │     elif [[ "$treat_start" == "$treat_end" ]]; then
```
[lines 655–655](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L655-L655)
```bash
   654 │         # usb_present — not a reconfiguration.
»  655 │         treatment="$treat_start"
   656 │     else
```
[lines 703–703](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L703-L703)
```bash
   702 │             case "$treatment" in
»  703 │                 CHANGED:*) treatment="${treatment}+PERTURBED:${perturbed}" ;;
   704 │                 *)         treatment="PERTURBED:${perturbed}:${treatment}" ;;
```
[lines 849–849](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L849-L849)
```bash
   848 │     if [[ -n "$t_tmo" ]]; then
»  849 │         t_sco=$(jk | grep "opcode 0x0428" | cut -d' ' -f1 \
   850 │                 | awk -v lim="$t_tmo" '$1 < lim' | tail -1)
```
[lines 900–900](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L900-L900)
```bash
   899 │     # one anchored pattern covers the timer- and event-driven units.
»  900 │     probes=$(journalctl -u bt-health-snapshot.service -u bt-health-snapshot-event.service \
   901 │              --since "$since" --no-pager -o cat 2>/dev/null \
```
[lines 907–907](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L907-L907)
```bash
   906 │     # already only "consistent with 1:1", never an established count.
»  907 │     aborts=$(journalctl -u bt-trace --since "$since" --no-pager -o cat 2>/dev/null \
   908 │              | grep -c "btmon exited" || true)
```
[lines 923–923](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L923-L923)
```bash
   922 │         # whose probe had not yet been issued.
»  923 │         t_probe=$(journalctl -u bt-health-snapshot.service --since "$since" --until "$t_tmo" \
   924 │                   --no-pager -o short-iso-precise 2>/dev/null \
```
[lines 961–961](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L961-L961)
```bash
   960 │     if (( auto )); then trial_type=observational_boot
»  961 │     else                trial_type="controlled_v$PROTOCOL_VERSION"
   962 │     fi
```
[lines 980–980](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L980-L980)
```bash
   979 │     prev_shutdown=unknown
»  980 │     case "$(journalctl -b -1 -n 400 --no-pager 2>/dev/null \
   981 │             | grep -oE 'Reached target (reboot|poweroff|halt)' | tail -1)" in
```
[lines 984–984](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L984-L984)
```bash
   983 │         *poweroff) prev_shutdown=poweroff ;;
»  984 │         *halt)     prev_shutdown=halt     ;;
   985 │     esac
```
[lines 1197–1198](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial#L1197-L1198)
```bash
  1196 │     awk -f "$LIBDIR/trial-reclass.awk" -f "$LIBDIR/trial-sco-table.awk" "$RESULTS" || {
» 1197 │         echo "bt-trial: SCO cross-tab FAILED — refusing to print a partial report" >&2
» 1198 │         exit 1
  1199 │     }
```

#### [`tools/bt-trial-audit`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial-audit) — 22 uncovered (2 of them bare `case` labels, not shown) of 128 coverable lines (82.8% run)

[lines 77–77](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial-audit#L77-L77)
```bash
    76 │ # instead of reporting that every row is fine.
»   77 │ CONTROL=$(printf '%s\n' \
    78 │     '2000-01-01T00:00:00.000000+00:00 h kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd' \
```
[lines 146–154](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial-audit#L146-L154)
```bash
   145 │     while IFS=$'\t' read -r bi bs be; do
»  146 │         [[ -n "$bi" ]] || continue
»  147 │         BSTART[$bi]=$bs; BEND[$bi]=$be; NBOOT=$((NBOOT + 1))
»  148 │     done < <(python3 -c '
»  149 │ import json, sys
»  150 │ try:
»  151 │     for b in json.loads(sys.stdin.read()):
»  152 │         print("%s\t%d\t%d" % (b["index"], b["first_entry"] // 1000000, b["last_entry"] // 1000000))
»  153 │ except Exception:
»  154 │     pass' <<<"$LB_JSON" 2>/dev/null)
   155 │ fi
```
[lines 210–211](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial-audit#L210-L211)
```bash
   209 │     if [[ -z "$close" ]]; then
»  210 │         echo "  row $((n - 1)): UNRESOLVED — close timestamp '$ts' is not a date"
»  211 │         unresolved=$((unresolved + 1)); continue
   212 │     fi
```
[lines 244–244](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial-audit#L244-L244)
```bash
   243 │     # and never the semantics.
»  244 │     W=$(bt_journal_lines "$RE_RESET|$RE_RELOAD|$RE_TIMEOUT" \
   245 │         -k -b "$b" --since "@$open" --until "@$close" -o short-iso-precise)
```
[lines 272–282](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-trial-audit#L272-L282)
```bash
   271 │     case "$bt1" in
»  272 │         confirmed)
   273 │             (( ${n_tmo:-0} == 0 )) && {
»  274 │                 echo "  row $((n - 1)) (boot $b, $ts): bt1_status DISAGREES"
»  275 │                 echo "                  recorded: confirmed, but the window holds no command timeout"
»  276 │                 disagreed=1; }
   277 │             ;;
»  278 │         not_observed)
»  279 │             (( ${n_tmo:-0} > 0 )) && {
»  280 │                 echo "  row $((n - 1)) (boot $b, $ts): bt1_status DISAGREES"
»  281 │                 echo "                  recorded: not_observed, but the window holds $n_tmo command timeout(s)"
»  282 │                 disagreed=1; }
   283 │             ;;
```

#### [`tools/bt-ui-capture`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture) — 38 uncovered (5 of them bare `case` labels, not shown) of 400 coverable lines (90.5% run)

[lines 148–150](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L148-L150)
```bash
   147 │     else
»  148 │         local pw
»  149 │         pw=$(getent passwd "$U" 2>/dev/null)
»  150 │         HOME_U=$(cut -d: -f6 <<<"$pw")
   151 │     fi
```
[lines 235–235](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L235-L235)
```bash
   234 │         for p in $(user_pids "$n"); do
»  235 │             echo "process $n pid=$p started=$(ps -o lstart= -p "$p" 2>/dev/null)" \
   236 │                  "PIPEWIRE_DEBUG=$(proc_env "$p" PIPEWIRE_DEBUG)" \
```
[lines 283–291](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L283-L291)
```bash
   282 │         write_file "$f" 0644 "$UID_U:$GID_U" "$content" && mf override "$f"
»  283 │     done < <(override_paths)
   284 │     local p
   285 │     for p in $(user_pids gnome-control-c); do
»  286 │         if [[ "$(proc_env "$p" G_MESSAGES_DEBUG)" == "$GCC_DOMAINS" ]]; then
»  287 │             echo "  GNOME Settings pid $p already runs with G_MESSAGES_DEBUG=$GCC_DOMAINS"
   288 │         else
»  289 │             echo "  NOTE: GNOME Settings is running (pid $p) WITHOUT the debug domains."
»  290 │             echo "        Close it and open it again: it is single-instance, so a new"
»  291 │             echo "        launch only re-activates the running copy. Nothing here closes it."
   292 │         fi
```
[lines 301–301](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L301-L301)
```bash
   300 │         else echo "  kept $f (not written by $MARKER)"; fi
»  301 │     done < <(override_paths)
   302 │ }
```
[lines 356–362](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L356-L362)
```bash
   355 │     case "$kind" in
»  356 │         atspi)
»  357 │             raw=$(as_user busctl --user call org.a11y.Bus /org/a11y/bus org.a11y.Bus GetAddress 2>/dev/null) \
   358 │                 || die "accessibility bus address not available"
»  359 │             addr=${raw#s \"}; addr=${addr%\"}
»  360 │             as_user python3 "$dir/bin/bt-ui-atspi.py" --address "$addr" --comm gnome-control-c \
   361 │                 | capped_write "$dir/atspi.log" ;;
»  362 │         sysbus)
   363 │             # Everything BlueZ says, and every call made to it (who powered,
```
[lines 383–385](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L383-L385)
```bash
   382 │     if ! find_user; then
»  383 │         (( DRY )) || die "no active graphical session found (set BT_UI_USER)"
»  384 │         echo "  (no desktop user found from logind; showing the plan for user 'i')"
»  385 │         U=i; UID_U=1000; GID_U=1000; HOME_U=/home/i; XDG=/run/user/1000
   386 │     fi
```
[lines 404–404](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L404-L404)
```bash
   403 │     else
»  404 │         echo "  WARNING: $REPO/scripts/bt-ui-atspi.py missing; the AT-SPI monitor will fail"
   405 │     fi
```
[lines 421–421](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L421-L421)
```bash
   420 │     if [[ ! -r "$CTL" ]]; then
»  421 │         echo "  cannot read $CTL (needs root and debugfs); would enable: ${SCO_FUNCS[*]}"
   422 │     fi
```
[lines 478–478](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L478-L478)
```bash
   477 │         write_file "$f" 0644 "$UID_U:$GID_U" "$content"
»  478 │     done < <(staged_pairs)
   479 │     local linger
```
[lines 543–543](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L543-L543)
```bash
   542 │     else
»  543 │         echo "session: none under $BASE"
   544 │     fi
```
[lines 551–552](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L551-L552)
```bash
   550 │             [[ -e "$f" ]] || continue
»  551 │             s=$(stat -c %s "$f" 2>/dev/null || echo '?')
»  552 │             echo "  $f  $s bytes"
   553 │         done
```
[lines 566–566](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L566-L566)
```bash
   565 │         if has_marker "$f"; then echo "  override present: $f"; fi
»  566 │     done < <(override_paths)
   567 │     for p in $(user_pids gnome-control-c); do
```
[lines 575–579](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L575-L579)
```bash
   574 │         has_marker "$f" || continue
»  575 │         got=""
»  576 │         for p in $(user_pids "$svc"); do got=$(proc_env "$p" "$var"); done
»  577 │         if [[ "$got" == "$want" ]]; then echo "  staged $svc: IN EFFECT ($var)"
»  578 │         else echo "  staged $svc: written, NOT yet in effect (running process has $var='$got')"; fi
»  579 │     done < <(staged_pairs)
   580 │     local since
```
[lines 650–650](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L650-L650)
```bash
   649 │                 echo "$c  $(stat -c '%s bytes, last write %y' "$c" 2>/dev/null)"
»  650 │             done < <(find "$d" -maxdepth 1 -name '*.btsnoop' -newermt "$s" 2>/dev/null | sort)
   651 │         done
```
[lines 658–658](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L658-L658)
```bash
   657 │     if [[ -z "$san" ]]; then
»  658 │         echo "  WARNING: sanitize-logs.sh not found; nothing written to $pub"
   659 │     else
```
[lines 665–665](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L665-L665)
```bash
   664 │             else
»  665 │                 echo "  NOT published: $(basename "$f") (see $out/sanitize-errors.txt)"
   666 │             fi
```
[lines 696–696](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-ui-capture#L696-L696)
```bash
   695 │     _monitor)       monitor_main "$@" ;;
»  696 │     -h|--help|help) sed -n '2,60p' "$0" ;;
   697 │     *) die "unknown command '$cmd' (plan|start|stage-restart|status|stop|unstage|collect)" ;;
```

#### [`tools/bt-usbstate`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-usbstate) — 1 uncovered of 67 coverable lines (98.5% run)

[lines 54–54](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-usbstate#L54-L54)
```bash
    53 │         [[ -f "$d/idVendor" && -f "$d/idProduct" ]] || continue
»   54 │         [[ "$(tr -dc '0-9a-fA-F' < "$d/idVendor")" == "$VID" && \
    55 │            "$(tr -dc '0-9a-fA-F' < "$d/idProduct")" == "$PID" ]] || continue
```

#### [`tools/bt-verify-install`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-verify-install) — 9 uncovered of 71 coverable lines (87.3% run)

[lines 20–22](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-verify-install#L20-L22)
```bash
    19 │ if [[ -z "$REPO" ]]; then
»   20 │     HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
»   21 │     for c in "$HERE/.." /root/exp/qca9377-bt-hang "$PWD"; do
»   22 │         [[ -e "$c/.git" && -e "$c/install.sh" ]] && { REPO=$(cd "$c" && pwd); break; }
    23 │     done
```
[lines 74–74](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-verify-install#L74-L74)
```bash
    73 │     if [[ ! -e "$src" ]]; then
»   74 │         printf '  %s?%s missing in repo: %s\n' "$Y" "$O" "${p%%:*}"; continue
    75 │     fi
```
[lines 108–112](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-verify-install#L108-L112)
```bash
   107 │     if [[ ! -e "$f" ]]; then
»  108 │         if [[ -e "$f.disabled" ]]; then
   109 │             # Deliberately disabled by `bt-mode experiment`, not missing.
»  110 │             printf '  %s~%s disabled by bt-mode: %s\n' "$Y" "$O" "$f"
   111 │         else
»  112 │             printf '  %s✗%s NOT INSTALLED: %s\n' "$R" "$O" "$f"; missing=$((missing+1))
   113 │         fi
```
[lines 117–117](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-verify-install#L117-L117)
```bash
   116 │     else
»  117 │         printf '  %s✗%s %s does not reference %s:%s\n' "$R" "$O" "$f" "$VID" "$PID"; drift=$((drift+1))
   118 │     fi
```
[lines 129–129](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-verify-install#L129-L129)
```bash
   128 │     { echo bluetooth
»  129 │       grep -oE 'systemctl enable --now [a-z0-9.-]+' "$REPO/install.sh" 2>/dev/null | awk '{print $NF}'
   130 │     } | sort -u
```

#### [`tools/bt-verify-kernel-mechanism`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-verify-kernel-mechanism) — 1 uncovered of 74 coverable lines (98.6% run)

[lines 93–93](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-verify-kernel-mechanism#L93-L93)
```bash
    92 │ done
»   93 │ if [[ -e "$MODULES_DIR/$KREL/kernel/drivers/bluetooth/btqca.ko" || \
    94 │       -e "$MODULES_DIR/$KREL/kernel/drivers/bluetooth/btqca.ko.zst" ]]; then
```

#### [`tools/bt-window`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-window) — 2 uncovered of 51 coverable lines (96.1% run)

[lines 91–91](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-window#L91-L91)
```bash
    90 │         $0 ~ usb { u++ }
»   91 │         END { print t + 0, u + 0 }')
    92 │ 
```
[lines 113–113](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/bt-window#L113-L113)
```bash
   112 │         $0 ~ u { b++ }
»  113 │         END { print a + 0, b + 0 }')
   114 │ iv=$(( ${iv_tool:-0} + ${iv_user:-0} ))
```

#### [`tools/sanitize-logs.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/sanitize-logs.sh) — 2 uncovered of 59 coverable lines (96.6% run)

[lines 197–197](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/sanitize-logs.sh#L197-L197)
```bash
   196 │ 
»  197 │ leftover=$(grep -oEi '[0-9a-f]{2}([:_-][0-9a-f]{2}){5,}' "$TMP" 2>/dev/null \
   198 │            | grep -vi '^aa:bb:cc:00:00:[0-9][0-9]$' | sort -u || true)
```
[lines 212–212](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/sanitize-logs.sh#L212-L212)
```bash
   211 │ 
»  212 │ ips=$(grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$TMP" 2>/dev/null \
   213 │       | grep -vE '^(0\.0\.0\.0|127\.0\.0\.1)$' | sort -u || true)
```

#### [`tools/verify-restored.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/verify-restored.sh) — 12 uncovered of 98 coverable lines (87.8% run)

[lines 72–72](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/verify-restored.sh#L72-L72)
```bash
    71 │ if [[ -z "$INSTALL_SH" ]]; then
»   72 │     bad "cannot find install.sh to derive the artifact list — restoration NOT verifiable"
    73 │ else
```
[lines 81–81](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/verify-restored.sh#L81-L81)
```bash
    80 │           | awk '{print $3}'
»   81 │           printf '%s\n' \
    82 │               /etc/udev/rules.d/50-bluetooth-no-autosuspend.rules \
```
[lines 110–110](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/verify-restored.sh#L110-L110)
```bash
   109 │     { [[ -n "${INSTALL_SH:-}" ]] && grep -oE 'systemctl enable --now [a-z0-9.-]+' "$INSTALL_SH" | awk '{print $NF}'
»  110 │       printf '%s\n' bt-hang-watchdog bt-health-snapshot.timer
   111 │     } | sort -u)
```
[lines 116–116](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/verify-restored.sh#L116-L116)
```bash
   115 │     if [[ "$st" == "active" || "$en" == "enabled" ]]; then
»  116 │         bad "$u is $st/$en"
   117 │     else
```
[lines 140–142](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/verify-restored.sh#L140-L142)
```bash
   139 │     auto) ok   "usb power/control = auto (original)" ;;
»  140 │     on)   info "usb power/control = on — clears when the device re-enumerates (reboot)" ;;
»  141 │     "")   info "device $VID:$PID not on the bus — cannot check power/control" ;;
»  142 │     *)    info "usb power/control = $ctrl" ;;
   143 │ esac
```
[lines 150–150](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/verify-restored.sh#L150-L150)
```bash
   149 │ else
»  150 │     bad "bluetooth.service is $st/$en — expected active/enabled"
   151 │ fi
```
[lines 158–159](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/verify-restored.sh#L158-L159)
```bash
   157 │ else
»  158 │     bad "dpkg --verify bluez reports modified files:"
»  159 │     dpkg --verify bluez 2>&1 | sed 's/^/      /'
   160 │ fi
```
[lines 165–166](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tools/verify-restored.sh#L165-L166)
```bash
   164 │ if [[ -e "$HEALTH_DIR" ]]; then
»  165 │     rows=$(( $(wc -l < "$HEALTH_DIR/metrics.tsv" 2>/dev/null || echo 1) - 1 ))
»  166 │     info "$HEALTH_DIR still present ($rows metric rows) — rm -rf to clear"
   167 │ else
```

#### [`uninstall.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/uninstall.sh) — 2 uncovered of 107 coverable lines (98.1% run)

[lines 20–20](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/uninstall.sh#L20-L20)
```bash
    19 │         --purge-metrics)  PURGE_METRICS=1 ;;
»   20 │         -h|--help)        sed -n '2,9p' "$0"; exit 0 ;;
    21 │         *) echo "unknown option: $a" >&2
```
[lines 179–179](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/uninstall.sh#L179-L179)
```bash
   178 │         case "${1:-}" in
»  179 │             install|rm|rmdir|mkdir|mv) ;;   # mv: restoring a .pre-qca9377-bt-hang copy
   180 │             *) echo "  staging: NOT executed (system command): $*"; return 0 ;;
```

## 5. `devtools/`: the instruments and the repository's own tools

<details><summary>609 uncovered lines in 22 files (expand)</summary>

The tools that run the suite (the instruments) show only what their toy-suite checks reach; the standalone scripts show at 0% (section 3).

#### [`devtools/access-audit`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-audit) — 4 uncovered of 85 coverable lines (95.3% run)

[lines 40–40](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-audit#L40-L40)
```bash
    39 │         --)          shift; CMD=("$@"); break ;;
»   40 │         -h|--help)   sed -n '2,13p' "$0"; exit 0 ;;
    41 │         *) echo "access-audit: unknown option: $1" >&2; exit 2 ;;
```
[lines 49–49](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-audit#L49-L49)
```bash
    48 │ if [[ -n "$tracer" && "$tracer" != 0 ]]; then
»   49 │     echo "access-audit: already running under a tracer (pid $tracer) — nothing measured" >&2; exit 3
    50 │ fi
```
[lines 96–96](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-audit#L96-L96)
```bash
    95 │     ok()  { echo "  ✓ $*"; pass=$((pass + 1)); }
»   96 │     bad() { echo "  ✗ $*"; fail=$((fail + 1)); }
    97 │     : > "$WORK/none"
```
[lines 140–140](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-audit#L140-L140)
```bash
   139 │     else
»  140 │         echo "  · a namespace world's own mounts: no user namespaces here — not verifiable"
   141 │     fi
```

#### [`devtools/awk-coverage`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/awk-coverage) — 12 uncovered of 91 coverable lines (86.8% run)

[lines 64–65](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/awk-coverage#L64-L65)
```bash
    63 │         --uncovered) SHOWUNCOV=1 ;;
»   64 │         -h|--help)   sed -n '2,6p' "$0"; exit 0 ;;
»   65 │         *) echo "unknown option: $1" >&2; exit 2 ;;
    66 │     esac
```
[lines 75–76](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/awk-coverage#L75-L76)
```bash
    74 │ if ! command -v gawk >/dev/null 2>&1; then
»   75 │     echo "awk-coverage: gawk is required (mawk has no profiler) — skipping" >&2
»   76 │     exit 0
    77 │ fi
```
[lines 114–116](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/awk-coverage#L114-L116)
```bash
   113 │ if (( ${nprof:-0} == 0 )); then
»  114 │     echo "awk-coverage: no profiles were written — the shim was not used" >&2
»  115 │     echo "              (a tool calling gawk or /usr/bin/awk directly bypasses PATH)" >&2
»  116 │     exit 2
   117 │ fi
```
[lines 158–161](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/awk-coverage#L158-L161)
```bash
   157 │             -f) f="${a[i+1]:-}"; i=$((i + 1)) ;;
»  158 │             -v|-F|-e|--source) i=$((i + 1)) ;;
»  159 │             --file=*) f="${a[i]#--file=}" ;;
»  160 │             -f?*) f="${a[i]#-f}" ;;
»  161 │             -?*) ;;
   162 │             *) ops=$((ops + 1)); [[ "${a[i]}" == /dev/null ]] && null=$((null + 1)) ;;
```
[lines 266–266](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/awk-coverage#L266-L266)
```bash
   265 │     # with a letter or digit: "$d/tests/../tools/x" was labelled "tests/..".
»  266 │     caller=$(tr -s " " "\n" < "$p.src" 2>/dev/null \
   267 │              | grep -oE "(tools|bin|devtools|tests)/[a-zA-Z0-9_][a-zA-Z0-9._-]*|(^|/)(install|uninstall)\.sh" \
```

#### [`devtools/branch-status`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/branch-status) — 30 uncovered of 80 coverable lines (62.5% run)

[lines 47–55](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/branch-status#L47-L55)
```bash
    46 │ while [[ $# -gt 0 ]]; do
»   47 │     case "$1" in
»   48 │         --unique) UNIQUE=1 ;;
»   49 │         --files)  FILES=1 ;;
»   50 │         --fetch)  FETCH=1 ;;
»   51 │         --all)    UNIQUE=1; FILES=1 ;;
»   52 │         -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
»   53 │         *) echo "branch-status: unknown option: $1" >&2; exit 2 ;;
    54 │     esac
»   55 │     shift
    56 │ done
```
[lines 71–72](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/branch-status#L71-L72)
```bash
    70 │ if (( ${#BRANCHES[@]} == 0 )); then
»   71 │     echo "branch-status: REFUSING — no branches found under refs/remotes/origin" >&2
»   72 │     exit 2
    73 │ fi
```
[lines 91–91](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/branch-status#L91-L91)
```bash
    90 │     elif (( ahead == 0 )); then status='fully merged'
»   91 │     else                        status='ahead only by superseded patches'
    92 │     fi
```
[lines 118–118](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/branch-status#L118-L118)
```bash
   117 │ # tree during ordinary work. The exit status stays 0.
»  118 │ claims=$(git log --merges --format='%h%x09%s' "$BASE" 2>/dev/null \
   119 │          | sed -nE "s/^([0-9a-f]+)\tMerge (remote-tracking branch|branch) '([^']+)'.*/\1\t\3/p")
```
[lines 149–156](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/branch-status#L149-L156)
```bash
   148 │ if (( UNIQUE )); then
»  149 │     echo
»  150 │     echo "Commits whose patch is NOT in $BASE"
»  151 │     echo "───────────────────────────────────────────────────────────────"
»  152 │     for b in "${BRANCHES[@]}"; do
»  153 │         n=$(git cherry "$BASE" "$b" 2>/dev/null | grep -c '^+')
»  154 │         [[ "${n:-0}" -eq 0 ]] && continue
»  155 │         printf '\n%s  (%s)\n' "$b" "$n"
»  156 │         git cherry -v "$BASE" "$b" 2>/dev/null | awk '/^\+/ { $1=""; print "   " $0 }'
   157 │     done
```
[lines 161–170](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/branch-status#L161-L170)
```bash
   160 │ if (( FILES )); then
»  161 │     echo
»  162 │     echo "Files present on a branch and absent from $BASE"
»  163 │     echo "───────────────────────────────────────────────────────────────"
»  164 │     echo "(filename level only — content unique to a SHARED file is invisible here)"
»  165 │     for b in "${BRANCHES[@]}"; do
»  166 │         only=$(git ls-tree -r --name-only "$b" | sort | comm -13 "$MAINFILES" -)
»  167 │         n=$(grep -c . <<<"$only")
»  168 │         [[ "${n:-0}" -eq 0 ]] && continue
»  169 │         printf '\n%s  (%s)\n' "$b" "$n"
»  170 │         sed 's/^/   /' <<<"$only"
   171 │     done
```

#### [`devtools/ci`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/ci) — 57 uncovered (3 of them bare `case` labels, not shown) of 115 coverable lines (50.4% run)

[lines 64–68](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/ci#L64-L68)
```bash
    63 │         --wait)   WAIT=1 ;;
»   64 │         --failed) SHOWFAILED=1 ;;
»   65 │         --recent) RECENT=1; [[ "${2:-}" =~ ^[0-9]+$ ]] && { N="$2"; shift; } ;;
»   66 │         --repo)   GHREPO="${2:?--repo needs <owner/name>}"; shift ;;
»   67 │         -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
»   68 │         -*) echo "ci: unknown option: $1" >&2; exit 2 ;;
    69 │         *)  SHA="$1" ;;
```
[lines 79–79](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/ci#L79-L79)
```bash
    78 │ if [[ -z "$SHA" ]]; then
»   79 │     SHA=$(git -C "$REPO" rev-parse HEAD 2>/dev/null) || { echo "ci: not a git checkout" >&2; exit 2; }
    80 │ fi
```
[lines 114–114](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/ci#L114-L114)
```bash
   113 │     err=$(mktemp)
»  114 │     out=$(gh run list "${GHR[@]}" --workflow checks.yml --limit 30 --json conclusion,status,headSha,databaseId,displayTitle \
   115 │         --jq ".[] | select(.headSha | startswith(\"$SHORT\")) | \"\\(if .conclusion == null or .conclusion == \"\" then \"-\" else .conclusion end)\\t\\(.status)\\t\\(.databaseId)\\t\\(.displayTitle)\"" \
```
[lines 129–133](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/ci#L129-L133)
```bash
   128 │ if (( RECENT )); then
»  129 │     printf 'CI — last %s run(s) on main, in %s\n\n' "$N" "$ASKED"
»  130 │     gh run list "${GHR[@]}" --workflow checks.yml --limit "$N" --branch main --json conclusion,status,headSha,displayTitle \
   131 │         --jq '.[] | "\(if .conclusion == null or .conclusion == "" then .status else .conclusion end)\t\(.headSha[0:7])\t\(.displayTitle[0:64])"' 2>/dev/null \
   132 │         | awk -F'\t' '{ printf "  %-10s %s  %s\n", $1, $2, $3 }'
»  133 │     exit 0
   134 │ fi
```
[lines 171–176](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/ci#L171-L176)
```bash
   170 │ if [[ -z "$row" ]]; then
»  171 │     if (( ! WAIT )); then
»  172 │         echo "ci: no run found for $SHORT in $ASKED — not pushed there, or Actions has not queued it yet" >&2
»  173 │         echo "  (a run can take a minute to appear after a push; --wait polls for it)" >&2
»  174 │         exit 2
   175 │     fi
»  176 │     printf 'ci — %s not queued yet' "$SHORT"
   177 │     # ~20 min at 30 s; a push that produced no run is a real error, not an
```
[lines 187–198](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/ci#L187-L198)
```bash
   186 │     # be made to fire is this project's most-repeated defect.
»  187 │     grace="${BT_CI_GRACE:-40}"
»  188 │     while [[ -z "$row" ]]; do
   189 │         # A retry after a gh failure does not spend the grace budget: the budget
   190 │         # measures GitHub not queuing the run, not the network dropping a call.
»  191 │         if (( gh_fail == 0 )); then
»  192 │             (( grace-- > 0 )) || { echo; echo "ci: no run for $SHORT in $ASKED after the grace budget — was it pushed to a branch Actions builds there?" >&2; exit 2; }
»  193 │             printf '.'
   194 │         fi
»  195 │         sleep "${BT_CI_POLL:-30}"
»  196 │         poll_fetch || true
   197 │     done
»  198 │     echo
   199 │ fi
```
[lines 212–217](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/ci#L212-L217)
```bash
   211 │         [[ "$status" == "completed" ]] && break
»  212 │         printf '.'
»  213 │         sleep "${BT_CI_POLL:-30}"
   214 │         # On a gh failure $row keeps the last good answer, so the loop simply
   215 │         # polls again; "disappeared" is judged only on a successful, empty fetch.
»  216 │         if poll_fetch; then
»  217 │             [[ -n "$row" ]] || { echo; echo "ci: the run for $SHORT disappeared while waiting" >&2; exit 2; }
   218 │         fi
```
[lines 232–232](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/ci#L232-L232)
```bash
   231 │     local a c s id
»  232 │     a=$(gh run list "${GHR[@]}" --workflow access-audit.yml --limit 30 --json conclusion,status,headSha,databaseId \
   233 │         --jq ".[] | select(.headSha | startswith(\"$SHORT\")) | \"\\(if .conclusion == null or .conclusion == \"\" then \"-\" else .conclusion end)\\t\\(.status)\\t\\(.databaseId)\"" \
```
[lines 238–245](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/ci#L238-L245)
```bash
   237 │     fi
»  238 │     IFS=$'\t' read -r c s id <<<"$a"
»  239 │     if [[ "$s" != completed ]]; then
»  240 │         echo "  access-audit — running  run $id (its own workflow; not part of the verdict)"
»  241 │     elif [[ "$c" == success ]]; then
»  242 │         echo "  access-audit — ✓ success  run $id (its own workflow; not part of the verdict)"
   243 │     else
»  244 │         echo "  access-audit — ✗ $c  run $id (its own workflow; not part of the verdict)"
»  245 │         echo "    its failing lines: gh run view ${GHREPO:+-R $GHREPO }$id --log-failed"
   246 │     fi
```
[lines 251–254](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/ci#L251-L254)
```bash
   250 │ if [[ "$status" != "completed" ]]; then
»  251 │     printf 'ci — %s  %s  run %s in %s  (%s)\n' "$SHORT" "RUNNING" "$runid" "$ASKED" "${title:0:60}"
»  252 │     echo "  not terminal yet — devtools/ci --wait $SHORT"
»  253 │     audit_line
»  254 │     exit 3
   255 │ fi
```
[lines 262–273](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/ci#L262-L273)
```bash
   261 │ show_failed() {
»  262 │     local log="$REPO/tmp/ci-$SHORT.log"
»  263 │     mkdir -p "$REPO/tmp"
»  264 │     if ! gh run view "${GHR[@]}" "$runid" --log-failed > "$log" 2>&1; then
»  265 │         echo "  (could not fetch the failed-step log: $(tail -1 "$log"))"; return
   266 │     fi
»  267 │     echo "  failing lines (full failed-step log: tmp/ci-$SHORT.log):"
»  268 │     grep -nE "✗|FAILED:|##\[error\]|EXCLUDED lines were executed" "$log" \
   269 │         | sed -E 's/^([0-9]+):[^\t]*\t[^\t]*\t[0-9TZ:.-]+ ?/\1: /' | cut -c1-200 | head -30 | sed 's/^/    /'
»  270 │     if grep -q "EXCLUDED lines were executed" "$log"; then
»  271 │         echo "  stale exclusion — the report, with the lines it hid:"
   272 │         # gh prefixes every log line with "<job>\t<step>\t<timestamp> "; strip that.
»  273 │         grep -A6 "EXCLUDED lines were executed" "$log" \
   274 │             | sed -E $'s/^[^\t]*\t[^\t]*\t[0-9TZ:.-]+ ?//' | cut -c1-160 | sed 's/^/    /'
```
[lines 284–291](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/ci#L284-L291)
```bash
   283 │         exit 0 ;;
»  284 │     failure|cancelled|timed_out|startup_failure)
»  285 │         printf 'ci — %s  ✗ %s  run %s in %s  (%s)\n' "$SHORT" "$concl" "$runid" "$ASKED" "${title:0:60}"
»  286 │         show_failed
»  287 │         audit_line
»  288 │         exit 1 ;;
»  289 │     *)
»  290 │         printf 'ci — %s  ? %s  run %s\n' "$SHORT" "${concl:-unknown}" "$runid"
»  291 │         exit 2 ;;
   292 │ esac
```

#### [`devtools/doc-main-hashes`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/doc-main-hashes) — 4 uncovered of 57 coverable lines (93.0% run)

[lines 62–63](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/doc-main-hashes#L62-L63)
```bash
    61 │     case "$a" in
»   62 │         -h|--help) sed -n '2,/^$/p' "$0"; exit 0 ;;
»   63 │         -*) echo "doc-main-hashes: unknown option: $a" >&2; exit 2 ;;
    64 │         *) if [[ ${#FILES[@]} -eq 0 && -d "$a" && "$DIR" == "." ]]; then DIR="$a"; else FILES+=("$a"); fi ;;
```
[lines 105–105](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/doc-main-hashes#L105-L105)
```bash
   104 │             if ! git rev-parse -q --verify "${t}^{commit}" >/dev/null 2>&1; then
»  105 │                 unresolved=$((unresolved + 1)); continue
   106 │             fi
```
[lines 128–128](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/doc-main-hashes#L128-L128)
```bash
   127 │         done
»  128 │     done < <(grep -nE '(^|[^[:alnum:]_-])main([^[:alnum:]_/-]|$)' "$f" || true)
   129 │ done
```

#### [`devtools/hooks/install-hooks.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/hooks/install-hooks.sh) — 9 uncovered of 9 coverable lines (0.0% run)

[lines 4–12](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/hooks/install-hooks.sh#L4-L12)
```bash
     3 │ # A hook already there that is not our link is left alone and reported.
»    4 │ set -u
»    5 │ ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
»    6 │ G="$(git -C "$ROOT" rev-parse --git-path hooks)"
»    7 │ [[ "$G" = /* ]] || G="$ROOT/$G"
»    8 │ for h in pre-push; do
»    9 │ 	want="../../devtools/hooks/$h"
»   10 │ 	if [[ -L "$G/$h" && "$(readlink "$G/$h")" == "$want" ]]; then echo "$h: already linked"; continue; fi
»   11 │ 	if [[ -e "$G/$h" ]]; then echo "$h: $G/$h exists and is not our link; left alone" >&2; continue; fi
»   12 │ 	ln -s "$want" "$G/$h" && echo "$h: linked"
    13 │ done
```

#### [`devtools/hooks/pre-push`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/hooks/pre-push) — 21 uncovered of 21 coverable lines (0.0% run)

[lines 12–36](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/hooks/pre-push#L12-L36)
```bash
    11 │ # (devtools/hooks/install-hooks.sh). Tests: devtools/hooks/test-pre-push.sh.
»   12 │ set -uo pipefail
»   13 │ REMOTE_NAME="${1:-}"; REMOTE_URL="${2:-}"
»   14 │ ROOT="$(git rev-parse --show-toplevel)" || exit 1
»   15 │ PUBLIC_RE='github\.com[:/]ivoitovych/qca9377-bt-hang(\.git)?/?$'
»   16 │ if ! [[ "$REMOTE_URL" =~ $PUBLIC_RE ]]; then
»   17 │ 	echo "pre-push: $REMOTE_NAME ($REMOTE_URL) is not the public repository: no publish scan"
»   18 │ 	exit 0
    19 │ fi
»   20 │ ZERO=0000000000000000000000000000000000000000
»   21 │ rc=0 refs=0
»   22 │ while read -r lref lsha rref rsha; do
»   23 │ 	[[ -n "${lsha:-}" ]] || continue
»   24 │ 	[[ "$lsha" != "$ZERO" ]] || continue   # deleting a remote ref adds nothing
»   25 │ 	base="$rsha"
    26 │ 	# A remote tip this checkout does not have: scan as a new branch rather than not at all.
»   27 │ 	if [[ "$base" != "$ZERO" ]] && ! git cat-file -e "$base^{commit}" 2>/dev/null; then base="$ZERO"; fi
»   28 │ 	refs=$((refs + 1))
»   29 │ 	echo "pre-push: scanning $lref → $REMOTE_NAME $rref"
»   30 │ 	"$ROOT/devtools/repo-scan" "$ROOT" --range "$base" "$lsha" || rc=1
    31 │ done
»   32 │ if (( rc != 0 )); then
»   33 │ 	echo "pre-push: publish scan FAILED: nothing was pushed to $REMOTE_NAME" >&2
»   34 │ 	exit 1
    35 │ fi
»   36 │ echo "pre-push: publish scan clean for $refs ref(s)"
    37 │ 
```

#### [`devtools/hooks/test-pre-push.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/hooks/test-pre-push.sh) — 30 uncovered of 30 coverable lines (0.0% run)

[lines 5–40](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/hooks/test-pre-push.sh#L5-L40)
```bash
     4 │ # exists only as a loose object (no branch, no index, no work tree touched).
»    5 │ set -u
»    6 │ ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
»    7 │ H="$ROOT/devtools/hooks/pre-push"
     8 │ # Built at run time: written out, the address and the ssh user@host would trip the scan of this
     9 │ # file itself (as they did on 2026-10-23).
»   10 │ SSH="git""@""github.com"
»   11 │ MAC=$(printf '%s:%s:%s:%s:%s:%s' 12 34 56 78 9a bc)
»   12 │ PUB="$SSH:ivoitovych/qca9377-bt-hang.git"
»   13 │ PRIV="$SSH:ivoitovych/qca9377-bt-hang-private.git"
»   14 │ ZERO=0000000000000000000000000000000000000000
»   15 │ cd "$ROOT" || exit 2
»   16 │ HEAD_SHA=$(git rev-parse HEAD)
»   17 │ blob=$(printf 'test address %s\n' "$MAC" | git hash-object -w --stdin)
»   18 │ tree=$( { git ls-tree HEAD; printf '100644 blob %s\tpre-push-test-leak.txt\n' "$blob"; } | git mktree)
»   19 │ leak=$(git commit-tree "$tree" -p HEAD -m "pre-push test: a leaking commit (never pushed)")
»   20 │ pass=0 fail=0
    21 │ expect() { # <name> <want-rc> <regex> <remote> <url> <stdin>
»   22 │ 	local out rc
»   23 │ 	out=$(printf '%s\n' "$6" | "$H" "$4" "$5" 2>&1); rc=$?
»   24 │ 	if [[ $rc -eq $2 ]] && grep -qE "$3" <<<"$out"; then pass=$((pass + 1)); echo "PASS $1 (rc=$rc)"
»   25 │ 	else fail=$((fail + 1)); echo "FAIL $1 (rc=$rc, want $2, /$3/)"; sed -e 's/^/     /' <<<"$out" | tail -n 6; fi
    26 │ }
    27 │ # A refusal must be the scanner's finding, not an error: the address is named in the output.
»   28 │ LEAK_RE="real MAC/BSSID found"
»   29 │ expect leak-public 1 "$LEAK_RE" origin "$PUB" "refs/heads/main $leak refs/heads/main $HEAD_SHA"
»   30 │ expect leak-new-branch 1 "$LEAK_RE" origin "$PUB" "refs/heads/t $leak refs/heads/t $ZERO"
»   31 │ expect leak-unknown-tip 1 "$LEAK_RE" origin "$PUB" "refs/heads/main $leak refs/heads/main 1111111111111111111111111111111111111111"
»   32 │ expect https-public 1 "$LEAK_RE" origin "https://github.com/ivoitovych/qca9377-bt-hang.git" "refs/heads/main $leak refs/heads/main $HEAD_SHA"
»   33 │ expect leak-private 0 "not the public repository" private "$PRIV" "refs/heads/main $leak refs/heads/main $HEAD_SHA"
»   34 │ expect clean-public 0 "publish scan clean for 1" origin "$PUB" "refs/heads/main $HEAD_SHA refs/heads/main $HEAD_SHA"
»   35 │ expect delete-public 0 "publish scan clean for 0" origin "$PUB" "(delete) $ZERO refs/heads/t $HEAD_SHA"
    36 │ # Two refs, one leaking: the whole push is refused.
»   37 │ expect mixed-refs 1 "$LEAK_RE" origin "$PUB" "refs/heads/main $HEAD_SHA refs/heads/main $HEAD_SHA
»   38 │ refs/heads/t $leak refs/heads/t $ZERO"
»   39 │ echo "passed $pass, failed $fail"
»   40 │ (( fail == 0 ))
    41 │ 
```

#### [`devtools/journal-contract`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-contract) — 35 uncovered of 72 coverable lines (51.4% run)

[lines 43–44](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-contract#L43-L44)
```bash
    42 │ if ! command -v journalctl >/dev/null 2>&1; then
»   43 │     note "journalctl not installed — nothing to check against (exit 0)"
»   44 │     exit 0
    45 │ fi
```
[lines 56–57](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-contract#L56-L57)
```bash
    55 │     # was designed to work exactly where this branch is taken.
»   56 │     note "no boots in the host journal — phase-1 shape checks skipped"
»   57 │     HOST_JOURNAL=0
    58 │ fi
```
[lines 70–70](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-contract#L70-L70)
```bash
    69 │ else
»   70 │     bad "--list-boots no longer prints a header — update the provenance fixture AND bt-boot-provenance"
    71 │ fi
```
[lines 79–79](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-contract#L79-L79)
```bash
    78 │ else
»   79 │     bad "--list-boots row layout changed: field4='$f4' field5='$f5'"
    80 │ fi
```
[lines 85–85](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-contract#L85-L85)
```bash
    84 │ # converted tool cuts field 1 as the timestamp.
»   85 │ line=$(journalctl -b "$(awk '$1 ~ /^-?[0-9]+$/ {print $1; exit}' <<<"$LB")" \
    86 │        -n 1 --no-pager -o short-iso-precise 2>/dev/null | tail -1)
```
[lines 89–89](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-contract#L89-L89)
```bash
    88 │ if [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{6} ]]; then
»   89 │     ok "short-iso-precise puts a microsecond ISO timestamp in field 1"
    90 │ else
```
[lines 108–108](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-contract#L108-L108)
```bash
   107 │ if (( nboots > 1 )) && [[ -n "$prev_start" ]]; then
»  108 │     seps=$(journalctl -k -b all --since "$prev_start" --no-pager -o short-iso-precise 2>/dev/null \
   109 │            | grep -c '^-- Boot ')
```
[lines 113–121](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-contract#L113-L121)
```bash
   112 │     else
»  113 │         bad "-b all no longer emits boot separators — stage2 boot-locality is broken"
   114 │     fi
»  115 │ elif (( nboots > 1 )); then
»  116 │     note "boot-list rows carry no parsable start time — separator claim unchecked"
   117 │ else
»  118 │     note "single boot retained — separator claim unchecked this run"
   119 │ fi
   120 │ 
»  121 │ fi   # HOST_JOURNAL
   122 │ 
```
[lines 151–152](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-contract#L151-L152)
```bash
   150 │ else
»  151 │     for c in /usr/lib/systemd/systemd-journal-remote /lib/systemd/systemd-journal-remote; do
»  152 │         [[ -x "$c" ]] && { JR="$c"; break; }
   153 │     done
```
[lines 158–171](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-contract#L158-L171)
```bash
   157 │ else
»  158 │     W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
»  159 │     B1=11111111111111111111111111111111
»  160 │     B2=22222222222222222222222222222222
   161 │     # Epochs chosen so the expected ISO strings are static under TZ=UTC.
   162 │     {
»  163 │       printf '__REALTIME_TIMESTAMP=1786694400000000\n_BOOT_ID=%s\n_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\n_HOSTNAME=host\nMESSAGE=Bluetooth: hci0: command 0x0406 tx timeout\n\n' "$B1"
»  164 │       printf '__REALTIME_TIMESTAMP=1786694410000000\n_BOOT_ID=%s\n_SYSTEMD_UNIT=bt-health-snapshot.service\nSYSLOG_IDENTIFIER=systemd\n_HOSTNAME=host\nMESSAGE=Snapshot Bluetooth health metrics\n\n' "$B1"
»  165 │       printf '__REALTIME_TIMESTAMP=1786694500000000\n_BOOT_ID=%s\n_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\n_HOSTNAME=host\nMESSAGE=usb 3-3: USB disconnect, device number 2\n\n' "$B2"
   166 │     } > "$W/export.txt"
»  167 │     if ! "$JR" --split-mode=none -o "$W/built.journal" "$W/export.txt" >/dev/null 2>&1        || [[ ! -s "$W/built.journal" ]]; then
»  168 │         bad "could not build a journal from export text — the equivalence phase is broken"
   169 │     else
   170 │         # Claim 5: the exact line grammar the fixtures are written in.
»  171 │         cat > "$W/want-all" <<'WANT'
   172 │ 2026-08-14T08:00:00.000000+00:00 host kernel: Bluetooth: hci0: command 0x0406 tx timeout
```
[lines 177–182](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-contract#L177-L182)
```bash
   176 │ WANT
»  177 │         TZ=UTC journalctl --file="$W/built.journal" -b all --no-pager -o short-iso-precise             > "$W/got-all" 2>/dev/null
»  178 │         if diff -q "$W/want-all" "$W/got-all" >/dev/null 2>&1; then
»  179 │             ok "real journalctl output is byte-identical to the fixture grammar (-b all)"
   180 │         else
»  181 │             bad "journalctl output diverged from the fixture grammar:"
»  182 │             diff "$W/want-all" "$W/got-all" | head -6 | sed 's/^/      /'
   183 │         fi
```
[lines 186–191](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-contract#L186-L191)
```bash
   185 │         # bt_journal implements as unit-<name>.log files.
»  186 │         n=$(TZ=UTC journalctl --file="$W/built.journal" -u bt-health-snapshot.service                 --no-pager -o cat 2>/dev/null | grep -c 'Snapshot Bluetooth health metrics')
»  187 │         [[ "${n:-0}" == "1" ]]             && ok "unit filtering matches the per-unit fixture-file model"             || bad "-u selected $n line(s), expected exactly 1"
   188 │         # Claim 7: no separator precedes the FIRST boot. The stage2 fixtures
   189 │         # carry a leading one; recorded divergence, see the header note.
»  190 │         first=$(head -1 "$W/got-all")
»  191 │         [[ "$first" != "-- Boot"* ]]             && ok "no separator before the first boot (stage2 fixtures diverge here, knowingly)"             || bad "journalctl now emits a LEADING boot separator — update the fixtures and this note"
   192 │     fi
```
[lines 200–200](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-contract#L200-L200)
```bash
   199 │ fi
»  200 │ echo "contract holds: $pass claim(s) verified, $skip skipped"
   201 │ 
```

#### [`devtools/journal-speed/bench-file.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-speed/bench-file.sh) — 15 uncovered of 15 coverable lines (0.0% run)

[lines 4–18](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-speed/bench-file.sh#L4-L18)
```bash
     3 │ # cost from the cost of merging ~100 files. Read-only.
»    4 │ set -u
»    5 │ F=${1:?archived system journal file}
»    6 │ t0=$(date +%s.%N)
»    7 │ n=$(journalctl --file="$F" --no-pager -q -o cat | wc -l)
»    8 │ t1=$(date +%s.%N)
»    9 │ echo "one file, all entries, -o cat:  $(echo "$t1 - $t0" | bc) s  lines=$n"
»   10 │ t0=$(date +%s.%N)
»   11 │ n=$(journalctl --file="$F" -k --no-pager -q -o cat | wc -l)
»   12 │ t1=$(date +%s.%N)
»   13 │ echo "one file, -k, -o cat:           $(echo "$t1 - $t0" | bc) s  lines=$n"
»   14 │ t0=$(date +%s.%N)
»   15 │ n=$(journalctl --file="$F" --no-pager -q -o export | wc -c)
»   16 │ t1=$(date +%s.%N)
»   17 │ echo "one file, -o export (bytes):    $(echo "$t1 - $t0" | bc) s  bytes=$n"
»   18 │ ls -l "$F"
    19 │ 
```

#### [`devtools/journal-speed/bench-parallel.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-speed/bench-parallel.sh) — 12 uncovered of 12 coverable lines (0.0% run)

[lines 4–19](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-speed/bench-parallel.sh#L4-L19)
```bash
     3 │ # messages only, counted with grep. Compare with bench.sh's merged read. Read-only.
»    4 │ set -u
»    5 │ D=/var/log/journal/fe39f92475564dc19f9053ec0b0605f6
»    6 │ RE='command( 0x[0-9a-f]+)? tx timeout'
»    7 │ P=${1:-$(nproc)}
»    8 │ t0=$(date +%s.%N)
»    9 │ lines=$(find "$D" -maxdepth 1 -name 'system*.journal' -print0 \
    10 │ 	| xargs -0 -P "$P" -I{} sh -c 'journalctl --file="$1" -k --no-pager -q -o cat | wc -l' _ {} \
    11 │ 	| awk '{s+=$1} END {print s}')
»   12 │ t1=$(date +%s.%N)
»   13 │ echo "all system files, -k, $P in parallel: $(echo "$t1 - $t0" | bc) s  kernel lines=$lines"
»   14 │ t0=$(date +%s.%N)
»   15 │ hits=$(find "$D" -maxdepth 1 -name 'system*.journal' -print0 \
    16 │ 	| xargs -0 -P "$P" -I{} sh -c 'journalctl --file="$1" -k --no-pager -q -o cat | grep -cE "$2"' _ {} "$RE" \
    17 │ 	| awk '{s+=$1} END {print s}')
»   18 │ t1=$(date +%s.%N)
»   19 │ echo "same, counting HCI command timeouts:  $(echo "$t1 - $t0" | bc) s  hits=$hits"
    20 │ 
```

#### [`devtools/journal-speed/bench.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-speed/bench.sh) — 23 uncovered of 23 coverable lines (0.0% run)

[lines 5–31](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/journal-speed/bench.sh#L5-L31)
```bash
     4 │ # against each other as well as timed.
»    5 │ set -u
»    6 │ S=${1:-"2026-10-22 09:00"}
»    7 │ U=${2:-"2026-10-22 12:00"}
»    8 │ RE='command( 0x[0-9a-f]+)? tx timeout|Setup Synchronous|opcode 0x0428'
»    9 │ OUT=/root/exp/qca9377-bt-hang/tmp/journal-speed
»   10 │ cd "$OUT" || exit 1
»   11 │ echo "window: $S .. $U"
    12 │ 
»   13 │ t0=$(date +%s.%N)
»   14 │ n=$(journalctl -k -b -1 -S "$S" -U "$U" --no-pager -q --grep="$RE" | wc -l)
»   15 │ t1=$(date +%s.%N)
»   16 │ echo "A journalctl --grep:          $(echo "$t1 - $t0" | bc) s  lines=$n"
    17 │ 
»   18 │ t0=$(date +%s.%N)
»   19 │ n=$(journalctl -k -b -1 -S "$S" -U "$U" --no-pager -q -o cat | grep -cE "$RE")
»   20 │ t1=$(date +%s.%N)
»   21 │ echo "B journalctl -o cat | grep:   $(echo "$t1 - $t0" | bc) s  lines=$n"
    22 │ 
»   23 │ t0=$(date +%s.%N)
»   24 │ total=$(journalctl -k -b -1 -S "$S" -U "$U" --no-pager -q -o cat | wc -l)
»   25 │ t1=$(date +%s.%N)
»   26 │ echo "  kernel lines in window:     $total ($(echo "$t1 - $t0" | bc) s to read them)"
    27 │ 
»   28 │ t0=$(date +%s.%N)
»   29 │ all=$(journalctl -b -1 -S "$S" -U "$U" --no-pager -q -o cat | wc -l)
»   30 │ t1=$(date +%s.%N)
»   31 │ echo "  all lines in window:        $all ($(echo "$t1 - $t0" | bc) s)"
    32 │ 
```

#### [`devtools/py-coverage`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/py-coverage) — 80 uncovered of 87 coverable lines (8.0% run)

[lines 46–47](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/py-coverage#L46-L47)
```bash
    45 │     case "$1" in
»   46 │         --min)       MIN="${2:?--min needs a number}"; shift ;;
»   47 │         --uncovered) SHOWUNCOV=1 ;;
    48 │         -h|--help)   sed -n '2,6p' "$0"; exit 0 ;;
```
[lines 51–55](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/py-coverage#L51-L55)
```bash
    50 │     esac
»   51 │     shift
    52 │ done
    53 │ 
»   54 │ command -v python3 >/dev/null 2>&1 || {
»   55 │     echo "py-coverage: python3 not installed — nothing can be measured" >&2; exit 2; }
    56 │ 
```
[lines 68–70](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/py-coverage#L68-L70)
```bash
    67 │ # tools/ or devtools/ (the README's rule) is measured from that moment.
»   68 │ PYFILES=(); PYSKIPPED=()
»   69 │ while IFS= read -r f; do
»   70 │     [[ -f "$f" ]] || continue
    71 │     # retest/ likewise: a published retest kit run in QEMU elsewhere, never in
```
[lines 82–92](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/py-coverage#L82-L92)
```bash
    81 │     # Added 2026-11-07, when that folder took the total to 49% again.
»   82 │     case "$f" in scripts/*|retest/*|patches/*|contributions/*|results/*)
»   83 │         IFS= read -r shebang < "$f" || continue
»   84 │         case "$shebang" in '#!'*python*) PYSKIPPED+=("$f") ;; *) case "$f" in *.py) PYSKIPPED+=("$f") ;; esac ;; esac
»   85 │         continue ;;
    86 │     esac
»   87 │     IFS= read -r shebang < "$f" || continue
»   88 │     case "$shebang" in '#!'*python*) PYFILES+=("$f") ;; esac
»   89 │     case "$f" in *.py) PYFILES+=("$f") ;; esac
»   90 │ done < <(git ls-files 2>/dev/null)
    91 │ 
»   92 │ if (( ${#PYFILES[@]} == 0 )); then
    93 │     # ENUMERATED == 0 IS A REFUSAL. A tree with no Python would make every
```
[lines 96–105](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/py-coverage#L96-L105)
```bash
    95 │     # repository has been burned by more than once.
»   96 │     echo "py-coverage: no Python files found in git ls-files — nothing enumerated" >&2
»   97 │     exit 2
    98 │ fi
»   99 │ for f in "${PYSKIPPED[@]+"${PYSKIPPED[@]}"}"; do
»  100 │     echo "out of scope (scripts/, retest/, patches/, contributions/, results/, not shipped): $f"
   101 │ done
   102 │ 
»  103 │ WORK=$(mktemp -d) || exit 1
»  104 │ trap 'rm -rf "$WORK"' EXIT
»  105 │ mkdir -p "$WORK/hook" "$WORK/counts"
   106 │ 
```
[lines 110–110](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/py-coverage#L110-L110)
```bash
   109 │ # be imported by every python3 anyone ran in this checkout, instrumented or not.
»  110 │ cat > "$WORK/hook/sitecustomize.py" <<'HOOK'
   111 │ import atexit, os, sys, trace, traceback
```
[lines 158–164](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/py-coverage#L158-L164)
```bash
   157 │ 
»  158 │ echo "running tests/run-tests under trace (${#PYFILES[@]} Python file(s))..." >&2
»  159 │ SUITE_OUT="$WORK/suite.log"
»  160 │ BT_PYCOV_DIR="$WORK/counts" BT_PYCOV_ROOT="$PWD" \
   161 │     PYTHONPATH="$WORK/hook${PYTHONPATH:+:$PYTHONPATH}" \
   162 │     tests/run-tests > "$SUITE_OUT" 2>&1   # in parallel: one counts file per interpreter, whichever worker ran it
»  163 │ SUITE_RC=$?
»  164 │ SUITE_TAIL=$(tail -1 "$SUITE_OUT")
   165 │ 
```
[lines 170–175](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/py-coverage#L170-L175)
```bash
   169 │ # with no hint that it came from a broken run.
»  170 │ if (( SUITE_RC != 0 )); then
»  171 │     echo "py-coverage: the suite FAILED — coverage from a failing run is not a measurement" >&2
»  172 │     echo "  $SUITE_TAIL" >&2
   173 │     # Which checks, from this run (devtools/coverage says why).
»  174 │     grep -E '^[[:space:]]*✗|: line [0-9]+: ' "$SUITE_OUT" | head -20 | sed 's/^/  /' >&2
»  175 │     exit 1
   176 │ fi
```
[lines 182–191](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/py-coverage#L182-L191)
```bash
   181 │ # percentage, which is the direction that looks like a finding.
»  182 │ NERR=$(ls "$WORK/counts"/err-* 2>/dev/null | wc -l)
»  183 │ if (( ${NERR:-0} > 0 )); then
»  184 │     echo "py-coverage: $NERR traced process(es) failed to record their counts:" >&2
»  185 │     head -20 "$WORK/counts"/err-* >&2
»  186 │     echo "  refusing to report a percentage computed from the ones that survived" >&2
»  187 │     exit 2
   188 │ fi
   189 │ 
»  190 │ NCOUNT=$(ls "$WORK/counts"/c-* 2>/dev/null | wc -l)
»  191 │ if (( ${NCOUNT:-0} == 0 )); then
   192 │     # ENUMERATED == 0. No interpreter recorded anything, which means the hook
```
[lines 195–199](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/py-coverage#L195-L199)
```bash
   194 │     # and not that the suite executes no Python.
»  195 │     echo "py-coverage: no traced process wrote any counts — the hook did not load" >&2
»  196 │     exit 2
   197 │ fi
   198 │ 
»  199 │ cat "$WORK/counts"/c-* 2>/dev/null | LC_ALL=C sort -u > "$WORK/executed"
   200 │ 
```
[lines 204–205](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/py-coverage#L204-L205)
```bash
   203 │ # an instruction for, which is the definition of "a statement that could run".
»  204 │ for f in "${PYFILES[@]}"; do
»  205 │     python3 - "$f" <<'DENOM'
   206 │ import sys, os
```
[lines 223–223](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/py-coverage#L223-L223)
```bash
   222 │ DENOM
»  223 │ done | LC_ALL=C sort -u > "$WORK/coverable"
   224 │ # SORTED THE SAME WAY AS THE OTHER SIDE, which is not a detail. The denominator
```
[lines 231–273](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/py-coverage#L231-L273)
```bash
   230 │ 
»  231 │ if [[ ! -s "$WORK/coverable" ]]; then
»  232 │     echo "py-coverage: no coverable lines derived — the denominator is empty" >&2
»  233 │     exit 2
   234 │ fi
   235 │ 
»  236 │ if (( SHOWUNCOV )); then
»  237 │     LC_ALL=C comm -23 "$WORK/coverable" <(LC_ALL=C sort -u "$WORK/executed") \
   238 │         | awk -F'\t' '{ if ($1 != last) { printf "\n%s\n", $1; last = $1 } printf "%6d  ", $2
»  239 │                         cmd = "sed -n \"" $2 "p\" \"" $1 "\""; cmd | getline l; close(cmd)
»  240 │                         sub(/^[ \t]+/, "", l); print l }'
»  241 │     exit 0
   242 │ fi
   243 │ 
»  244 │ awk -F'\t' '
»  245 │     NR == FNR { cov[$1 "\t" $2] = 1; next }
   246 │     {
»  247 │         tot[$1]++
»  248 │         if (($1 "\t" $2) in cov) hit[$1]++
   249 │     }
»  250 │     END {
»  251 │         n = 0
»  252 │         for (f in tot) {
»  253 │             pct = 100 * (hit[f] + 0) / tot[f]
»  254 │             printf "  %5.1f%%  %6d/%-6d %s\n", pct, hit[f] + 0, tot[f], f
»  255 │             H += hit[f] + 0; T += tot[f]; n++
   256 │         }
»  257 │         printf "\nfiles measured: %d\n", n
»  258 │         printf "TOTAL: %.1f%% (%d of %d statement lines)\n", (T ? 100 * H / T : 0), H, T
»  259 │         printf "%d\n", (T ? int(100 * H / T) : 0) > "/dev/stderr"
   260 │     }
»  261 │ ' <(LC_ALL=C sort -u "$WORK/executed") "$WORK/coverable" 2> "$WORK/pct"
   262 │ 
»  263 │ echo
»  264 │ echo "suite: $SUITE_TAIL"
   265 │ 
»  266 │ TOTAL_PCT=$(tr -d '[:space:]' < "$WORK/pct" 2>/dev/null)
»  267 │ TOTAL_PCT=${TOTAL_PCT:-0}
»  268 │ if [[ -n "$MIN" ]]; then
»  269 │     if (( TOTAL_PCT < MIN )); then
»  270 │         echo "python line coverage ${TOTAL_PCT}% is below the --min ${MIN}% floor" >&2
»  271 │         exit 1
   272 │     fi
»  273 │     echo "python line coverage ${TOTAL_PCT}% meets the --min ${MIN}% floor"
   274 │ fi
```

#### [`devtools/repo-save`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-save) — 19 uncovered of 116 coverable lines (83.6% run)

[lines 32–32](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-save#L32-L32)
```bash
    31 │             shift ;;
»   32 │         -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    33 │         # Unknown flags previously became the commit message: "repo-save . --amend
```
[lines 55–56](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-save#L55-L56)
```bash
    54 │ if ! git add -A; then
»   55 │     echo "ABORT: git add -A failed (stale index.lock? unreadable file?)" >&2
»   56 │     exit 1
    57 │ fi
```
[lines 115–115](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-save#L115-L115)
```bash
   114 │ else
»  115 │     echo "ABORT: no commit message given" >&2; exit 2
   116 │ fi
```
[lines 125–125](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-save#L125-L125)
```bash
   124 │ # been the same outcome by a different mechanism.
»  125 │ n_real=$(grep -oEi '[0-9a-f]{2}([:_-][0-9a-f]{2}){5,}' <<<"$MSGTEXT" \
   126 │          | tr 'A-F_-' 'a-f::' \
```
[lines 145–147](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-save#L145-L147)
```bash
   144 │ if [[ -z "$want_name" || -z "$want_mail" ]]; then
»  145 │     echo "  ✗ no identity configured in this checkout (git config user.name / user.email)" >&2
»  146 │     echo "ABORT: nothing committed" >&2
»  147 │     exit 1
   148 │ fi
```
[lines 157–157](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-save#L157-L157)
```bash
   156 │     if [[ -z "$ident" ]]; then
»  157 │         echo "  ✗ no $role identity — git would invent one" >&2; id_bad=1
   158 │     elif [[ "$ident" != "$want" ]]; then
```
[lines 179–183](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-save#L179-L183)
```bash
   178 │ if [[ "$recorded_a" != "$want" || "$recorded_c" != "$want" ]]; then
»  179 │     echo "  ✗ the recorded author or committer is not this checkout's identity — undoing the commit" >&2
»  180 │     echo "      author: $recorded_a   committer: $recorded_c" >&2
»  181 │     git reset -q --soft HEAD~1
»  182 │     echo "ABORT: commit undone; nothing pushed" >&2
»  183 │     exit 1
   184 │ fi
```
[lines 220–221](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-save#L220-L221)
```bash
   219 │     if [[ "$a" != "$want" || "$m" != "$want" ]]; then
»  220 │         echo "  ✗ ${c:0:12} $(git log -1 --format=%s "$c" | cut -c1-60): author $a, committer $m" >&2
»  221 │         id_push_bad=1
   222 │     fi
```
[lines 225–226](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-save#L225-L226)
```bash
   224 │ if (( id_push_bad )); then
»  225 │     echo "  ✗ a commit about to be pushed is not authored and committed by this checkout's identity ($want) — not pushed" >&2
»  226 │     exit 1
   227 │ fi
```
[lines 232–232](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-save#L232-L232)
```bash
   231 │ if [[ "$l" == "$r" ]]; then echo "  ✓ remote matches: ${l:0:8}"; else
»  232 │     echo "  ✗ MISMATCH local=${l:0:8} remote=${r:0:8}" >&2; exit 1; fi
   233 │ 
```

#### [`devtools/repo-scan`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-scan) — 23 uncovered of 85 coverable lines (72.9% run)

[lines 26–29](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-scan#L26-L29)
```bash
    25 │         --all)   ALL=1 ;;
»   26 │         --range) RANGE_BASE="${2:?--range needs <base> <head>}"; RANGE_HEAD="${3:?--range needs <base> <head>}"; shift 2 ;;
»   27 │         --quiet) QUIET=1 ;;
»   28 │         -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
»   29 │         -*) echo "unknown option: $1" >&2; exit 2 ;;
    30 │         # Positional. Previously only $1 was inspected, so "repo-scan --all DIR"
```
[lines 55–62](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-scan#L55-L62)
```bash
    54 │     # tree is then new, so it is diffed against the empty tree.
»   55 │     base="$RANGE_BASE"
»   56 │     [[ "$base" =~ ^0+$ ]] && base=$(git hash-object -t tree /dev/null)
»   57 │     git rev-parse -q --verify "$RANGE_HEAD^{commit}" >/dev/null \
    58 │         || { echo "  ✗ --range: $RANGE_HEAD is not a commit here" >&2; exit 2; }
»   59 │     CONTENT=$(git diff "$base" "$RANGE_HEAD" -- | grep '^+' | grep -v '^+++ ' | sed 's/^+//')
»   60 │     SCOPE="pushed additions ${RANGE_BASE:0:12}..${RANGE_HEAD:0:12}"
»   61 │     if [[ -z "$CONTENT" ]]; then
»   62 │         echo "scan clean ($SCOPE: no added lines)"; exit 0
    63 │     fi
```
[lines 71–72](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-scan#L71-L72)
```bash
    70 │     if [[ -z "$(git diff --cached --name-only)" ]]; then
»   71 │         CONTENT=$(git ls-files -z | xargs -0 cat 2>/dev/null)
»   72 │         SCOPE="all tracked files (nothing staged)"
    73 │     fi
```
[lines 79–80](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-scan#L79-L80)
```bash
    78 │ if [[ -z "$CONTENT" ]]; then
»   79 │     echo "  ✗ nothing to scan ($SCOPE) — refusing to report clean" >&2
»   80 │     exit 1
    81 │ fi
```
[lines 113–113](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-scan#L113-L113)
```bash
   112 │ # (results/u29-gnome-pairing-feedback-2026-11-07/).
»  113 │ macs=$(grep -oEi '[0-9a-f]{2}([:_-][0-9a-f]{2}){5,}' <<<"$CONTENT" \
   114 │        | tr 'A-F_-' 'a-f::' \
```
[lines 130–132](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-scan#L130-L132)
```bash
   129 │ # 2026-10-29).
»  130 │ PUB_UUIDS=$(grep -oEi '^[[:space:]]*[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}@' \
   131 │         "$ROOT/devtools/repo-scan-public-addresses" 2>/dev/null | tr -d '[:space:]@' || true)
»  132 │ uuids=$(grep -oEi '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' <<<"$CONTENT" \
   133 │         | grep -viE '^0000[0-9a-f]{4}-0000-1000-8000-00805f9b34fb$' \
```
[lines 151–151](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-scan#L151-L151)
```bash
   150 │ # never an address; it is removed before the match. A bare dotted quad still fails.
»  151 │ ips=$(sed -E 's/§ ?[0-9]+(\.[0-9]+)+//g' <<<"$CONTENT" \
   152 │       | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' \
```
[lines 204–204](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-scan#L204-L204)
```bash
   203 │     # entry into one, which a one-entry test list cannot show (found 2026-10-21).
»  204 │     PUB_EXACT=$(grep -vE '^[[:space:]]*(#|$)' "$PUB_LIST" | grep -v '^@' | sed 's/[[:space:]]//g' \
   205 │         | grep -v '^$' || true)
```
[lines 216–216](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-scan#L216-L216)
```bash
   215 │ # host only lists.
»  216 │ mails=$(grep -oEi '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' <<<"$CONTENT" \
   217 │         | grep -viE '@(vger\.kernel\.org|lists\.linux\.dev|example\.(com|org))$' \
```
[lines 242–244](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-scan#L242-L244)
```bash
   241 │     if [[ -n "$RANGE_HEAD" ]]; then
»  242 │         found=$(git grep -l -i -F -e "$tok" "$RANGE_HEAD" -- | sed "s|^$RANGE_HEAD:||")
   243 │     elif [[ "$SCOPE" == "staged additions" ]]; then
»  244 │         found=$(git grep -l -i -F --cached -e "$tok" --)
   245 │     else
```

#### [`devtools/repo-validate`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-validate) — 18 uncovered of 119 coverable lines (84.9% run)

[lines 93–93](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-validate#L93-L93)
```bash
    92 │     if ! command -v systemd-analyze >/dev/null 2>&1; then
»   93 │         printf '  • unit  %s (skipped: systemd-analyze not installed)\n' "$f"; continue
    94 │     fi
```
[lines 97–97](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-validate#L97-L97)
```bash
    96 │     if [[ -z "$out" ]]; then ok "unit  $f"
»   97 │     else bad "unit  $f"; sed 's/^/      /' <<<"$out"; fi
    98 │ done < <(files)
```
[lines 107–110](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-validate#L107-L110)
```bash
   106 │     if ! command -v udevadm >/dev/null 2>&1; then
»  107 │         printf '  • udev  %s (skipped: udevadm not installed)\n' "$f"; continue
   108 │     fi
   109 │     if out=$(udevadm verify "./$f" 2>&1); then ok "udev  $f"
»  110 │     else bad "udev  $f"; sed 's/^/      /' <<<"$out"; fi
   111 │ done < <(files)
```
[lines 117–117](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-validate#L117-L117)
```bash
   116 │     if ! command -v jq >/dev/null 2>&1; then
»  117 │         printf '  • json  %s (skipped: jq not installed)\n' "$f"; continue
   118 │     fi
```
[lines 127–127](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-validate#L127-L127)
```bash
   126 │     if ! command -v python3 >/dev/null 2>&1; then
»  127 │         printf '  • py    %s (skipped: python3 not installed)\n' "$f"; continue
   128 │     fi
```
[lines 135–138](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-validate#L135-L138)
```bash
   134 │     # file a crash report — machine state the access audit reported in CI.
»  135 │     if out=$(python3 -c 'import ast, sys
»  136 │ try:
»  137 │     ast.parse(open(sys.argv[1]).read(), sys.argv[1])
»  138 │ except Exception as e:
   139 │     sys.exit("%s: %s" % (type(e).__name__, e))' "$f" 2>&1); then ok "py    $f"
```
[lines 157–157](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-validate#L157-L157)
```bash
   156 │     if ! command -v awk >/dev/null 2>&1; then
»  157 │         printf '  • awk   %s (skipped: awk not installed)\n' "$f"; continue
   158 │     fi
```
[lines 206–208](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-validate#L206-L208)
```bash
   205 │     else
»  206 │         printf '  ✗ %s\n' "tests FAILED"
»  207 │         fail=1
»  208 │         sed 's/^/      /' <<<"$out"
   209 │     fi
```
[lines 271–276](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/repo-validate#L271-L276)
```bash
   270 │     case "$dmhrc" in
»  271 │         0) printf '  ✓ %s\n' "$(tail -1 <<<"$dmh")" ;;
   272 │         3) printf '  • %s\n' "$(tail -1 <<<"$dmh")" ;;
   273 │         # Ids only on this branch: true once it fast-forwards, false if rewritten.
»  274 │         4) sed 's/^/  /' <<<"$dmh" ;;
»  275 │         *) printf '  ✗ %s\n' "commit ids the documents place on main"; fail=1
»  276 │            sed 's/^/      /' <<<"$dmh" ;;
   277 │     esac
```

#### [`devtools/review-open`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/review-open) — 2 uncovered of 10 coverable lines (80.0% run)

[lines 28–29](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/review-open#L28-L29)
```bash
    27 │ case "$MODE" in
»   28 │     open|--all|--counts) ;;
»   29 │     -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    30 │     # Any other word listed the open rows as if asked for them: a typo of
```

#### [`devtools/save`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/save) — 6 uncovered of 45 coverable lines (86.7% run)

[lines 67–67](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/save#L67-L67)
```bash
    66 │     if ! "$REPO/tools/bt-exhibit" index >/dev/null 2>&1; then
»   67 │         echo "save: warning — bt-exhibit index failed; committing anyway" >&2
    68 │     fi
```
[lines 143–143](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/save#L143-L143)
```bash
   142 │ if (( FULL )); then
»  143 │     exec "$HERE/repo-save" "$REPO" -F "$MSG" "$@"
   144 │ fi
```
[lines 152–155](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/save#L152-L155)
```bash
   151 │ if (( RC != 0 )); then
»  152 │     cat "$OUT"
»  153 │     echo
»  154 │     echo "save: repo-save exited $RC — full output above, nothing was hidden." >&2
»  155 │     exit "$RC"
   156 │ fi
```

#### [`devtools/status`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/status) — 7 uncovered of 69 coverable lines (89.9% run)

[lines 90–96](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/status#L90-L96)
```bash
    89 │ if [[ -x "$(dirname "$0")/ci" ]]; then
»   90 │     ci_line=$("$(dirname "$0")/ci" "$local_head" 2>/dev/null); ci_rc=$?
»   91 │     ci_txt=$(sed -n '1p' <<<"$ci_line" | sed -E 's/^ci — [0-9a-f]+ +//')
»   92 │     case "$ci_rc" in
»   93 │         0) row "${G}✓${O}" "CI" "$ci_txt" ;;
»   94 │         1) row "${R}✗${O}" "CI" "$ci_txt"; rc=1 ;;
»   95 │         3) row "${Y}~${O}" "CI" "$ci_txt" ;;
»   96 │         *) row "${Y}?${O}" "CI" "no verdict readable for ${local_head:0:7} (not pushed, not queued, or gh unavailable)" ;;
    97 │     esac
```

#### [`devtools/test-bt-journal-files.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-bt-journal-files.sh) — 47 uncovered of 47 coverable lines (0.0% run)

[lines 5–63](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-bt-journal-files.sh#L5-L63)
```bash
     4 │ # on PATH, so --rotate cannot reach journald).
»    5 │ set -u
»    6 │ ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
»    7 │ T="$ROOT/tools/bt-journal-files"
»    8 │ W="$ROOT/tmp/test-bt-journal-files"
»    9 │ rm -rf "$W"; mkdir -p "$W/src/mid1" "$W/stub" "$W/badzstd"
»   10 │ REAL_ZSTD=$(command -v zstd)
»   11 │ printf '#!/bin/sh\necho "rotate called" >> "%s/rotate.log"\n' "$W" > "$W/stub/journalctl"
»   12 │ chmod +x "$W/stub/journalctl"
    13 │ # A zstd whose decompression adds a byte: verification must catch it.
»   14 │ printf '#!/bin/sh\n"%s" "$@"; rc=$?\ncase " $* " in *" -dc "*) printf X;; esac\nexit $rc\n' "$REAL_ZSTD" > "$W/badzstd/zstd"
»   15 │ chmod +x "$W/badzstd/zstd"
    16 │ # Closed-file names, built at run time: written out, "name@id-…journal" reads as an email
    17 │ # address to the publish scan.
»   18 │ AT='@'
»   19 │ N4="system${AT}aaa-0000000000000004-0000000000000004.journal"
»   20 │ head -c 300000 /dev/urandom > "$W/src/mid1/system${AT}aaa-0000000000000001-0000000000000001.journal"
»   21 │ head -c 200000 /dev/urandom > "$W/src/mid1/user-1000${AT}aaa-0000000000000002-0000000000000002.journal"
»   22 │ head -c 100000 /dev/urandom > "$W/src/mid1/system${AT}bbb-0000000000000003-0000000000000003.journal~"
»   23 │ head -c 50000 /dev/urandom > "$W/src/mid1/system.journal"
»   24 │ export BT_JOURNAL_SRC="$W/src" BT_JOURNAL_FILES_DIR="$W/dest" BT_JOURNAL_FILES_FREE_MIN_GB=0
»   25 │ P="$W/stub:$PATH"
»   26 │ pass=0 fail=0
»   27 │ check() { if eval "$2"; then pass=$((pass + 1)); echo "PASS $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }
    28 │ 
»   29 │ out=$(PATH="$P" "$T" 2>&1); rc=$?
»   30 │ check "first run copies the 3 closed files" '[[ $rc -eq 0 && "$out" == *"3 copied now"* ]]'
»   31 │ check "the active file is not copied" '[[ ! -e "$W/dest/mid1/system.journal.zst" ]]'
»   32 │ check "manifest has 3 rows" '[[ $(tail -n +2 "$W/dest/MANIFEST.tsv" | wc -l) -eq 3 ]]'
»   33 │ ok=1
»   34 │ for f in "$W"/src/mid1/*@*; do
»   35 │ 	cmp -s "$f" <(zstd -dc < "$W/dest/mid1/$(basename "$f").zst") || ok=0
    36 │ done
»   37 │ check "every copy decompresses to its source byte for byte" '[[ $ok -eq 1 ]]'
»   38 │ check "no rotate without --rotate" '[[ ! -e "$W/rotate.log" ]]'
    39 │ 
»   40 │ out=$(PATH="$P" "$T" 2>&1); rc=$?
»   41 │ check "second run copies nothing" '[[ $rc -eq 0 && "$out" == *"0 copied now, 3 already"* ]]'
    42 │ 
»   43 │ head -c 10000 /dev/urandom > "$W/src/mid1/$N4"
»   44 │ out=$(PATH="$P" "$T" --status 2>&1); rc=$?
»   45 │ check "--status names the new file and writes nothing" '[[ $rc -eq 0 && "$out" == *"not copied: mid1/$N4"* && ! -e "$W/dest/mid1/$N4.zst" ]]'
    46 │ 
»   47 │ out=$(PATH="$P" BT_JOURNAL_FILES_FREE_MIN_GB=100000 "$T" 2>&1); rc=$?
»   48 │ check "low free space refuses and copies nothing" '[[ $rc -eq 2 && "$out" == *"GB free"* && ! -e "$W/dest/mid1/$N4.zst" ]]'
    49 │ 
»   50 │ out=$(PATH="$P" BT_JOURNAL_FILES_BUDGET_GB=0 "$T" 2>&1); rc=$?
»   51 │ check "a full budget refuses" '[[ $rc -eq 2 && "$out" == *"budget"* ]]'
    52 │ 
»   53 │ out=$(PATH="$W/badzstd:$P" "$T" 2>&1); rc=$?
»   54 │ check "a copy that does not verify is not filed" '[[ $rc -eq 1 && "$out" == *"FAILED verification"* && ! -e "$W/dest/mid1/$N4.zst" && ! -e "$W/dest/mid1/$N4.zst.partial" ]]'
    55 │ 
»   56 │ out=$(PATH="$P" "$T" --rotate 2>&1); rc=$?
»   57 │ check "--rotate asks journald to rotate, then copies the new file" '[[ $rc -eq 0 && -s "$W/rotate.log" && "$out" == *"1 copied now"* ]]'
    58 │ 
»   59 │ before=$(find "$W/src" -type f | wc -l)
»   60 │ check "the source directory is never changed" '[[ $before -eq 5 ]]'
»   61 │ echo "passed $pass, failed $fail"
»   62 │ rm -rf "$W"
»   63 │ (( fail == 0 ))
    64 │ 
```

#### [`devtools/test-comprehension`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension) — 116 uncovered (1 of them bare `case` labels, not shown) of 126 coverable lines (7.9% run)

[lines 60–65](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L60-L65)
```bash
    59 │     case "$1" in
»   60 │         --min)  MIN="${2:?--min needs a number}"; shift ;;
    61 │         --suite-files) LIST_SUITE=1 ;;
»   62 │         --dump) DUMP="${2:?--dump needs a directory}"; shift ;;
»   63 │         -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
»   64 │         -*) echo "test-comprehension: unknown option: $1" >&2; exit 2 ;;
»   65 │         *)  WANT="$1" ;;
    66 │     esac
```
[lines 86–87](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L86-L87)
```bash
    85 │ 
»   86 │ WORK=$(mktemp -d) || exit 1
»   87 │ trap 'rm -rf "$WORK"' EXIT
    88 │ 
```
[lines 95–107](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L95-L107)
```bash
    94 │ # because the numerator was a count and not an intersection.
»   95 │ if [[ -n "$DUMP" ]]; then
»   96 │     COV="$DUMP"
    97 │ else
»   98 │     COV="$WORK/cov"
»   99 │     echo "running the suite under trace (devtools/coverage --dump)..." >&2
»  100 │     devtools/coverage --quiet --dump "$COV" >/dev/null 2>"$WORK/cov.err" || {
»  101 │         echo "test-comprehension: coverage run failed; cannot measure" >&2
   102 │         # What coverage said, the failing checks among it: discarded, a red here
   103 │         # could be named by no one (2026-10-18).
»  104 │         tail -25 "$WORK/cov.err" | sed 's/^/  /' >&2; exit 2; }
   105 │ fi
»  106 │ for t in coverable-lines covered-lines; do
»  107 │     [[ -s "$COV/$t" ]] || { echo "test-comprehension: $COV/$t missing or empty" >&2; exit 2; }
   108 │ done
```
[lines 128–131](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L128-L131)
```bash
   127 │     {
»  128 │         awk '{ while (/\\$/ && (getline nxt) > 0) { sub(/\\$/, "", $0); $0 = $0 nxt } print }' install.sh \
   129 │         | grep -oE 'install_file[[:space:]]+"\$SRC/[^"]+"' \
   130 │         | sed 's|.*\$SRC/||; s|"||'
»  131 │         git ls-files -s -- bin tools | awk '$1 == "100755" { print $4 }'
   132 │     } | grep -vE '\.awk$|^tools/lib/|\.service$|\.timer$|\.conf$|\.rules$|\.tsv$' \
```
[lines 135–141](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L135-L141)
```bash
   134 │ }
»  135 │ mapfile -t UNITS < <(units)
   136 │ # An empty derivation is a refusal, not a pass — the rule this repository
   137 │ # arrived at after five checks that reported success over nothing.
»  138 │ if (( ${#UNITS[@]} < 20 )); then
»  139 │     echo "test-comprehension: derived only ${#UNITS[@]} unit(s) from install.sh" >&2
»  140 │     echo "                    refusing to report comprehensiveness over nothing" >&2
»  141 │     exit 2
   142 │ fi
```
[lines 157–157](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L157-L157)
```bash
   156 │ # that reads it.
»  157 │ SEAMS_DRIVEN=$(grep -ohE '\bBT_[A-Z0-9_]+=' "${SUITE[@]}" | sort -u | tr -d '=')
   158 │ 
```
[lines 164–173](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L164-L173)
```bash
   163 │ # understate work done, never overstate it.
»  164 │ TOTAL_ASSERTS=$(cat "${SUITE[@]}" | grep -cE '^[^#]*(^|[ \t]|\|\| )(ok|bad) "' || true)
   165 │ 
»  166 │ printf '%-30s %-7s %-9s %-9s %-9s %-9s %s\n' \
   167 │        unit asserts modes refusals seams branches score
»  168 │ printf '%s\n' "──────────────────────────────────────────────────────────────────────────────"
   169 │ 
»  170 │ : > "$WORK/rows"; : > "$WORK/gaps"; : > "$WORK/unmeasured"
»  171 │ for u in "${UNITS[@]}"; do
»  172 │     [[ -f "$u" ]] || continue
»  173 │     [[ -z "$WANT" || "$u" == *"$WANT"* ]] || continue
   174 │ 
```
[lines 180–189](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L180-L189)
```bash
   179 │     # modes. Those are outcomes, and they are already measured as branches.
»  180 │     awk -v file="$u" '
»  181 │         function trim(x) { sub(/^[ \t]+/, "", x); sub(/[ \t]+$/, "", x); return x }
»  182 │         !inc && /^[ \t]*case[ \t]+"?\$\{?1[:}"]?/ {
»  183 │             inc = 1; depth = 0; ind = match($0, /[^ \t]/); next
   184 │         }
»  185 │         inc {
»  186 │             t = trim($0)
»  187 │             if (t ~ /^case /) { depth++; next }
»  188 │             if (t ~ /^esac/)  { if (depth == 0) { inc = 0 } else depth--; next }
»  189 │             if (depth > 0) next
   190 │             # A LABEL LINE, matched tightly. The first draft used "starts with
```
[lines 195–203](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L195-L203)
```bash
   194 │             # and the pattern alphabet is small.
»  195 │             if (t ~ /^[A-Za-z0-9_*?.\/-]+(\|[A-Za-z0-9_*?.\/-]+)*\)/) {
»  196 │                 lbl = t; sub(/\).*/, "", lbl)
»  197 │                 print FNR "\t" lbl
   198 │             }
   199 │         }
»  200 │     ' "$u" > "$WORK/modes"
   201 │ 
»  202 │     nmode=0; nmode_hit=0; modegap=""
»  203 │     if [[ -s "$WORK/modes" ]]; then
   204 │         # A mode is exercised when any line between its label and the next was
```
[lines 207–213](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L207-L213)
```bash
   206 │         # command — so the branch body is the only evidence there is.
»  207 │         mapfile -t MLINES < <(cut -f1 "$WORK/modes")
»  208 │         mapfile -t MNAMES < <(cut -f2 "$WORK/modes")
»  209 │         for i in "${!MLINES[@]}"; do
»  210 │             lo=${MLINES[$i]}
»  211 │             hi=$(( ${MLINES[$((i+1))]:-0} ))
»  212 │             (( hi == 0 )) && hi=$(( lo + 40 ))
»  213 │             nmode=$((nmode + 1))
   214 │             # `>= lo`, not `> lo`. A one-line branch — `protocol) protocol ;;`
```
[lines 219–224](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L219-L224)
```bash
   218 │             # bound costs nothing: a bare pattern is never traced.
»  219 │             if awk -F'\t' -v f="$u" -v a="$lo" -v b="$hi" \
   220 │                    '$1 == f && $2 >= a && $2 < b { found = 1 } END { exit !found }' \
   221 │                    "$COV/covered-lines"; then
»  222 │                 nmode_hit=$((nmode_hit + 1))
   223 │             else
»  224 │                 modegap="$modegap ${MNAMES[$i]}"
   225 │             fi
```
[lines 230–233](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L230-L233)
```bash
   229 │     # ── REFUSALS: every non-zero exit, and whether anything reached it ───
»  230 │     nref=0; nref_hit=0; refgap=""
»  231 │     while read -r ln; do
»  232 │         [[ -n "$ln" ]] || continue
»  233 │         nref=$((nref + 1))
   234 │         # A REFUSAL ON A CONTINUATION LINE BELONGS TO ITS COMMAND.
```
[lines 245–256](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L245-L256)
```bash
   244 │         # it before being looked up.
»  245 │         cln=$(awk -F'\t' -v f="$u" -v n="$ln" \
   246 │                   '$1 == f && $2 <= n && $2 > best { best = $2 } END { print best + 0 }' \
   247 │                   "$COV/coverable-lines")
»  248 │         (( cln == 0 )) && cln="$ln"
»  249 │         if awk -F'\t' -v f="$u" -v n="$cln" \
   250 │                '$1 == f && $2 == n { found = 1 } END { exit !found }' \
   251 │                "$COV/covered-lines"; then
»  252 │             nref_hit=$((nref_hit + 1))
   253 │         else
»  254 │             refgap="$refgap $ln"
   255 │         fi
»  256 │     done < <(grep -nE '(^|[ \t;&|])exit[ \t]+[1-9]' "$u" | cut -d: -f1 \
   257 │              | while read -r c; do
```
[lines 263–273](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L263-L273)
```bash
   262 │                    # guess about where quoting starts and ends.
»  263 │                    awk -F'\t' -v f="$u" -v n="$c" \
   264 │                        '$1 == f && $2 == n { found = 1 } END { exit !found }' \
   265 │                        "$COV/excluded-lines" || echo "$c"
»  266 │                done)
   267 │ 
   268 │     # ── SEAMS: every BT_* the unit reads, and whether the suite drives it ─
»  269 │     nseam=0; nseam_hit=0; seamgap=""
»  270 │     for v in $(grep -ohE '\$\{BT_[A-Z0-9_]+' "$u" | sed 's/\${//' | sort -u); do
»  271 │         nseam=$((nseam + 1))
»  272 │         if grep -qx "$v" <<<"$SEAMS_DRIVEN"; then nseam_hit=$((nseam_hit + 1))
»  273 │         else seamgap="$seamgap $v"; fi
   274 │     done
```
[lines 277–282](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L277-L282)
```bash
   276 │     # ── BRANCHES: ordinary line coverage, from the same tables ───────────
»  277 │     read -r cov tot < <(awk -F'\t' -v f="$u" '
»  278 │         FNR == NR { if ($1 == f) c++; next }
»  279 │         $1 == f { t++ }
»  280 │         END { print c + 0, t + 0 }' "$COV/covered-lines" "$COV/coverable-lines")
   281 │ 
»  282 │     pct() { (( $2 == 0 )) && echo "—" || awk -v a="$1" -v b="$2" 'BEGIN{printf "%d%%", 100*a/b}'; }
   283 │     # The score is the WEAKEST dimension, not the average. A unit whose every
```
[lines 286–291](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L286-L291)
```bash
   285 │     # a unit with untested refusals, and averaging hides exactly that.
»  286 │     worst=100; measured=0
»  287 │     for pair in "$nmode_hit:$nmode" "$nref_hit:$nref" "$nseam_hit:$nseam" "$cov:$tot"; do
»  288 │         a=${pair%%:*}; b=${pair##*:}
»  289 │         (( b == 0 )) && continue
»  290 │         measured=$((measured + 1))
»  291 │         v=$(( 100 * a / b )); (( v < worst )) && worst=$v
   292 │     done
```
[lines 300–309](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L300-L309)
```bash
   299 │     # the instrument written to detect it.
»  300 │     if (( measured == 0 )); then
»  301 │         lang=$(head -1 "$u" | sed -E "s|^#!||; s|.*/env +||; s|.*/||; s| .*||")
»  302 │         nassert=$(cat "${SUITE[@]}" | grep -cE '(ok|bad) "[^"]*'"$(basename "$u")" || true)
»  303 │         printf '%-30s %-7s %-9s %-9s %-9s %-9s %s\n' "$u" "${nassert:-0}" \
   304 │             "—" "—" "—" "—" "UNMEASURED (${lang:-unknown})" >> "$WORK/unmeasured"
»  305 │         continue
   306 │     fi
   307 │ 
»  308 │     nassert=$(cat "${SUITE[@]}" | grep -cE '(ok|bad) "[^"]*'"$(basename "$u" | sed 's/\./\\./g')" || true)
»  309 │     printf '%-30s %-7s %-9s %-9s %-9s %-9s %d%%\n' "$u" "${nassert:-0}" \
   310 │         "$nmode_hit/$nmode" "$nref_hit/$nref" "$nseam_hit/$nseam" "$cov/$tot" "$worst" \
```
[lines 315–315](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L315-L315)
```bash
   314 │     # \t\t and every gap label below was attributed to the wrong dimension.
»  315 │     printf '%d\t%s\t%s\t%s\t%s\n' "$worst" "$u" \
   316 │         "${modegap:--}" "${refgap:--}" "${seamgap:--}" >> "$WORK/gaps"
```
[lines 319–325](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L319-L325)
```bash
   318 │ 
»  319 │ sort -t% -k1 -n "$WORK/rows" 2>/dev/null | sort -n -k7 | head -100
»  320 │ echo
»  321 │ if [[ -s "$WORK/unmeasured" ]]; then
»  322 │     echo "not measurable by these instruments — a language nothing here traces"
»  323 │     echo "──────────────────────────────────────────────────────────────────────────────"
»  324 │     cat "$WORK/unmeasured"
»  325 │     echo
   326 │ fi
```
[lines 332–353](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-comprehension#L332-L353)
```bash
   331 │ # that changes what anyone does next.
»  332 │ echo "never exercised"
»  333 │ echo "──────────────────────────────────────────────────────────────────────────────"
»  334 │ sort -n "$WORK/gaps" | while IFS=$'\t' read -r sc unit mg rg sg; do
»  335 │     [[ "$mg$rg$sg" == "---" ]] && continue
»  336 │     printf '%s\n' "$unit"
»  337 │     [[ "$mg" != "-" ]] && printf '    modes     %s\n' "$(echo "$mg" | tr -s ' ')"
»  338 │     [[ "$rg" != "-" ]] && printf '    refusals  line(s)%s\n' "$rg"
»  339 │     [[ "$sg" != "-" ]] && printf '    seams     %s\n' "$(echo "$sg" | tr -s ' ')"
   340 │ done
   341 │ 
»  342 │ TOTAL=$(awk '{ s += $1; n++ } END { if (n) printf "%d", s/n; else print 0 }' "$WORK/gaps")
»  343 │ WEAKEST=$(sort -n "$WORK/gaps" | head -1 | cut -f1)
»  344 │ echo
»  345 │ printf 'units measured: %d   assertions in the suite: %d   mean weakest-dimension: %d%%   worst unit: %d%%\n' \
   346 │        "$(grep -c . "$WORK/gaps")" "${TOTAL_ASSERTS:-0}" "${TOTAL:-0}" "${WEAKEST:-0}"
   347 │ 
»  348 │ if [[ -n "$MIN" ]]; then
»  349 │     if (( ${WEAKEST:-0} < MIN )); then
»  350 │         echo "test-comprehension: a unit scores ${WEAKEST}%, below the floor of ${MIN}%" >&2
»  351 │         exit 1
   352 │     fi
»  353 │     echo "every unit is at or above the ${MIN}% floor"
   354 │ fi
```

#### [`devtools/test-journal-fast.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-journal-fast.sh) — 34 uncovered of 34 coverable lines (0.0% run)

[lines 7–47](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/test-journal-fast.sh#L7-L47)
```bash
     6 │ #   devtools/test-journal-fast.sh [<boot -1 day, e.g. 2026-10-22>]
»    7 │ set -uo pipefail
»    8 │ ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
     9 │ # shellcheck source=tools/lib/journal.sh
»   10 │ source "$ROOT/tools/lib/journal.sh"
»   11 │ D=${1:-2026-10-22}
»   12 │ W="$ROOT/tmp/test-journal-fast"; mkdir -p "$W"
»   13 │ B1=$(journalctl --list-boots --no-pager | awk '$1 == "-1" { print $2 }')
»   14 │ B0START=$(journalctl --list-boots --no-pager | awk '$1 == "0" { print $4" "$5 }')
»   15 │ B1END=$(journalctl --list-boots --no-pager | awk '$1 == "-1" { print $(NF-2)" "$(NF-1) }')
»   16 │ EPOCH0=$(date -d "$B0START" +%s)
»   17 │ pass=0 fail=0
    18 │ run() { # <name> <args...>
»   19 │ 	local name="$1"; shift
»   20 │ 	local t0 t1 t2 rcs rcf
»   21 │ 	t0=$(date +%s.%N)
»   22 │ 	BT_JOURNAL_FAST=0 bt_journal "$@" > "$W/slow.out" 2>/dev/null; rcs=$?
»   23 │ 	t1=$(date +%s.%N)
»   24 │ 	BT_JOURNAL_FAST=1 bt_journal "$@" > "$W/fast.out" 2>/dev/null; rcf=$?
»   25 │ 	t2=$(date +%s.%N)
»   26 │ 	if [[ $rcs -eq $rcf ]] && cmp -s "$W/slow.out" "$W/fast.out"; then
»   27 │ 		pass=$((pass + 1)); printf 'PASS %-34s lines=%-8s rc=%s  plain %6.1fs  fast %5.1fs\n' \
    28 │ 			"$name" "$(wc -l < "$W/fast.out")" "$rcf" "$(echo "$t1 - $t0" | bc)" "$(echo "$t2 - $t1" | bc)"
    29 │ 	else
»   30 │ 		fail=$((fail + 1)); printf 'FAIL %-34s rc plain=%s fast=%s, lines plain=%s fast=%s\n' \
    31 │ 			"$name" "$rcs" "$rcf" "$(wc -l < "$W/slow.out")" "$(wc -l < "$W/fast.out")"
»   32 │ 		diff "$W/slow.out" "$W/fast.out" | head -n 6 | sed 's/^/     /'
    33 │ 	fi
    34 │ }
»   35 │ run "this boot, whole, iso" -k -b 0 --no-pager -o short-iso-precise
»   36 │ run "no -b means this boot" -k --since "@$EPOCH0" --no-pager -o short-iso-precise
»   37 │ run "boot -1, 1 h window, iso" -k -b -1 --since "$D 09:00" --until "$D 10:00" --no-pager -o short-iso-precise
»   38 │ run "boot -1, 3 h, cat, --grep" -k -b -1 --since "$D 09:00" --until "$D 12:00" --no-pager -o cat --grep='hci0: (Opcode|result)'
»   39 │ run "boot -1 by id, 1 h, -p err" -k -b "$B1" --since "$D 12:00" --until "$D 13:00" --no-pager -p err -o short-iso-precise
»   40 │ run "boot -1, its last 40 min" -k -b -1 --since "$(date -d "$B1END 40 min ago" '+%F %T')" --no-pager -o short-iso-precise
»   41 │ run "--grep, no match, no -q" -k -b 0 --no-pager --grep='zzz-no-such-line-zzz'
»   42 │ run "--grep, no match, -q" -k -b 0 -q --no-pager --grep='zzz-no-such-line-zzz'
»   43 │ run "-b0 glued, short output" -k -b0 --no-pager --since "@$EPOCH0" -o short
»   44 │ run "not kernel: falls back" -u bluetooth -b 0 --no-pager -n 5
»   45 │ echo "passed $pass, failed $fail"
»   46 │ rm -f "$W/slow.out" "$W/fast.out"
»   47 │ (( fail == 0 ))
    48 │ 
```

</details>

## 6. `tests/`: the suite's own file and its helpers

<details><summary>608 uncovered lines in 4 files (expand)</summary>

Paths a green run does not take (section 3). `tests/btmon/render` is the renderer the `btmon` stubs print through.

#### [`tests/btmon/render`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/btmon/render) — 36 uncovered of 36 coverable lines (0.0% run)

[lines 21–65](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/btmon/render#L21-L65)
```bash
    20 │ # same failure.
»   21 │ col=80
»   22 │ for a in "$@"; do
»   23 │     case "$a" in
»   24 │         --columns=*) col=${a#--columns=} ;;
»   25 │         -C?*)        col=${a#-C} ;;
    26 │     esac
    27 │ done
»   28 │ exec awk -v col="$col" '
»   29 │ function spaces(n,   s) { s = ""; while (n-- > 0) s = s " "; return s }
»   30 │ /^[<>@=*] / {
»   31 │     line = $0; blk = ""
    32 │     # The right-hand block: frame or channel, index, date, time (as -T prints them).
»   33 │     if (match(line, /( #[0-9]+| \{[^}]*\})?( \[hci[0-9]+\])?( [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])? [0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9][0-9][0-9][0-9][0-9][0-9]$/)) {
»   34 │         blk = substr(line, RSTART); line = substr(line, 1, RSTART - 1)
    35 │     }
»   36 │     sub(/ +$/, "", line)
»   37 │     head = substr(line, 1, 2); rest = substr(line, 3)
»   38 │     i = index(rest, ": ")
»   39 │     if (i == 0) { o[++n] = $0; next }
»   40 │     label = substr(rest, 1, i - 1); body = substr(rest, i + 2)
    41 │     # <extra>: an Open carries "(privileged) version N.M" or "version N.M"; everything else that
    42 │     # has one carries it in parentheses after the name, "(0x01|0x0028) plen 17".
»   43 │     extra = ""; text = body
»   44 │     if (label ~ / Open$/ && match(body, / (\(privileged\) )?version [0-9.]+$/)) {
»   45 │         extra = substr(body, RSTART + 1); text = substr(body, 1, RSTART - 1)
»   46 │     } else if (match(body, / \([^()]*\)[^()]*$/)) {
»   47 │         extra = substr(body, RSTART + 1); text = substr(body, 1, RSTART - 1)
    48 │     }
»   49 │     len = length(head label)
»   50 │     max = col - len - length(extra) - length(blk) - 3
»   51 │     if (max <= -2) { dead = 1; exit }
»   52 │     s = ": " text
»   53 │     if (length(s) > max) {
»   54 │         s = substr(s, 1, max)
»   55 │         if (max >= 2) s = substr(s, 1, max - 2) ".."
»   56 │         if (max >= 3 && substr(s, max - 2, 1) == " ") s = substr(s, 1, max - 3) "." substr(s, max - 1)
    57 │     }
»   58 │     out = head label s; len += length(s)
»   59 │     if (extra != "") { out = out " " extra; len += 1 + length(extra) }
»   60 │     if (blk != "") { out = out spaces(col - len - length(blk) - 1) blk }
»   61 │     o[++n] = out; next
    62 │ }
»   63 │ { o[++n] = $0 }
»   64 │ END { if (dead) exit 134; for (k = 1; k <= n; k++) print o[k] }
»   65 │ '
    66 │ 
```

#### [`tests/journal/boots/boot-list`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/journal/boots/boot-list) — 1 uncovered of 1 coverable lines (0.0% run)

[lines 2–2](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/journal/boots/boot-list#L2-L2)
```bash
     1 │ #!/bin/sh
»    2 │ printf -- "-1\n0\n"
     3 │ 
```

#### [`tests/journal/phase/boot-list`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/journal/phase/boot-list) — 2 uncovered of 2 coverable lines (0.0% run)

[lines 2–3](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/journal/phase/boot-list#L2-L3)
```bash
     1 │ #!/bin/sh
»    2 │ echo -1
»    3 │ echo 0
     4 │ 
```

#### [`tests/run-tests`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests) — 569 uncovered (3 of them bare `case` labels, not shown) of 4940 coverable lines (88.5% run)

[lines 98–104](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L98-L104)
```bash
    97 │ if [[ -e "$BT_REAL_TRIAL_STATE/current" && "${BT_ALLOW_OPEN_TRIAL:-0}" != 1 ]]; then
»   98 │     echo "run-tests: a trial is OPEN on this machine — refusing to run." >&2
»   99 │     awk '{ print "           " $0 }' "$BT_REAL_TRIAL_STATE/current" >&2 2>/dev/null
»  100 │     echo "           This suite drives tools that act. Close the trial, or wait" >&2
»  101 │     echo "           for it to close, and run again." >&2
»  102 │     echo "           BT_ALLOW_OPEN_TRIAL=1 overrides — only when the state file" >&2
»  103 │     echo "           is stale, e.g. after a crash." >&2
»  104 │     exit 2
   105 │ fi
```
[lines 131–132](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L131-L132)
```bash
   130 │ case "${1:-}" in
»  131 │     --jobs|-j) SUITE_JOBS="${2:-}"; shift; shift ;;
»  132 │     --serial)  SUITE_JOBS=1; shift ;;
   133 │ esac
```
[lines 136–137](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L136-L137)
```bash
   135 │ if ! [[ "$SUITE_JOBS" =~ ^[1-9][0-9]*$ ]]; then
»  136 │     echo "run-tests: --jobs takes a whole number of workers, 1 or more (got '$SUITE_JOBS')" >&2
»  137 │     exit 2
   138 │ fi
```
[lines 156–156](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L156-L156)
```bash
   155 │ if [[ "${1:-}" == --section ]]; then
»  156 │     [[ -n "${2:-}" ]] || { echo "usage: run-tests --section <text from a heading>" >&2; exit 2; }
   157 │     # A filter around one run, not a run. It sits here, before anything is
```
[lines 161–161](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L161-L161)
```bash
   160 │     # safe.directory for its git, and no run marker of this one.
»  161 │     out=$("$0"); rc=$?
   162 │     awk -v want="$2" '
```
[lines 168–169](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L168-L169)
```bash
   167 │         END { if (tail != "") { print ""; print tail } }
»  168 │     ' <<<"$out"
»  169 │     exit $rc
   170 │ fi
```
[lines 252–254](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L252-L254)
```bash
   251 │ if (( ${GUARD_N:-0} < 20 )); then
»  252 │     echo "run-tests: derived only ${GUARD_N:-0} guarded tool name(s) from install.sh" >&2
»  253 │     echo "           refusing to run with an unguarded PATH" >&2
»  254 │     exit 2
   255 │ fi
```
[lines 365–367](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L365-L367)
```bash
   364 │ if (( ${TRIP_N:-0} < 30 )); then
»  365 │     echo "run-tests: read only ${TRIP_N:-0} machine tool(s) from tests/machine-tools —" >&2
»  366 │     echo "           refusing to run with the machine within reach" >&2
»  367 │     exit 2
   368 │ fi
```
[lines 451–453](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L451-L453)
```bash
   450 │ real_tool() {   # <check> <tool> [args...] — 127 when the host has no such tool
»  451 │     local check="$1" t="$2" p; shift 2
»  452 │     p=$(PATH="$SUITE_ORIG_PATH" command -v "$t") || return 127
»  453 │     env BT_MACHINE_CONTRACT="$check" "$p" "$@"
   454 │ }
```
[lines 501–501](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L501-L501)
```bash
   500 │ while IFS= read -r _sd; do
»  501 │     [[ -n "$_sd" ]] && git config --file "$SUITE_GITCONFIG" --add safe.directory "$_sd"
   502 │ done < <(git config --global --get-all safe.directory 2>/dev/null; git config --system --get-all safe.directory 2>/dev/null)
```
[lines 560–563](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L560-L563)
```bash
   559 │     if (( ! REPORTED )) && declare -F final_resource_report >/dev/null; then
»  560 │         echo
»  561 │         echo "  ** RUN DID NOT FINISH — interrupted, or exited early. The checks"
»  562 │         echo "     below are the only account of what it touched. **"
»  563 │         final_resource_report
   564 │     fi
```
[lines 603–603](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L603-L603)
```bash
   602 │     if [[ -e "$BT_REAL_TRIAL_STATE/current" ]]; then
»  603 │         echo "open=yes:$(cksum < "$BT_REAL_TRIAL_STATE/current" 2>/dev/null)"
   604 │     else
```
[lines 818–819](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L818-L819)
```bash
   817 │             # the differ reads as one empty path; it is not a file.
»  818 │             while IFS= read -r p; do [[ "$p" == "  ("* ]] || bad "      $p"; done < <(
»  819 │                 bin_footprint_diff "$INSTALL_FOOTPRINT_BEFORE" "$INSTALL_FOOTPRINT_AFTER")
   820 │             bad "  something wrote through to an installed tool, unit, rule or override."
```
[lines 829–829](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L829-L829)
```bash
   828 │ ok()   { echo "  ✓ $*"; pass=$((pass + 1)); SUITE_AT="✓ $*"; }
»  829 │ bad()  { echo "  ✗ $*"; fail=$((fail + 1)); SUITE_AT="✗ $*"; }
   830 │ 
```
[lines 855–864](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L855-L864)
```bash
   854 │     awk -F'\t' -v row="$2" -v names="${*:3}" '
»  855 │         function cells(   i, o) {
»  856 │             o = ""
»  857 │             for (i = 1; i <= n; i++) o = o (i > 1 ? " " : "") ((want[i] in col) ? $(col[want[i]]) : "?no-column:" want[i])
»  858 │             return o
   859 │         }
»  860 │         NR == 1 { n = split(names, want, " "); for (i = 1; i <= NF; i++) col[$i] = i; next }
»  861 │         row == "all" { print cells(); next }
»  862 │         row == "last" { last = cells(); next }
»  863 │         NR == row + 0 { print cells(); exit }
»  864 │         END { if (row == "last" && NR > 1) print last }' "$1" 2>/dev/null
   865 │ }
```
[lines 908–912](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L908-L912)
```bash
   907 │         [[ -z "$st" || "$st" == Z ]] && return 0
»  908 │         sleep 0.05
   909 │     done
»  910 │     return 1
   911 │ }
»  912 │ proc_state() { awk '{ print "state " $3 ", parent " $4 }' "/proc/$1/stat" 2>/dev/null || echo absent; }
   913 │ 
```
[lines 951–956](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L951-L956)
```bash
   950 │     unshare -Urmn bash -c '
»  951 │         mount -t overlay co-world -o lowerdir="$PWD",upperdir="$1",workdir="$2" "$PWD" || exit 97
»  952 │         cd "$PWD" || exit 97        # re-enter: the old directory handle is the lower layer
   953 │         # An identity of its own, in the overlay'"'"'s .git/config: a fresh clone
   954 │         # has none, and CI'"'"'s checkout is one (2026-10-08).
»  955 │         git config user.name "Checkout World"; git config user.email world@example.com
»  956 │         eval "$3"' co-world "$COW/up" "$COW/wk" "$1"
   957 │ }
```
[lines 987–998](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L987-L998)
```bash
   986 │     if ! co_git_inside .; then
»  987 │         COWORLD_SKIPPED="the checkout world (this checkout's git directory lies outside it, as in a git worktree: the overlay cannot hold its writes)"
»  988 │         return
   989 │     fi
   990 │     if ! unshare -Urmn true 2>/dev/null; then
»  991 │         COWORLD_SKIPPED="the checkout world (no user, mount and network namespaces here)"
»  992 │         return
   993 │     fi
   994 │     COBEFORE=$(co_snapshot)
»  995 │     proof=$(co_world "
»  996 │         echo $mark > $mark.proof
»  997 │         git commit -q --allow-empty -m 'checkout world: proof' || exit 1
»  998 │         echo \"file=\$(cat $mark.proof) head=\$(git log -1 --format=%s)\"
   999 │         # No way out: the world's network namespace has no interface but lo, and
```
[lines 1003–1009](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1003-L1009)
```bash
  1002 │         # /etc/hosts first, as CI's access audit reported (2026-10-09).
» 1003 │         ifs=\$(awk 'NR > 2 { sub(\":\", \"\", \$1); printf \"%s \", \$1 }' /proc/self/net/dev)
» 1004 │         if [[ \"\$ifs\" == 'lo ' ]] && ! (exec 3<>/dev/tcp/192.0.2.1/9) 2>/dev/null; then echo net=none
» 1005 │         else echo \"net=reached (interfaces: \$ifs)\"; fi
  1006 │     " 2>&1); rc=$?
  1007 │     if (( rc == 97 )); then
» 1008 │         COWORLD_SKIPPED="the checkout world (an overlay of this checkout cannot be mounted here)"
» 1009 │     elif [[ "$proof" == "file=$mark head=checkout world: proof"*"net=none" && ! -e "$mark.proof" \
  1010 │             && "$COBEFORE" == "$(co_snapshot)" ]]; then
```
[lines 1015–1015](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1015-L1015)
```bash
  1014 │         bad "the checkout world did NOT prove itself — nothing was run in it: inside '$(tr '\n' ' ' <<<"$proof")'; outside $([[ -e "$mark.proof" ]] && echo 'the marker exists' || echo 'no marker'), $([[ "$COBEFORE" == "$(co_snapshot)" ]] && echo 'refs unchanged' || echo 'REFS OR STATUS CHANGED')"
» 1015 │         rm -f "$mark.proof"
  1016 │     fi
```
[lines 1026–1040](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1026-L1040)
```bash
  1025 │     machine_stub "$COW/bin" systemd-analyze udevadm
» 1026 │     COSETUP="
» 1027 │         B='$COW/bare'; rm -rf \"\$B\"; mkdir -p \"\$B\"
» 1028 │         git init -q --bare \"\$B/origin.git\"; git init -q --bare \"\$B/private.git\"
  1029 │         # CI checks out at depth 1, and a bare repository refuses a push from a
  1030 │         # shallow clone unless told to take one.
» 1031 │         git -C \"\$B/origin.git\" config receive.shallowUpdate true
» 1032 │         git -C \"\$B/private.git\" config receive.shallowUpdate true
  1033 │         # The real URL, read BEFORE the rewrite exists: a key exported ahead of
  1034 │         # its value is an empty insteadOf, and that matches every URL.
» 1035 │         ORIGIN_URL=\$(git remote get-url origin)
» 1036 │         export GIT_CONFIG_COUNT=2 PATH='$COW/bin':\"\$PATH\"
» 1037 │         export GIT_CONFIG_KEY_0=\"url.\$B/origin.git.insteadOf\" GIT_CONFIG_VALUE_0=\"\$ORIGIN_URL\"
  1038 │         # No hooks in here: hooks installed in this checkout would run at every
  1039 │         # commit and push the world makes, against the world's scratch remotes.
» 1040 │         export GIT_CONFIG_KEY_1=core.hooksPath GIT_CONFIG_VALUE_1='$COW/nohooks'
  1041 │         # The private remote is a real one, in the overlay's .git/config: git
```
[lines 1044–1051](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1044-L1051)
```bash
  1043 │         # get-url\` — repo-save's test for it — does not count one as existing.
» 1044 │         git remote add private \"\$B/private.git\"
» 1045 │         export BT_TRIAL_STATE_DIR='$COW/trial'
» 1046 │         git add -A && git commit -q --allow-empty -m 'checkout world: the tree as it is'
» 1047 │         git checkout -q -B main      # -B: the checkout may already be on main, as CI's is
» 1048 │         git push -q origin main 2>/dev/null
» 1049 │         git checkout -q -b kernel/mgmt-flush-status
» 1050 │         printf 'held patch\n' > held-world.patch; git add held-world.patch; git commit -q -m 'held: a patch'
» 1051 │         git checkout -q main
  1052 │     "
```
[lines 1332–1335](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1332-L1335)
```bash
  1331 │ if (( ${#SHFILES[@]} < 20 )); then
» 1332 │     echo "run-tests: derived only ${#SHFILES[@]} shell file(s) from git ls-files" >&2
» 1333 │     echo "           four repo-wide invariants scan this set; refusing to run" >&2
» 1334 │     echo "           and report them green over nothing" >&2
» 1335 │     exit 2
  1336 │ fi
```
[lines 1379–1379](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1379-L1379)
```bash
  1378 │ suite_sections() {   # one line per section, in file order: <first line> <last line> <heading>
» 1379 │     awk 'prev ~ /^echo "/ && /^echo "─/ { if (n++) print s, NR - 2, h; s = NR - 1; h = substr(prev, 7, length(prev) - 7) }
  1380 │          { prev = $0 } END { print s, NR, h }' tests/run-tests
```
[lines 1392–1394](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1392-L1394)
```bash
  1391 │     awk -v a="$1" -v b="$2" 'NR == 1 { print "cd \"$SUITE_ROOT\" || exit 1"; next }
» 1392 │                              NR < a  { print ""; next }
» 1393 │                              NR <= b { print; next }
» 1394 │                                      { exit }' "$SUITE_ROOT/tests/run-tests" > "$3/tests/run-tests"
  1395 │ }
```
[lines 1402–1403](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1402-L1403)
```bash
  1401 │     if [[ -z "${SUITE_UNIT_PARENT:-}" || "$(cat "${SUITE_UNIT_DIR:-/nonexistent}/parent" 2>/dev/null)" != "$SUITE_UNIT_PARENT" ]]; then
» 1402 │         echo "run-tests: SUITE_UNIT is set, but no parallel run of this suite started this process — refusing." >&2
» 1403 │         exit 2
  1404 │     fi
```
[lines 1432–1432](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1432-L1432)
```bash
  1431 │     _units=(); _unit_of=(); _weight=(); _long=()
» 1432 │     for (( _k = 0; _k < _last; _k++ )); do
  1433 │         read -r _a _b _h <<<"${_secs[$_k]}"
```
[lines 1480–1480](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1480-L1480)
```bash
  1479 │         ( exec -c "$BASH" -c 'eval "$1"; export SUITE_UNIT="$2" SUITE_UNIT_ID="$3" SUITE_UNIT_DIR="$4" SUITE_UNIT_PARENT="$5"
» 1480 │                              exec "$BASH" tests/run-tests' \
  1481 │               worker "$SUITE_CALLER_ENV" "${_units[$_u]}" "$_u" "$SUITE_PAR" "$SUITE_RUN_ID" \
```
[lines 1512–1514](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1512-L1514)
```bash
  1511 │     # section to split is the one at the top of this line.
» 1512 │     _longest=$(for _u in "${!_took[@]}"; do
» 1513 │                    read -r _a _b _h <<<"${_secs[${_units[$_u]%% *}]}"
» 1514 │                    printf '%d\t%d.%d s  %s\n' "${_took[$_u]}" $(( _took[_u] / 10 )) $(( _took[_u] % 10 )) "$_h"
  1515 │                done | sort -t$'\t' -k1,1nr | head -3 | cut -f2- | paste -sd'|' | sed 's/|/; /g')
```
[lines 1590–1590](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1590-L1590)
```bash
  1589 │ # leaves it after 10:31 and it is swallowed into that cluster instead.
» 1590 │ PHA=$(awk "${PB[@]}" <<'PHDATA'
  1591 │ 7 EXO 2026-08-20T10:20:00.000000+02:00
```
[lines 1627–1627](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1627-L1627)
```bash
  1626 │ # a check that stops one gap early passes it as clean.
» 1627 │ PHB=$(awk "${PB[@]}" <<'PHDATA'
  1628 │ 3 EXO 2026-08-21T11:00:00.000000+02:00
```
[lines 1650–1650](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1650-L1650)
```bash
  1649 │ # drops the timeout without a word.
» 1650 │ PHD=$(awk "${PB[@]}" <<'PHDATA'
  1651 │ 6 EXO 2026-08-23T09:00:00.000000+02:00
```
[lines 1694–1694](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1694-L1694)
```bash
  1693 │     bad "bt-phase end-to-end wrong (rc=$ph_rc):"
» 1694 │     tail -4 <<<"$PH" | sed 's/^/      /'
  1695 │ fi
```
[lines 1775–1776](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1775-L1776)
```bash
  1774 │ bt1_block() {
» 1775 │     awk '/BT1-CURRENT-BEGIN/{inside=1; next}
» 1776 │          /BT1-CURRENT-END/{inside=0}
  1777 │          inside' "$1"
```
[lines 1810–1811](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1810-L1811)
```bash
  1809 │         1) ok "$label" ;;
» 1810 │         0) bad "$label — found: $(head -3 <<<"$out" | tr '\n' ' ')" ;;
» 1811 │         *) bad "$label — the search itself FAILED (grep rc=$rc); not a negative result" ;;
  1812 │     esac
```
[lines 1856–1856](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1856-L1856)
```bash
  1855 │ elif (( labels_rc == 1 )); then
» 1856 │     ok "outward-facing docs use project labels only as parenthetical search handles (none present)"
  1857 │ else
```
[lines 1876–1876](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L1876-L1876)
```bash
  1875 │ # whitespace, on a line whose non-comment part contains it.
» 1876 │ RG_HITS=$(grep -HnE '^[^#]*(^|[;&|(]|\$\()[[:space:]]*rg[[:space:]]' "${SUITE_FILES[@]}" 2>/dev/null \
  1877 │           | grep -vE 'RG_HITS=|deep-review follow-up|command token')
```
[lines 2009–2009](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2009-L2009)
```bash
  2008 │     bad "SCO 2x2 wrong or missing — outcome read by position, recovered miscounted, or awk failed:"
» 2009 │     grep -A4 'hung' <<<"$R1" | head -6
  2010 │ fi
```
[lines 2035–2035](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2035-L2035)
```bash
  2034 │     bad "censored handling wrong — expected rate over 2 with 1/3 censored:"
» 2035 │     grep -E 'observational_boot' <<<"$R1" | head -2
  2036 │ fi
```
[lines 2071–2071](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2071-L2071)
```bash
  2070 │     bad "report changed when columns were reordered — a consumer reads by position"
» 2071 │     diff <(echo "$R1") <(echo "$R2") | head -12 | sed 's/^/      /'
  2072 │ fi
```
[lines 2107–2112](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2107-L2112)
```bash
  2106 │ awk -F'\t' -v OFS='\t' '
» 2107 │     NR == 1 { for (i = 1; i <= NF; i++) c[$i] = i; print; next }
» 2108 │     { print }
» 2109 │     $c["trial_type"] == "observational_boot" && $c["trial"] == 2 {
» 2110 │         $c["trial"] = 6; $c["bt1_status"] = "unknown"; add = $0
  2111 │     }
» 2112 │     END { print add }' "$FIX" > "$RU/evidence/trials/results.tsv"
  2113 │ RUO=$(BT_REPO="$RU" tools/bt-trial report 2>&1)
```
[lines 2119–2119](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2119-L2119)
```bash
  2118 │     bad "unknown trial mishandled — expected 1/2 1/2 0/1 50% 1/4 5400s:"
» 2119 │     grep -E 'observational_boot +stock' <<<"$RUO" | head -1 | sed 's/^/      /'
  2120 │ fi
```
[lines 2137–2137](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2137-L2137)
```bash
  2136 │     awk -F'\t' -v keep=" $* " 'NR == 1 { for (i = 1; i <= NF; i++) c[$i] = i; print; next }
» 2137 │                                index(keep, " " $c["trial"] " ")' "$FIX" > "$d/evidence/trials/results.tsv"
  2138 │ }
```
[lines 2164–2164](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2164-L2164)
```bash
  2163 │ # -f, and that the interval helper actually returns a number.
» 2164 │ offenders=$(grep -rnE "awk[^|]*-f [^ ]+\.awk[^|]*'" tools/ bin/ 2>/dev/null \
  2165 │             | grep -vE "^tools/lib/|-f \"\\\$LIBDIR/[a-z-]+\.awk\" -f " || true)
```
[lines 2170–2173](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2170-L2173)
```bash
  2169 │     bad "inline program alongside -f (it will be read as a filename):"
» 2170 │     sed 's/^/      /' <<<"$offenders"
  2171 │ fi
  2172 │ 
» 2173 │ iv=$(awk -f tools/lib/timestamp.awk -f tools/lib/interval.awk \
  2174 │         -v a="2026-08-31T23:59:59.000000+02:00" -v b="2026-09-01T00:00:02.000000+02:00" </dev/null)
```
[lines 2178–2178](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2178-L2178)
```bash
  2177 │ 
» 2178 │ iv2=$(awk -f tools/lib/timestamp.awk -f tools/lib/interval.awk \
  2179 │         -v a="not-a-timestamp" -v b="2026-09-01T00:00:02.000000+02:00" </dev/null)
```
[lines 2223–2225](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2223-L2225)
```bash
  2222 │ # The epoch's own second is a time, not a refusal.
» 2223 │ iv0=$(awk -f tools/lib/timestamp.awk -f tools/lib/interval.awk \
  2224 │         -v a="1970-01-01T00:00:00+00:00" -v b="1970-01-01T00:00:03+00:00" </dev/null)
» 2225 │ iv00=$(awk -f tools/lib/timestamp.awk -f tools/lib/interval.awk \
  2226 │         -v a="1970-01-01T00:00:00+00:00" -v b="1970-01-01T00:00:00+00:00" </dev/null)
```
[lines 2233–2241](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2233-L2241)
```bash
  2232 │ # hours computed from -1.
» 2233 │ bh=$(awk -f tools/lib/timestamp.awk -f tools/lib/boot-hours.awk \
  2234 │         -v a="2026-02-28T22:00:00.000000+02:00" -v b="2026-03-01T01:00:00.000000+02:00" </dev/null)
» 2235 │ bhA=$(awk -f tools/lib/timestamp.awk -f tools/lib/boot-hours.awk \
  2236 │         -v a="not-a-timestamp" -v b="2026-03-01T01:00:00.000000+02:00" </dev/null); bhArc=$?
» 2237 │ bhB=$(awk -f tools/lib/timestamp.awk -f tools/lib/boot-hours.awk \
  2238 │         -v a="2026-02-28T22:00:00.000000+02:00" -v b="not-a-timestamp" </dev/null); bhBrc=$?
» 2239 │ bh0=$(awk -f tools/lib/timestamp.awk -f tools/lib/boot-hours.awk \
  2240 │         -v a="1970-01-01T00:00:00+00:00" -v b="1970-01-01T01:30:00+00:00" </dev/null)
» 2241 │ bh00=$(awk -f tools/lib/timestamp.awk -f tools/lib/boot-hours.awk \
  2242 │         -v a="1970-01-01T00:00:00+00:00" -v b="1970-01-01T00:00:00+00:00" </dev/null)
```
[lines 2394–2394](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2394-L2394)
```bash
  2393 │ # passed (devtools/mutate, 2026-09-29).
» 2394 │ if [[ -n "$ASIDE" && "$(cat "$ASIDE/state-before.txt" 2>/dev/null)" == old \
  2395 │       && -e "$LC/ev-set/evidence/trials/stock/trial-01/steps.log" \
```
[lines 2445–2445](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2445-L2445)
```bash
  2444 │     bad "closing a trial FAILED (rc=$rc):"
» 2445 │     tail -3 <<<"$out" | sed 's/^/      /'
  2446 │ fi
```
[lines 2502–2504](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2502-L2504)
```bash
  2501 │ if [[ -s "$LC/evidence/trials/results.tsv" ]]; then
» 2502 │     bs=$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)c[$i]=i;next} NR==2{print $c["bt1_status"]}' \
  2503 │          "$LC/evidence/trials/results.tsv")
» 2504 │     tr=$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)c[$i]=i;next} NR==2{print $c["trial_result"]}' \
  2505 │          "$LC/evidence/trials/results.tsv")
```
[lines 2521–2525](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2521-L2525)
```bash
  2520 │     case "$bs" in
» 2521 │         not_observed)
  2522 │             ok "bt1_status populated from evidence ($bs) — a readable, quiet journal" ;;
» 2523 │         unknown)
  2524 │             bad "bt1_status is 'unknown' with a readable journal — evidence collection failed (classifier ordered before collection?)" ;;
» 2525 │         *)  bad "bt1_status is '${bs:-empty}' from a quiet journal — expected not_observed" ;;
  2526 │     esac
```
[lines 2529–2529](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2529-L2529)
```bash
  2528 │     # stub, so a value any real machine could produce would mean it was not.
» 2529 │     kr=$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)c[$i]=i;next} NR==2{print $c["kernel"]}' \
  2530 │          "$LC/evidence/trials/results.tsv")
```
[lines 2535–2537](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2535-L2537)
```bash
  2534 │     case "$tr" in
» 2535 │         survived|failed|alive_after_intervention|aborted)
  2536 │             ok "trial_result populated from its domain ($tr)" ;;
» 2537 │         *)  bad "trial_result is '${tr:-empty}' — outside its domain" ;;
  2538 │     esac
```
[lines 2567–2567](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2567-L2567)
```bash
  2566 │ 
» 2567 │ hr=$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)c[$i]=i;next} END{print $c["trial_result"]}' \
  2568 │      "$LC/evidence/trials/results.tsv")
```
[lines 2654–2654](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2654-L2654)
```bash
  2653 │ 
» 2654 │ TMO_LINE='2026-08-13T01:00:00.000000+02:00 n kernel: Bluetooth: hci0: command tx timeout
  2655 │ '
```
[lines 2665–2665](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2665-L2665)
```bash
  2664 │ # the code happens to expect.
» 2665 │ TMO_OPCODE_LINE='2026-08-13T01:00:00.000000+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
  2666 │ '
```
[lines 2670–2674](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2670-L2674)
```bash
  2669 │ # into the BT-1 count.
» 2670 │ LINK_TMO_LINE='2026-08-13T01:00:00.000000+02:00 n kernel: Bluetooth: hci0: link tx timeout
  2671 │ '
» 2672 │ EARLY_LINE='EARLY intervention: 1 audio-teardown failure(s) in 90s
  2673 │ '
» 2674 │ LATE_LINE='Detected 6 controller timeouts within 60s - intervening.
  2675 │ '
```
[lines 2727–2727](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2727-L2727)
```bash
  2726 │ trial ok >/dev/null 2>&1
» 2727 │ ubs=$(awk -F"\t" 'NR==1{for(i=1;i<=NF;i++)c[$i]=i;next} END{print $c["bt1_status"]}' \
  2728 │       "$LC/evidence/trials/results.tsv" 2>/dev/null)
```
[lines 2773–2773](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2773-L2773)
```bash
  2772 │     trial ok >/dev/null 2>&1
» 2773 │     njs=$(awk -F"\t" 'NR==1{for(i=1;i<=NF;i++)c[$i]=i;next} END{print $c["bt1_status"]}' \
  2774 │           "$LC/evidence/trials/results.tsv" 2>/dev/null)
```
[lines 2828–2828](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L2828-L2828)
```bash
  2827 │     bad "slow-journal close: rc=$slowrc row (bt1_status sco_sent timeouts perturbed)='$SLOWROW'"
» 2828 │     while IFS= read -r l; do echo "        $l"; done <<<"$SLOWOUT"
  2829 │ fi
```
[lines 3089–3089](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3089-L3089)
```bash
  3088 │     bad "no-match close: rc=$nmrc row (bt1_status sco_sent timeouts perturbed)='$NMROW'"
» 3089 │     while IFS= read -r l; do echo "        $l"; done <<<"$NMOUT"
  3090 │ fi
```
[lines 3335–3335](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3335-L3335)
```bash
  3334 │     # exempts, not hidden in the checker.
» 3335 │     QGREP=$(grep -n -- '| *grep -q' "${SHFILES[@]}" 2>/dev/null \
  3336 │             | grep -v "^[^:]*:[0-9]*:[[:space:]]*#" \
```
[lines 3342–3342](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3342-L3342)
```bash
  3341 │         bad "grep -q at the end of a pipeline — inverted under pipefail:"
» 3342 │         while IFS= read -r l; do echo "        $l"; done <<<"$QGREP"
  3343 │     fi
```
[lines 3362–3362](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3362-L3362)
```bash
  3361 │ else
» 3362 │     ok "grep -q pipeline is not inverted on this shell — rule kept regardless"
  3363 │ fi
```
[lines 3381–3381](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3381-L3381)
```bash
  3380 │ # The live file is checked, not a fixture: the migration is the thing at risk.
» 3381 │ WIDTH=$(awk -F'\t' 'NR==1{n=NF; next} NF && NF!=n {print NR": "NF" vs "n}' \
  3382 │         evidence/trials/results.tsv 2>/dev/null)
```
[lines 3387–3387](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3387-L3387)
```bash
  3386 │     bad "results.tsv row/header width mismatch:"
» 3387 │     while IFS= read -r l; do echo "        line $l fields"; done <<<"$WIDTH"
  3388 │ fi
```
[lines 3458–3458](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3458-L3458)
```bash
  3457 │ # by --since, or by -n.
» 3458 │ UNBOUNDED=$(grep -n 'journalctl -k -b 0' tools/bt-trial \
  3459 │             | grep -v -- '--until' | grep -v -- '--since' | grep -v -- ' -n ' \
```
[lines 3465–3465](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3465-L3465)
```bash
  3464 │     bad "unbounded journalctl -k -b 0 in bt-trial — a slow close loses the row:"
» 3465 │     while IFS= read -r l; do echo "        $l"; done <<<"$UNBOUNDED"
  3466 │ fi
```
[lines 3512–3512](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3512-L3512)
```bash
  3511 │ else
» 3512 │     TAILSCAN=$(grep -nE '(bt_journal|journalctl)[^|]*\|[^|]*tail' "${TAILF[@]}" 2>/dev/null \
  3513 │                | grep -v -- ' -n ' | grep -vE '^[^:]*:[0-9]*:[[:space:]]*#')
```
[lines 3527–3527](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3527-L3527)
```bash
  3526 │ else
» 3527 │     KSCAN=$(grep -nE '(^|[^_[:alnum:]])bt_journal +-k +-b 0' "${SHFILES[@]}" 2>/dev/null \
  3528 │             | grep -v -- '--until' | grep -v -- '--since' | grep -v -- ' -n ' \
```
[lines 3535–3535](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3535-L3535)
```bash
  3534 │         bad "unbounded whole-boot kernel read outside bt_journal_count:"
» 3535 │         while IFS= read -r l; do bad "      $l"; done <<<"$KSCAN"
  3536 │     fi
```
[lines 3555–3561](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3555-L3561)
```bash
  3554 │         awk -v f="$f" '
» 3555 │             { while (/\\$/ && (getline nxt) > 0) { sub(/\\$/, "", $0); $0 = $0 nxt } }
» 3556 │             /^[[:space:]]*#/ { next }
» 3557 │             !/(^|[^_[:alnum:]])(bt_journal|journalctl)([[:space:]]|$)/ { next }
» 3558 │             /bt_journal_count/ { next }
» 3559 │             !(/[[:space:]]-b([[:space:]]|$)/ || /--boot/ || /\$\{[A-Za-z_][A-Za-z0-9_]*\[@\]\}/) { next }
» 3560 │             /--grep|[[:space:]]-g[[:space:]]|[[:space:]]-n[[:space:]0-9]|--lines|--since|[[:space:]]-S[[:space:]]|--until|[[:space:]]-U[[:space:]]|[[:space:]]-p[[:space:]]|--priority|--list-boots|\|[[:space:]]*head[[:space:]]/ { next }
» 3561 │             { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); gsub(/[[:space:]]+/, " "); print f "\t" $0 }' "$f"
  3562 │     done
```
[lines 3572–3575](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3572-L3575)
```bash
  3571 │ else
» 3572 │     [[ -n "$WBNEW" ]] && { bad "unbounded journal read(s) in the tools, not in tests/whole-boot-reads.txt (bound it, or list it with its reason):"
» 3573 │                            while IFS= read -r l; do bad "      $l"; done <<<"$WBNEW"; }
» 3574 │     [[ -n "$WBGONE" ]] && { bad "listed in tests/whole-boot-reads.txt, no longer in the tools (remove the line):"
» 3575 │                             while IFS= read -r l; do bad "      $l"; done <<<"$WBGONE"; }
  3576 │ fi
```
[lines 3638–3638](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3638-L3638)
```bash
  3637 │ # clean reset and a disconnect would be needed to close it.
» 3638 │ S2=$(awk -f tools/lib/timestamp.awk -f tools/lib/stage2.awk \
  3639 │      tests/stage2-invariants.data 2>&1)
```
[lines 3715–3715](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3715-L3715)
```bash
  3714 │ TT='tx timeout'
» 3715 │ STRAY=$(grep -nE "(grep|count|cnt)[^|#]*['\"][^'\"]*${TT}" "${SHFILES[@]}" 2>/dev/null \
  3716 │         | grep -vF "command( 0x[0-9a-f]+)? ${TT}" \
```
[lines 3722–3722](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3722-L3722)
```bash
  3721 │     bad "call sites spelling the timeout pattern differently:"
» 3722 │     while IFS= read -r l; do echo "        $l"; done <<<"$STRAY"
  3723 │ fi
```
[lines 3754–3754](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3754-L3754)
```bash
  3753 │ # udev rules, drop-ins written outside install_file, mode stamps).
» 3754 │ INSTALLED=$(awk '{ while (/\\$/ && (getline nxt) > 0) { sub(/\\$/, "", $0); $0 = $0 nxt } print }' \
  3755 │                 install.sh 2>/dev/null \
```
[lines 3767–3767](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3767-L3767)
```bash
  3766 │         bad "installed but never uninstalled:"
» 3767 │         while IFS= read -r l; do echo "        $l"; done <<<"$ORPHANS"
  3768 │     fi
```
[lines 3812–3812](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3812-L3812)
```bash
  3811 │     # the explanation of the defect as the defect.
» 3812 │     hit=$(sed -n '/^## Extraction method/,/^## Output/p' "$ex" \
  3813 │           | sed -n '/^```console/,/^```$/p' \
```
[lines 3821–3821](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3821-L3821)
```bash
  3820 │     bad "session-temporary paths in extraction commands:"
» 3821 │     while IFS= read -r l; do [[ -n "$l" ]] && echo "        $l"; done <<<"$EXBAD"
  3822 │ fi
```
[lines 3858–3858](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3858-L3858)
```bash
  3857 │         bad "fixture directory $libdir has no library $lib"
» 3858 │         continue
  3859 │     fi
```
[lines 3871–3871](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3871-L3871)
```bash
  3870 │                 bad "$(basename "$libdir")/DEPS names a missing library: $dep"
» 3871 │                 continue 2
  3872 │             fi
```
[lines 3883–3883](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3883-L3883)
```bash
  3882 │             bad "$(basename "$libdir")/$case_name: missing .expected or .rc"
» 3883 │             continue
  3884 │         fi
```
[lines 3892–3892](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3892-L3892)
```bash
  3891 │             bad "$(basename "$libdir")/$case_name (rc $got_rc, want $want_rc)"
» 3892 │             diff <(echo "$want") <(echo "$got") | head -8 | sed 's/^/        /'
  3893 │         fi
```
[lines 3980–3980](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3980-L3980)
```bash
  3979 │ # $EMPTYLIB, an empty library directory, is declared with the shared helpers.
» 3980 │ iv_out=$(BT_LIBDIR="$EMPTYLIB" tools/bt-interval \
  3981 │          2026-08-13T05:14:16.715095+02:00 2026-08-13T05:14:30.461003+02:00 2>&1); iv_rc=$?
```
[lines 3997–3997](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L3997-L3997)
```bash
  3996 │     bad "bt-stage2 --from failed (rc=$s2_rc):"
» 3997 │     tail -3 <<<"$S2W" | sed 's/^/      /'
  3998 │ fi
```
[lines 4050–4050](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4050-L4050)
```bash
  4049 │     bad "bt-boot-provenance failed (rc=$prov_rc):"
» 4050 │     tail -3 <<<"$PROV" | sed 's/^/      /'
  4051 │ fi
```
[lines 4235–4235](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4235-L4235)
```bash
  4234 │ # maintainer at the wrong command.
» 4235 │ [[ "$AAOUT" == *"HCI cmd 0x0428  Setup Synchronous Connection (SCO/HFP)"* \
  4236 │    && "$AAOUT" == *"HCI cmd 0x0406  Disconnect"* ]] \
```
[lines 4284–4284](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4284-L4284)
```bash
  4283 │ AAWITHOUT=$(cat "$AASPY/args" 2>/dev/null)
» 4284 │ [[ "$AAWITH" == *"--since 2026-08-13 10:00"* && "$AAWITH" == *"--until 2026-08-13 11:00"* \
  4285 │    && -n "$AAWITHOUT" && "$AAWITHOUT" != *--since* && "$AAWITHOUT" != *--until* ]] \
```
[lines 4304–4304](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4304-L4304)
```bash
  4303 │ mkdir -p "$AASPY/health/trace"; : > "$AASPY/health/trace/b.btsnoop"
» 4304 │ AADEF=$(env -u BT_TRACE_DIR PATH="$AASPY/bin:$PATH" BT_HEALTH_DIR="$AASPY/health" \
  4305 │         BT_JOURNAL_FIXTURE="$BA" tools/bt-actions --raw 2>&1)
```
[lines 4486–4486](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4486-L4486)
```bash
  4485 │ EOUT=$(wd_run 10 BT_EARLY=1)
» 4486 │ [[ "$EOUT" == *"EARLY intervention: 1 audio-teardown failure(s)"* \
  4487 │    && "$EOUT" == *"resetting BEFORE any HCI timeout"* ]] \
```
[lines 4496–4496](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4496-L4496)
```bash
  4495 │ # the log would again read as evidence that early intervention prevents BT-1.
» 4496 │ [[ "$EOUT" == *"CONTROLLER RESPONDS AFTER EARLY INTERVENTION"* \
  4497 │    && "$EOUT" == *"counterfactual censored"* ]] \
```
[lines 4532–4532](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4532-L4532)
```bash
  4531 │ NOPOUT=$(wd_until "suppressed by cooldown" 60 PATH="$WDNOP:$WD/noprobe-farm" BT_COOLDOWN=99999)
» 4532 │ [[ "$NOPOUT" == *"neither hciconfig nor btmgmt found"* \
  4533 │    && "$NOPOUT" == *"cannot be confirmed"* ]] \
```
[lines 4618–4618](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4618-L4618)
```bash
  4617 │ WBW1=$(wb_run "early window" "1000 1059 1059 1060" "$WB_HIT|$WB_HIT|$WB_HIT|$WB_EARLY" BT_THRESHOLD=3 BT_WINDOW=60 BT_COOLDOWN=0)
» 4618 │ [[ "$(wb_counts "$WBW")" == "1 1 2 " && "$WBW" != *"intervening"* \
  4619 │    && "$(wb_counts "$WBW1")" == "1 2 3 " && "$WBW1" == *"Detected 3 controller timeouts"* ]] \
```
[lines 4628–4628](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4628-L4628)
```bash
  4627 │ WBC1=$(wb_run "early window" "1000 1099 1100" "$WB_HIT|$WB_HIT|$WB_EARLY" BT_THRESHOLD=1 BT_COOLDOWN=100)
» 4628 │ [[ $(grep -c 'intervening' <<<"$WBC") == 2 && "$WBC" != *"suppressed by cooldown"* \
  4629 │    && $(grep -c 'intervening' <<<"$WBC1") == 1 && "$WBC1" == *"suppressed by cooldown (1s remaining)"* ]] \
```
[lines 4638–4638](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4638-L4638)
```bash
  4637 │ printf '%s\n' "$WB_HIT" "$WB_HIT" "$WB_HIT" "$WB_HIT" > "$WB/jrn/default.log"
» 4638 │ WBF=$(wd_until "Giving up" 80 PATH="$WB/bin:$WD/stub:$PATH" BT_JOURNAL_FIXTURE="$WB/jrn" \
  4639 │           BT_VERBOSE=1 BT_EARLY=1 BT_EARLY_THRESHOLD=99 BT_THRESHOLD=1 BT_COOLDOWN=0 BT_MAX_FAILS=2)
```
[lines 4650–4650](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4650-L4650)
```bash
  4649 │ WBE1=$(wb_run "  window: 1/99" "1000 1089 1090" "$WB_EARLY|$WB_EARLY|$WB_HIT" BT_THRESHOLD=99 BT_EARLY_THRESHOLD=2 BT_EARLY_WINDOW=90 BT_COOLDOWN=0)
» 4650 │ [[ "$WBE" == *"early window: 1/2"* && "$WBE" != *"early window: 2/2"* && "$WBE" != *"EARLY intervention"* \
  4651 │    && "$WBE1" == *"early window: 2/2"* && "$WBE1" == *"EARLY intervention"* ]] \
```
[lines 4695–4695](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4695-L4695)
```bash
  4694 │ EMPTYSYS=$(mktemp -d)
» 4695 │ FOUT=$(timeout 10 env PATH="$WD/stub:$PATH" \
  4696 │         BT_JOURNAL_FIXTURE=tests/journal/watchdog \
```
[lines 4718–4718](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4718-L4718)
```bash
  4717 │ WNS=$(sort -u "$WN/sudo.log" 2>/dev/null)
» 4718 │ [[ "$WNS" == "sudo -u $(id -un) DBUS_SESSION_BUS_ADDRESS=unix:path=$WN/run/$(id -u)/bus notify-send -u critical Bluetooth "*"absent from USB"* \
  4719 │    && $(grep -c . <<<"$WNS") == 1 ]] \
```
[lines 4736–4738](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4736-L4738)
```bash
  4735 │ : > "$WD/spy.log"; touch "$WD/dead"
» 4736 │ EGOUT=$(wd_until "cold power-off" 60 BT_EARLY=1 BT_MAX_FAILS=1 BT_COOLDOWN=0 \
  4737 │                  BT_JOURNAL_FIXTURE="$WDEG")
» 4738 │ [[ "$EGOUT" == *"EARLY intervention"* \
  4739 │    && "$EGOUT" == *"Giving up: 1 consecutive recovery attempts failed."* \
```
[lines 4761–4763](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4761-L4763)
```bash
  4760 │ WDEMPTYJ=$(mktemp -d)
» 4761 │ PYOUT=$(timeout 10 env PATH="$WDNOPY/stub:$WDNOPY/farm" BT_JOURNAL_FIXTURE="$WDEMPTYJ" \
  4762 │         BT_SYSFS_USB="$WD/sysfs" BT_SYSFS_DRIVERS="$WD/drv" bin/bt-hang-watchdog 2>&1)
» 4763 │ [[ "$PYOUT" == *"WARNING: python3 not found"* \
  4764 │    && "$PYOUT" == *"different treatment than documented"* ]] \
```
[lines 4919–4919](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4919-L4919)
```bash
  4918 │ BSOUT=$(BT_JOURNAL_FIXTURE="$BJ" BT_BOOT_LIST=tests/journal/boots/boot-list tools/bt-boot-stats 2>&1)
» 4919 │ [[ "$(awk '$1 == "-1" {print $5}' <<<"$BSOUT")" == "1" \
  4920 │    && "$(awk '$1 == "0" {print $5}' <<<"$BSOUT")" == "2" ]] \
```
[lines 4972–4972](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L4972-L4972)
```bash
  4971 │ HRMACH=(PATH="$HRBIN:$PATH" BT_SHARE_DIR="$HRSYS/share" BT_UNIT_DIR="$HRSYS/units")
» 4972 │ HROUT=$(env "${HRMACH[@]}" BT_JOURNAL_FIXTURE="$HR" BT_SYSFS_USB="$HRSYS/usb" BT_SYSFS_MODULE="$HRSYS/mod" \
  4973 │         BT_METRICS=/nonexistent tools/bt-health-report.sh 2>&1); hrrc=$?
```
[lines 5011–5011](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5011-L5011)
```bash
  5010 │ HRV1=$(hrv hr-none)
» 5011 │ [[ "$HRV1" == *"no watchdog intervention is recorded"* \
  5012 │    && "$HRV1" == *"does not imply that no timeout occurred"* ]] \
```
[lines 5025–5025](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5025-L5025)
```bash
  5024 │ # readings differ by exactly the counterfactual nobody has.
» 5025 │ [[ "$HRV2" == *"1 confirmed post-timeout HCI recovery event(s) recorded"* \
  5026 │    && "$HRV2" != *"VERDICT: WORKING"* ]] \
```
[lines 5039–5039](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5039-L5039)
```bash
  5038 │ hr_verdict=$(grep -m1 'VERDICT:' <<<"$HRV2L")
» 5039 │ [[ "$hr_verdict" == *"legacy RECOVERED marker(s) have mixed context"* \
  5040 │    && "$hr_verdict" != *"confirmed post-timeout"* ]] \
```
[lines 5057–5057](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5057-L5057)
```bash
  5056 │ # knob.
» 5057 │ [[ "$HRV4" == *"THIS BOOT and never"* && "$HRV4" == *"reset may itself alter the trajectory"* \
  5058 │    && "$HRV4" != *"BT_THRESHOLD"* ]] \
```
[lines 5065–5067](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5065-L5067)
```bash
  5064 │ HRM=$(mktemp)
» 5065 │ printf 'timestamp	tx_timeouts
» 5066 │ 2026-08-10T09:00:00	0
» 5067 │ 2026-08-10T09:05:00	2
  5068 │ ' > "$HRM"
```
[lines 5125–5125](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5125-L5125)
```bash
  5124 │ 
» 5125 │ HRV7=$(env "${HRMACH[@]}" BT_JOURNAL_FIXTURE=tests/journal/health BT_SYSFS_USB="$HRSYS/usb" \
  5126 │        BT_SYSFS_MODULE="$HRSYS/mod" BT_SYSFS_BT="$HRSYS/bt" BT_METRICS=/nonexistent \
```
[lines 5156–5156](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5156-L5156)
```bash
  5155 │ # works where the baseline was never installed tests the wrong machine.
» 5156 │ HRV8=$(env "${HRMACH[@]}" BT_JOURNAL_FIXTURE=tests/journal/health BT_SYSFS_USB="$HRNB/sys/usb" \
  5157 │        BT_SYSFS_MODULE="$HRNB/sys/mod" BT_SYSFS_BT="$HRNB/sys/bt" BT_METRICS=/nonexistent \
```
[lines 5209–5211](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5209-L5211)
```bash
  5208 │ PMSYS2=$(mktemp -d); mkdir -p "$PMSYS2/usb" "$PMSYS2/bt"
» 5209 │ PMOUT3=$(BT_JOURNAL_FIXTURE="$PM" BT_SYSFS_USB="$PMSYS2/usb" BT_SYSFS_BT="$PMSYS2/bt" \
  5210 │          tools/bt-postmortem 2>&1)
» 5211 │ [[ "$PMOUT3" == *"CONTROLLER IS DOWN RIGHT NOW"* && "$PMOUT3" == *"left the bus"* \
  5212 │    && "$PMOUT3" == *"POWER-OFF"* ]] \
```
[lines 5221–5221](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5221-L5221)
```bash
  5220 │ echo 13d3 > "$PMSYS2/usb/3-3/idVendor"; echo 3503 > "$PMSYS2/usb/3-3/idProduct"
» 5221 │ PMENUM=$(BT_JOURNAL_FIXTURE="$PM" BT_SYSFS_USB="$PMSYS2/usb" BT_SYSFS_BT="$PMSYS2/bt" \
  5222 │          tools/bt-postmortem 2>&1)
```
[lines 5239–5239](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5239-L5239)
```bash
  5238 │ PMEARLY=$(pmf pm-early)
» 5239 │ [[ "$PMEARLY" == *"answered after EARLY intervention"* \
  5240 │    && "$PMEARLY" == *"Early signal preceded the first timeout by 10s"* ]] \
```
[lines 5265–5265](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5265-L5265)
```bash
  5264 │ # window existed, so BT_EARLY could not have helped in this incident.
» 5265 │ [[ "$PMNR" == *"AFTER the first timeout"* \
  5266 │    && "$PMNR" == *"could not have helped"* \
```
[lines 5337–5337](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5337-L5337)
```bash
  5336 │ # Stage 2: nothing on the bus, no adapter.
» 5337 │ SOUT=$(PATH="$STBIN:$PATH" BT_REPO="$STREPO" BT_JOURNAL_FIXTURE="$ST" BT_SYSFS_USB="$STSYS/usb" BT_SYSFS_BT="$STSYS/bt" \
  5338 │        tools/bt-status 2>&1); src=$?
```
[lines 5349–5349](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5349-L5349)
```bash
  5348 │ # `bt-status && ...` got different behaviour from a DISPLAY flag.
» 5349 │ BRC=$(PATH="$STBIN:$PATH" BT_REPO="$STREPO" BT_JOURNAL_FIXTURE="$ST" BT_SYSFS_USB="$STSYS/usb" BT_SYSFS_BT="$STSYS/bt" \
  5350 │       tools/bt-status --brief >/dev/null 2>&1; echo $?)
```
[lines 5382–5382](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5382-L5382)
```bash
  5381 │ # go back to asserting more than has been observed.
» 5382 │ [[ "$SOUT" == *"Off the USB bus"* && "$SOUT" == *"full power-off is the demonstrated recovery"* \
  5383 │    && "$SOUT" == *"warm reboot is unresolved"* ]] \
```
[lines 5390–5390](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5390-L5390)
```bash
  5389 │ mkdir -p "$STSYS/usb/3-3"; echo 13d3 > "$STSYS/usb/3-3/idVendor"; echo 3503 > "$STSYS/usb/3-3/idProduct"
» 5390 │ SENUM=$(PATH="$STBIN:$PATH" BT_REPO="$STREPO" BT_JOURNAL_FIXTURE="$ST" BT_SYSFS_USB="$STSYS/usb" BT_SYSFS_BT="$STSYS/bt" \
  5391 │         tools/bt-status 2>&1)
```
[lines 5398–5398](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5398-L5398)
```bash
  5397 │ mkdir -p "$STSYS/bt/hci0"
» 5398 │ SOK=$(PATH="$STBIN:$PATH" BT_REPO="$STREPO" BT_JOURNAL_FIXTURE="$ST" BT_SYSFS_USB="$STSYS/usb" BT_SYSFS_BT="$STSYS/bt" \
  5399 │       tools/bt-status 2>&1)
```
[lines 5424–5424](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5424-L5424)
```bash
  5423 │ SVEOK=$(sv status-early-ok)
» 5424 │ [[ "$SVEOK" == *"CONTROLLER ANSWERED AFTER EARLY INTERVENTION"* \
  5425 │    && "$SVEOK" == *"no experiment has occupied"* ]] \
```
[lines 5454–5454](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5454-L5454)
```bash
  5453 │ SVCQ=$(sv status-clean-quiet)
» 5454 │ [[ "$SVCQ" == *"proves nothing if the trigger was never attempted"* \
  5455 │    && "$SVCQ" != *"real clean run"* ]] \
```
[lines 5463–5463](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5463-L5463)
```bash
  5462 │ printf 'gap 1\ngap 2\ngap 3\n' > "$STTR/gaps.log"
» 5463 │ SVTR=$(PATH="$STBIN:$PATH" BT_REPO="$STREPO" BT_JOURNAL_FIXTURE="$ST" BT_SYSFS_USB="$STSYS/usb" BT_SYSFS_BT="$STSYS/bt" \
  5464 │        BT_TRACE_DIR="$STTR" tools/bt-status 2>&1)
```
[lines 5470–5470](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5470-L5470)
```bash
  5469 │ 
» 5470 │ SVNOTR=$(PATH="$STBIN:$PATH" BT_REPO="$STREPO" BT_JOURNAL_FIXTURE="$ST" BT_SYSFS_USB="$STSYS/usb" BT_SYSFS_BT="$STSYS/bt" \
  5471 │          BT_TRACE_DIR=/nonexistent tools/bt-status 2>&1)
```
[lines 5478–5478](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5478-L5478)
```bash
  5477 │ # empty section, because it is run from anywhere and often from /.
» 5478 │ SVNOREPO=$(PATH="$STBIN:$PATH" BT_REPO="$STREPO" BT_JOURNAL_FIXTURE="$ST" BT_SYSFS_USB="$STSYS/usb" BT_SYSFS_BT="$STSYS/bt" \
  5479 │            BT_REPO=/nonexistent/checkout tools/bt-status 2>&1)
```
[lines 5505–5505](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5505-L5505)
```bash
  5504 │ WTV=$(cd "$WT/elsewhere" && "$W/tools/bt-verify-install" 2>&1)
» 5505 │ WTS=$(cd "$WT/elsewhere" && env -u BT_REPO PATH="$STBIN:$PATH" BT_JOURNAL_FIXTURE="$ST" \
  5506 │           BT_SYSFS_USB="$STSYS/usb" BT_SYSFS_BT="$STSYS/bt" "$W/tools/bt-status" 2>&1)
```
[lines 5612–5612](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5612-L5612)
```bash
  5611 │ # be able to overwrite an override. Matched on the shape that caused it.
» 5612 │ FALLBACK=$(grep -rnE '\|\|[[:space:]]*REPO=/' tools bin 2>/dev/null \
  5613 │            | grep -v 'BT_EVIDENCE_REPO' | grep -vE ':[0-9]+:[[:space:]]*#' || true)
```
[lines 5649–5649](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5649-L5649)
```bash
  5648 │     # output, or the reverse, is the hand-written exhibit this replaced.
» 5649 │     exp=$(exhibit new probe-one --claim "The probe emits its marker." \
  5650 │                   --why "Because the marker is unique to this run." \
```
[lines 5807–5807](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5807-L5807)
```bash
  5806 │     exhibit index >/dev/null 2>&1
» 5807 │     exwrap=$(grep -c 'names a BSSID, and this second line must reach the index cell\.' \
  5808 │              "$EXR/evidence/exhibits/README.md" 2>/dev/null)
```
[lines 5825–5825](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5825-L5825)
```bash
  5824 │     exhibit index >/dev/null 2>&1
» 5825 │     exhist=$(grep -c 'Historical claim: The probe emits its marker\.' \
  5826 │              "$EXR/evidence/exhibits/README.md" 2>/dev/null)
```
[lines 5833–5835](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5833-L5835)
```bash
  5832 │     # correct behaviour is to produce nothing, and that is worth asserting.
» 5833 │     exhibit new probe-one --claim "c" --cmd 'echo hi' >/dev/null 2>&1
» 5834 │     exrc=$?
» 5835 │     (( exrc != 0 )) && [[ ! -f "$EXR/evidence/exhibits/001-probe-one.md" ]] \
  5836 │         && ok "bt-exhibit writes no exhibit when the sanitiser cannot run" \
```
[lines 5897–5899](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L5897-L5899)
```bash
  5896 │     # bt-retention would actually compare against a boot range.
» 5897 │     exrt=$(bash -c '
» 5898 │         source tools/lib/evidence-window.sh
» 5899 │         payload=$(bt_ew_read "$1")
  5900 │         printf "%s|%s\n" "$payload" "$(bt_ew_earliest "$payload")"' _ "$EXWF")
```
[lines 6249–6249](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6249-L6249)
```bash
  6248 │ 
» 6249 │ [[ "$DGRES" == *"aggregate, unpaired, system-wide counts"* \
  6250 │    && "$DGRES" != *"driver_info = 0"* && "$DGRES" != *"did nothing about them"* ]] \
```
[lines 6267–6267](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6267-L6267)
```bash
  6266 │ # honest answer, and its exit code must not be confused with health.
» 6267 │ DGNONE=$(PATH="$DG/bin:$PATH" BT_JOURNAL_FIXTURE=tests/journal/diagnose-signature BT_SYSFS_USB="$DG/empty" \
  6268 │          tools/bt-diagnose 2>&1); dgnonerc=$?
```
[lines 6395–6397](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6395-L6397)
```bash
  6394 │ if (( EUID != 0 )); then
» 6395 │     if   [[ "$(unshare -r  id -u 2>/dev/null)" == 0 ]]; then BM_PRIV=(unshare -r)
» 6396 │     elif [[ "$(fakeroot -- id -u 2>/dev/null)" == 0 ]]; then BM_PRIV=(fakeroot --)
» 6397 │     else BM_CAN=0
  6398 │     fi
```
[lines 6414–6414](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6414-L6414)
```bash
  6413 │ 
» 6414 │ [[ -e "$BM/udev/50-bluetooth-no-autosuspend.rules" && ! -e "$BM/share/mode" \
  6415 │    && ! -s "$BM/spy.log" ]] \
```
[lines 6427–6427](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6427-L6427)
```bash
  6426 │     # reversible, and a deleted udev rule is not.
» 6427 │     [[ -e "$BM/udev/50-bluetooth-no-autosuspend.rules.disabled" \
  6428 │        && -e "$BM/udev/51-bluetooth-health-snapshot.rules.disabled" \
```
[lines 6443–6443](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6443-L6443)
```bash
  6442 │ 
» 6443 │     [[ "$(cat "$BM/mod/enable_autosuspend")" == "Y" \
  6444 │        && "$(cat "$BM/usb/3-3/power/control")" == "auto" ]] \
```
[lines 6465–6465](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6465-L6465)
```bash
  6464 │ 
» 6465 │     [[ "$(cat "$BM/mod/enable_autosuspend")" == "N" \
  6466 │        && "$(cat "$BM/usb/3-3/power/control")" == "on" ]] \
```
[lines 6494–6494](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6494-L6494)
```bash
  6493 │     # perform it.
» 6494 │     PRIV_SKIPPED="bt-mode round trip"
  6495 │ fi
```
[lines 6501–6501](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6501-L6501)
```bash
  6500 │     ok "bt-mode's seams held — all $BM_OVN real overrides in the state they started in"
» 6501 │ elif (( ${BM_OVN:-0} != 3 )); then
  6502 │     bad "the override state function reported $BM_OVN path(s), not 3 — check is blind"
```
[lines 6567–6567](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6567-L6567)
```bash
  6566 │ # of it and mean the opposite.
» 6567 │ [[ "$KMNEW" == *"13d3:3491  present"* && "$KMNEW" == *"13d3:3501  present"* \
  6568 │    && "$KMNEW" == *"13d3:3503  ABSENT"* ]] \
```
[lines 6587–6587](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6587-L6587)
```bash
  6586 │ chmod +x "$KMNOHEX/bin"/*
» 6587 │ KMBLIND=$(env PATH="$KMNOHEX/bin:$PATH" BT_MODULES_DIR="$KM/mods" \
  6588 │               tools/bt-verify-kernel-mechanism 7.0.0-test 2>&1)
```
[lines 6672–6672](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6672-L6672)
```bash
  6671 │ # and it is a row metrics.tsv must still be able to carry: absent, not crashed.
» 6672 │ BSGONE=$(env PATH="$BS/stub:$PATH" BT_SYSFS_USB="$BS/empty" BT_SYSFS_MODULE="$BS/mod" \
  6673 │              BT_JOURNAL_FIXTURE="$BS/jrn" tools/bt-state --tsv 2>&1); bsgrc=$?
```
[lines 6729–6729](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6729-L6729)
```bash
  6728 │ # exercised — which is what turned CI red on 6ca042e.
» 6729 │ BSMGOUT=$(env PATH="$BSMG/bin2:$BSMG/farm" \
  6730 │               BT_SYSFS_USB="$BS/usb" BT_SYSFS_MODULE="$BS/mod" \
```
[lines 6761–6761](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6761-L6761)
```bash
  6760 │ # minimum not break the run — and the fixture answers whatever is asked.
» 6761 │ AASINCE=$(BT_JOURNAL_FIXTURE=tests/journal/actions tools/bt-actions -b 0 \
  6762 │           --since "2026-08-13 00:00:00" --until "2026-08-14 00:00:00" 2>&1); aasrc=$?
```
[lines 6781–6781](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6781-L6781)
```bash
  6780 │ printf 'BEGIN { print "not-a-number"; exit 0 }\n' > "$IVLIB/interval.awk"
» 6781 │ IVOUT=$(BT_LIBDIR="$IVLIB" tools/bt-interval "2026-08-13T10:00:00+02:00" \
  6782 │                                              "2026-08-13T10:01:00+02:00" 2>&1); ivrc=$?
```
[lines 6874–6874](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6874-L6874)
```bash
  6873 │ # written as "-" or 0 by design, so an empty field is always a defect.
» 6874 │ hs_blank=$(awk -F'\t' 'NR==2 { for (i=1;i<=NF;i++) if ($i == "") { print i; exit } }' \
  6875 │            "$HS/metrics.tsv")
```
[lines 6952–6952](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L6952-L6952)
```bash
  6951 │ 
» 6952 │ [[ "$(hs_col dev_present)" == "1" && "$(hs_col hci_alive)" == "1" \
  6953 │    && "$(hs_col usb_power_ctrl)" == "on" && "$(hs_col btusb_autosusp)" == "N" ]] \
```
[lines 7240–7240](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L7240-L7240)
```bash
  7239 │ DDOFF=$(dd_run off)
» 7240 │ [[ "$DDOFF" == *"disabled debug in 12 file(s)"* \
  7241 │    && "$(grep -c ' -p$' "$DD/control")" == "12" ]] \
```
[lines 7296–7296](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L7296-L7296)
```bash
  7295 │ BTRC=$(mktemp -d)
» 7296 │ BTRCOUT=$(python3 tests/btmon/real/mkcap.py "$BTRC" 2>&1 && python3 - "$BTRC" <<'PYEOF'
  7297 │ import struct, sys, os
```
[lines 7347–7347](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L7347-L7347)
```bash
  7346 │ # parameterisation and not another looks random from the kernel log alone.
» 7347 │ [[ "$SCOUT" == *"REQUEST"* && "$SCOUT" == *"Voice setting: 0x0060"* \
  7348 │    && "$SCOUT" == *"COMPLETION"* && "$SCOUT" == *"Link type: eSCO"* ]] \
```
[lines 7370–7370](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L7370-L7370)
```bash
  7369 │ SCGONE=$(sco_run sco-unanswered)
» 7370 │ [[ "$SCGONE" == *"setup requests      2"* && "$SCGONE" == *"completion events   1"* \
  7371 │    && "$SCGONE" == *"1 request(s) received no completion event"* ]] \
```
[lines 7398–7398](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L7398-L7398)
```bash
  7397 │ SCW=$(sco_run sco-unanswered --window 2)
» 7398 │ [[ "$SCW" == *"09:14:22.101234"* && "$SCW" == *"09:31:44.002000"* \
  7399 │    && "$SCW" != *"Number of Completed Packets"* ]] \
```
[lines 7416–7416](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L7416-L7416)
```bash
  7415 │ 
» 7416 │ SCEMPTY=$(env PATH="$SC/stub:$PATH" BTMON_FIXTURE=/dev/null \
  7417 │               tools/bt-sco --dir "$SC/stub" 2>&1); scemprc=$?
```
[lines 7495–7495](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L7495-L7495)
```bash
  7494 │ : > "$CD/cap/x.btsnoop.txt"
» 7495 │ CDNONE=$(env PATH="$CD/stub:$PATH" BT_TRACE_DIR="$CD/trace" BT_CAPTURE_DIR="$CD/cap" \
  7496 │              tools/bt-capdiff 2>&1); cdnrc=$?
```
[lines 7620–7620](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L7620-L7620)
```bash
  7619 │     || bad "bt-ctrl-window's Command Complete / Command Status decoding (rc=$cwrc): $(grep -- '->' <<<"$CWO" | head -3 | tr '\n' '|')"
» 7620 │ [[ "$CWO" == *"06 00 81 0a 00 00  ->  New Settings: 0x00000a81"* && "$CWO" == *"11 00 07 01  ->  Discovering"* \
  7621 │    && "$CWO" == *"99 00 01  ->  event 0x0099"* && "$CWO" == *"23 00 07  ->  Start Discovery (0x0023)"* \
```
[lines 7625–7625](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L7625-L7625)
```bash
  7624 │     || bad "bt-ctrl-window's other records: $(grep -- '->' <<<"$CWO" | tail -5 | tr '\n' '|')"
» 7625 │ [[ "$CWO" == *"inside the window"* && "$CWO" != *"before the window"* && "$CWO" != *"after the window"* \
  7626 │    && "$CWO" != *"Set Powered"* && "$CWO" != *"06 00 01 00 00 00 00"* ]] \
```
[lines 7630–7630](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L7630-L7630)
```bash
  7629 │ CWH=$(cw_run 21:03:25 21:03:30 --hci)
» 7630 │ [[ "$CWO" != *"HCI"* && "$CWH" == *"< HCI Command: Inquiry"* && "$CWH" == *"> HCI Event: Inquiry Result"* \
  7631 │    && "$CWH" != *"LE Set Scan Enable"* ]] \
```
[lines 7877–7877](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L7877-L7877)
```bash
  7876 │ git -C "$EXF" init -q 2>/dev/null; touch "$EXF/install.sh"
» 7877 │ EXFOUT=$(BT_REPO="$EXF" "$EXF/tools/bt-exhibit" new failing-sanitiser \
  7878 │          --cmd 'echo hello' --claim 'x' --why 'y' 2>&1); exfrc=$?
```
[lines 7963–7963](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L7963-L7963)
```bash
  7962 │ 
» 7963 │ TRCHK=$(env PATH="$CP/stub:$PATH" BT_TRACE_DIR="$CP/trace" BT_TRACE_KEEP=3 \
  7964 │             bin/bt-trace --check 2>&1); trrc=$?
```
[lines 7978–7978](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L7978-L7978)
```bash
  7977 │ # the one thing --check exists to say out loud.
» 7978 │ TRNOBT=$(env PATH="$CP/dbg:/nonexistent" BT_TRACE_DIR="$CP/trace" \
  7979 │              bin/bt-trace --check 2>&1); trnrc=$?
```
[lines 7994–7994](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L7994-L7994)
```bash
  7993 │ # 2026-09-28) and on any laptop or runner whose disk is fuller than that.
» 7994 │ USCHK=$(env PATH="$CP/stub:$PATH" BT_USBMON_DIR="$CP/usb" BT_USBMON_KEEP=2 \
  7995 │             BT_USBMON_MIN_FREE_GB=0 \
```
[lines 8013–8013](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8013-L8013)
```bash
  8012 │ # ever removed, this hangs the suite, and a hang is the failure to catch.
» 8013 │ USGONE=$(timeout 20 env PATH="$CP/stub:$PATH" BT_USBMON_DIR="$CP/usb" \
  8014 │              BT_USBMON_MIN_FREE_GB=0 \
```
[lines 8068–8068](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8068-L8068)
```bash
  8067 │     # real call could hide in. Same convention as PIPEFAIL-DEMO above.
» 8068 │     RAW=$(grep -nE '(^|[^_[:alnum:]])journalctl ' "${CONVERTED[@]}" 2>/dev/null \
  8069 │           | grep -v 'SEAM-ADVICE' \
```
[lines 8076–8076](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8076-L8076)
```bash
  8075 │         bad "a converted tool bypassed bt_journal — it is untestable again:"
» 8076 │         while IFS= read -r l; do echo "        $l"; done <<<"$RAW"
  8077 │     fi
```
[lines 8095–8095](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8095-L8095)
```bash
  8094 │     ok "the coredump seam is in use by ${#CDCONV[@]} tool(s)"
» 8095 │     CDRAW=$(grep -nE '(^|[^_[:alnum:]])coredumpctl ' "${CDCONV[@]}" 2>/dev/null \
  8096 │             | grep -v 'SEAM-ADVICE' \
```
[lines 8103–8103](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8103-L8103)
```bash
  8102 │         bad "a converted tool bypassed bt_coredumpctl — it is untestable again:"
» 8103 │         while IFS= read -r l; do echo "        $l"; done <<<"$CDRAW"
  8104 │     fi
```
[lines 8139–8139](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8139-L8139)
```bash
  8138 │                 || UNSHIPPED="$UNSHIPPED $f -> $lib"
» 8139 │         done < <(grep -oE 'source "\$[A-Z_]*LIB[A-Z_]*/[a-z-]+\.sh"' "$f" | sed 's|.*/||; s|"||')
  8140 │     done
```
[lines 8145–8145](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8145-L8145)
```bash
  8144 │         bad "an installed tool sources a library install.sh does not ship:"
» 8145 │         for u in $UNSHIPPED; do echo "        $u"; done
  8146 │     fi
```
[lines 8181–8181](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8181-L8181)
```bash
  8180 │ chmod +x "$JG/bin/journalctl"
» 8181 │ JGCOUNT=$(cat <<'JGC'
  8182 │ source tools/lib/journal.sh
```
[lines 8254–8254](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8254-L8254)
```bash
  8253 │     || bad "trial-sco-decode's summary (rc=$tsdrc): $(tr '\n' '|' <<<"$tsdsum")"
» 8254 │ [[ $(grep -c '^< HCI Command: Setup Synchronous Connection (0x01|0x0028)' <<<"$TSDO") == 4 \
  8255 │    && $(grep -c '^< HCI Command: Enhanced Setup Synchronous Connection (0x01|0x003d)' <<<"$TSDO") == 1 \
```
[lines 8278–8278](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8278-L8278)
```bash
  8277 │ TSDW=$(tsd scripts/trial-sco-decode.py '2026-08-10 09:00:00' '2026-08-10 09:25:00')
» 8278 │ [[ "$TSDW" == *"09:14:22.101234"* && "$TSDW" != *"09:31:44"* && "$TSDW" == *"# capture: 1 setup command(s) decoded in the window"* \
  8279 │    && "$TSDW" == *"(no captures)"* ]] \
```
[lines 8333–8333](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8333-L8333)
```bash
  8332 │     bad "install.sh dry run failed (rc=$irc):"
» 8333 │     tail -3 <<<"$IOUT" | sed 's/^/      /'
  8334 │ fi
```
[lines 8345–8345](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8345-L8345)
```bash
  8344 │ 
» 8345 │ WROTE=$(find /usr/local /etc/systemd/system /etc/modprobe.d /etc/udev/rules.d \
  8346 │              -newer "$INSTALL_STAMP" -type f 2>/dev/null | head -5)
```
[lines 8370–8370](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8370-L8370)
```bash
  8369 │ IDEV=$(BT_VID=0cf3 BT_PID=e300 install_dry)
» 8370 │ [[ "$IDEV" == *"0cf3:e300"* && "$IDEV" == *"non-default device"* \
  8371 │    && "$IDEV" == *"10-device.conf (BT_VID=0cf3 BT_PID=e300)"* ]] \
```
[lines 8472–8472](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8472-L8472)
```bash
  8471 │     while (( i < $3 )); do grep -q "$2" "$1" 2>/dev/null && return 0; sleep 0.1; i=$((i+1)); done
» 8472 │     return 1
  8473 │ }
```
[lines 8779–8779](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8779-L8779)
```bash
  8778 │ if kill -0 "$TRPID" 2>/dev/null; then
» 8779 │     kill -9 "$TRPID" 2>/dev/null
  8780 │     bad "a floor-stopped bt-trace ignored SIGTERM — systemctl stop would time out"
```
[lines 8832–8832](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8832-L8832)
```bash
  8831 │         > "$BC/frames.bin"
» 8832 │     BCLOG=$(BT_CAPTURE_DIR="$BC/cap" BT_CAPTURE_SOURCE="$BC/frames.bin" \
  8833 │             python3 bin/bt-capture --duration 1 --min-free-gb 0 2>&1); bcrc=$?
```
[lines 8883–8883](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8883-L8883)
```bash
  8882 │     rm -f "$BC/cap"/*.btsnoop
» 8883 │     BCROT=$(BT_CAPTURE_DIR="$BC/cap" BT_CAPTURE_SOURCE="$BC/frames.bin" \
  8884 │             python3 bin/bt-capture --duration 1 --min-free-gb 0 --max-mb 0 2>&1)
```
[lines 8920–8920](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L8920-L8920)
```bash
  8919 │     # and on the message.
» 8920 │     BCFLOOR=$(BT_CAPTURE_DIR="$BC/cap" python3 bin/bt-capture --prune-only \
  8921 │               --keep 99 --min-free-gb 999999 2>&1); bcfrc=$?
```
[lines 9326–9328](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L9326-L9328)
```bash
  9325 │ }
» 9326 │ TLRK=$(tlpert '2026-08-13T09:00:00.000000+0200 host kernel: usb 3-3: new full-speed USB device number 2 using xhci_hcd
» 9327 │ 2026-08-13T09:00:10.000000+0200 host kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
» 9328 │ 2026-08-13T09:00:20.000000+0200 host kernel: Bluetooth: MGMT ver 1.22
  9329 │ ')
```
[lines 9334–9334](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L9334-L9334)
```bash
  9333 │ 
» 9334 │ TLRW=$(tlpert '2026-08-13T09:00:10.000000+0200 host kernel: Bluetooth: hci0: Resetting usb device
  9335 │ ')
```
[lines 9342–9343](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L9342-L9343)
```bash
  9341 │ # a window can carry both — the row has to say so rather than pick one.
» 9342 │ TLRB=$(tlpert '2026-08-13T09:00:10.000000+0200 host kernel: usbcore: deregistering interface driver btusb
» 9343 │ 2026-08-13T09:00:15.000000+0200 host kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  9344 │ ')
```
[lines 9352–9353](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L9352-L9353)
```bash
  9351 │ # detector fires, not that it discriminates.
» 9352 │ TLRN=$(tlpert '2026-08-13T09:00:00.000000+0200 host kernel: Bluetooth: hci0: command 0x0406 tx timeout
» 9353 │ 2026-08-13T09:00:20.000000+0200 host kernel: Bluetooth: MGMT ver 1.22
  9354 │ ')
```
[lines 9461–9470](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L9461-L9470)
```bash
  9460 │       awk -v h="$(head -1 evidence/trials/results.tsv)" -v p="$1" 'BEGIN {
» 9461 │         n = split(h, c, "\t"); for (i = 1; i <= n; i++) f[i] = "-"
» 9462 │         for (i = 1; i <= n; i++) {
» 9463 │             if      (c[i] == "timestamp")   f[i] = "2026-08-14T21:16:56+02:00"
» 9464 │             else if (c[i] == "duration_s")  f[i] = 10000
» 9465 │             else if (c[i] == "perturbed")   f[i] = p
» 9466 │             else if (c[i] == "bt1_status")  f[i] = "confirmed"
» 9467 │             else if (c[i] == "trial_result") f[i] = "failed"
» 9468 │             else if (c[i] == "treatment")   f[i] = "probes=off"
  9469 │         }
» 9470 │         s = f[1]; for (i = 2; i <= n; i++) s = s "\t" f[i]; print s }'
  9471 │     } > "$d/evidence/trials/results.tsv"
```
[lines 9602–9602](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L9602-L9602)
```bash
  9601 │     bad "bt-trial-audit scans a window through a pipe — cost grows with the window it audits:"
» 9602 │     while IFS= read -r l; do bad "      journalctl $l"; done < <(grep -- '--since' "$TAS/calls.log" | grep -v -- '--grep')
  9603 │ fi
```
[lines 9720–9720](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L9720-L9720)
```bash
  9719 │     bad "bt-retention mis-sorted the exhibits (rc=$rtrc):"
» 9720 │     while IFS= read -r l; do bad "      $l"; done < <(grep -E 'GONE|AT RISK|retained|judgeable' <<<"$RTOUT")
  9721 │ fi
```
[lines 9830–9830](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L9830-L9830)
```bash
  9829 │ RTA=$(BT_JOURNAL_FIXTURE=tests/journal/retention BT_EVIDENCE_REPO="$RT" tools/bt-retention --at-risk 2>&1)
» 9830 │ if [[ -n "$(rt_line "$RTA" 024-risk)" && -z "$(rt_line "$RTA" 025-kept)" \
  9831 │    && -z "$(rt_line "$RTA" 016-gone)" && -z "$(rt_line "$RTA" 018-bare)" ]]; then
```
[lines 9835–9835](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L9835-L9835)
```bash
  9834 │     bad "--at-risk did not narrow to the oldest retained boot:"
» 9835 │     while IFS= read -r l; do bad "      $l"; done < <(grep -E 'GONE|AT RISK|retained|judgeable' <<<"$RTA")
  9836 │ fi
```
[lines 9896–9896](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L9896-L9896)
```bash
  9895 │     bad "the declared window was ignored or misread (rc=$rtdrc):"
» 9896 │     while IFS= read -r l; do bad "      $l"; done < <(grep -E 'declared|GONE|retained|judgeable' <<<"$RTDO")
  9897 │ fi
```
[lines 9919–9919](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L9919-L9919)
```bash
  9918 │ RTDB=$(BT_JOURNAL_FIXTURE=tests/journal/retention BT_EVIDENCE_REPO="$RTD" tools/bt-retention 2>&1)
» 9919 │ [[ "$(rt_line "$RTDB" 043-window-in-provenance)" == *"retained"* \
  9920 │    && "$(rt_line "$RTDB" 043-window-in-provenance)" != *"declared"* ]] \
```
[lines 9948–9948](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L9948-L9948)
```bash
  9947 │     bad "the two boot-range parsers disagree:"
» 9948 │     while IFS= read -r l; do bad "      $l"; done < <(diff <(echo "$RTJ") <(echo "$RTT") | head -8)
  9949 │ fi
```
[lines 10006–10006](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L10006-L10006)
```bash
 10005 │ ARD=$(mktemp -d)
»10006 │ ARTO=$(BT_JOURNAL_FIXTURE=tests/journal/archive BT_ARCHIVE_DIR="$ARD" \
 10007 │        BT_ARCHIVE_COMP="$ARTRUNC/losing-comp" BT_ARCHIVE_EXT=gz BT_ARCHIVE_DECOMP='gzip -dc' \
```
[lines 10234–10234](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L10234-L10234)
```bash
 10233 │     bad "the archiver was driven wrongly (rc=$bkjrc, $(bkj_calls "$BKJ") call(s)):"
»10234 │     while IFS= read -r l; do bad "      $l"; done < <(head -6 "$BKJ/calls.log" 2>/dev/null)
 10235 │ fi
```
[lines 10383–10383](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L10383-L10383)
```bash
 10382 │ BKJE=$(bkj_setup); BKJEF=$(mktemp -d); : > "$BKJEF/list-boots.log"
»10383 │ BKJEOUT=$(BT_JOURNAL_FIXTURE="$BKJEF" BT_ARCHIVE_BIN="$BKJE/bin/bt-archive" \
 10384 │           BT_ARCHIVE_DIR="$BKJE/dest" tools/bt-backup-journal 2>&1); berc=$?
```
[lines 10395–10395](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L10395-L10395)
```bash
 10394 │ BKJN=$(bkj_setup)
»10395 │ BKJNOUT=$(BT_JOURNAL_FIXTURE="$BKJ_FIX" BT_ARCHIVE_BIN="$BKJN/bin/not-there" \
 10396 │           BT_ARCHIVE_DIR="$BKJN/dest" tools/bt-backup-journal 2>&1); bnrc=$?
```
[lines 10442–10443](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L10442-L10443)
```bash
 10441 │     # A runner without zstd can still drive the first refusal, and must.
»10442 │     JFZ=$(jf_run "$JF/src" "$JF/dst"); jfzrc=$?
»10443 │     (( jfzrc == 2 )) && [[ "$JFZ" == *"REFUSING"*"zstd not found"* ]] \
 10444 │         && ok "bt-journal-files refuses without zstd (zstd absent here: the copy cases did not run)" \
```
[lines 10612–10612](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L10612-L10612)
```bash
 10611 │ # and this fails on the count, the anchor, or both.
»10612 │ [[ "$SNOUT" == *"command timeouts        3"* \
 10613 │    && "$SNOUT" == *"first timeout      2026-08-16T21:42:44.918327+0200"* ]] \
```
[lines 10747–10747](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L10747-L10747)
```bash
 10746 │ SNOF=$(mktemp -d); mkdir -p "$SNOF/repo"
»10747 │ SNOFO=$(BT_JOURNAL_FIXTURE=tests/journal/snapshot-otherfail BT_SNAPSHOT_DIR="$SNOF/snap" \
 10748 │         BT_REPO="$SNOF/repo" tools/bt-snapshot 2>&1); snofrc=$?
```
[lines 10823–10823](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L10823-L10823)
```bash
 10822 │ # reading it as "the patches did nothing".
»10823 │ SNGZ=$(BT_JOURNAL_FIXTURE=tests/journal/snapshot-bluez BT_SNAPSHOT_DIR="$SNG/z" \
 10824 │        BT_REPO="$SNG/repo" tools/bt-snapshot 2>&1)
```
[lines 10955–10955](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L10955-L10955)
```bash
 10954 │ SNBZ=$(mktemp -d); mkdir -p "$SNBZ/repo"
»10955 │ SNBU=$(BT_JOURNAL_FIXTURE="$SNF" BT_SNAPSHOT_DIR="$SNBZ/snap" BT_REPO="$SNBZ/repo" \
 10956 │        tools/bt-snapshot 2>&1); snburc=$?
```
[lines 11008–11008](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11008-L11008)
```bash
 11007 │ SN=$(mktemp -d); mkdir -p "$SN/repo" "$SN/emptyfix"; : > "$SN/emptyfix/default.log"
»11008 │ SNE=$(BT_JOURNAL_FIXTURE="$SN/emptyfix" BT_SNAPSHOT_DIR="$SN/snap" BT_REPO="$SN/repo" \
 11009 │       tools/bt-snapshot 2>&1); snerc=$?
```
[lines 11022–11022](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11022-L11022)
```bash
 11021 │ SN=$(mktemp -d); mkdir -p "$SN/repo/inside"
»11022 │ SNIN=$(BT_JOURNAL_FIXTURE="$SNF" BT_SNAPSHOT_DIR="$SN/repo/inside" BT_REPO="$SN/repo" \
 11023 │        tools/bt-snapshot 2>&1); sninrc=$?
```
[lines 11029–11029](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11029-L11029)
```bash
 11028 │ ln -s "$SN/repo/inside" "$SN/link-to-inside"
»11029 │ SNLNK=$(BT_JOURNAL_FIXTURE="$SNF" BT_SNAPSHOT_DIR="$SN/link-to-inside" BT_REPO="$SN/repo" \
 11030 │         tools/bt-snapshot 2>&1); snlrc=$?
```
[lines 11050–11050](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11050-L11050)
```bash
 11049 │ # `busctl` added later for convenience fails here rather than in a window.
»11050 │ SNTOUCH=$(grep -nE '(hciconfig|btmgmt|bluetoothctl|rfkill|busctl|dbus-send|dbus-monitor|gdbus)' tools/bt-snapshot \
 11051 │           | grep -vE '^[0-9]+:[[:space:]]*#' || true)
```
[lines 11084–11084](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11084-L11084)
```bash
 11083 │ ARL=$(mktemp -d); mkdir -p "$ARL/dest" "$ARL/repo"
»11084 │ ARLOUT=$(BT_JOURNAL_FIXTURE=tests/journal/archive BT_ARCHIVE_DIR="$ARL/dest" \
 11085 │          BT_REPO="$ARL/repo" tools/bt-archive --list 2>&1); arlrc=$?
```
[lines 11127–11127](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11127-L11127)
```bash
 11126 │ CR0=$(cr_run tests/coredump/held); cr0rc=$?
»11127 │ [[ "$CR0" == *"crashes at the SAME offset 367e5 in bluetoothd"* \
 11128 │    && "$CR0" == *"2 crashes at the SAME"* ]] \
```
[lines 11142–11142](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11142-L11142)
```bash
 11141 │ CR2=$(cr_run tests/coredump/held --boot -2)
»11142 │ [[ "$CR2" == *"2 crashes at the SAME offset ade55 in libc.so.6"* \
 11143 │    && "$CR2" != *"offset 367e5"* ]] \
```
[lines 11199–11199](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11199-L11199)
```bash
 11198 │ # on the pid. This is also what pins PID to whitespace field 5 of a `list` row.
»11199 │ [[ "$CR0" == *"Newest bluetoothd stack (pid 313564)"* \
 11200 │    && "$CR0" == *"0x000060ff12be87e5"* && "$CR0" != *"0x00005c48db1977e5"* ]] \
```
[lines 11222–11222](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11222-L11222)
```bash
 11221 │ printf '2026-08-20T09:00:00+0200 n systemd[1]: Started bluetooth.service.\n' > "$CRQUIET/default.log"
»11222 │ CRQ=$(BT_JOURNAL_FIXTURE="$CRQUIET" BT_COREDUMP_FIXTURE=tests/coredump/nonbt \
 11223 │       tools/bt-crash 2>&1); crqrc=$?
```
[lines 11278–11278](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11278-L11278)
```bash
 11277 │ # source, because no fixture can prove the absence of a call that is not made.
»11278 │ CRTOUCH=$(grep -nE '(hciconfig|btmgmt|bluetoothctl|rfkill)' tools/bt-crash \
 11279 │           | grep -vE '^[0-9]+:[[:space:]]*#' || true)
```
[lines 11319–11319](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11319-L11319)
```bash
 11318 │ if PATH="$SUITE_ORIG_PATH" command -v coredumpctl >/dev/null 2>&1; then
»11319 │     CDREAL=$(real_tool coredump-contract coredumpctl list --no-pager 2>/dev/null || true)
 11320 │ fi
```
[lines 11325–11326](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11325-L11326)
```bash
 11324 │ else
»11325 │     CDHEAD=$(head -1 <<<"$CDREAL")
»11326 │     [[ "$CDHEAD" == TIME* && "$CDHEAD" == *PID* && "$CDHEAD" == *SIG* ]] \
 11327 │         && ok "real coredumpctl list prints the header row the fixture carries" \
```
[lines 11331–11332](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11331-L11332)
```bash
 11330 │     # The same awk field bt-crash takes the pid from, against the real tool.
»11331 │     CDPID=$(awk 'NR > 1 && $5 ~ /^[0-9]+$/ { print $5; exit }' <<<"$CDREAL")
»11332 │     [[ -n "$CDPID" ]] \
 11333 │         && ok "PID is whitespace field 5 of a real coredumpctl list row" \
```
[lines 11336–11340](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11336-L11340)
```bash
 11335 │ 
»11336 │     CDINFO=$(real_tool coredump-contract coredumpctl info "$CDPID" --no-pager 2>/dev/null || true)
»11337 │     if [[ "$CDINFO" == *"Stack trace of thread"* ]]; then
»11338 │         ok "real coredumpctl info carries the 'Stack trace of thread' line the fixture claims"
»11339 │     elif [[ -z "$CDINFO" ]]; then
»11340 │         COREDUMP_SKIPPED="the coredumpctl info contract (core for pid $CDPID no longer readable)"
 11341 │     else
```
[lines 11385–11385](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11385-L11385)
```bash
 11384 │ TLSP=$(tl status)
»11385 │ [[ "$TLSP" == *"PERTURBED"* && "$TLSP" == *"btusb reloads=1"* \
 11386 │    && "$TLSP" == *"bt-trial abort"* ]] \
```
[lines 11505–11505](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11505-L11505)
```bash
 11504 │     || bad "the close dropped the enhanced setup: $(grep -c . <<<"$TLSP") line(s) in sco-params.txt"
»11505 │ [[ $(grep -cE '^        (Handle: 256|Link type: eSCO \(0x02\))$' <<<"$TLSP") == 2 \
 11506 │    && "$TLSP" != *"a year"* && "$TLSP" != *"Link type: late"* && "$TLSP" != *"unrelated"* ]] \
```
[lines 11833–11834](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11833-L11834)
```bash
 11832 │ if command -v dbus-daemon >/dev/null 2>&1 && python3 -c 'import gi; gi.require_version("Gio", "2.0")' 2>/dev/null; then
»11833 │     mkdir -p "$UIT/bus"
»11834 │     cat > "$UIT/bus.conf" <<EOF
 11835 │ <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
```
[lines 11849–11852](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11849-L11852)
```bash
 11848 │ EOF
»11849 │     uibus=$(dbus-daemon --config-file="$UIT/bus.conf" --fork --print-address=1 --print-pid=1 2>/dev/null)
»11850 │     uiaddr=$(sed -n 1p <<<"$uibus"); UIBUSPID=$(sed -n 2p <<<"$uibus")
»11851 │     printf '%s' "$uiaddr" > "$UISTATE/bus-address"
»11852 │     cat > "$UIT/emitter.py" <<'PYEOF'
 11853 │ import ctypes, sys
```
[lines 11891–11896](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11891-L11896)
```bash
 11890 │ PYEOF
»11891 │     UIAD="$UIT/atspi"; mkdir -p "$UIAD/bin"; cp scripts/bt-ui-atspi.py "$UIAD/bin/"
»11892 │     ui BT_UI_USER=prove-user BT_UI_MAX_BYTES=4000 BT_UI_KEEP=2 -- _monitor atspi "$UIAD" >/dev/null 2>&1 &
»11893 │     UIMON=$!
»11894 │     for _ in $(seq 1 50); do
»11895 │         [[ "$(uic 'bt-ui-atspi start' "$UIAD/atspi.log")" -gt 0 ]] && break
»11896 │         sleep 0.1
 11897 │     done
```
[lines 11902–11920](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11902-L11920)
```bash
 11901 │     # audit, 2026-10-09).
»11902 │     uirec=$(sed -n 's/.*bt-ui-atspi start pid=\([0-9][0-9]*\).*/\1/p' "$UIAD/atspi.log" 2>/dev/null | head -1)
 11903 │     # The application first, then a bystander emitting a state the application
 11904 │     # never does, LAST, so that rotation could not discard the evidence.
»11905 │     python3 "$UIT/emitter.py" "$uiaddr" 120 gnome-control-c showing
»11906 │     python3 "$UIT/emitter.py" "$uiaddr" 5 bystander focused
»11907 │     sleep 1
»11908 │     kill "${uirec:-$UIMON}" 2>/dev/null     # no start line: the monitor itself, and the orphan scan names the rest
»11909 │     wait "$UIMON" 2>/dev/null
»11910 │     cat "$UIAD"/atspi.log* > "$UIT/atspi.all" 2>/dev/null
»11911 │     uinf=$(find "$UIAD" -maxdepth 1 -name 'atspi.log*' | wc -l)
»11912 │     uibig=$(find "$UIAD" -maxdepth 1 -name 'atspi.log*' -size +8k | wc -l)
»11913 │     uiok "the AT-SPI recorder names the widget and its parent on every event it records" \
 11914 │         uieq "$(uic "object:state-changed:showing v1=1 role=panel name='Configuration' parent='Output'" "$UIT/atspi.all")" \
 11915 │              "$(uic 'object:state-changed:showing v1=1 ' "$UIT/atspi.all")"
»11916 │     uiok "the AT-SPI recorder keeps the application's events and drops a bystander's and BoundsChanged" \
 11917 │         test "$(uic 'object:state-changed:showing' "$UIT/atspi.all")" -gt 0 \
 11918 │              -a "$(uic 'state-changed:focused' "$UIT/atspi.all")" -eq 0 -a "$(uic 'BoundsChanged|bounds-changed' "$UIT/atspi.all")" -eq 0
»11919 │     uiok "the AT-SPI monitor rotated and stayed bounded" test "$uinf" -ge 2 -a "$uinf" -le 3 -a "$uibig" -eq 0
»11920 │     kill "$UIBUSPID" 2>/dev/null
 11921 │ else
```
[lines 11983–11991](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11983-L11991)
```bash
 11982 │     unshare -Urm bash -c '
»11983 │         set -e
»11984 │         mount -t tmpfs bt-ui-world /var/log
»11985 │         mount -t tmpfs bt-ui-world /sys/kernel/debug
»11986 │         mount -t tmpfs bt-ui-world /usr/share/applications
»11987 │         mkdir -p /var/log/bt-health/ui /sys/kernel/debug/dynamic_debug
»11988 │         cp "$1/control.orig" /sys/kernel/debug/dynamic_debug/control
»11989 │         cp "$1"/apps/*.desktop /usr/share/applications/
»11990 │         set +e
»11991 │         eval "$2"' ui-world "$UIT" "$1"
 11992 │ }
```
[lines 11995–11999](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L11995-L11999)
```bash
 11994 │ if unshare -Urm true 2>/dev/null && [[ -d /var/log && -d /sys/kernel/debug && -d /usr/share/applications ]]; then
»11995 │     uiproof=$(ui_world "
»11996 │         echo $UIMARK > /var/log/bt-health/ui/$UIMARK
»11997 │         echo $UIMARK > /sys/kernel/debug/dynamic_debug/$UIMARK
»11998 │         echo $UIMARK > /usr/share/applications/$UIMARK.desktop
»11999 │         echo \"uid=\$(id -u) log=\$(cat /var/log/bt-health/ui/$UIMARK) dbg=\$(cat /sys/kernel/debug/dynamic_debug/$UIMARK) app=\$(cat /usr/share/applications/$UIMARK.desktop)\"
 12000 │     " 2>&1)
```
[lines 12007–12019](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12007-L12019)
```bash
 12006 │         ok "the namespace world proves itself: root inside, its markers inside, none on the machine"
»12007 │         UIDEF=$(ui_world "
»12008 │             export PATH='$UIT/stub':\"\$PATH\" PROVE_CALLS='$UICALLS' PROVE_STATE='$UISTATE'
»12009 │             export BT_UI_HOME='$UIT/home-ns' BT_UI_UID=4242 BT_UI_GID=4242 BT_UI_REPO='$UIT/repo' BT_UI_MARK='$UIT/repo/bin/bt-mark'
»12010 │             export BT_UI_CAPTURE_DIRS='$UIT/cap/capture $UIT/cap/trace' BT_JOURNAL_FIXTURE='$UIT/fixture'
»12011 │             unset BT_UI_BASE BT_DYNDBG_CTL BT_UI_APPDIR BT_UI_EUID BT_UI_USER
»12012 │             echo 2 > '$UISTATE/pw-level'
»12013 │             tools/bt-ui-capture start >/dev/null 2>&1; echo \"start=\$?\"
»12014 │             echo \"session=\$(cat /var/log/bt-health/ui/current)\"
»12015 │             echo \"on=\$(grep -cE '^module bluetooth func .* \\+p\$' /sys/kernel/debug/dynamic_debug/control)\"
»12016 │             echo \"override=\$(grep -c '^# bt-ui-capture' '$UIT/home-ns/.local/share/applications/gnome-sound-panel.desktop')\"
»12017 │             tools/bt-ui-capture stop >/dev/null 2>&1; echo \"stop=\$?\"
»12018 │             echo \"off=\$(grep -cE '^module bluetooth func .* -p\$' /sys/kernel/debug/dynamic_debug/control)\"
»12019 │             echo \"pointer=\$([ -e /var/log/bt-health/ui/current ] && echo left || echo cleared)\"
 12020 │         " 2>&1)
```
[lines 12055–12074](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12055-L12074)
```bash
 12054 │     co_setup
»12055 │     COH=$(co_world "$COSETUP
»12056 │         echo '== status'; devtools/held status 2>&1; echo \"rc=\$?\"
»12057 │         git push -q origin kernel/mgmt-flush-status:refs/heads/kernel/leak 2>/dev/null
»12058 │         echo '== leak'; devtools/held status 2>&1; echo \"rc=\$?\"
»12059 │         git push -q origin :refs/heads/kernel/leak 2>/dev/null
»12060 │         echo '== edit'; devtools/held edit 2>&1; echo \"rc=\$? branch=\$(git branch --show-current)\"
»12061 │         printf 'edited\n' >> held-world.patch
»12062 │         printf 'held: an edit\n' > '$COW/held-msg'
»12063 │         echo '== commit'; devtools/held commit '$COW/held-msg' > '$COW/held-commit.out' 2>&1; echo \"rc=\$? branch=\$(git branch --show-current)\"
»12064 │         echo \"private-has-edit=\$(git --git-dir=\$B/private.git log --format=%s kernel/mgmt-flush-status 2>/dev/null | grep -c 'held: an edit')\"
»12065 │         echo \"origin-kernel-heads=\$(git --git-dir=\$B/origin.git for-each-ref refs/heads/kernel | grep -c .)\"
»12066 │         echo dirty >> BRIEF.md
»12067 │         echo '== dirty'; devtools/held edit 2>&1; echo \"rc=\$?\"
»12068 │         git checkout -q -- BRIEF.md
»12069 │         echo '== usage'; devtools/held frobnicate >/dev/null 2>&1; echo \"rc=\$?\"
 12070 │         # origin rewritten to a repository that does not exist: unreachable
 12071 │         # without a resolver lookup of the real name (the machine's /etc/hosts).
»12072 │         echo '== offline'; GIT_CONFIG_KEY_0=\"url.\$B/unreachable.git.insteadOf\" devtools/held status 2>&1; echo \"rc=\$?\"
 12073 │     " 2>&1)
»12074 │     [[ "$(co_sect status <<<"$COH")" == *"origin carries no kernel/* branch ✓"* \
 12075 │        && "$(co_sect status <<<"$COH")" == *"held branch is 1 commit(s) ahead of main, 0 behind"* \
```
[lines 12088–12088](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12088-L12088)
```bash
 12087 │         || bad "held commit: $(co_sect commit <<<"$COH" | tr '\n' '|') $(grep -E '^(private-has-edit|origin-kernel-heads)=' <<<"$COH" | tr '\n' ' ') — repo-save said: $(tail -6 "$COW/held-commit.out" 2>/dev/null | tr '\n' '|')"
»12088 │     [[ "$(co_sect dirty <<<"$COH")" == *"working tree not clean"* && "$(co_sect dirty <<<"$COH")" == *"rc=1"* \
 12089 │        && "$(co_sect usage <<<"$COH")" == *"rc=2"* ]] \
```
[lines 12092–12092](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12092-L12092)
```bash
 12091 │         || bad "held dirty/usage: $(co_sect dirty <<<"$COH" | tr '\n' '|') $(co_sect usage <<<"$COH" | tr '\n' '|')"
»12092 │     [[ "$(co_sect offline <<<"$COH")" == *"cannot reach origin"*"NOT checked"* && "$(co_sect offline <<<"$COH")" == *"rc=1"* \
 12093 │        && "$(co_sect offline <<<"$COH")" != *"no kernel/* branch ✓"* ]] \
```
[lines 12111–12118](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12111-L12118)
```bash
 12110 │     co_setup
»12111 │     COY=$(co_world "$COSETUP
»12112 │         echo 'main moves' > main-world.txt; git add main-world.txt; git commit -q -m 'main: a change'
»12113 │         echo '== sync'; devtools/held sync 2>&1; echo \"rc=\$?\"
»12114 │         echo \"branch=\$(git branch --show-current)\"
»12115 │         echo \"private-has-main-change=\$(git --git-dir=\$B/private.git log --format=%s kernel/mgmt-flush-status 2>/dev/null | grep -c 'main: a change')\"
»12116 │         echo \"origin-kernel-heads=\$(git --git-dir=\$B/origin.git for-each-ref refs/heads/kernel | grep -c .)\"
 12117 │     " 2>&1)
»12118 │     [[ "$(co_sect sync <<<"$COY")" == *"rc=0"* && "$COY" == *"branch=main"* && "$COY" == *"private-has-main-change=1"* \
 12119 │        && "$COY" == *"origin-kernel-heads=0"* && "$(co_sect sync <<<"$COY")" == *"held branch is 2 commit(s) ahead of main, 0 behind"* ]] \
```
[lines 12122–12137](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12122-L12137)
```bash
 12121 │         || bad "held sync: $(co_sect sync <<<"$COY" | tr '\n' '|') $(grep -E '^(branch|private-has-main-change|origin-kernel-heads)=' <<<"$COY" | tr '\n' ' ')"
»12122 │     COX=$(co_world "$COSETUP
 12123 │         exhibit() { printf '# EX-%s — %s\n\n**Claim.** %s.\n' \"\$1\" \"\$2\" \"\$2\" > evidence/exhibits/\$1-\$2.md
»12124 │                     tools/bt-exhibit index >/dev/null; git add evidence/exhibits; git commit -q -m \"exhibit \$1\"; }
»12125 │         git checkout -q kernel/mgmt-flush-status; exhibit 998 held-world; git checkout -q main; exhibit 997 main-world
»12126 │         echo '== index'; devtools/held sync 2>&1; echo \"rc=\$? branch=\$(git branch --show-current)\"
»12127 │         echo \"tip=\$(git log -1 --format=%s kernel/mgmt-flush-status)\"
»12128 │         echo \"index-rows=\$(git show kernel/mgmt-flush-status:evidence/exhibits/README.md | grep -cE '^\\| EX-99[78] ')\"
»12129 │         echo \"private-tip=\$(git --git-dir=\$B/private.git log -1 --format=%s kernel/mgmt-flush-status)\"
»12130 │         git checkout -q kernel/mgmt-flush-status; echo held-side >> held-world.patch; git commit -qam 'held: a side'
»12131 │         git checkout -q main; echo main-side >> held-world.patch; git add held-world.patch; git commit -qm 'main: a side'
»12132 │         echo '== conflict'; devtools/held sync 2>&1; echo \"rc=\$? branch=\$(git branch --show-current)\"
»12133 │         git merge --abort 2>/dev/null; git checkout -q main
»12134 │         echo dirty >> BRIEF.md
»12135 │         echo '== dirty-sync'; devtools/held sync 2>&1; echo \"rc=\$? branch=\$(git branch --show-current)\"
 12136 │     " 2>&1)
»12137 │     [[ "$(co_sect index <<<"$COX")" == *"rc=0 branch=main"* && "$COX" == *"tip=Merge main into kernel/mgmt-flush-status"* \
 12138 │        && "$COX" == *"index-rows=2"* && "$COX" == *"private-tip=Merge main into kernel/mgmt-flush-status"* ]] \
```
[lines 12144–12144](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12144-L12144)
```bash
 12143 │     # "could not return to main" instead of what to do (a surviving mutant).
»12144 │     [[ "$(co_sect conflict <<<"$COX")" == *"unresolved conflicts:"*"held-world.patch"*"resolve them, then: devtools/held commit"* \
 12145 │        && "$(co_sect conflict <<<"$COX")" == *"rc=1 branch=kernel/mgmt-flush-status"* \
```
[lines 12171–12182](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12171-L12182)
```bash
 12170 │     printf 'save: a world commit\n' > "$COW/save-msg"; : > "$COW/save-empty"
»12171 │     COS=$(co_world "$COSETUP
»12172 │         echo '== noarg'; devtools/save >/dev/null 2>&1; echo \"rc=\$?\"
»12173 │         echo '== missing'; devtools/save '$COW/nope' 2>&1; echo \"rc=\$?\"
»12174 │         echo '== empty'; devtools/save '$COW/save-empty' 2>&1; echo \"rc=\$?\"
»12175 │         printf '# EX-999 — a world probe\n\n**Claim.** none.\n' > evidence/exhibits/999-world-probe.md
»12176 │         for i in \$(seq 1 ${SBUDGET:-0}); do echo \"line \$i\"; done >> BRIEF.md
»12177 │         echo world > save-world.txt
»12178 │         echo '== save'; devtools/save '$COW/save-msg' --no-push 2>&1; echo \"rc=\$?\"
»12179 │         echo \"head=\$(git log -1 --format=%s)\"
»12180 │         echo \"pushed=\$(git --git-dir=\$B/origin.git log --format=%s main 2>/dev/null | grep -c 'save: a world commit')\"
 12181 │     " 2>&1)
»12182 │     [[ "$(co_sect noarg <<<"$COS")" == *"rc=2"* && "$(co_sect missing <<<"$COS")" == *"cannot read message file"*"rc=2"* \
 12183 │        && "$(co_sect empty <<<"$COS")" == *"REFUSING"*"empty"*"rc=2"* ]] \
```
[lines 12186–12186](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12186-L12186)
```bash
 12185 │         || bad "save refusals: $(co_sect noarg <<<"$COS" | tr '\n' '|') $(co_sect missing <<<"$COS" | tr '\n' '|') $(co_sect empty <<<"$COS" | tr '\n' '|')"
»12186 │     [[ "$(co_sect save <<<"$COS")" == *"BRIEF.md does not mention EX-999"* && "$(co_sect save <<<"$COS")" == *"docs/STATUS.md does not mention EX-999"* \
 12187 │        && -n "$SBUDGET" && "$(co_sect save <<<"$COS")" == *"over its ${SBUDGET}-line budget"* ]] \
```
[lines 12206–12207](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12206-L12207)
```bash
 12205 │ if (( COWORLD_OK )); then
»12206 │     COR=$(co_world "
»12207 │         cat > reviews/README.md <<'REG'
 12208 │ | ID | Item | Status |
```
[lines 12217–12222](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12217-L12222)
```bash
 12216 │ REG
»12217 │         echo '== open'; devtools/review-open; echo \"rc=\$?\"
»12218 │         echo '== all'; devtools/review-open --all; echo \"rc=\$?\"
»12219 │         echo '== counts'; devtools/review-open --counts; echo \"rc=\$?\"
»12220 │         echo '== bad'; devtools/review-open --al 2>&1; echo \"rc=\$?\"
 12221 │     " 2>&1)
»12222 │     [[ "$(co_sect open <<<"$COR")" == *"UT: 2 rows, 1 not closed"* && "$(co_sect open <<<"$COR")" == *"R2: 2 rows, 1 not closed"* \
 12223 │        && "$(co_sect open <<<"$COR")" == *"TX: 1 rows, 1 not closed"* && "$(co_sect open <<<"$COR")" == *"UT-02"* \
```
[lines 12228–12228](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12228-L12228)
```bash
 12227 │         || bad "review-open: $(co_sect open <<<"$COR" | tr '\n' '|')"
»12228 │     [[ $(grep -cE '^(UT|R2|TX)-[0-9]+ ' <<<"$(co_sect all <<<"$COR")") == 5 && "$(co_sect counts <<<"$COR")" == *"  no"* \
 12229 │        && "$(co_sect counts <<<"$COR")" == *"   1  done"* ]] \
```
[lines 12310–12311](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12310-L12311)
```bash
 12309 │     [[ "$got" == "$SS/bin/systemctl" ]] || {
»12310 │         echo "stage: systemctl resolves to $got, not the stub — refusing to --apply" >&2
»12311 │         return 99; }
 12312 │ }
```
[lines 12351–12351](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12351-L12351)
```bash
 12350 │ # question is whether the file on disk carries the mode the installer DECLARED.
»12351 │ IMODES=$(awk '{ while (/\\$/ && (getline nxt) > 0) { sub(/\\$/, "", $0); $0 = $0 nxt } print }' install.sh \
 12352 │     | grep -oE 'install_file[[:space:]]+"\$SRC/[^"]+"[[:space:]]+[^[:space:]]+[[:space:]]+0[0-7]{3}' \
```
[lines 12457–12457](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12457-L12457)
```bash
 12456 │ # ── the round trip closes ────────────────────────────────────────────────
»12457 │ SDIR_MADE=$(while read -r d; do [[ -n "$d" && -d "$SR$d" ]] && echo "$d"; done \
 12458 │             < <(sed -n '/^DIRS=(/,/^)/p' uninstall.sh | grep -oE '/[a-zA-Z0-9._/-]+') | grep -c .)
```
[lines 12500–12500](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12500-L12500)
```bash
 12499 │ SRLOUT=$(stage_at "$SRL")
»12500 │ [[ "$SRLOUT" == *"still contains files not installed by this project"* \
 12501 │    && "$SRLOUT" == *"override.conf"* ]] \
```
[lines 12530–12530](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12530-L12530)
```bash
 12529 │ printf 'original bt-mark, not ours\n' > "$SRPX/usr/local/bin/bt-mark"
»12530 │ SRPXI=$(env PATH="$SS/bin:$PATH" BT_MODE_STAMP=/nonexistent/mode BT_STATE="$SRPX/no-such-trial" \
 12531 │         BT_DESTDIR="$SRPX" ./install.sh --tools-only 2>&1); srpxirc=$?
```
[lines 12556–12556](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12556-L12556)
```bash
 12555 │ echo 1758000000 > "$SRUP/usr/local/share/qca9377-bt-hang/installed-at"
»12556 │ SRUPI=$(env PATH="$SS/bin:$PATH" BT_MODE_STAMP=/nonexistent/mode BT_STATE="$SRUP/no-such-trial" \
 12557 │         BT_DESTDIR="$SRUP" ./install.sh --tools-only 2>&1); srupirc=$?
```
[lines 12611–12611](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12611-L12611)
```bash
 12610 │ SRB=$(mktemp -d)
»12611 │ SPMF=$(env PATH="$SPM/bin:$PATH" BT_DESTDIR="$SRB" BT_PROC_MODULES="$SFREE" \
 12612 │            ./uninstall.sh --apply 2>&1)
```
[lines 12623–12623](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12623-L12623)
```bash
 12622 │     || bad "uninstall.sh did not choose the idle-btusb reload branch"
»12623 │ SPMB=$(env PATH="$SPM/bin:$PATH" BT_DESTDIR="$SRB" BT_PROC_MODULES="$SBUSY" \
 12624 │            ./uninstall.sh --apply 2>&1)
```
[lines 12632–12632](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12632-L12632)
```bash
 12631 │ SNONE=$(mktemp); : > "$SNONE"
»12632 │ SPMN=$(env PATH="$SPM/bin:$PATH" BT_DESTDIR="$SRB" BT_PROC_MODULES="$SNONE" \
 12633 │            ./uninstall.sh --apply 2>&1)
```
[lines 12647–12647](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12647-L12647)
```bash
 12646 │ SRG=$(mktemp -d); SMS=$(mktemp); echo "experiment since=2026-08-13T12:22:10" > "$SMS"
»12647 │ GEX=$(env PATH="$SS/bin:$PATH" BT_MODE_STAMP="$SMS" BT_DESTDIR="$SRG" \
 12648 │           BT_STATE="$SRG/none" ./install.sh --apply 2>&1); gexrc=$?
```
[lines 12654–12654](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12654-L12654)
```bash
 12653 │ 
»12654 │ GFO=$(env PATH="$SS/bin:$PATH" BT_MODE_STAMP="$SMS" BT_DESTDIR="$SRG" \
 12655 │           BT_FORCE_INSTALL=1 BT_STATE="$SRG/none" ./install.sh --apply 2>&1); gforc=$?
```
[lines 12668–12668](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12668-L12668)
```bash
 12667 │ SRT=$(mktemp -d)
»12668 │ GTO=$(env PATH="$SS2/bin:$PATH" BT_MODE_STAMP="$SMS" BT_DESTDIR="$SRT" \
 12669 │           BT_FORCE_INSTALL=1 BT_STATE="$SRT/none" ./install.sh --apply 2>&1)
```
[lines 12687–12688](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12687-L12688)
```bash
 12686 │ for e in "$PWD"/*; do ln -s "$e" "$RG/"; done; rm -f "$RG/install.sh"
»12687 │ awk '!done && /^    if \(\( TOOLS_ONLY \)\); then$/ { skip = 1; next }
»12688 │      skip { if (/^    fi$/) { skip = 0; done = 1 }; next }
 12689 │      { print }' install.sh > "$RG/install.sh"; chmod +x "$RG/install.sh"
```
[lines 12694–12694](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12694-L12694)
```bash
 12693 │     || bad "run()'s tools-only gate was not cut out of the copy: $(( $(wc -l < install.sh) - $(wc -l < "$RG/install.sh") )) line(s) removed"
»12694 │ RGA=$(cd "$RG" && env PATH="$SS/bin:$PATH" BT_MODE_STAMP=/nonexistent/mode BT_STATE="$RGS/none" \
 12695 │           BT_PROC_MODULES="$RGM" BT_DESTDIR="$RGS" ./install.sh --apply 2>&1)
```
[lines 12700–12700](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12700-L12700)
```bash
 12699 │ rgj=$(grep -c '^journalctl -k' "$SS/spy.log" || true)
»12700 │ RGT=$(cd "$RG" && env PATH="$SS/bin:$PATH" BT_MODE_STAMP=/nonexistent/mode BT_STATE="$RGS/none" \
 12701 │           BT_PROC_MODULES="$RGM" BT_DESTDIR="$RGS" ./install.sh --tools-only 2>&1); rgtrc=$?
```
[lines 12713–12713](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12713-L12713)
```bash
 12712 │ printf 'start=1786700000\nbuild=stock\nn=2\n' > "$SRT2/state/current"
»12713 │ GTR=$(env PATH="$SS/bin:$PATH" BT_MODE_STAMP=/nonexistent/mode BT_DESTDIR="$SRT2" \
 12714 │           BT_STATE="$SRT2/state" ./install.sh --apply 2>&1)
```
[lines 12756–12756](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12756-L12756)
```bash
 12755 │ # halves separately — reporting each correctly-staged call as a leak.
»12756 │ SLOOSE=$(suite_cat \
 12757 │          | awk '{ while (/\\$/ && (getline nxt) > 0) { sub(/\\$/, "", $0); $0 = $0 nxt } print }' \
```
[lines 12796–12796](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12796-L12796)
```bash
 12795 │ : > "$SRD/etc/udev/rules.d/51-bluetooth-health-snapshot.rules.disabled"
»12796 │ TOD=$(env PATH="$SS/bin:$PATH" BT_MODE_STAMP=/nonexistent/mode BT_STATE="$SRD/no-such-trial" \
 12797 │           BT_DESTDIR="$SRD" ./install.sh --tools-only 2>&1); todrc=$?
```
[lines 12809–12811](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L12809-L12811)
```bash
 12808 │ SRE=$(mktemp -d)
»12809 │ TOE=$(env PATH="$SS/bin:$PATH" BT_MODE_STAMP=/nonexistent/mode BT_STATE="$SRE/no-such-trial" \
 12810 │           BT_DESTDIR="$SRE" ./install.sh --tools-only 2>&1)
»12811 │ [[ -s "$SRE/etc/modprobe.d/btusb-qca9377.conf" && -s "$SRE/etc/udev/rules.d/50-bluetooth-no-autosuspend.rules" \
 12812 │    && -s "$SRE/etc/udev/rules.d/51-bluetooth-health-snapshot.rules" ]] \
```
[lines 13008–13008](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L13008-L13008)
```bash
 13007 │ BWF=$(PATH="$BWFBIN:$PATH" BT_JOURNAL_FIXTURE=tests/journal/window tools/bt-window 2>&1); bwfrc=$?
»13008 │ if [[ "$BWF" == *"2026-08-15T21:02:31.230123"* && "$BWF" == *"command timeouts   3"* \
 13009 │    && "$BWF" == *"no intervention"* && "$BWF" == *"1 USB-layer line"* ]]; then
```
[lines 13031–13031](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L13031-L13031)
```bash
 13030 │     bad "reset window mis-attributed — the kernel's reset wording or the rfkill qualifier is wrong:"
»13031 │     while IFS= read -r l; do bad "      $l"; done < <(grep -E 'INTERVENTION|intervention|tooling|operator' <<<"$BWR")
 13032 │ fi
```
[lines 13038–13038](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L13038-L13038)
```bash
 13037 │     bad "operator window mis-attributed:"
»13038 │     while IFS= read -r l; do bad "      $l"; done < <(grep -E 'INTERVENTION|intervention|tooling|operator' <<<"$BWK")
 13039 │ fi
```
[lines 13063–13063](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L13063-L13063)
```bash
 13062 │ for f in "${SHFILES[@]}"; do case "$f" in tools/*|bin/*) TOOLFILES+=("$f") ;; esac; done
»13063 │ RESETSITE=$(grep -nE 'usb_queue_reset_device' "${TOOLFILES[@]}" 2>/dev/null \
 13064 │             | grep -vE '^[^:]*:[0-9]*:[[:space:]]*#' \
```
[lines 13072–13072](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L13072-L13072)
```bash
 13071 │     bad "a reset detector matches only this project's wording — an external reset is invisible:"
»13072 │     while IFS= read -r l; do bad "      $l"; done <<<"$RESETSITE"
 13073 │ fi
```
[lines 13113–13113](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L13113-L13113)
```bash
 13112 │     bad "bt-window's reads are not bounded to the fault — $BWUNBOUND unbounded, $BWSINCE since-bounded:"
»13113 │     while IFS= read -r l; do bad "      journalctl $l"; done < "$BWS/calls.log"
 13114 │ fi
```
[lines 13345–13348](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L13345-L13348)
```bash
 13344 │     # outcome with real-world consequences, so that is what is asserted.
»13345 │     tools/sanitize-logs.sh "$SAN" "$SANOUT" >/dev/null 2>&1
»13346 │     rc=$?
»13347 │     if (( rc != 0 )); then
»13348 │         ok "sanitize-logs refuses on an awk that cannot express its patterns"
 13349 │     else
```
[lines 13352–13353](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L13352-L13353)
```bash
 13351 │     fi
»13352 │     if [[ ! -s "$SANOUT" ]]; then
»13353 │         ok "a refused run writes no output file"
 13354 │     else
```
[lines 13357–13358](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L13357-L13358)
```bash
 13356 │     fi
»13357 │     echo "  · redaction assertions SKIPPED: this awk lacks ERE intervals on groups"
»13358 │     echo "    (install gawk to run them; mawk 1.3.4 is not sufficient)"
 13359 │ fi
```
[lines 13491–13491](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L13491-L13491)
```bash
 13490 │     # for the engine's reason, burying the real signal.
»13491 │     (( sanbrc != 0 )) \
 13492 │        && grep -q '00:11:22:33:44:55' "$SANB/one.log" \
```
[lines 13496–13497](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L13496-L13497)
```bash
 13495 │         || bad "-i on an incapable awk modified a file or returned success (rc=$sanbrc)"
»13496 │     echo "  · batch-mode redaction assertion SKIPPED: this awk lacks ERE intervals on groups"
»13497 │     echo "    (install gawk to run it; mawk 1.3.4 is not sufficient)"
 13498 │ fi
```
[lines 13887–13891](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L13887-L13891)
```bash
 13886 │     # would never notice it.
»13887 │     (( utfrc != 0 )) && [[ ! -s "$SCRATCH/utf8/clean.log" ]] \
 13888 │         && ok "on an incapable awk the non-ASCII case is refused and no clean.log is written" \
 13889 │         || bad "an incapable awk produced output for the non-ASCII case (rc=$utfrc) — a partial redaction may have been written"
»13890 │     echo "  · non-ASCII redaction assertion SKIPPED: this awk lacks ERE intervals on groups"
»13891 │     echo "    (install gawk to run it; mawk 1.3.4 is not sufficient)"
 13892 │ fi
```
[lines 14070–14084](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14070-L14084)
```bash
 14069 │ MUTSH=$(devtools/mutants "$MUT/f.sh" | cut -f1-5 | tr '\t' ' ')
»14070 │ MUTSHWANT='2 8 > >= shell-arith
»14071 │ 2 15 && || shell-list
»14072 │ 2 26 == != shell-test
»14073 │ 2 31 && || shell-test
»14074 │ 2 34 -z -n shell-test
»14075 │ 3 7 -gt -ge shell-test
»14076 │ 3 15 || && shell-list
»14077 │ 5 3 !   shell-neg
»14078 │ 6 8 >= > shell-arith
»14079 │ 10 15 > >= awk
»14080 │ 10 19 && || awk
»14081 │ 10 25 != == awk
»14082 │ 10 37 ++ -- awk
»14083 │ 11 16 >= > awk
»14084 │ 13 14 > >= shell-arith
 14085 │ 13 21 && || shell-list'
```
[lines 14092–14096](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14092-L14096)
```bash
 14091 │ MUTAWK=$(devtools/mutants "$MUT/f.awk" | cut -f1-5 | tr '\t' ' ')
»14092 │ MUTAWKWANT='1 3 > >= awk
»14093 │ 1 7 && || awk
»14094 │ 1 13 != == awk
»14095 │ 1 25 ++ -- awk
»14096 │ 3 25 > >= awk
 14097 │ 3 31 -- ++ awk'
```
[lines 14249–14249](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14249-L14249)
```bash
 14248 │ STNOREM=$(st_run); stnrc=$?
»14249 │ [[ "$STNOREM" == *"could not reach origin — cannot confirm"* \
 14250 │    && "$STNOREM" != *"pushed"*"=="* ]] \
```
[lines 14408–14408](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14408-L14408)
```bash
 14407 │ printf '#!/bin/sh\nexit 1\n' > "$INCS/bin/failing-sanitiser"; chmod +x "$INCS/bin/failing-sanitiser"
»14408 │ INCSOUT=$(env "${INCENV[@]}" BT_EVIDENCE_REPO="$INCS/repo" BT_SANITIZER="$INCS/bin/failing-sanitiser" \
 14409 │           tools/bt-incident sanitiser-failure-check --since '10 minutes ago' 2>&1); incsrc=$?
```
[lines 14436–14436](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14436-L14436)
```bash
 14435 │ # carries no address.
»14436 │ INCSFILES=$(find "$INCS"/repo/evidence/sessions/2* -maxdepth 1 -type f -size +0 \( -name '*.log' -o -name '*.txt' \) \
 14437 │             ! -name MANIFEST.txt ! -name hci-captures.txt 2>/dev/null | sort)
```
[lines 14451–14451](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14451-L14451)
```bash
 14450 │ if command -v python3 >/dev/null 2>&1; then
»14451 │     BAPOUT=$(python3 - scripts/bt-audio-policy.py <<'PYEOF'
 14452 │ import importlib.util, sys
```
[lines 14492–14492](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14492-L14492)
```bash
 14491 │     BCR=$(mktemp -d); mkdir -p "$BCR/cap"
»14492 │     BCROUT=$(cd "$BCR" && python3 - "$OLDPWD/bin/bt-capture" "$BCR" <<'PYEOF'
 14493 │ import importlib.util, importlib.machinery, io, os, socket, struct, sys, types
```
[lines 14568–14568](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14568-L14568)
```bash
 14567 │ : > "$CIS/calls"
»14568 │ CIOUT=$(cd "$CIS/elsewhere" && env PATH="$CIS/bin:$PATH" CI_STUB_LOG="$CIS/calls" \
 14569 │         "$OLDPWD/devtools/ci" HEAD 2>&1); circ=$?
```
[lines 14575–14575](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14575-L14575)
```bash
 14574 │     || bad "devtools/ci ran gh from '$cwd_seen', not the checkout (rc=$circ)"
»14575 │ CIFAIL=$(cd "$CIS/elsewhere" && env PATH="$CIS/bin:$PATH" CI_STUB_LOG="$CIS/calls" CI_STUB_FAIL=1 \
 14576 │          BT_CI_GRACE=2 BT_CI_POLL=0 "$OLDPWD/devtools/ci" --wait HEAD 2>&1); cifrc=$?
```
[lines 14583–14583](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14583-L14583)
```bash
 14582 │ : > "$CIS/counter"
»14583 │ CITR=$(cd "$CIS/elsewhere" && env PATH="$CIS/bin:$PATH" CI_STUB_LOG="$CIS/calls" \
 14584 │        CI_STUB_FAIL_TIMES=2 CI_STUB_COUNTER="$CIS/counter" BT_CI_POLL=0 \
```
[lines 14615–14615](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14615-L14615)
```bash
 14614 │ CIARGS=(--repo other-owner/third HEAD); CIX=$(cirun); CIXA=$(cat "$CIS/args")
»14615 │ [[ "$CIPA" == *"-R example-owner/private-repo"* && "$CIP" == *"run 123 in example-owner/private-repo"* \
 14616 │    && "$CIOA" == *"-R example-owner/public-repo"* && "$CIO" == *"in example-owner/public-repo"* ]] \
```
[lines 14619–14619](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14619-L14619)
```bash
 14618 │     || bad "devtools/ci's repository: private args '$CIPA', out '$CIP'; origin args '$CIOA'"
»14619 │ [[ "$CIXA" == *"-R other-owner/third"* && "$CIX" == *"in other-owner/third"* \
 14620 │    && "$CIE" == *"no run found for"*"in example-owner/private-repo"* ]] \
```
[lines 14696–14696](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14696-L14696)
```bash
 14695 │ # or /dev/stdin, because the first read consumed it. It is snapshotted now.
»14696 │ SVPIPE=$(printf 'message from a stream\n\nbody line\n' \
 14697 │          | devtools/repo-save "$SCRATCH/save" -F /dev/stdin --no-push 2>&1); svprc=$?
```
[lines 14983–14983](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14983-L14983)
```bash
 14982 │ if [[ -n "${BT_DECOY_WORLD:-}" ]]; then
»14983 │     AAS="access-audit: inside the decoy world, where its planted machine reads are leaks"; aasrc=3
 14984 │ else
```
[lines 14988–14988](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L14988-L14988)
```bash
 14987 │ if (( aasrc == 3 )); then
»14988 │     AUDIT_SKIPPED="devtools/access-audit's self-test ($(head -1 <<<"$AAS" | sed 's/^access-audit: //'))"
 14989 │ else
```
[lines 15030–15030](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15030-L15030)
```bash
 15029 │     [[ -n "${!_v+set}" ]] && continue
»15030 │     _p=$(git ls-files bin tools install.sh uninstall.sh | xargs grep -ohE "\\\$\\{$_v:-\\\$\\{BT_[A-Z0-9_]+" 2>/dev/null \
 15031 │          | sed -E 's/.*\$\{(BT_[A-Z0-9_]+)$/\1/' | sort -u | head -1)
```
[lines 15119–15119](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15119-L15119)
```bash
 15118 │ # it is simply not in the list.
»15119 │ LOOSE=$(grep -HnE 'tools/bt-trial +(autostart|start|ok|hang|abort|step)\b' "${SUITE_FILES[@]}" \
 15120 │         | grep -v ":[0-9]*:[[:space:]]*#")
```
[lines 15216–15216](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15216-L15216)
```bash
 15215 │    && [[ "$TCS" == "tests/run-tests
»15216 │ $SFD/10-guards.sh
 15217 │ $SFD/20-tools.sh" ]] \
```
[lines 15264–15264](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15264-L15264)
```bash
 15263 │         || bad "awk-coverage's grouping by program: $(grep -E '%|TOTAL' <<<"$ACO" | tr '\n' '|')"
»15264 │     [[ "$ACO" == *"50.0%      1/2      prog:parse-check-only:$ACT/tools/lib/lonely.awk#"* \
 15265 │        && "$ACO" == *"parse checks set aside: 4 (their files also ran over data); counted: 2 (their files never did)"* ]] \
```
[lines 15268–15268](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15268-L15268)
```bash
 15267 │         || bad "awk-coverage's parse checks: $(grep -E 'parse|lonely' <<<"$ACO" | tr '\n' '|')"
»15268 │     [[ "$ACO" == *"TOTAL: 75.0% (6 of 8 statements)"* && "$ACO" == *"suite: toy: done"* && $acorc == 0 && $acfrc == 1 \
 15269 │        && "$ACF" == *"awk statement coverage 75% is below the --min 76% floor"* ]] \
```
[lines 15283–15283](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15283-L15283)
```bash
 15282 │ else
»15283 │     AWKCOV_SKIPPED="devtools/awk-coverage against a toy suite (no gawk here; mawk has no profiler)"
 15284 │ fi
```
[lines 15292–15292](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15292-L15292)
```bash
 15291 │     bad "$SELF0N uses of \$0 outside comments; a scan over \$0 stops covering the suite when it splits:"
»15292 │     while IFS= read -r l; do bad "      $l"; done <<<"$SELF0"
 15293 │ fi
```
[lines 15305–15305](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15305-L15305)
```bash
 15304 │     bad "$SELFNN scans of tests/run-tests by name (2 expected, the runner's); a scan of the entry file stops covering the suite when it splits:"
»15305 │     while IFS= read -r l; do bad "      $l"; done <<<"$SELFN"
 15306 │ fi
```
[lines 15314–15314](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15314-L15314)
```bash
 15313 │     bad "$EXITN EXIT traps in this file; a second one REPLACES the first and its cleanup is lost:"
»15314 │     while IFS= read -r l; do bad "      $l"; done <<<"$EXITT"
 15315 │ fi
```
[lines 15327–15327](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15327-L15327)
```bash
 15326 │ while IFS= read -r _gl; do
»15327 │     [[ "$_gl" == safe.directory=* ]] || _gleak+="${_gl%%=*} "
 15328 │ done < <(git config --global --list 2>/dev/null)
```
[lines 15380–15380](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15380-L15380)
```bash
 15379 │     bad "bt-trial invoked outside trial() — may write to the real evidence tree:"
»15380 │     while IFS= read -r l; do echo "        $l"; done <<<"$LOOSE"
 15381 │ fi
```
[lines 15388–15391](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15388-L15391)
```bash
 15387 │ TWRAPS=$(suite_cat | grep -cE '^[^#]*tools/bt-trial "\$@"' || true)
»15388 │ TWBAD=$(suite_cat | awk '{ l[NR] = $0 }
»15389 │     /^[^#]*tools\/bt-trial "\$@"/ {
»15390 │         ctx = l[NR-3] " " l[NR-2] " " l[NR-1] " " $0
»15391 │         if (ctx !~ /BT_REPO=/ || ctx !~ /BT_EVIDENCE_REPO=/) print "line " NR ": " $0
 15392 │     }')
```
[lines 15402–15402](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15402-L15402)
```bash
 15401 │ # name, it covered only what had not moved into a part.
»15402 │ CTAGS=$(grep -Hn 'BT_MACHINE_CONTRAC[T]=' "${SUITE_FILES[@]}" | grep -vE ':[0-9]+:[[:space:]]*#' \
 15403 │         | grep -vc 'CONTRAC[T]="[$]check" "[$]p" "[$]@"' || true)
```
[lines 15421–15433](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15421-L15433)
```bash
 15420 │     # joined up the ancestry: "bt-state < bt-evidence stop"
»15421 │     awk -F'\t' '{ nc = split($3, cs, / < /); s = ""
»15422 │                   for (j = 1; j <= nc; j++) {
»15423 │                       nw = split(cs[j], w, " "); i = 1
»15424 │                       while (i < nw && (w[i] ~ /(^|\/)(ba|da)?sh$/ || w[i] == "timeout" || w[i] ~ /^[0-9]+$/)) i++
»15425 │                       c = w[i]; sub(/.*\//, "", c)
»15426 │                       if (w[i + 1] ~ /^[a-z][a-z0-9-]*$/) c = c " " w[i + 1]
»15427 │                       s = s (j > 1 ? " < " : "") c }
»15428 │                   k = $1 "\t" s; n[k]++
»15429 │                   if (!(k in a)) { a[k] = $2; at[k] = $4 } }
»15430 │                 END { for (k in n) { split(k, q, "\t"); g++
»15431 │                           printf "%d\t%d\t1\t%5d  %-12s %s\n", n[k], g, n[k], q[1], substr(q[2], 1, 90)
»15432 │                           printf "%d\t%d\t2\t                    argv: %s   after: %s\n", n[k], g,
»15433 │                                  substr(a[k], 1, 40), substr(at[k], 1, 60) } }' \
 15434 │         <(grep -v $'^journalctl\t--suite-tripwire-canary\t' "$TRIP_LOG") \
```
[lines 15447–15448](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15447-L15448)
```bash
 15446 │     bad "$(grep -c . <<<"$ORPHANS") process(es) outlived the test that started them — stop daemons with stop_daemon:"
»15447 │     sed 's/^/        /' <<<"$ORPHANS" | head -10
»15448 │     kill -TERM $(cut -d' ' -f1 <<<"$ORPHANS") 2>/dev/null
 15449 │ fi
```
[lines 15519–15522](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15519-L15522)
```bash
 15518 │ elif [[ -n "$MISSING" ]]; then
»15519 │     echo "  NOT ASKED HERE: of $GUARDN guarded tools, these are absent:$MISSING"
»15520 │     echo "                  every assertion whose subject is one of them SKIPPED."
»15521 │     echo "                  A green run on this host is weaker than a green run"
»15522 │     echo "                  where they are installed. Verify there before merging."
 15523 │ else
```
[lines 15532–15534](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15532-L15534)
```bash
 15531 │ if [[ -n "$PRIV_SKIPPED" ]]; then
»15532 │     echo "  NOT ASKED HERE: $PRIV_SKIPPED — this run reached none of EUID 0, a"
»15533 │     echo "                  user namespace, or fakeroot, and the tool under test"
»15534 │     echo "                  refuses to act without one of them."
 15535 │ fi
```
[lines 15572–15573](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/tests/run-tests#L15572-L15573)
```bash
 15571 │ if (( fail )); then
»15572 │     echo "FAILED: $fail of $((pass + fail)) invariants"
»15573 │     exit 1
 15574 │ fi
```

</details>

## 7. `results/` and `evidence/`: experiment records

<details><summary>206 uncovered lines in 20 files (expand)</summary>

Scripts of finished experiments; whether bash coverage should count them at all is the question here (section 3).

#### [`evidence/trials/E3/hang-verdicts-check-2026-11-07/boot-setup-scan.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/evidence/trials/E3/hang-verdicts-check-2026-11-07/boot-setup-scan.sh) — 5 uncovered of 5 coverable lines (0.0% run)

[lines 5–9](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/evidence/trials/E3/hang-verdicts-check-2026-11-07/boot-setup-scan.sh#L5-L9)
```bash
     4 │ # port during the first two minutes, and the "Opcode … failed" lines. Journal reads only.
»    5 │ set -uo pipefail
»    6 │ for b in "$@"; do
»    7 │   first=$(journalctl -b "$b" --no-pager -o short-iso -n 1 --reverse 2>/dev/null | head -0; journalctl -b "$b" --no-pager -o short-iso 2>/dev/null | head -1 | cut -d' ' -f1)
»    8 │   echo "=== boot $b (first entry $first)"
»    9 │   journalctl -b "$b" -k --no-pager -o short-iso \
    10 │     --grep "QCA: patch rome|using rampatch|usb 3-3: USB disconnect|Opcode 0x[0-9a-f]+ failed|unexpected cc|Controllers:" 2>/dev/null | head -12
```

#### [`results/bt10-l2cap-hang-2026-10-23/run-one.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/bt10-l2cap-hang-2026-10-23/run-one.sh) — 16 uncovered of 16 coverable lines (0.0% run)

[lines 6–21](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/bt10-l2cap-hang-2026-10-23/run-one.sh#L6-L21)
```bash
     5 │ # Refuses to overwrite a log. Prints the case's verdict line, or HANG when the limit was hit.
»    6 │ set -u
»    7 │ IMG=${1:?usage}; LOG=${2:?usage}; LIM=${3:?usage}; CPUS=${4:?usage}; CASE=${5:?usage}
»    8 │ R=/root/exp/qca9377-bt-hang
»    9 │ B=$R/cache/co02-w2c-bluez
»   10 │ TP=$R/cache/co02-bluez/tools/l2cap-tester
»   11 │ [[ -r "$IMG" ]] || { echo "no image $IMG"; exit 2; }
»   12 │ [[ -e "$LOG" ]] && { echo "refusing: $LOG exists"; exit 2; }
»   13 │ opts=()
»   14 │ if [[ "$CPUS" == 4 ]]; then opts+=(-q "$R/tmp/mesh-tester-ci/qemu-smp.sh"); fi
»   15 │ cd "$B" || exit 2
»   16 │ echo "start $(date -u '+%T') kernel $IMG cpus $CPUS case $CASE limit $LIM" > "$LOG"
»   17 │ timeout "$LIM" "$B/tools/test-runner" "${opts[@]}" -k "$IMG" -- "$TP" -s "$CASE" >> "$LOG" 2>&1
»   18 │ rc=$?
»   19 │ echo "exit=$rc end $(date -u '+%T')" >> "$LOG"
»   20 │ v=$(grep -a -E "^$CASE +.*(Passed|Failed|Not Run|Timed out)" "$LOG" | sed -e 's/\x1b\[[0-9;]*m//g' | tr -s ' ')
»   21 │ if [[ $rc -eq 124 ]]; then echo "$(basename "$IMG"): HANG (limit $LIM s)"; else echo "$(basename "$IMG"): ${v:-no verdict, rc=$rc}"; fi
    22 │ 
```

#### [`results/bt10-l2cap-hang-2026-10-23/sweep-images.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/bt10-l2cap-hang-2026-10-23/sweep-images.sh) — 8 uncovered of 8 coverable lines (0.0% run)

[lines 4–11](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/bt10-l2cap-hang-2026-10-23/sweep-images.sh#L4-L11)
```bash
     3 │ # built for CO-02 (tmp/co02-w2c/img), 4 vCPUs, 180 s limit each. Logs tmp/l2cap-hang/logs/sweep-*.
»    4 │ set -u
»    5 │ R=/root/exp/qca9377-bt-hang
»    6 │ I=$R/tmp/co02-w2c/img
»    7 │ L=$R/tmp/l2cap-hang/logs
»    8 │ mkdir -p "$L"
»    9 │ C="L2CAP Ext-Flowctl Server - Accept 2 Close 1"
»   10 │ for t in v4-smp st7.2v4-base-smp st6.18v4-base-smp 612-base-smp st6.6-base-smp u38w-pre-smp; do
»   11 │ 	"$R/tmp/l2cap-hang/run-one.sh" "$I/bzImage-$t" "$L/sweep-$t.log" 180 4 "$C"
    12 │ done
```

#### [`results/ci-local-2026-10-10/container-setup/build-tester-kernel.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/ci-local-2026-10-10/container-setup/build-tester-kernel.sh) — 10 uncovered of 10 coverable lines (0.0% run)

[lines 5–14](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/ci-local-2026-10-10/container-setup/build-tester-kernel.sh#L5-L14)
```bash
     4 │ # the same: copy tester.config, make olddefconfig, make -j).
»    5 │ R=/home/user/qca9377-bt-hang
»    6 │ K=$R/cache/bluetooth-next
»    7 │ LOG=$R/tmp/ci-local-research/tester-kernel-build.log
»    8 │ cp $R/cache/bluez/doc/tester.config $K/.config
»    9 │ { echo "tree: $(git -C $K log -1 --format='%H %s')"; echo "config: cache/bluez/doc/tester.config from $(git -C $R/cache/bluez log -1 --format=%h)"; date -u; } > $LOG
»   10 │ nice -n 19 make -C $K olddefconfig >> $LOG 2>&1
»   11 │ nice -n 19 make -C $K -j4 bzImage >> $LOG 2>&1
»   12 │ echo "kernel make rc=$?" >> $LOG
»   13 │ date -u >> $LOG
»   14 │ ls -la $K/arch/x86/boot/bzImage >> $LOG 2>&1
    15 │ 
```

#### [`results/ci-local-2026-10-10/harness-diag/probe.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/ci-local-2026-10-10/harness-diag/probe.sh) — 7 uncovered of 7 coverable lines (0.0% run)

[lines 4–9](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/ci-local-2026-10-10/harness-diag/probe.sh#L4-L9)
```bash
     3 │ # --server answer an H4 "Read Local Version Information" over its unix socket?
»    4 │ R=/home/user/qca9377-bt-hang; W=$R/tmp/functional-repeat/20261011T125340Z-pair_bredr-diag/work/src
»    5 │ H=$R/tmp/ci-local-research/harness-diag; S=$H/srv; rm -rf $S; mkdir -p $S
»    6 │ ASAN_OPTIONS=detect_leaks=0 $W/emulator/btvirt --server=$S > $H/btvirt.log 2>&1 &
»    7 │ BTV=$!; for i in $(seq 1 50); do [[ -S $S/bt-server-bredrle ]] && break; sleep 0.1; done
»    8 │ ls -la $S
»    9 │ python3 -I - "$S/bt-server-bredrle" <<'PY'
    10 │ import socket, sys, time
```
[lines 18–18](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/ci-local-2026-10-10/harness-diag/probe.sh#L18-L18)
```bash
    17 │ PY
»   18 │ kill $BTV; wait $BTV 2>/dev/null; echo "btvirt log:"; cat $H/btvirt.log
    19 │ 
```

#### [`results/ci-local-2026-10-10/harness-diag/probe2.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/ci-local-2026-10-10/harness-diag/probe2.sh) — 16 uncovered of 16 coverable lines (0.0% run)

[lines 4–10](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/ci-local-2026-10-10/harness-diag/probe2.sh#L4-L10)
```bash
     3 │ # bt-server-bredrle and bt-server-le (bt_crypto_new, AF_ALG) on this host.
»    4 │ R=/home/user/qca9377-bt-hang; W=$R/tmp/functional-repeat/20261011T125340Z-pair_bredr-diag/work/src
»    5 │ H=$R/tmp/ci-local-research/harness-diag; S=$H/srv2; rm -rf $S; mkdir -p $S
»    6 │ date -u +%H:%M:%S; uname -r
»    7 │ ASAN_OPTIONS=detect_leaks=0 $W/emulator/btvirt --server=$S > $H/btvirt2.log 2>&1 &
»    8 │ BTV=$!; for i in $(seq 1 50); do [[ -S $S/bt-server-mon ]] && break; sleep 0.1; done
»    9 │ for srv in bt-server-bredr bt-server-bredrle bt-server-le; do
»   10 │ python3 -I - "$S/$srv" <<'PY'
    11 │ import socket, sys, time
```
[lines 22–30](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/ci-local-2026-10-10/harness-diag/probe2.sh#L22-L30)
```bash
    21 │ done
»   22 │ kill -0 $BTV 2>/dev/null && echo "btvirt still alive (pid $BTV)"; kill $BTV; wait $BTV 2>/dev/null
»   23 │ echo "btvirt log:"; cat $H/btvirt2.log
»   24 │ echo "--- AF_ALG on this host"; python3 -I -c "
»   25 │ import socket
»   26 │ for fam in ('AF_ALG',):
»   27 │     try: socket.socket(socket.AF_ALG, socket.SOCK_SEQPACKET, 0); print(fam, 'socket ok')
»   28 │     except OSError as e: print(fam, e)
»   29 │ "
»   30 │ echo "--- kernel config evidence"; ls /boot/config-* /proc/config.gz 2>&1 | head -2; grep -c . /proc/crypto 2>/dev/null; grep -m3 "^name" /proc/crypto 2>/dev/null
    31 │ 
```

#### [`results/u29-emulator-2026-11-07/u29-t1-a2dp-backport/scripts/build.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t1-a2dp-backport/scripts/build.sh) — 22 uncovered of 22 coverable lines (0.0% run)

[lines 8–32](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t1-a2dp-backport/scripts/build.sh#L8-L32)
```bash
     7 │ # Log: logs/build-<name>.log ; the configure line is the first line of it.
»    8 │ set -u
»    9 │ top=/root/exp/agent-work/u29-t1-a2dp-backport
»   10 │ name=$1
»   11 │ case $name in
»   12 │ base) dir=$top/src/bluez-5.72-base ;;
»   13 │ patched) dir=$top/src/bluez-5.72-patched ;;
»   14 │ tools) dir=$top/src/bluez-5.72-tools ;;
»   15 │ *) echo "bad name"; exit 2 ;;
    16 │ esac
»   17 │ if [ "$name" = tools ]; then
»   18 │   conf='./configure CFLAGS="-std=gnu17 -g -O2" --enable-tools --enable-testing --enable-experimental --enable-deprecated --enable-external-ell --enable-monitor --enable-client --disable-obex --disable-cups --disable-mesh --disable-midi --disable-manpages --localstatedir=/var --sysconfdir=/etc --prefix=/usr'
    19 │ else
»   20 │   conf='./configure --enable-asan --enable-ubsan --enable-debug --disable-silent-rules --enable-tools --enable-testing --enable-experimental --enable-deprecated --enable-external-ell --enable-library --enable-monitor --enable-client --enable-udev --disable-obex --disable-cups --disable-mesh --disable-midi --disable-manpages --localstatedir=/var --sysconfdir=/etc --prefix=/usr'
    21 │ fi
»   22 │ echo "configure: $conf" > "$top/logs/build-$name.log"
»   23 │ docker run --rm -v "$dir:/b" -w /b co03-noble-build:1 sh -c "
»   24 │ set -e
»   25 │ make distclean >/dev/null 2>&1 || true
»   26 │ $conf
»   27 │ make -j8
»   28 │ echo make-exit \$?
»   29 │ ls -la src/bluetoothd client/bluetoothctl tools/btmgmt
»   30 │ " >> "$top/logs/build-$name.log" 2>&1
»   31 │ echo "$name build exit $?"
»   32 │ tail -4 "$top/logs/build-$name.log"
    33 │ 
```

#### [`results/u29-emulator-2026-11-07/u29-t1-a2dp-backport/scripts/run.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t1-a2dp-backport/scripts/run.sh) — 21 uncovered of 21 coverable lines (0.0% run)

[lines 10–27](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t1-a2dp-backport/scripts/run.sh#L10-L27)
```bash
     9 │ # stdout.log, commands.txt).
»   10 │ set -eu
»   11 │ top=/root/exp/agent-work/u29-t1-a2dp-backport
»   12 │ arm=$1
»   13 │ name=${2:-$arm}
»   14 │ U29_REPS=${3:-${U29_REPS:-5}}
»   15 │ U29_ACL=${4:-${U29_ACL:-none}}
»   16 │ case $arm in
»   17 │ baseline) h0=bluez-5.72-base ;;
»   18 │ patched) h0=bluez-5.72-patched ;;
»   19 │ *) echo "arm: baseline or patched" >&2; exit 2 ;;
    20 │ esac
»   21 │ out=$top/runs/$name
»   22 │ mkdir -p "$out"
»   23 │ echo "arm=$arm host0=$h0 reps=${U29_REPS:-5} acl=${U29_ACL:-none}" > "$out/commands.txt"
»   24 │ echo "run.sh $arm $name" >> "$out/commands.txt"
»   25 │ echo "$(date +%H:%M:%S) start $arm $name" >> "$top/PROGRESS.log"
»   26 │ set +e
»   27 │ docker run --rm --name "u29t1-$name" \
    28 │     --device /dev/kvm \
```
[lines 44–47](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t1-a2dp-backport/scripts/run.sh#L44-L47)
```bash
    43 │     > "$out/stdout.log" 2>&1
»   44 │ rc=$?
»   45 │ echo "$(date +%H:%M:%S) end $arm $name rc=$rc" >> "$top/PROGRESS.log"
»   46 │ echo "exit $rc"
»   47 │ exit $rc
    48 │ 
```

#### [`results/u29-emulator-2026-11-07/u29-t1-a2dp-backport/scripts/sums.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t1-a2dp-backport/scripts/sums.sh) — 11 uncovered of 11 coverable lines (0.0% run)

[lines 3–8](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t1-a2dp-backport/scripts/sums.sh#L3-L8)
```bash
     2 │ # Source hashes (both sides) and SHA256SUMS over the runs.
»    3 │ top=/root/exp/agent-work/u29-t1-a2dp-backport
»    4 │ cd "$top" || exit 1
     5 │ {
»    6 │   for side in base patched; do
»    7 │     for f in profiles/audio/a2dp.c profiles/audio/avdtp.c src/error.c src/device.c; do
»    8 │       echo "$side $(sha256sum "src/bluez-5.72-$side/$f")"
     9 │     done
```
[lines 12–17](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t1-a2dp-backport/scripts/sums.sh#L12-L17)
```bash
    11 │ } > "$top/source-hashes.txt"
»   12 │ find runs -type f -not -name '*.btsnoop' | sort | xargs sha256sum > "$top/SHA256SUMS"
»   13 │ find runs -type f -name '*.btsnoop' | sort | xargs sha256sum >> "$top/SHA256SUMS"
»   14 │ sha256sum source-hashes.txt src/upstream-patch/0001-a2dp-Fix-connection-error-message.patch >> "$top/SHA256SUMS"
»   15 │ git -C src/bluez-5.72 rev-parse HEAD > "$top/source-revisions.txt"
»   16 │ git -C src/bluez-5.72-patched rev-parse HEAD >> "$top/source-revisions.txt"
»   17 │ cat "$top/source-hashes.txt"
    18 │ 
```

#### [`results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/build.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/build.sh) — 8 uncovered of 8 coverable lines (0.0% run)

[lines 5–13](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/build.sh#L5-L13)
```bash
     4 │ # Log: logs/build.log
»    5 │ set -u
»    6 │ top=/root/exp/agent-work/u29-t2-temporary-lifetime
»    7 │ mkdir -p "$top/logs"
»    8 │ conf='./configure CFLAGS="-std=gnu17 -g -O2" --enable-tools --enable-testing --enable-experimental --enable-deprecated --enable-external-ell --enable-monitor --enable-client --disable-obex --disable-cups --disable-mesh --disable-midi --disable-manpages --localstatedir=/var --sysconfdir=/etc --prefix=/usr'
»    9 │ echo "configure line: $conf" > "$top/logs/build.log"
»   10 │ docker run --rm --name u29t2-build -v "$top/src/bluez-5.72:/b" -w /b co03-noble-build:1 sh -c "
»   11 │ make distclean >/dev/null 2>&1; $conf && make -j8; echo \"make exit \$?\"; ls -la src/bluetoothd emulator/btvirt tools/btmgmt monitor/btmon tools/test-runner client/bluetoothctl" \
    12 │     >> "$top/logs/build.log" 2>&1
»   13 │ tail -8 "$top/logs/build.log"
    14 │ 
```

#### [`results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/make-sums.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/make-sums.sh) — 5 uncovered of 5 coverable lines (0.0% run)

[lines 4–10](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/make-sums.sh#L4-L10)
```bash
     3 │ # logs) plus the source files and the binaries used.
»    4 │ top=/root/exp/agent-work/u29-t2-temporary-lifetime
»    5 │ cd "$top" || exit 1
     6 │ {
»    7 │     find runs scripts tests logs -type f ! -name '*.pyc' | sort | xargs sha256sum
»    8 │     sha256sum src/bluez-5.72/src/adapter.c src/bluez-5.72/src/device.c PROGRESS.log
     9 │ } > SHA256SUMS
»   10 │ echo "$(grep -c '' SHA256SUMS) lines"
    11 │ 
```

#### [`results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/run-all.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/run-all.sh) — 11 uncovered of 11 coverable lines (0.0% run)

[lines 6–21](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/run-all.sh#L6-L21)
```bash
     5 │ # Usage: run-all.sh
»    6 │ top=/root/exp/agent-work/u29-t2-temporary-lifetime
     7 │ chain() {
»    8 │     arm=$1
»    9 │     for n in 0 1 2; do
»   10 │         if [ -e "$top/runs/$arm-$n" ]; then
»   11 │             echo "skip $arm-$n (exists)"
»   12 │             continue
    13 │         fi
»   14 │         "$top/scripts/run-arm.sh" "$arm" "$n" || echo "FAILED $arm-$n"
    15 │     done
    16 │ }
»   17 │ for arm in A B C D E F; do
»   18 │     chain "$arm" &
    19 │ done
»   20 │ wait
»   21 │ echo "all chains done"
    22 │ 
```

#### [`results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/run-arm.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/run-arm.sh) — 12 uncovered of 12 coverable lines (0.0% run)

[lines 7–14](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/run-arm.sh#L7-L14)
```bash
     6 │ #         btmon-dut.log, *.btsnoop, events.jsonl, summary.json, command.txt)
»    7 │ set -eu
»    8 │ top=/root/exp/agent-work/u29-t2-temporary-lifetime
»    9 │ arm=$1
»   10 │ n=$2
»   11 │ run=$top/runs/$arm-$n
»   12 │ mkdir -p "$run"
»   13 │ echo "$0 $arm $n  (start $(date +%H:%M:%S))" >> "$top/PROGRESS.log"
»   14 │ cat > "$run/command.txt" <<EOF
    15 │ docker run --rm --name u29t2-$arm-$n --device /dev/kvm -v $top:$top -w $run \\
```
[lines 22–23](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/run-arm.sh#L22-L23)
```bash
    21 │ EOF
»   22 │ rc=0
»   23 │ docker run --rm --name "u29t2-$arm-$n" \
    24 │     --device /dev/kvm \
```
[lines 36–37](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/run-arm.sh#L36-L37)
```bash
    35 │     > "$run/stdout.log" 2>&1 || rc=$?
»   36 │ echo "$0 $arm $n  (end $(date +%H:%M:%S), exit $rc)" >> "$top/PROGRESS.log"
»   37 │ exit $rc
    38 │ 
```

#### [`results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/wait-all-done.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/wait-all-done.sh) — 8 uncovered of 8 coverable lines (0.0% run)

[lines 4–12](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-emulator-2026-11-07/u29-t2-temporary-lifetime/scripts/wait-all-done.sh#L4-L12)
```bash
     3 │ # usage: wait-all-done.sh [seconds]
»    4 │ max=${1:-540}
»    5 │ i=0
»    6 │ while [ "$i" -lt "$max" ]; do
»    7 │     n=$(docker ps --filter name=u29t2- --format '{{.Names}}' | grep -c .)
»    8 │     [ "$n" -eq 0 ] && { echo "no u29t2- container running"; exit 0; }
»    9 │     sleep 10
»   10 │     i=$((i + 10))
    11 │ done
»   12 │ echo "still running: $(docker ps --filter name=u29t2- --format '{{.Names}}' | tr '\n' ' ')"
    13 │ 
```

#### [`results/u29-gnome-pairing-feedback-2026-11-07/scripts/build-mr137.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-gnome-pairing-feedback-2026-11-07/scripts/build-mr137.sh) — 6 uncovered of 6 coverable lines (0.0% run)

[lines 3–8](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-gnome-pairing-feedback-2026-11-07/scripts/build-mr137.sh#L3-L8)
```bash
     2 │ # Second image: same Dockerfile, MR 137 diff applied unedited to the copy of the source.
»    3 │ A=/root/exp/agent-work/u29-g1-gnome-pairing-feedback
»    4 │ echo "$(date +%H:%M:%S) build-mr137 start" >> $A/PROGRESS.log
»    5 │ docker build --build-arg APPLY_DIFF=yes -f $A/docker/Dockerfile -t u29-gnome-bluetooth:mr137 $A > $A/runs/build-mr137.log 2>&1
»    6 │ rc=$?
»    7 │ echo "$(date +%H:%M:%S) build-mr137 end rc=$rc" >> $A/PROGRESS.log
»    8 │ exit $rc
     9 │ 
```

#### [`results/u29-gnome-pairing-feedback-2026-11-07/scripts/build.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-gnome-pairing-feedback-2026-11-07/scripts/build.sh) — 6 uncovered of 6 coverable lines (0.0% run)

[lines 3–8](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-gnome-pairing-feedback-2026-11-07/scripts/build.sh#L3-L8)
```bash
     2 │ # Build the image. Run from anywhere; uses absolute paths.
»    3 │ A=/root/exp/agent-work/u29-g1-gnome-pairing-feedback
»    4 │ echo "$(date +%H:%M:%S) build start" >> $A/PROGRESS.log
»    5 │ docker build --pull -f $A/docker/Dockerfile -t u29-gnome-bluetooth:master $A > $A/runs/build.log 2>&1
»    6 │ rc=$?
»    7 │ echo "$(date +%H:%M:%S) build end rc=$rc" >> $A/PROGRESS.log
»    8 │ exit $rc
     9 │ 
```

#### [`results/u29-gnome-pairing-feedback-2026-11-07/scripts/run-mr137.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-gnome-pairing-feedback-2026-11-07/scripts/run-mr137.sh) — 7 uncovered of 7 coverable lines (0.0% run)

[lines 4–10](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-gnome-pairing-feedback-2026-11-07/scripts/run-mr137.sh#L4-L10)
```bash
     3 │ # e.g.   run-mr137.sh mr137 out-mr137 AuthenticationRejected,AuthenticationFailed,AuthenticationCanceled 1
»    4 │ A=/root/exp/agent-work/u29-g1-gnome-pairing-feedback
»    5 │ mkdir -p $A/runs/$2
»    6 │ echo "$(date +%H:%M:%S) run-mr137 $1 start" >> $A/PROGRESS.log
»    7 │ docker run --rm -e ERRORS=$3 -e CONTROL=$4 -v $A/runs/$2:/out -v $A/tests:/work/tests:ro u29-gnome-bluetooth:$1 sh /work/tests/in-container-mr137.sh > $A/runs/$2.log 2>&1
»    8 │ rc=$?
»    9 │ echo "$(date +%H:%M:%S) run-mr137 $1 end rc=$rc" >> $A/PROGRESS.log
»   10 │ exit $rc
    11 │ 
```

#### [`results/u29-gnome-pairing-feedback-2026-11-07/scripts/run.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-gnome-pairing-feedback-2026-11-07/scripts/run.sh) — 6 uncovered of 6 coverable lines (0.0% run)

[lines 3–8](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-gnome-pairing-feedback-2026-11-07/scripts/run.sh#L3-L8)
```bash
     2 │ # Run the test in the container. Default network, no extra capabilities, no host sockets.
»    3 │ A=/root/exp/agent-work/u29-g1-gnome-pairing-feedback
»    4 │ echo "$(date +%H:%M:%S) run start" >> $A/PROGRESS.log
»    5 │ docker run --rm -v $A/runs/out:/out -v $A/tests:/work/tests:ro u29-gnome-bluetooth:master sh /work/tests/in-container.sh > $A/runs/run.log 2>&1
»    6 │ rc=$?
»    7 │ echo "$(date +%H:%M:%S) run end rc=$rc" >> $A/PROGRESS.log
»    8 │ exit $rc
     9 │ 
```

#### [`results/u29-gnome-pairing-feedback-2026-11-07/tests/in-container-mr137.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-gnome-pairing-feedback-2026-11-07/tests/in-container-mr137.sh) — 8 uncovered of 8 coverable lines (0.0% run)

[lines 3–10](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-gnome-pairing-feedback-2026-11-07/tests/in-container-mr137.sh#L3-L10)
```bash
     2 │ # Inside the container: compile the harness, run pair-failure-mr137-test.py under Xvfb.
»    3 │ export OUTDIR=/out
»    4 │ export HARNESS=/work/widget-harness
»    5 │ export LD_LIBRARY_PATH=/build/builddir/lib:/usr/local/lib64:/usr/local/lib
»    6 │ export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig
»    7 │ git -C /build/gnome-bluetooth status --short > /out/applied-state.txt 2>&1
»    8 │ grep -c "overlay" /build/gnome-bluetooth/lib/settings.ui > /out/settings-ui-overlay-count.txt
»    9 │ gcc -o /work/widget-harness /work/tests/widget-harness.c $(pkg-config --cflags --libs gnome-bluetooth-ui-3.0 gtk4 libadwaita-1) || exit 10
»   10 │ exec xvfb-run -a -s "-screen 0 1024x768x24" python3 /work/tests/pair-failure-mr137-test.py
    11 │ 
```

#### [`results/u29-gnome-pairing-feedback-2026-11-07/tests/in-container.sh`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-gnome-pairing-feedback-2026-11-07/tests/in-container.sh) — 13 uncovered of 13 coverable lines (0.0% run)

[lines 3–16](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/results/u29-gnome-pairing-feedback-2026-11-07/tests/in-container.sh#L3-L16)
```bash
     2 │ # Runs inside the container: compile the harness, run the test under Xvfb.
»    3 │ export OUTDIR=/out
»    4 │ export HARNESS=/work/widget-harness
»    5 │ export LD_LIBRARY_PATH=/usr/local/lib64:/usr/local/lib
     6 │ # GnomeBluetoothPriv is not installed (install: false); use the build dir
»    7 │ export LD_LIBRARY_PATH=/build/builddir/lib:$LD_LIBRARY_PATH
»    8 │ export GI_TYPELIB_PATH=/build/builddir/lib:/usr/local/lib64/girepository-1.0:/usr/local/lib/girepository-1.0
»    9 │ export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig
»   10 │ cat /etc/os-release > /out/os-release.txt
»   11 │ git -C /build/gnome-bluetooth log -1 --format=%H > /out/commit.txt 2>&1
»   12 │ meson --version > /out/versions.txt
»   13 │ pkg-config --modversion gtk4 libadwaita-1 gnome-bluetooth-ui-3.0 >> /out/versions.txt
»   14 │ rpm -q python3-dbusmock >> /out/versions.txt
»   15 │ gcc -o /work/widget-harness /work/tests/widget-harness.c $(pkg-config --cflags --libs gnome-bluetooth-ui-3.0 gtk4 libadwaita-1) || exit 10
»   16 │ exec xvfb-run -a -s "-screen 0 1024x768x24" python3 /work/tests/pair-failure-test.py
    17 │ 
```

</details>

## 8. awk: the statements that never ran

Programs are named as `devtools/awk-coverage` names them: `lib:<file>:<function>` for the libraries in `tools/lib/`, `prog:<file>#<hash>` for an awk program written inline in that file (search the file for the statement to find it). Statements, not lines: gawk's profile does not keep line numbers.

- `prog:tests/run-tests#332780  (4/5 statements)`
    - `print NR ": " NF " vs " n`
- `lib:tools/lib/trial-reclass.awk:reclass_treatment  (24/26 statements)`
    - `return t`
    - `return t`
- `prog:devtools/review-open#141421  (46/47 statements)`
    - `order[++np] = p`
- `prog:tools/bt-capdiff#078357  (10/11 statements)`
    - `next`
- `prog:tests/run-tests#274309 (+1 other caller)  (113/115 statements)`
    - `continue`
    - `nendo[boot]++`
- `prog:tests/run-tests#547544 (+1 other caller)  (100/103 statements)`
    - `next`
    - `next`
    - `note("usb: reset after descriptor errors (hub recovery)", "")`
- `prog:tests/run-tests#680884  (3/5 statements)`
    - `print i`
    - `exit`
- `prog:tests/run-tests#658627  (15/16 statements)`
    - `next`
- `prog:(unknown)#867649 (+1 other caller)  (1/2 statements)`
    - `print "numeric"`
- `prog:devtools/awk-coverage#192684  (53/54 statements)`
    - `continue`
- `prog:tools/bt-actions#886227  (173/175 statements)`
    - `cls = "WDOG"`
    - `lbl = "  controller answers after early intervention (counterfactual censored)"`
- `prog:tests/run-tests#305447  (1/2 statements)`
    - `print`
- `prog:(unknown)#271474 (+2 other callers)  (47/49 statements)`
    - `o[++n] = $0`
    - `next`
- `fn:devtools/awk-coverage#192684:name  (8/11 statements)`
    - `return scope`
    - `h = substr(rest, 1, index(rest, ":") - 1)`
    - `tail = substr(rest, index(rest, ":"))`
- `prog:devtools/awk-coverage#481852  (23/30 statements)`
    - `fn = s`
    - `sub(/^function[[:space:]]+/, "", fn)`
    - `sub(/[[:space:]]*\(.*$/, "", fn)`
    - `if (fn in own) {`
    - `scope = "lib:" own[fn] ":" fn`
    - `scope = "fn:" h ":" fn`
    - `idx = 0`
- `lib:tools/lib/stage2.awk:emit  (41/42 statements)`
    - `dur = 0`
- `prog:tests/run-tests#190974  (2/3 statements)`
    - `n++`
- `prog:tests/run-tests#720194  (4/5 statements)`
    - `print "line " NR ": " $0`
- `lib:tools/lib/actions-render.awk:flush  (10/11 statements)`
    - `printf "%-13s %-5s  %s\n                          x%d until %s (burst, %.2fs apart)\n", disp(ft), fc, fl, n, disp(lt), cad`

## 9. Python: the lines that never ran

| file | lines run | coverage |
|---|---|---|
| `bin/bt-capture` | 141 of 163 | 86.5% |
| `tests/btmon/real/mkcap.py` | 23 of 23 | 100.0% |
| `devtools/access-classify` | 307 of 337 | 91.1% |
| `devtools/mutants` | 227 of 254 | 89.4% |

#### [`bin/bt-capture`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-capture) — 22 uncovered of 163 coverable lines (86.5% run)

[lines 126–131](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-capture#L126-L131)
```python
   125 │     s = socket.socket(af, socket.SOCK_RAW, proto)
»  126 │     libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
»  127 │     addr = struct.pack("<HHH", af, HCI_DEV_NONE, HCI_CHANNEL_MONITOR)
»  128 │     if libc.bind(s.fileno(), addr, len(addr)) != 0:
»  129 │         err = ctypes.get_errno()
»  130 │         raise OSError(err, os.strerror(err))
»  131 │     return s
   132 │ 
```
[lines 188–189](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-capture#L188-L189)
```python
   187 │             os.unlink(victim)
»  188 │         except OSError:
»  189 │             pass
   190 │ 
```
[lines 200–201](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-capture#L200-L201)
```python
   199 │             os.unlink(victim)
»  200 │         except OSError:
»  201 │             pass
   202 │ 
```
[lines 255–258](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-capture#L255-L258)
```python
   254 │     if not prune(args.dir, args.keep, args.min_free_gb):
»  255 │         log(f"ERROR: still under {args.min_free_gb}GB with nothing left to prune.")
»  256 │         log("       Refusing to capture rather than filling the filesystem.")
»  257 │         log("       Free space, then: systemctl restart bt-capture")
»  258 │         return 1
   259 │ 
```
[lines 279–283](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-capture#L279-L283)
```python
   278 │             continue
»  279 │         except OSError as e:
»  280 │             log(f"ERROR: monitor socket read failed: {e}")
»  281 │             return 1
   282 │         if len(data) < 6:
»  283 │             continue
   284 │ 
```
[lines 312–314](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-capture#L312-L314)
```python
   311 │             out.write(rec + payload)
»  312 │         except OSError as e:
»  313 │             log(f"ERROR: write failed: {e}")
»  314 │             return 1
   315 │         written += len(rec) + len(payload)
```
[lines 337–337](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/bin/bt-capture#L337-L337)
```python
   336 │     except KeyboardInterrupt:
»  337 │         sys.exit(0)
   338 │ 
```

#### [`devtools/access-classify`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify) — 30 uncovered of 337 coverable lines (91.1% run)

[lines 59–59](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L59-L59)
```python
    58 │     else:
»   59 │         usage(f'unknown option: {a}')
    60 │ if not opts['--root'] or not opts['--scratch']:
```
[lines 86–86](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L86-L86)
```python
    85 │     except OSError as e:
»   86 │         usage(f'cannot read {opts["--allow"]}: {e.strerror}')
    87 │ not_asked = []      # the run's own report of the checks it did not ask
```
[lines 92–93](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L92-L93)
```python
    91 │             not_asked = [line for line in f if 'NOT ASKED HERE:' in line]
»   92 │     except OSError as e:
»   93 │         usage(f'cannot read {opts["--not-asked"]}: {e.strerror}')
    94 │ 
```
[lines 170–178](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L170-L178)
```python
   169 │     if name in TWO:
»  170 │         return [(d, unq(g(i))) for d, i in ((g(0), 1), (g(2), 3)) if unq(g(i)) is not None]
   171 │     if name == 'symlinkat':
»  172 │         p = unq(g(2))
»  173 │         return [(g(1), p)] if p is not None else []
   174 │     if name == 'symlink':
»  175 │         p = unq(g(1))
»  176 │         return [('AT_FDCWD', p)] if p is not None else []
   177 │     if name in ('rename', 'link'):
»  178 │         return [('AT_FDCWD', unq(g(i))) for i in (0, 1) if unq(g(i)) is not None]
   179 │     p = unq(g(0))
```
[lines 193–193](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L193-L193)
```python
   192 │     if dirfd != 'AT_FDCWD' or pr.cwd is None:
»  193 │         return None                     # relative to a descriptor this does not track
   194 │     return os.path.normpath(os.path.join(pr.cwd, p))
```
[lines 213–213](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L213-L213)
```python
   212 │                 if not c.own_cmd:
»  213 │                     c.cmd = pr.cmd
   214 │                 if not c.own_ns:
```
[lines 223–225](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L223-L225)
```python
   222 │     if name == 'fchdir':
»  223 │         if ok:
»  224 │             pr.cwd, pr.own_cwd = None, True     # a directory this does not track
»  225 │         return
   226 │     if name in SKIP:
```
[lines 240–240](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L240-L240)
```python
   239 │             if base == 'unshare' and any('n' in w for w in flags):
»  240 │                 pr.net = pr.own_net = True
   241 │             # Not pr.ns now: a vforked mount can log its whole execve before
```
[lines 260–260](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L260-L260)
```python
   259 │         if p == '':
»  260 │             continue                    # AT_EMPTY_PATH: the descriptor itself
   261 │         rp = resolve(p, pr, dirfd)      # before a chdir moves the base it is relative to
```
[lines 265–265](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L265-L265)
```python
   264 │     if name == 'chdir' and ok and pairs:
»  265 │         pr.cwd, pr.own_cwd = resolve(pairs[0][1], pr, 'AT_FDCWD'), True
   266 │ 
```
[lines 271–271](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L271-L271)
```python
   270 │     if not m:
»  271 │         continue
   272 │     pid, rest = int(m.group(1)), m.group(2)
```
[lines 286–286](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L286-L286)
```python
   285 │         if head is None:
»  286 │             continue
   287 │         rest = head + r.group(2)
```
[lines 296–296](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L296-L296)
```python
   295 │ if not events:
»  296 │     usage(f'{log} holds no file access — strace did not trace the run')
   297 │ 
```
[lines 376–377](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L376-L377)
```python
   375 │     if mode != 'write' and path.startswith(('/usr/local/bin/', '/usr/local/lib/', '/opt/')) \
»  376 │             and base not in PROJECT:
»  377 │         return 'host-software'
   378 │     if mode != 'write' and (path.startswith(PROBES) or path.endswith(('/pyvenv.cfg', '._pth'))):
```
[lines 381–387](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L381-L387)
```python
   380 │     if under(path, '/nonexistent'):
»  381 │         return 'declared-absent'
   382 │     if not ok and mode == 'read' and re.search(r'/(\.git(/.*)?|HEAD)$', path):
»  383 │         holder = re.sub(r'/\.git(/.*)?$|/HEAD$', '', path) or '/'
»  384 │         if holder in ANCESTORS or holder == '/':
»  385 │             return 'git-discovery'
   386 │     if mode != 'write' and path in ('/etc/passwd', '/etc/group', '/etc/nsswitch.conf'):
»  387 │         return 'identity'
   388 │     if path.startswith('/tmp/'):
```
[lines 394–394](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L394-L394)
```python
   393 │             return 'MACHINE' + d
»  394 │     return 'MACHINE/other'
   395 │ 
```
[lines 421–421](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/access-classify#L421-L421)
```python
   420 │     if path is None:
»  421 │         continue
   422 │     cl = classify(path, pr, mode, ok, call)
```

#### [`devtools/mutants`](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/mutants) — 27 uncovered of 254 coverable lines (89.4% run)

[lines 57–59](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/mutants#L57-L59)
```python
    56 │         if c == "#":
»   57 │             for k in range(i, n):
»   58 │                 live[k] = False
»   59 │             break
    60 │         if c == '"':
```
[lines 65–66](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/mutants#L65-L66)
```python
    64 │                 if text[i] == "\\":
»   65 │                     live[i] = False
»   66 │                     i += 1
    67 │                 if i < n:
```
[lines 79–80](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/mutants#L79-L80)
```python
    78 │                 if text[i] == "\\":
»   79 │                     live[i] = False
»   80 │                     i += 1
    81 │                 if i < n:
```
[lines 108–108](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/mutants#L108-L108)
```python
   107 │                 if text[s - 1:s] in ("-", ">", "<", "=") or text[e:e + 1] in (">", "<", "&"):
»  108 │                     continue
   109 │             for k in range(s, e):
```
[lines 146–147](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/mutants#L146-L147)
```python
   145 │                 if j < 0:
»  146 │                     i = n
»  147 │                     break
   148 │                 in_awk = in_sq = False
```
[lines 152–163](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/mutants#L152-L163)
```python
   151 │             if in_dq:
»  152 │                 j = i
»  153 │                 while j < n and line[j] != '"':
»  154 │                     j += 2 if line[j] == "\\" else 1
»  155 │                 if j >= n:
»  156 │                     i = n
»  157 │                     break
»  158 │                 in_dq = False
»  159 │                 i = j + 1
»  160 │                 continue
   161 │             if c == "\\":
»  162 │                 i += 2
»  163 │                 continue
   164 │             if c == "#" and (i == 0 or line[i - 1] in " \t;|&(`"):
```
[lines 174–174](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/mutants#L174-L174)
```python
   173 │                     else:
»  174 │                         in_sq = True
   175 │                     i = n
```
[lines 178–178](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/mutants#L178-L178)
```python
   177 │                 if starts_awk:
»  178 │                     awk_line(line[i + 1:j], found, i + 1)
   179 │                 i = j + 1
```
[lines 186–188](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/mutants#L186-L188)
```python
   185 │                 if j >= n:
»  186 │                     in_dq = True
»  187 │                     i = n
»  188 │                     break
   189 │                 i = j + 1
```
[lines 219–219](https://github.com/ivoitovych/qca9377-bt-hang/blob/c5defd7d94b75daa693ca44947c3c629822ed8c9/devtools/mutants#L219-L219)
```python
   218 │                         if frm in (">", "<") and (nxt in (">", "<", "=") or prv in (">", "<", "-")):
»  219 │                             continue
   220 │                         if frm in ("++", "--") and False:
```

## 10. What coverage does not count, and why (`devtools/coverage-exclude`)

Each exclusion is derived by content and checked on every run: an exclusion that matches nothing, or hides a line that ran, fails the gate. Challenge any of them.

```
devtools/coverage           # runs the suite under trace; cannot trace itself
devtools/check              # runs repo-validate and the suite
devtools/assert-test-catches  # runs the suite once per mutation, by design
devtools/mutate             # runs the suite once per mutant, in namespaces it builds; tested by its own --self-test (every run, and a CI step); its proposal (devtools/mutants) is tested by the suite
devtools/sandbox            # runs the suite inside namespaces it builds; tested by its own --self-test
reviews/verify.sh           # runs the suite and coverage to check the register
tests/system-roundtrip      # CI-gated install/revert; must not run by accident
tests/system-upgrade        # CI-gated: the investigation machine's deploy, rehearsed; same gate
tests/run-tests:/^(\|\| *)?bad /   # failure branches: unreachable in a green run
tools/bt-actions:93-274     # inline classifier; see devtools/awk-coverage (re-derived 2026-09-24: 9373e62 moved the file by +7)
tools/bt-actions:288-294    # inline MGMT-intent extractor; same (295, its closing line, runs since 2026-09-29: pass 2 is now driven)
tools/bt-sco:117-125        # inline request/completion block filter; same (re-derived 2026-10-19: +2, the Enhanced comment)
tools/bt-capdiff:88-108     # inline record extractor; same
tools/sanitize-logs.sh:142-191  # inline substituter and its verifier; same
tools/bt-boot-list:69-74    # inline JSON boot-index reader; same
tools/bt-env-history:82-91  # inline metrics.tsv column reader; same
tools/bt-logvolume:110-114  # inline message normaliser; same
tools/bt-logvolume:116-121  # inline share renderer (same pipeline, second program)
tools/bt-trial:274-278      # inline trial-number counter; same (re-derived 2026-09-29: +3, the btusb seam comment; +21, main's module_build and KJ_RE; main re-derived it 2026-10-03, +15, for its own tree; unmoved by the merge of 2026-10-03's main — the range starts at the `n=$(awk` line and stops before the closing `END …)`, the line bash attributes the command to)
tools/bt-trial:1089-1097    # inline sco-params window filter; same (re-derived 2026-09-19 (+16), 2026-09-20 (+12, the abort/autostop edits), 2026-09-24 (+37, dbe7123), 2026-09-29 and 2026-10-03 on each branch, by content at the merge, and 2026-10-16 (-2, the close's extras moved after the row), and 2026-10-18 (the decode itself moved after the row, by content), and 2026-10-19 (+3, the --columns comment) — R2-112; CI's stale-exclusion check caught the old range covering live code each time. The range is btmon-line+2 … +10, the program's body: the `echo` after it runs since a test decodes a capture (2026-09-29))
tools/bt-verify-install:57-60   # inline install_file parser; same
tools/bt-ctrl-window:38-77      # inline management-record decoder; same — `btmon … | awk` reports the line the pipeline starts on, so 37 runs (2026-10-10; +2 on 2026-10-19, the --columns comment)
tests/run-tests:162-167       # inline --section extractor; same (re-derived 2026-09-28: +27, the git-isolation block above it; 2026-09-29: +126, the machine tripwire, the declared machine and the run marker; then +11, the declared usbfs and runtime-user roots; 2026-10-08: +13, the nested-run refusal; 2026-10-09: moved to the top, before anything is declared; 2026-10-18: +26, by content, the --jobs block above it; then +2, by content, the instruments' note)
tools/bt-verify-kernel-mechanism:138-147  # inline byte-aligned device-id matcher; same (+3 on 2026-10-09: the TMPDIR note above it)
devtools/awk-coverage:210-251  # inline profile reader; same — measured by itself, against the suite's toy suite (2026-10-08; +2 by content on 2026-10-18, the --serial comment; then +2, its parallel note)
devtools/awk-coverage:292-358  # inline report; same (+2 by content, 2026-10-18; then +2)
devtools/review-open:35-70    # inline register reader; same — driven in the checkout world (2026-10-08)
tools/bt-health-report.sh:93-93    # --list-boots fallback: only when bt-boot-list is not beside the script
tools/bt-health-report.sh:235-235  # no-baseline branch: exercised only through the temp-tree copy
tests/run-tests:646-652     # inline footprint differ; driven and pinned by the assertion above (re-derived 2026-09-28 from the trace, not by arithmetic; 2026-09-29 by content, the differ now compares every field; then +11 by content, the declared usbfs and runtime-user roots; 2026-10-08 +13 by content, the nested-run refusal; 2026-10-09 +25 by content, the --section block above it and the declared home; then +29, the declared host state and seams; then +2, real_tool's note on env; 2026-10-17 +5 by content, the tripwire chain comment; 2026-10-18 +28 by content, the --jobs block and the trap's worker stop; then +2 by content; 2026-10-28 +10 by content, the journal seams' declaration)
tests/run-tests:/while IFS= read -r p; do bad /   # the two damage reports: reached only when
tests/run-tests:/^ *bin_footprint_diff "\$(REPO|BIN)_FOOTPRINT_BEFORE"/  # something actually changed
tools/bt-window:88-90       # inline timeout/USB counter; counts asserted from a fixture
tools/bt-window:110-112     # inline intervention counter; same
tools/bt-retention:92-98    # inline JSON boot-range reader; the trace lands on the fi at 99
tools/bt-retention:113-113  # text-form reader's process substitution; trace lands on the fi at 114
```

Out of scope, as not shipped: for bash coverage `scripts/`, `retest/`, `patches/`, `docs/mesh-tester-ci/` and `contributions/`; for Python coverage `scripts/`, `retest/`, `patches/`, `contributions/` and `results/`.
## Appendix A. The bare `case` labels left out of the listings

File and line, at this commit; each is a pattern-only line that bash never traces.

- `bin/bt-dyndbg`: 115, 138, 143, 152
- `bin/bt-evidence`: 98, 131, 140, 152, 219, 228
- `devtools/ci`: 279, 284, 289
- `devtools/held`: 24, 43, 65, 72, 76
- `devtools/test-comprehension`: 266
- `tests/run-tests`: 2521, 2523, 2535
- `tools/bt-trial`: 336, 343, 369, 432, 466, 476, 815, 817, 1140, 1177, 1208
- `tools/bt-trial-audit`: 272, 278
- `tools/bt-ui-capture`: 258, 356, 362, 367, 676

