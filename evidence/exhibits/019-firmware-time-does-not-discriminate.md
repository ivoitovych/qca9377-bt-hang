# EX-019 — firmware-time-does-not-discriminate

**Claim.** Firmware initialisation time cannot distinguish a cold start from a warm reboot on this machine, so it cannot supply the electrical evidence the shutdown-target column is missing.

**Relevance.** EX-017 turns on whether power was applied during a 98 s gap. Firmware time was the most promising independent witness: a cold start might re-initialise more than a warm one. It spans 3.909-4.043 s across six boots, and the confirmed power cycle and the reboot.target case sit 0.11 s apart - inside the spread of boots that were all shut down the same way.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ bt-boot-provenance 6
```

## Output

Verbatim, 1 line(s), exit status 127.

```
bash: line 1: bt-boot-provenance: command not found
```

> ⚠️ **This exhibit's captured command DID NOT RUN** — exit 127, the tool was
> not yet on PATH when the exhibit was generated. The one-pass discipline held
> (the failure was recorded verbatim, as designed), but the Reading table below
> is therefore **hand-transcribed from an earlier interactive run of the same
> command**, not the product of the extraction above — precisely the
> command/output drift `bt-exhibit` exists to prevent. The numbers agree with
> the `bt-boot-provenance` table quoted in `EX-017`, which is their actual
> provenance. Re-capture this exhibit on the affected machine
> (`bt-exhibit new firmware-time-does-not-discriminate-2 …`) before citing it
> upstream. `bt-exhibit` now refuses to write an exhibit whose command exits
> 126/127, so this class cannot recur silently.

## Reading

| boot | prev end | firmware |
|---|---|---:|
| −5 | `poweroff` | 4.043 s |
| −4 | `poweroff` | 3.922 s |
| −3 | `poweroff` | 3.914 s |
| −2 | `poweroff` | 3.910 s |
| −1 | `poweroff` | 3.909 s |
| 0 | **`reboot`** | 4.020 s |

Total spread 0.134 s. The one `reboot.target` row sits between two `poweroff`
rows. If a cold start did measurably more firmware work than a warm one on this
platform, the last row would separate; it does not.

## Why a negative result is worth an exhibit

Because the alternative is that someone tries it again. The question "could
firmware time tell us whether the rail dropped?" is a good question with an
obvious appeal, and the only way to stop it being re-asked every few weeks is to
record that it was asked, how it was tested, and what came back.

It also bounds what the instrument can ever claim. `bt-trial`'s `prev_shutdown`
column and `bt-boot-provenance`'s `prev end` record the **operating system's
shutdown trajectory** and nothing more. There is no field in the journal that
witnesses the M.2 rail, so the protocol's step 0 — *"a warm reboot does not drop
the M.2 power rail and will not recover it"* — cannot be settled from logs at
all. It needs a deliberate trial: hang the controller, warm-reboot without
touching the power, and look.

That trial is worth running, but it is **secondary**. The stage-2 natural
history (`EX-018`) comes first, and running this one would consume a hang that
the stage-2 question needs.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-13T12:11:53+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `d6d9b2dc` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `127` |
| redacted | `no` |
