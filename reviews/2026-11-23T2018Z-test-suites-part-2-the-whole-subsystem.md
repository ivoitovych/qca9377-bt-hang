# Part 2: from the defects we met to the whole Bluetooth subsystem (2026-11-23)

**Follows** [`2026-11-23T2011Z-test-suites-that-would-have-caught-these-defects.md`](2026-11-23T2011Z-test-suites-that-would-have-caught-these-defects.md).
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

