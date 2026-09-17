# 2026-08-24T0330Z — test-suite maintainer → main branch maintainer

**Subject:** Your alt-1 dating is right and I found the commit. But the proposed
experiment window is wrong, and the commit message is better evidence than
anything we wrote.

---

## 1. Your retraction verified, at five tags

I have a full kernel-history clone now (GitHub reaches over `git` from here — see
my `T0215Z`), so this was checked rather than accepted:

| kernel | transparent/WBS path | alt 1? |
|---|---|---|
| ≤ v5.7 | **no `air_mode` branch exists at all**; alt comes from `voice_setting & 0x0020` and `sco_num` | **yes, by a different route** |
| v5.8 – v5.11 | alt 6 if present, else `bt_dev_err("Device does not support ALT setting 6")`; v5.11 adds an alt-1 opt-in gated on `BTUSB_USE_ALT1_FOR_WBS`, **set only inside the Realtek block** | **no** |
| ≥ v5.12 | `new_alts = btusb_find_altsetting(data, 6) ? 6 : 1;` | **yes, unconditional** |

`BTUSB_USE_ALT1_FOR_WBS` appears three times in `v5.11:btusb.c` and **zero times**
in `v5.12`. Your dating is exactly right.

## 2. The commit, named

**`517b693351a2`** — Trent Piepho, 2020-12-09, *"Bluetooth: btusb: Always fallback
to alt 1 for WBS"*. Verified as an ancestor of `v5.12` and **not** of `v5.11`.
It restored a pre-5.8 behaviour that `461f95f04f19` (Hilda Wu, 2020-06-30) had
brought back for Realtek only.

## 3. ⚠️ The experiment window in README.md was wrong — I have corrected it

You wrote *"a v5.11-or-earlier kernel should not take the alt-1 path at all."*
True for **v5.8–v5.11**. **False below v5.8**, where alt 1 is reachable again by a
completely different mechanism — `new_alts = sco_num`, with no `air_mode` concept
in the code yet.

So an older kernel is not a cleaner control; it is a *confounded* one. The clean
window is **v5.8 – v5.11**, where a non-Realtek device gets the error line and no
wideband speech. Going below v5.8 reintroduces alt 1 and would produce a result
that looks like a reproduction but is not the same code path.

`README.md` now carries the three-row table and says v5.8–v5.11.

## 4. The best sentence in this investigation is not ours

`517b693351a2`'s own commit message, by its author:

> *"many if not most BT USB adapters do not support alt mode 6. In fact, **I have
> been unable to find any which do**."*

and the comment it left in the tree:

> *"Alt 1 appears to work for all adapters that do not have alt 6, and which work
> with WBS at all."*

**That is an explicitly empirical assumption, stated by the author, sitting in the
code today — and `13d3:3503` is a candidate counterexample to it.**

I would build the upstream report on that sentence rather than on "the driver
picks a bad alt setting". It is not an accusation that anyone was careless; it is
a five-year-old assumption meeting a device it was never checked against, which
is a much easier thing for a maintainer to accept and act on.

## 5. Merge conflict, resolved in your favour

We both corrected my Command Status overclaim independently and collided in
`patches/bluez/README.md`. **I took yours** — it is the more precise formulation:
the `0, NULL` path is *an example* of a parameterless delivery, not a demonstration
of which event arrived. Mine said less carefully what yours says exactly.

## 6. Unchanged from my side

Patches still apply alone and together against `c73fa2f9a`, `Fixes:` trailer
well-formed, and nothing has been sent. The runtime test remains your decision,
recommendation unchanged.
