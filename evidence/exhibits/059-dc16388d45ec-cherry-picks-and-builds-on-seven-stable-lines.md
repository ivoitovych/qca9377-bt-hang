# EX-059 — dc16388d45ec-cherry-picks-and-builds-on-seven-stable-lines

**Claim.** Mainline commit dc16388d45ec cherry-picks with git, without conflict, onto the fetched tip of every live stable line (7.2.y, 6.18.y, 6.12.y, 6.6.y, 6.1.y, 5.15.y, 5.10.y), the 13d3:3503 entry is present in the picked btusb.c on each, and drivers/bluetooth builds with -Werror both unpatched and picked on each.

**Relevance.** A stable pickup is a git cherry-pick, so this is the check a backport request rests on, as opposed to a text-level patch dry run. Each worktree is reset to the tip fetched by the command itself, so the tips printed are the tips at the time of the run; the unpatched build is the control that shows -Werror is satisfiable on that tree before the commit is applied.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/build-btusb-stable-matrix.sh dc16388d45ec
```

## Output

Verbatim, 10 line(s), exit status 0.

```
fetching stable…
commit: dc16388d45ec Bluetooth: btusb: Add IMC Networks QCA9377 to quirks table
branch                 tip            cherry-pick  entry   unpatched      picked
stable/linux-7.2.y     9a66fdc0d7fd   OK           x1      rc=0 134608B   rc=0 134640B  (-Werror)
stable/linux-6.18.y    1b357ecb3213   OK           x1      rc=0 132896B   rc=0 132896B  (-Werror)
stable/linux-6.12.y    e2acc2211022   OK           x1      rc=0 125144B   rc=0 125144B  (-Werror)
stable/linux-6.6.y     79643295eba1   OK           x1      rc=0 118568B   rc=0 118568B  (-Werror)
stable/linux-6.1.y     1a8763b93150   OK           x1      rc=0 106200B   rc=0 106200B  (-Werror)
stable/linux-5.15.y    0248c33e835e   OK           x1      rc=0 100776B   rc=0 100840B  (-Werror)
stable/linux-5.10.y    1797d8bf8d0c   OK           x1      rc=0 106736B   rc=0 106736B  (-Werror)
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-02T03:08:30+02:00` |
| kernel | `7.0.0-34-generic` |
| capture boot id | `c34cfa10` |
| evidence boot ids | none named by the command (it selects by index or not by boot) — see the window above |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
