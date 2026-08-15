# Why the suite took 52 seconds, and what it takes to stop

**Written** 2026-08-15T00:18Z · **Covers** the tree at `ce854c0`, rebased onto `be082d1`
· **Opened by** the observation that the suite runs for a long time

**Verdict.** 52 seconds for 497 assertions, and **81% of it was spent waiting on clocks
rather than doing work**. None of the waiting was necessary. It is now 28 seconds, and
the three changes that got it there each fixed a correctness problem as a side effect —
which is the useful part of the finding, not the seconds.

---

## 1. Where the time was

Measured by timestamping every line the suite prints and differencing the section
headings. Not estimated.

| section | before | after |
|---|---|---|
| `bt-hang-watchdog` | **27.5 s** | 1.0 s |
| `bt-usbmon` supervision loop | **9.3 s** | 1.2 s |
| `bt-trace` supervision loop | **5.4 s** | 5.4 s |
| publish gates (scratch repos) | 2.2 s | 2.3 s |
| `bt-trial` lifecycle | 1.9 s | 2.2 s |
| installer round trip | 1.5 s | 1.9 s |
| everything else (≈40 sections) | ~4 s | ~4 s |
| **total** | **51.8 s** | **27.5 s** |

Four hundred and ninety-seven assertions, and about forty of them accounted for four
fifths of the runtime. The rest of the suite — every fixture, every awk case, every
refusal path — runs in roughly four seconds.

---

## 2. The cause, which is one cause

**Every expensive test waited on a clock instead of on the thing it was asserting.**

`bin/bt-hang-watchdog` reads its journal with `-f`, so it never ends on its own. A
scenario is over when the line under test has been printed — but the tests were written
as `wd_run 10`, `wd_run 15`, a `timeout` ceiling. With the controller dead and no
cooldown the watchdog retries until something kills it, so those two scenarios spent
**18 of the 52 seconds** observing messages that appeared in the first tenth of one.

Measured per scenario, which is what made it obvious:

```
timeout 10   actual  0.07 s   (base)
timeout 3    actual  3.01 s   BT_COOLDOWN=0 BT_MAX_FAILS=1
timeout 10   actual  0.06 s   BT_EARLY=1
timeout 10   actual  0.08 s   BT_VERBOSE=1
timeout 15   actual 15.01 s   BT_MAX_FAILS=1 BT_COOLDOWN=0     <- mine
```

A fixed timeout is also the *weaker* assertion. It passes whenever the message appears
within the ceiling, and it cannot distinguish "the message never appeared" from "the
clock ran out" — both look the same from outside.

---

## 3. What changed

**`wd_until <marker> <max-tenths> [env…]`** — run the watchdog, poll its output, stop the
moment the marker appears. Faster and stricter: it fails if the marker never appears at
all, where the timeout version only failed if the whole run outlasted the ceiling.

One assertion had to be restated rather than translated. It read

```sh
[[ "$GOUT" == *"idling"* ]] && (( grc == 124 ))     # 124 = killed by `timeout`
```

— inferring "the watchdog idles rather than exiting" from `timeout`'s exit code. The
helper now records whether the process was *still running* when it was stopped, which is
the property that sentence actually claims. `124` only says the clock won a race.

**Poll for the observable being asserted, not for a proxy.** The capture-daemon tests
waited for a log line and then slept for the file to appear. Tightening the check
interval lost that race and the tests failed — correctly. They now wait for the file
count and for the gap-log entry themselves. A sleep that is long enough today is a false
pass tomorrow.

---

## 4. Two product defects the timing work exposed

Neither was found by reading. Both were found by making the tests faster.

**`bt-usbmon` dropped gap records under a fractional check interval.** The gap bound was
computed with `$(( CHECK_SEC + 5 ))`, and bash arithmetic is integer-only: a fractional
`BT_USBMON_CHECK_SEC` made the expansion fail, the `printf` never ran, and the entry
silently disappeared — in the one file whose job is to admit when the capture was not
looking. A gap log that drops entries under some settings is worse than no gap log,
because its silence reads as coverage. Now computed with awk.

**`bt-usbmon` deferred SIGTERM through its restart backoff.** After a capture process
dies the loop waits five seconds before restarting, and bash defers a trapped signal
until the running foreground command returns — so `systemctl stop bt-usbmon` during a
backoff waited out the full five. This is the same defect already fixed in `bt-trace`'s
disk-floor idle loop, where it was an hour rather than five seconds. `sleep 5 & wait $!`
is interruptible.

That makes **three** instances of one bash behaviour in this repository. It is worth
stating as a rule rather than fixing case by case: *a foreground `sleep` in a process
that installs a signal trap makes that trap unreachable for the duration of the sleep.*

---

## 5. What is left, and what it would cost

**`bt-trace` at 5.4 s** is the only expensive section remaining, and it is bounded by the
daemon rather than by the test. Its loop does `elapsed=$(( elapsed + POLL_SEC ))`, so
`POLL_SEC` must stay an integer, and the size check happens at most once per second. The
three scenarios need one rotation, one crash and one disk-floor stop, so ~1 s each is the
floor without changing the tool.

Making it faster means making `POLL_SEC` fractional in the product, which means replacing
that arithmetic. That is a real change to a capture daemon to save four seconds of test
time, and the trade is not obviously worth it. **Recommended: leave it.**

Three cheaper things, if the number matters more later:

| | saves | cost |
|---|---|---|
| Run independent sections in parallel (`--section` already isolates them) | ~15 s | the output interleaves; needs per-section buffering, and UT-12 (splitting the file) first |
| Reuse one staging root across the installer scenarios instead of four | ~1 s | weakens the "install into an EMPTY root" property; **not recommended** |
| Drop the second `stage_install` (the re-install case) | ~0.6 s | loses the stamp-preservation and overwrite-warning assertions; **not recommended** |

**The honest summary of the remaining 28 seconds:** about 10 of them are three daemons
being genuinely run — started, driven, rotated, crashed, signalled and stopped — and that
is the part of this suite that finds defects a fixture cannot. The other 18 are spread
across 497 assertions at roughly 35 ms each. There is no large win left that does not
cost coverage.

---

## 6. The thing worth remembering

Every one of the slow tests was slow because it waited for time to pass instead of for a
condition to hold, and every one of them was *also* a weaker assertion for the same
reason. The timeout that cost fifteen seconds could not tell a missing message from a
slow one; the sleep that cost one second was a coin toss that had been landing the right
way. Making them fast and making them correct turned out to be the same edit.
