# Patch 1 on the laptop: a second SCO connect during a call (prepared 2026-10-26, NOT RUN)

Optional; the operator's decision. Reviewers 5 and 6 recommend it as cheap; 1 to 4 call it optional.
The emulator covers the case 3/3 on bluetooth-next and on Ubuntu's code.

**What it shows:** with patch 1 a `connect()` of a second SCO socket to a headset whose call link
is up fails with `EBUSY`, and the call goes on. Without patch 1 the failed connect drops the call's
hold, and the call's link is disconnected about 10 ms later.

**The program:** `sco-connect-twice.c`. It refuses to run unless the kernel lists a connected
SCO/eSCO link to the given address (`HCIGETCONNLIST`, a read of the kernel's table; checked on
2026-10-26 with a dummy address: "no connected SCO/eSCO link…", exit 3), so it cannot open a link
of its own. It makes one `connect()`, closes the socket at once, then reads the link table every
second for 10 s. It prints handles and times, never the address. Build:
`cc -O2 -Wall -Wextra -I<bluez tree>/lib -o sco-connect-twice sco-connect-twice.c` (built as
`tmp/co02-v6send/sco-connect-twice`).

**Procedure (with the operator):**
1. A call, or the Sound panel's microphone test, holds a SCO link to one headset (the Shure: the
   81-minute link of `EX-074` shows the Sound panel keeps one up).
2. Run `tmp/co02-v6send/sco-connect-twice 0 <the headset's address>`. Expected:
   `second connect() returned -1 (Device or resource busy)`, ten "call's link still up", `PASS`.
   The operator says whether the audio went on.
3. Evidence: `scripts/capture-window.sh` on the capture around the printed times, with
   `'Synchronous|Disconnect'`: no Disconnect of the call's handle and no new setup. Then
   `scripts/sco-link-closure.py` after the call: the link closes normally at hang-up. The user
   journal (`scripts/user-journal.sh`) for PipeWire's view. An exhibit of each.

Risk: the module on the laptop is the patched one (`EX-071`), so the expected path is the
`EBUSY` one. If patch 1 did not work there, the call's link would drop. That is a call interrupted,
not a controller fault: the link setups and disconnects of `EX-074` are this controller's ordinary
work.
