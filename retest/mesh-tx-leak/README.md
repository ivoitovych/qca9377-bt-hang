# MGMT Mesh Send handle leak: retest kit

Reproducer, kernel configs, scripts and raw VM logs for a retest of
"Bluetooth: MGMT: fix mesh_tx leak on hci_cmd_sync_queue() failure"
([patchwork 14831271](https://patchwork.kernel.org/patch/14831271/)) on
bluetooth-next `036d4119079a`.

Results and their interpretation are in [REPORT.md](REPORT.md). This file
covers what is here and how to run it again.

## Layout

| Path | Contents |
|---|---|
| `REPORT.md` | Findings, claim by claim, with caveats |
| `mesh-leak-check.c` | Reproducer: drives MGMT against BlueZ's emulated controller and prints `RESULT` lines |
| `build-repro.sh` | Builds the reproducer against a BlueZ tree |
| `kernel/` | `build-kernel.sh`, config fragments, the full `.config` of each build, the patch under test (`mesh-tx-leak-fix.diff`), the test-only delay patch, and the mbox checksum |
| `run-vm.sh` | Runs one command in a fresh test-runner VM and saves its console log |
| `run-matrix.sh` | All scenarios for one kernel build (`main` or `diag`) |
| `run-kmemleak-reps.sh`, `kmemleak-after-exit.sh` | Repeated kmemleak runs with three scan methods |
| `run-busy-drain-reps.sh` | Repeated busy-drain runs |
| `audit-logs.sh` | Checks every log: run completed, expected kernel commit, no kernel reports |
| `summarize.py` | Side-by-side comparison of two builds |
| `tabulate-reps.py` | Tables for the repeated runs |
| `results/logs/<build>/` | Raw console logs (kernel log + reproducer or tester output); `reps-<build>/` holds the repeated runs |
| `results/summary-*.md`, `results/audit.txt` | Generated from the logs |

The four builds are `control` (base), `patched` (base + patch),
`diag-control` (base + delay knob, kmemleak) and `diag-patched` (delay
knob + patch, kmemleak).

## Reading the results

* The reproducer only observes. It exits 0 when a scenario ran to the
  end, not when the kernel behaved "correctly". What happened is in its
  `RESULT` lines; compare builds with `summarize.py`.
* Each scenario ran once per build, advertising type and CPU count. The
  kmemleak cases and busy-drain were also repeated (`results/logs/reps-*`,
  `results/summary-reps.md`).
* The runs used QEMU without KVM (TCG).

## Reproducing

Tested on Ubuntu 24.04 (x86_64), gcc 13.3, QEMU 8.2.2.

### 1. Packages

```sh
sudo apt-get install qemu-system-x86 build-essential flex bison bc ccache \
  libelf-dev libssl-dev libglib2.0-dev libdbus-1-dev libudev-dev \
  libical-dev libreadline-dev python3-docutils autoconf automake libtool \
  pkg-config
```

### 2. Sources

```sh
export WORK=$HOME/mesh-retest           # any directory
export BLUEZ=$WORK/bluez
KIT=/path/to/this/directory
mkdir -p $WORK && cd $WORK

git clone https://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth-next.git linux
git -C linux checkout 036d4119079a

git clone https://git.kernel.org/pub/scm/bluetooth/bluez.git bluez
git -C bluez checkout 7edaa61403390fe1cf2f1fb6d45fdd90fe6e93b3

curl -L -o mesh_tx_leak.mbox https://patchwork.kernel.org/patch/14831271/mbox/
sha256sum mesh_tx_leak.mbox             # compare with $KIT/kernel/patch-mbox.sha256
```

### 3. Kernel trees and builds

```sh
cd $WORK/linux
git worktree add -b retest-patched      ../src-patched      036d4119079a
git -C ../src-patched      am $WORK/mesh_tx_leak.mbox
git worktree add -b retest-diag-control ../src-diag-control 036d4119079a
git -C ../src-diag-control am $KIT/kernel/test-only-mesh-send-delay.patch
git worktree add -b retest-diag-patched ../src-diag-patched retest-diag-control
git -C ../src-diag-patched am $WORK/mesh_tx_leak.mbox

cd $WORK
T=$BLUEZ/doc/tester.config F=$KIT/kernel/fault.config K=$KIT/kernel/kmemleak.config
$KIT/kernel/build-kernel.sh control      $WORK/linux            $T $F
$KIT/kernel/build-kernel.sh patched      $WORK/src-patched      $T $F
$KIT/kernel/build-kernel.sh diag-control $WORK/src-diag-control $T $F $K
$KIT/kernel/build-kernel.sh diag-patched $WORK/src-diag-patched $T $F $K
```

`git am` needs a git identity configured. Each build lands in
`$WORK/build-<name>/`; compare its `.config` with `kernel/config-<name>`.

`git am` creates new commit IDs, so the three patched builds will boot
with different `-g<hash>` banners from the ones in `results/logs`, although
the source trees are identical (compare `git rev-parse HEAD^{tree}`).
`audit-logs.sh` checks the banners against the commits used here; edit
`expected()` in it for your own builds.

### 4. BlueZ and the reproducer

```sh
cd $BLUEZ
./bootstrap
./configure --enable-testing --enable-experimental --disable-systemd \
  --disable-cups --disable-obex --disable-manpages --enable-library
make -j"$(nproc)" tools/test-runner tools/mgmt-tester tools/mesh-tester
$KIT/build-repro.sh $BLUEZ             # -> $BLUEZ/tools/mesh-leak-check
```

### 5. Runs

```sh
cd $KIT
./run-matrix.sh main control 2
./run-matrix.sh main patched 2
./run-matrix.sh diag diag-control 2
./run-matrix.sh diag diag-patched 2
./run-kmemleak-reps.sh diag-control 5
./run-kmemleak-reps.sh diag-patched 2
./run-busy-drain-reps.sh control 5
./run-busy-drain-reps.sh patched 5
```

New logs go to `logs/<build>/` (not tracked). Then:

```sh
./audit-logs.sh logs
./summarize.py logs control patched
./summarize.py logs diag-control diag-patched
./tabulate-reps.py logs control patched diag-control diag-patched
```

`run-matrix.sh main` exits non-zero because mesh-tester exits 1 when any
of its cases fail; check `cmd=` in its output.

## Reproducer scenarios

```
mesh-leak-check <scenario> <legacy|ext> [options]
```

| Scenario | What it does |
|---|---|
| `baseline` | Two normal sends |
| `offline` | Mesh Send while powered off (`-ENETDOWN`), then power on and send again |
| `offline-busy` | Three powered-off failures, a 4th send, then a 5th after power on |
| `enomem` | One send with an injected kmalloc failure in `hci_cmd_sync_queue()`, then a normal send |
| `enomem-busy` | Three injected failures, then a 4th send |
| `close-reuse` | Socket A fails and is closed; socket B sends |
| `busy-drain` | Socket A reaches Busy; socket B sends four times; A sends again |
| `kmemleak-enetdown`, `kmemleak-enomem`, `kmemleak-enodev` | One failure, socket closed, controller removed, kmemleak scans (`diag` builds) |

`legacy` uses an emulated BR/EDR+LE controller with legacy advertising;
`ext` uses the 5.0 variant with extended advertising. Options for the
kmemleak scenarios: `plain`, `shrink` (shrink slab caches before each
scan), `stackoff` (no task-stack scanning), `noscan` (leave scanning to
`kmemleak-after-exit.sh`).
