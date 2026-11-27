# Part 2: from the defects we met to the whole Bluetooth subsystem (2026-11-23)

**Follows** [`part-1-the-suites-that-would-have-caught-these-defects.md`](part-1-the-suites-that-would-have-caught-these-defects.md).
That page started from the defects this project found and asked which test would have caught
each. It is therefore shaped by one laptop, three headsets and one user's habits. This page
starts from the other end: **a map of everything the subsystem does**, and a way to derive
the tests from the map so that what is covered is known and what is not is visible. It is a
design opinion; one measurement was taken (below), nothing was run.

## Contents

1. The idea in one page
2. One measurement: how large the thing is, and how much of it is exercised today
3. The map: six inventories that together are the subsystem
4. From the map to the tests: the five generators
5. Coverage: how to know what is covered
6. How the seven suites of part 1 fit in
7. Order of construction, and who would own what
8. Limits

## 1. The idea in one page

A suite built from past defects protects against their return. To protect against the
defects not yet met, the tests must come from a **description of the subsystem**, not from
its history. The subsystem can be described completely by six inventories, each of which
already exists in the source in some form and can be extracted by a script:

1. the **commands and events** at each boundary (HCI, the management interface, the socket
   options, the D-Bus methods and signals, the profile protocols' messages);
2. the **objects** and their **states** (adapter, connection of each kind, channel,
   advertising set, discovery, pairing, transport, endpoint, stream);
3. the **endings** each object can meet (closed by the user, by the peer, by loss of the
   link, by power-off, by removal, by suspend, by the death of the process that owned it);
4. the **configurations** (controller features and quirks, transports and their drivers,
   daemon options, kernel lines);
5. the **peers** (roles and profiles, and the documented ways a peer may behave);
6. the **failures** (each error a lower layer may return, a missing answer, a late one,
   allocation failure).

A test is then a point in the product of these: *operation X on object O in state S, under
configuration C, with peer P, ended or disturbed by E or failing by F*. Nobody writes the
product by hand. **Five generators** walk it (section 4), and a small set of **invariants**
gives the verdict, so that no expected output is written per case. Coverage is the share of
the map that has been walked and is reported per inventory (section 5): not "lines
executed", but "of 335 commands, how many were sent in each state; of the states of a
connection, how many were ended in each of the seven ways".

The defects this project found are then not the design input but the **acceptance test of
the design**: a generated suite that does not rediscover CO-02, BT-9, BT-21, the mesh
lifetime defects and the btusb resume defects on an old tree is not finished.

## 2. One measurement

Counted on 2026-11-23 in BlueZ master (`1adfe662e`) and bluetooth-next (`cf357cfc02`), with
`grep` on the named files; rough, and meant only to give the sizes.

| what | count | where counted |
|---|---|---|
| HCI commands known to BlueZ's protocol header | 335 | `monitor/bt.h` |
| HCI commands the emulated controller answers | 213 | `emulator/btdev.c` |
| HCI events known | 119 | `monitor/bt.h` |
| tester cases, all testers together | about 1,000 (mgmt 529, iso 213, l2cap 144, sco 30, ioctl 28, hci 18, rfcomm 11, mesh 10, 6lowpan 9, smp 8, userchan 4, bnep 1, gap 1) | `tools/*-tester.c` |
| unit test programs | 42 | `unit/` |
| D-Bus interface documents | 55 | `doc/` |
| kernel protocol source files / driver source files | 36 / 39 | `net/bluetooth`, `drivers/bluetooth` |
| controller quirk flags | 34 | `include/net/bluetooth/hci.h` |
| device-table lines in the USB driver | about 400 | `drivers/bluetooth/btusb_main.c` |

Three things can be read off without running anything.

- **A third of the commands cannot be tested at all today**: 122 of 335 have no answer in
  the emulated controller, so no kernel path that sends them is reachable by any tester.
- **The tests are very unevenly spread**: the management interface has 529 cases, security
  (SMP) has 8, RFCOMM 11, BNEP 1. The spread follows who wrote tests when, not where the
  risk is. SCO, where this project found its most serious kernel defect, has 30.
- **Thirty-four quirks times about four hundred devices** is the configuration space of the
  USB driver alone, and the testers run one configuration: the emulated one, with no driver.

About a thousand cases for a subsystem of this size, all of the form "one operation, one
answer", is the quantitative version of part 1's section 2.

## 3. The map: six inventories

Each inventory is a table extracted from the source by a script and kept beside the tests.
When upstream adds a command, a state or a quirk, the table grows and the coverage report
shows a new uncovered row the same day. That is the property that makes the suite
*consistent*: its shape follows the subsystem, not the memory of its authors.

| inventory | extracted from | rough size |
|---|---|---|
| commands and events | HCI: the protocol header; management: its header and `doc/mgmt.rst`; sockets: the option constants per socket family; D-Bus: the 55 interface documents; profiles: each protocol's message table | 335 + 119 HCI; the others to be counted the same way |
| objects and states | the kernel's state enumerations and flags for adapter, connection, channel; the daemon's device, transport and endpoint state machines | tens of states per object, about ten objects |
| endings | fixed list: user close, peer close, link loss, power-off, adapter removal, suspend and resume, death of the owning process, timeout | 8 |
| configurations | the 34 quirks, the controller feature bits, the transport drivers, the daemon's configuration keys, the maintained kernel lines | large; sampled, see 4.4 |
| peers | role (central, peripheral, broadcaster, source, sink) by profile, and per profile the list of legal but awkward behaviours (slow answer, reordered answer, refusal, disconnect in the middle) | about a dozen profiles |
| failures | every status code a command may return; no answer; late answer; allocation failure at each allocation site | hundreds, but enumerable |

Two of these are not written down anywhere today and are the real intellectual work: the
**state tables of the objects**, and the **list of awkward peer behaviours**. Everything else
is extraction.

## 4. From the map to the tests: five generators

**4.1 Conformance walker.** For every command at every boundary, in every state of the
object it acts on: send it, and check the documented answer or the documented refusal. This
is what the present testers do by hand for about a thousand points; generated, it covers the
commands-by-states table completely, and its first output is the list of cells where the
documentation does not say what should happen. Precondition: the emulated controller must
answer all 335 commands, at least with a correct refusal.

**4.2 Interleaving walker.** Part 1's suite A, generalised: every multi-step procedure
(found mechanically: every function that queues more than one command), held at every step,
crossed with every ending from the list of eight. Verdict by invariants only.

**4.3 Failure walker.** Every command in every procedure answered with every status it may
legally carry, with silence, and with a late answer after the timeout; every allocation
failed in turn (the kernel's fault-injection facility does this already). Verdict: the error
reaches the caller, nothing leaks, the object returns to a named state.

**4.4 Configuration sampler.** The product of quirks, features and drivers cannot be walked
whole. Take every quirk alone, every pair of quirks (pairwise covering needs a few dozen
configurations, not 2^34), and every real combination that occurs in the device tables. The
last list is finite and extractable, and is exactly the set of configurations users have.

**4.5 Model-based sequence generator.** Random but legal long sequences of user-level
operations over the state tables, with a scripted peer, on the whole stack (kernel, daemon,
audio server). It reaches the states nobody thought to list. Each failure is reduced
automatically to a shortest sequence and stored as a fixed regression case. Coverage-guided
fuzzing of the packet parsers (which upstream already has for the kernel through syzkaller)
belongs here as the same idea at the byte level.

**Invariants, the common verdict.** No warning or sanitizer report in the kernel log; no
reference, timer, work item or socket left after teardown; every state reached is a named
one; every request receives exactly one answer; what the kernel, the daemon and the audio
server each believe about a connection agrees once the system is quiet; a second identical
run gives the same result.

## 5. Coverage: how to know what is covered

Report five numbers per release, each against its inventory, each with the uncovered rows
listed by name:

1. command-by-state cells exercised, of all cells (per boundary);
2. procedure-step-by-ending cells exercised, of all cells;
3. command-by-status cells exercised, of all cells;
4. quirks exercised alone and in pairs; device-table configurations exercised;
5. state-machine transitions taken at least once by the sequence generator.

Line and branch coverage of the kernel and daemon sources is a sixth, cheaper number and a
check on the other five: a source line never executed while all five tables are full means
an inventory is missing a row.

What these numbers do not measure is said in section 8.

## 6. How the seven suites of part 1 fit in

| part 1 suite | place in this model |
|---|---|
| A interleaving | generator 4.2 |
| B lifetime under sanitizers | not a suite: the mode in which all five generators run |
| C error contract | generator 4.3 |
| D transport | the driver column of the configuration inventory, with the emulated USB controller as the instrument |
| E stable-line matrix | the kernel-line column of the configuration inventory: every generator runs on every maintained line |
| F whole stack with scripted peer | generator 4.5 and the peer inventory |
| G hardware shelf and device-table check | the part of 4.4 that an emulator cannot stand in for; kept small on purpose |

So part 1 is a subset reached from the defect side; nothing in it is discarded.

## 7. Order of construction, and who would own what

1. **Inventory scripts and the coverage report on the existing testers.** No new test; a few
   days of work; shows upstream its own gaps in its own terms. This is the piece most
   likely to be accepted, and it makes every later piece measurable.
2. **Complete the emulated controller** to answer every command, and add the hold gate and
   the scripted answer (status, silence, lateness). Belongs in BlueZ's `emulator/`.
3. **Generators 4.1 to 4.3**, in that order; each is a table-driven tester beside the
   existing ones. The object state tables are written here, one object at a time, starting
   with the connection.
4. **Run on the maintained kernel lines** (the configuration inventory's cheapest column).
5. **The emulated USB controller and the configuration sampler** for the drivers. Kernel
   side; the largest single piece.
6. **The sequence generator on the whole stack.** Last, because its failures are only
   readable once the layers below are quiet.

Acceptance at each step: on a tree from before the fixes, the step rediscovers the defects
of this project that lie in its area. Steps 1 to 4 fit BlueZ and its existing continuous
integration; step 5 is a kernel self-test; step 6 would live with the distributions or the
audio server projects, since no single upstream owns the whole stack.

## 8. Limits

- **The map is not the territory.** Radio behaviour, timing on real silicon, firmware
  defects and the behaviour of real headsets are outside any emulator. The hardware shelf
  stays, and so does the kind of observation this project did by hand.
- **Coverage of the tables is not correctness.** Every cell can be exercised with a weak
  invariant and prove little. The invariants are the part to review hardest.
- **The state tables can be wrong** in the same way the code is, if written by reading the
  code. Where the Bluetooth specification defines the states, take them from there.
- **Size.** The full product is far beyond any budget; the design depends on the sampler
  (4.4) and on running the walkers per object, not across objects. The cross-object cases
  are left to the sequence generator, which gives no guarantee, only probability.
- **This page is a design, not a result.** The one measurement in section 2 is a rough
  count; no generator was built and no number in section 5 exists yet. The smallest honest
  next step is item 1 of section 7.

---

Complete as of 2026-11-23. Written in two pieces (sections 1 to 2, then 3 to 8) and not
edited afterwards.
