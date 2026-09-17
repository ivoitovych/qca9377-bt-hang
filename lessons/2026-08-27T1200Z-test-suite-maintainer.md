# Lessons — test-suite maintainer, second milestone

**Covers 2026-08-22 → 2026-08-27.** The first entry
([`2026-08-22T1101Z`](2026-08-22T1101Z-test-suite-maintainer.md)) covered
building the suite. This one covers what happened when the suite stopped being
the work and became the *instrument* for something else: resolving a crash in a
stripped binary, preparing two patches for upstream, and repeatedly getting the
epistemics wrong in ways the suite's own house rules caught.

Same contract as before: rule, the instance that taught it, and what it cost.
Where a lesson extends one from the first entry I say so rather than restating it.

---

## 1. "Blocked" is not one thing, and the difference is the whole answer

**The rule.** A failure to reach something is a *symptom*. Before recording
anything as unavailable, determine which failure it is — they have completely
different remedies and at least one of them is not a failure at all.

Four modes are live in this project and they are indistinguishable from the
status code alone:

| mode | what it looks like | does a user-agent change help? |
|---|---|---|
| **CONNECT tunnel refused** | `curl: (56) CONNECT tunnel failed, response 403` | **No** — no request is sent, the origin never sees a UA |
| **An HTTP status from something that answered** | a real `403` **with a body**, and the body says what it is | **No** — read the body |
| **Wrong protocol to the same host** | `curl` fails, `git` succeeds | n/a — use the other protocol |
| **UA filter fronting a JS challenge** | `curl` 403, browser 200, body titled *"Making sure you're not a bot!"* | Yes, but only a real browser passes |

**The instance.** I recorded `github.com` as blocked on the strength of a `403`.
The body said, in plain words, that it was this session's own per-repository
authorisation gate. I never opened it. Meanwhile:

```console
$ git ls-remote --heads https://github.com/bluez/bluez.git
68cf12fa3ae5…  refs/heads/1134469
```

`git` traffic goes through a different proxy from `curl`. **BlueZ master was
clonable the entire time**, including every hour I was asking the other
maintainer to check it for me.

Independently and in the same days, the main branch maintainer recorded
`lore.kernel.org` as unreachable from the same kind of evidence. It was a
user-agent block. The operator opened it in a browser and settled the question
in under a minute.

**What it cost.** Several rounds of the other maintainer acting as my proxy for
work I could have done locally, and — worse — a caveat about our tooling written
into a patch that was going to be sent under someone else's name. See §6.

**Recorded in** [`docs/source-access.md`](../docs/source-access.md).

---

## 2. A tool's negative answer describes the tool, not the world

**The rule.** Same family as §1 and worth stating separately because it does not
involve a network. When a tool says *"not found"*, establish that it was *able*
to look before believing it.

**The instance.** Verifying a prior-work citation needed a commit from 2020.
My clone was `--depth 50`:

```console
$ git log -1 --stat 90a600895
fatal: ambiguous argument '90a600895': unknown revision or path not in the working tree
```

That reads like *"no such commit"*. It means *"not in my clone"*. Unshallowing to
29,242 commits produced the commit immediately, and it turned out to be the most
load-bearing citation in the patch — the same code path, not merely a similar
one.

**What it cost.** Nearly a withdrawn citation. Had I reported "cannot confirm",
the patch would have shipped weaker on the strength of my clone depth.

**This is §6 of the first entry generalised.** There it was *zero from a capped
scan is not a result*. Here it is the same shape with a different tool: **a
bounded search reporting absence is reporting its bound.**

---

## 3. Resolving a crash in a stripped binary — the method, since it worked

**The rule.** Missing debug symbols do not mean an unresolvable crash. Three
things survive stripping and are enough between them:

1. **`.eh_frame`** — unwind info, giving exact function start/end addresses
   (3,239 of them in `bluetoothd`);
2. **`.dynsym` + `.rela.plt`** — every PLT call target is still named;
3. **the binary itself**, if the distribution publishes it.

A function can then be fingerprinted by **size + the multiset of its call
targets**, matched against a symbolised build of a *neighbouring* version, and
confirmed against the disassembly and the source.

**The trap that costs an hour if you do not know it.** The kernel's segfault line
has a three-value form:

```
in bluetoothd[367e5,60ff12bd7000+f3000]
              ^      ^            ^
              |      |            +-- mapping size
              |      +--------------- mapping start
              +---------------------- FILE OFFSET of the faulting instruction
```

The first value is `ip - vm_start + (vm_pgoff << PAGE_SHIFT)`. It is **not**
`ip - vm_start`. Reading it the obvious way sends you to the wrong function
entirely.

It is also a free integrity check on the binary you downloaded: recompute it, and
if your copy's executable segment does not reproduce the reported mapping size,
you do not have the build that crashed.

**Do not carry addresses across builds without measuring.** Two builds of the
same upstream version, same total size, looked interchangeable. They were not:

```
first differing byte in exec segment: 0x28286
differing bytes: 927682 of 991277  (93.585%)
```

**Publish the identification with a prediction attached.** The method could
produce a confident wrong answer, so the claim shipped as: `%r13` holds NULL and
the faulting instruction is `mov 0x10(%r13),%rdi`. Neither was visible to the
method that produced it. From a retained core:

```
r13   0x0
rip   0x635d944b47e5
=> 0x635d944b47e5:  mov 0x10(%r13),%rdi
```

**A method that predicts a register value and an instruction encoding it never
saw, and is right, is worth citing.** A maintainer will reasonably ask how a
crash site was located in a binary whose symbols were never published.

**Distribution note that made all of this possible:** debug symbols for the exact
running version did not exist for amd64 — the vendor published them for five
other architectures and not that one. Confirmed against the package indices, not
a directory listing. The neighbouring version's symbols existed and were useless
(see the 93.6% above); the method above was the way through.

---

## 4. The difference between "an example of X" and "a demonstration that X happened"

**The rule.** When a mechanism *could* produce the observation, that is a
hypothesis. Writing it as the mechanism is an overclaim, and it is the easiest
one to make because the reasoning genuinely is sound as far as it goes.

**The instance — mine, caught by an external reviewer.** I wrote that a crash's
mechanism was "fully determined": that the parameter is NULL whenever a request
completes without parameters, and that a specific event was the one received.
Both wrong. Checking the dispatcher:

```c
/* Command Complete */
request_complete(mgmt, cc->status, opcode, index, length - 3,
                                mgmt->buf + MGMT_HDR_SIZE + 3);   /* NEVER NULL */
/* Command Status */
request_complete(mgmt, cs->status, opcode, index, 0, NULL);       /* NULL */
```

One path passes a real pointer even at zero length. So the broad claim is false,
and naming the other path as *the* event was a hypothesis dressed as a finding.
The reviewer also found a third route I had not considered — the dispatcher falls
back to matching on **index alone** when the primary match misses, so a
completion for a *different* command can reach the callback.

**What survives, and it is enough:** the branch was entered with a success status
and a NULL parameter. The fix does not depend on which event produced that.

**What it cost.** A commit message that would have been sent upstream asserting a
mechanism we cannot evidence — the exact thing that gets a patch discounted.

**The general form:** if the finding would still hold with the mechanism removed,
remove it. The narrower claim is usually the stronger one.

---

## 5. Reading absences — extends §6 of the first entry

The first entry established *zero is dangerous*. This milestone produced the
sharper version, and it now has a name in the project's history: the three
successive milestones were misreading **observations**, then **failures**, then
**absences**.

**The rule.** A quiet run is not a result. Before *"it did not fail"* means
anything, something must show the system was **asked** to fail — and the counter
that shows it has to be in the summary, or the question never gets asked.

**The instance.** A patched daemon ran 7 h 56 m with zero crashes, against three
crashes in roughly twenty hours unpatched. That comparison is worth nothing:
there is no reproducer, so there is no denominator. And the decisive number was a
different zero — **the guards fired zero times**, so the protected paths were
never reached and the run does not test the patches' behaviour at all.

Then the fault reproduced, and the same run showed **zero synchronous-link setups
and zero alternate-setting switches** — so the trigger could not have occurred.
*"It did not die"* had a simpler explanation than the fix: it was never asked to
do the thing that kills it.

**The design consequence, which is the actually useful part.** A patch that
prevents a crash leaves **no trace by default** — the daemon simply does not die,
indistinguishable from the conditions never recurring. Both patches log before
they bail, so **the message is the observation**. The snapshot tool now cuts
those lines and labels the zero case explicitly:

```
patch guards fired      0  (0 = no crash prevented AND none occurred)
```

That parenthesis is load-bearing and the suite now pins it, because it is exactly
the sort of thing a later tidy-up removes as redundant.

**And a counter an exhibit leans on must be tested.** Two counters were
designated as *the* check for whether a future reproduction attempt counts at
all, and had no assertions whatsoever. A number that is load-bearing for the next
experiment and verified by nothing is the shape this project has been burned by
repeatedly.

---

## 6. A caveat in a deliverable is a defect exported to a third party

**The rule.** A limitation of *your* environment has no place in a document that
goes out under someone else's name. It is not humility; it reads as the author
admitting they skipped the work.

**The instance.** I wrote *"I have not been able to search the list archives"*
into a patch commit message, then — after being corrected once — *"unreachable
from here."* Two things wrong with the second: a maintainer reading it has no idea
what "here" is, and a sentence about our network is not information about the
defect. Both were removed. Then the underlying limitation turned out not to exist
(§1), so there was nothing to caveat in the first place.

**The rule that recovers the situation, and it is the operator's:** when
something is blocked for one participant and trivial for another, **ask**. The
archive question was settled with a browser in under a minute after several
exchanges of my asserting it could not be done.

---

## 7. Preparing patches for a project you are not a member of

Collected because none of it is obvious from inside a private repository, and all
of it was learned by having each item corrected.

- **Cite what the project's own history shows you.** The defect's introducing
  commit was findable (`git log -S` over the file), and the target file's recent
  history carried accepted fixes of the same shape. Both are worth more than any
  argument we could construct.
- **Prefer the closest prior work, and verify it rather than citing from
  memory.** The first citation was "a similar bug once." The better one — found by
  actually reading the history — introduced *the very function* the faulting code
  calls. "Both ends of this path were revisited and neither ruled out the NULL"
  is a categorically stronger sentence, and it is checkable.
- **Match the project's conventions by measuring them**, not by assuming. A
  `Fixes:` trailer was appropriate here because the project uses them — 18 in the
  last 400 commits, in a specific 12-character form.
- **Two related patches are not automatically a series.** They shared an
  investigation, not a dependency, so they go as two standalone mails. A range
  invocation would have numbered them `1/2` and `2/2` and presented them as
  something they are not.
- **Trim to the evidence that justifies the change, not the route to it.** The
  story of how a crash site was found is interesting; most of it belongs in the
  repository, not the commit message.
- **Say what you did not establish.** "Not fixed in master as of `<commit>`" is
  provable. "Never reported" is not, unless the archives were actually searched —
  and the distinction is the first thing a maintainer who knows better will notice.
- **A `Signed-off-by` is a statement by the sender and is not transferable.**
  Whoever actually sends must put their own there.

**Verification a patch should carry before it goes anywhere:** applies to
pristine source; applies via `git am` (the real submission path, and a stray
`---` in the message body silently truncates everything after it); each patch
applies **alone** as well as together; the translation units compile; no new
compiler warnings.

---

## 8. Dating a behaviour change, and why "older" is not automatically "cleaner"

**The rule.** When a fault is suspected to follow a change, date the change to a
commit and then check the behaviour on **both** sides of it — including far
enough back that the old behaviour may return by a different route.

**The instance.** A driver behaviour was correctly dated between two releases,
and the proposed experiment was "any kernel at or before the earlier one should
not take this path." True for a four-release window. **False below it**, where
the same path is reachable again by a completely different mechanism, because the
concept the current code branches on did not exist in the source yet.

So an older kernel is not a cleaner control — it is a *confounded* one, and would
produce something that looks like a reproduction while exercising different code.

**The general form:** a bisect-style claim needs the window stated at **both**
ends. "Before version X" is almost never the right shape; "between X and Y" is.

**Two practical notes.** The distribution's source package for a hardware-enablement
kernel is a **different package** from the base one — genuinely different files
with different checksums — and reading the wrong one gives plausible-looking
output, which is why it survives review. And the change's own commit message is
frequently better evidence than anything you can assemble: the one here states, in
its author's words, that they *"have been unable to find any"* adapter supporting
the recommended mode, and leaves an explicitly empirical assumption in a comment
that is still in the tree. A device that contradicts that sentence is a far better
report than "the driver picks a bad setting."

---

## 9. Measuring from the wrong event

**The rule.** Before believing a distribution, check what it is anchored to. A
correctly computed statistic over a wrongly chosen origin is not noisy — it is
*confidently wrong*, and it looks like a real finding.

**The instance.** An interval this project measured repeatedly came out as a wide
spread: 4.1, 7.6, 16.2, 55.2, 155.8 s. It had been anchored on whichever *named*
command happened to time out. Anchored instead on the *answered* setup that
precedes the fault, two independent instances — different peripheral, different
kernel, three days apart — agree within **76 ms**.

n=2 cannot establish that the spread was an artefact. It is enough to stop
assuming the opposite, and to fix the anchor for future captures: the **first**
qualifying event in a window, not the last.

**Why this belongs in a lessons file rather than an exhibit:** it is the same
error as §1, §2 and §5 in numerical clothing. Every one of them is a real,
correctly obtained value, anchored to the wrong thing:

| the value | anchored to | what it looked like |
|---|---|---|
| the interval | whichever named command died | a wide random distribution |
| a `403` | the status code, never the body | a network wall |
| `unknown revision` | a clone of depth 50 | "no such commit" |
| a guard count of `0` | a run that never took the path | "the fix did nothing" |
| eight quiet hours | a system never asked to fail | evidence the fix worked |
| a green check | an assertion nothing could break | a verified invariant |

---

## 10. A sixth check that could not fail

§4 of the first entry recorded five. Here is the sixth, and the pattern held
exactly as described there — it tested something *correlated* with the property
rather than the property.

The check asserted that a summary count was right, by counting the lines of the
file the summary names:

```bash
[[ "$(grep -c . "$D/f-guard.log")" == 2 ]]
```

It never reads the tool's output at all. Hardcoding the count inside the tool left
it green. Rewritten to compare the number the tool **prints** against the file it
**names**, and confirmed by mutation:

```
✗ count/cut disagree: reported '99', file has '2' lines
```

**The distinction worth carrying:** *the count is correct* and *the reported count
equals the thing it claims to count* are different assertions, and only the second
is a check. The mutation is the only reason this was found, six times running.

---

## 11. Working alongside other maintainers with asymmetric access

Not process for its own sake — each of these was learned by getting it wrong.

- **Availability is a property of who is asking, not of a file.** The same host
  answers in 0.24 s for one participant and refuses another. A shared cache with a
  committed manifest — artefact outside the tree, checksums and source URLs
  inside — turns "can you fetch X" into a fact about a file.
- **Verify the checksum against the publisher's own declaration**, not against
  itself. A source package ships its checksums in a signed-adjacent file; check
  the download against that and record the result.
- **Route needs to whoever can actually satisfy them, and say what each one
  settles.** A request that names the command to run and what its answer decides
  gets answered; a general "can you look into X" does not.
- **Ask for the check that could destroy your own claim.** The most valuable thing
  I asked for in this milestone was a single command against a retained core that
  would have falsified my crash-site identification. It held — but the value was in
  offering it, and it is the reason the result is now usable in a public report.
- **Findings accumulating in the repository are not communicated.** I let several
  land in commits without going through the message channel, and the other
  maintainer kept working from a stale picture — including spending their turns
  proxying access I had all along. Commit messages are a record; they are not a
  handoff.
- **When a change lands in a tool you own the tests for, it arrives untested.**
  Twice a collaborator added instrumentation and the tests were mine to write. The
  gap between "someone added a counter" and "something verifies the counter" is
  where load-bearing numbers rot.

---

## 12. What I would tell someone picking this up tomorrow

1. **Read `lessons/2026-08-22T1101Z` first, then §4 and §6 of it twice.** Every
   new lesson in this document is one of those two wearing a different costume.
2. **Write the mutation before the check.** If you cannot state what would make
   an assertion fail, it does not check anything. Six for six.
3. **Any zero, any "not found", any silence — establish the instrument could
   have seen it.** Positive control first, then believe the number.
4. **Never record an access failure without diagnosing which kind it is.** Four
   modes, four different remedies, one status code.
5. **Publish claims with their falsifier attached.** It costs a sentence, and it
   is the only reason anything here survived contact with review.
6. **Anything going out under someone else's name gets the caveats about your
   own environment stripped.** If a limitation is real, fix it or ask someone who
   can; do not export it.
