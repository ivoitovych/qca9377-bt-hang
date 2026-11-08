# CO-39 — BlueZ: non-discoverable advertisements keep a temporary device alive (U29)

**What:** `btd_adapter_device_found()` (src/adapter.c) calls `device_update_last_seen()` for an
existing device *before* it drops a report that is not discoverable. For a temporary device that
call restarts the 30 s `TemporaryTimeout` timer. So a peer advertising with flags 0x18 (no
discoverable bit) keeps an unpaired, unconnected device object alive as long as it advertises.
On the laptop (2026-11-07) this kept the MOMENTUM 4's row alive for three minutes. The headset
was not in pairing mode, and every click on the row was refused "Pairing Not Allowed"
(`docs/issues.md` U29).

- **Origin:** `def01de02` ("device: Add timer for removing temporary devices", Luiz Augusto von
  Dentz, 2020-07-15). It made `device_update_last_seen()` restart the timer. The call before the
  drop is older (`c65c8bf64`, 2014) and was harmless until then. This is the proposed `Fixes:`.
- **Present in:** master `a80671987` and Ubuntu's 5.72.

**State (2026-11-08): patch written, local validation in progress; nothing sent.**

- **The patch:** `results/u29-lifetime-patch-2026-11-07/patch/` (master, `src/adapter.c` +15 −2,
  plus a 5.72 port). A report refreshes the timer only if it is discoverable, monitored or
  RSI, or the device is not temporary, or it is connected.
- **Measured** (QEMU, emulated controllers; 108 runs plus 5 reruns, master and 5.72, unchanged
  and patched):
  - the U29 case is removed about 30 s after the disconnect, instead of about 153 s;
  - discoverable, filtered, paired, pairing and connected devices are unchanged;
  - `make check` 35/35; checkpatch clean.
- **No-Flags case:** documented as a deliberate choice that follows BlueZ's existing rule,
  `device_is_discoverable()` (README of the results).
- **v2, 2026-11-08** (results README, "v2"):
  - **A regression test for BlueZ's functional suite** (`v2/patch/`, "test: functional: add
    test for temporary device lifetime"): it fails on master in 6 of 6 runs and passes with
    the patch in 7 of 7. The suite's other tests are identical on both builds; two
    `test_bearer` LE tests time out on both.
  - **Pairing:** `Pair()` makes a public-address device non-temporary for its whole duration,
    so a pending pairing is unaffected by the patch. This is shown with reports arriving during
    the pairing. The private-address case was not run.
  - **`FilterDiscoverable = false`:** no change, as the source predicts.
- **Running:** BlueZ's own CI bot, locally, on master and master plus the patch
  (`scripts/bot-ci-local.sh`, output `tmp/u29-ci/out/`).

**Next:** check those results, then a one-page readiness summary: patch revision, exact tests,
master versus patched, limits, the `Fixes:` line. Then the operator's decision.

**Send form:** a real author line and no Signed-off-by (BlueZ userspace, `doc/maintainer-guidelines.rst`
Rule 2). The operator runs the send.

**Decides:** the operator.

**Refs:**
- `docs/issues.md` U29;
- `results/u29-emulator-2026-11-07/` §2 (the reproduction);
- `results/u29-lifetime-patch-2026-11-07/`;
- reviews `reviews/2026-11-07T1415Z-u29-source-investigation-reviewer-6-verbatim.md` §1.6 and
  `reviews/2026-11-07T1515Z-u29-reviewer-2-fourth-message-verbatim.md`.
