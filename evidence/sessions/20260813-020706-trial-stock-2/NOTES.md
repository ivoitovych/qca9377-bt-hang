# Incident: trial-stock-2

**Collected:** 2026-08-13T02:07:24+02:00 (window: @1786579536)

## What was being done

Trial stock #2 (protocol v2). Filled in retroactively, 2026-08-13.

## What happened

The trial was contaminated: `install.sh --apply` (run with BT_FORCE_INSTALL=1
to deploy the EX-015 pattern fix) reloaded btusb mid-trial — an intervention
the treatment column does not record. Two collections of the same slug exist
two minutes apart because the incident was collected twice while sorting this
out; both windows are quiet because the controller was healthy at the time.

## What it means

The trial was discarded — no results.tsv row, no trial directory. Its lasting
product is the guard: install.sh now warns about an open trial in EVERY mode,
and bt-trial scans each trial's interior for btusb reloads/resets and marks
the row PERTURBED so it can never pool into a denominator.
