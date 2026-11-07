# Run trees (2026-11-01)

All trees: clone of `../repo`, base BlueZ master `14bd6ab65`, commits
cherry-picked in order, built in `bluez-action-ci:60348956fc7b` with
`bootstrap-configure --disable-lsan --enable-asan --enable-ubsan`
(`scripts/asan-tree.sh build`), ELL `002b32d7c091`, tester kernel
`bzImage-bot-base-47d4d9f67e92`. `commits.txt` in each lists what was
built and what was added after the build (Python only).

| tree | C changes on 14bd6ab65 | test files at build |
|---|---|---|
| co23-before | none | CO-23 test, second version (`c4af2f061`) |
| co23-after | CO-23 fix (`d5456099b`) | as co23-before; local `test_local_pause.py`, `test_local_original.py` added after build |
| stk-base | none | CO-23 test v2 + CO-37 test rebased (`93b79b0b5`) + local adjacent tests |
| stk-fix1 | CO-37 fix 1 (`2cf0c7770`) | as stk-base |
| stk-fix12 | CO-23 fix + CO-37 fixes 1 and 2 | as stk-base |
| rfc | Bastien Nocera's RFC, `git am` of patchwork 14568134 mbox (`62dd1cc85`) | CO-37 test as in its original mail (`915e984a0`) + local adjacent tests |
| rfc-co37 | RFC + CO-37 fixes 1 and 2 (original mails) | as rfc |
| prop3 | final stacked series + local experiment `ad36b0e73` (media.c idle release) | final stacked |
| prop4 | final stacked series + local experiment `e91bde9d3` (a2dp.c idle unregister) | final stacked |

Labels run with `asan-tree.sh test` use the tree's own test files; labels
run with `asan-tree.sh testsrc` (`final`, `final2`, `fpair`, `fa2dp`,
`adj2`, `adj2probe`, and every prop3/prop4 label) take the tests from an
unbuilt checkout and the binaries from the tree:

- `srcs/co23` = branch `src-co23` (final CO-23 series `d5456099b`
  `f006e025f` + local pause/control tests);
- `srcs/stack` = branch `src-stack` (final stacked series ending
  `a1fe74a79` + local adjacent tests).

The final CO-23 test (`f006e025f`) differs from the second version only
in Python and `doc/` (reconnect once the link is down), so the C builds
are valid for it.

`runs/ext-v572` used `/root/exp/agent-work/exit-uaf/runs/v572/src`
(BlueZ 5.72 + master's test tools, built by the earlier campaign) with
the tests of `srcs/stack` (`scripts/asan-ext.sh`).
