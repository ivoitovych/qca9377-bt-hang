# build.mk - recipes for the mesh-tester reproduction (Phase 2; extended in phases 3-5).
# Every recipe is run as:  make -C <dir> -f /root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/build.mk <target>
# so the shell never changes directory itself. Output of every step is captured
# under tmp/mesh-tester-ci/ next to this file, or under LOGDIR when given
# (phase 5 keeps every raw log in LOGDIR=tmp/mesh-tester-ci/logs/phase5).

REPO   := /root/exp/qca9377-bt-hang
BLUEZ  := $(REPO)/cache/bluez-upstream
GUEST  := $(REPO)/cache/mesh-guest
OUT    := $(REPO)/tmp/mesh-tester-ci
LOGDIR := $(OUT)
JOBS   := 16
BZIMAGE := $(GUEST)/arch/x86/boot/bzImage
RUNNER  := $(BLUEZ)/tools/test-runner
MESH    := $(BLUEZ)/tools/mesh-tester
MGMT    := $(BLUEZ)/tools/mgmt-tester
QEMU_TCG := $(OUT)/qemu-tcg.sh
VALGRIND := valgrind --error-exitcode=65

# ---- BlueZ (run with -C $(BLUEZ)); same as the bot: ./bootstrap-configure --disable-lsan ; make -jN
bluez-libtoolize:
	libtoolize --copy --force > $(LOGDIR)/bluez-libtoolize.log 2>&1

# CONFIGURE_PARAMS: today's bot = --disable-lsan ; the bot of 2026-05-05..09-09 (valgrind era) =
# --disable-lsan --disable-asan --disable-ubsan (ci/testrunnersetup.py at f01e64b95f). BTAG names the logs.
CONFIGURE_PARAMS := --disable-lsan
BTAG := asan
bluez-configure:
	./bootstrap-configure $(CONFIGURE_PARAMS) > $(LOGDIR)/bluez-configure-$(BTAG).log 2>&1

bluez-make:
	$(MAKE) -j$(JOBS) > $(LOGDIR)/bluez-make-$(BTAG).log 2>&1

# Phase 5: build only the testers (run with -C <bluez tree>); BTAG names the log
bluez-make-testers:
	$(MAKE) -j$(JOBS) tools/mesh-tester tools/mgmt-tester > $(LOGDIR)/bluez-make-testers-$(BTAG).log 2>&1

# ---- guest kernel (run with -C $(GUEST)); same as the bot: cp tester.config .config ; make olddefconfig ; make -jN
kernel-config:
	cp $(BLUEZ)/doc/tester.config .config
	$(MAKE) olddefconfig > $(LOGDIR)/kernel-olddefconfig.log 2>&1

kernel-build:
	$(MAKE) -j$(JOBS) > $(LOGDIR)/kernel-build.log 2>&1

# Phase 3: refresh the config, build, and keep the image under a name (KTAG) so
# several bases/patch states can coexist: bzImage-$(KTAG) + kernel-build-$(KTAG).log
# Phase 5: FRAG, if given, is a config fragment appended to tester.config before
# olddefconfig (fault injection, KCSAN); the resulting .config is kept as
# config-$(KTAG) next to the image.
KTAG := unnamed
FRAG :=
kernel-all:
	cp $(BLUEZ)/doc/tester.config .config
	if [ -n "$(FRAG)" ]; then cat $(FRAG) >> .config; fi
	$(MAKE) olddefconfig > $(LOGDIR)/kernel-olddefconfig-$(KTAG).log 2>&1
	$(MAKE) -j$(JOBS) > $(LOGDIR)/kernel-build-$(KTAG).log 2>&1
	cp arch/x86/boot/bzImage $(OUT)/bzImage-$(KTAG)
	cp .config $(OUT)/config-$(KTAG)
	git log -1 --format='%H %s' > $(OUT)/bzImage-$(KTAG).commit

# ---- runs (run with -C $(OUT)); TAG names the output file, e.g. TAG=unpatched-kvm
# fast: KVM, tester alone (today's bot minus ASAN env); slow: as the bot did in May, valgrind + TCG
run-mesh-kvm:
	$(RUNNER) -k $(BZIMAGE) -m -- $(MESH) -d > $(LOGDIR)/run-$(TAG).log 2>&1

run-mesh-kvm-valgrind:
	$(RUNNER) -k $(BZIMAGE) -m -- $(VALGRIND) $(MESH) -d > $(LOGDIR)/run-$(TAG).log 2>&1

run-mesh-tcg:
	$(RUNNER) -q $(QEMU_TCG) -k $(BZIMAGE) -m -- $(MESH) -d > $(LOGDIR)/run-$(TAG).log 2>&1

run-mesh-tcg-valgrind:
	$(RUNNER) -q $(QEMU_TCG) -k $(BZIMAGE) -m -- $(VALGRIND) $(MESH) -d > $(LOGDIR)/run-$(TAG).log 2>&1

# generic: RUNNER_OPTS (e.g. "-q $(QEMU_TCG)") and CMD (what runs inside the guest)
run-custom:
	$(RUNNER) $(RUNNER_OPTS) -k $(BZIMAGE) -- $(CMD) > $(LOGDIR)/run-$(TAG).log 2>&1

run-mgmt-kvm:
	$(RUNNER) -k $(BZIMAGE) -- $(MGMT) > $(LOGDIR)/run-$(TAG).log 2>&1

# Phase 3: KVM, no in-guest monitor (as the bot runs), debug output; and N
# repeated runs of the tests whose name contains STR (default: cancel)
run-mesh-kvm-nomon:
	$(RUNNER) -k $(BZIMAGE) -- $(MESH) -d > $(LOGDIR)/run-$(TAG).log 2>&1

# Phase 5: the same with a name filter (STR) and debug output
run-mesh-kvm-nomon-str:
	$(RUNNER) -k $(BZIMAGE) -- $(MESH) -d -s "$(STR)" > $(LOGDIR)/run-$(TAG).log 2>&1

STR := cancel
REPEAT := 1 2 3 4 5
run-mesh-repeat:
	for i in $(REPEAT); do \
		$(RUNNER) -k $(BZIMAGE) -- $(MESH) -s "$(STR)" > $(LOGDIR)/run-$(TAG)-$$i.log 2>&1; \
	done
	grep -H -E 'Passed  |Failed  |Timed out|Not Run|Total:' $(LOGDIR)/run-$(TAG)-*.log > $(LOGDIR)/run-$(TAG)-summary.txt

# Phase 5: the splat grep over a run log, written next to it
splat-grep:
	grep -n -E 'lockdep|circular|WARNING|BUG:|KASAN|KCSAN|possible|INFO: |deadlock|sleeping function|tx timeout|FAULT_INJECTION' $(LOGDIR)/run-$(TAG).log > $(LOGDIR)/splat-$(TAG).txt; true

.PHONY: bluez-configure bluez-make bluez-make-testers kernel-config kernel-build kernel-all run-mesh-kvm run-mesh-kvm-valgrind run-mesh-tcg run-mesh-tcg-valgrind run-mgmt-kvm run-custom run-mesh-kvm-nomon run-mesh-kvm-nomon-str run-mesh-repeat splat-grep
