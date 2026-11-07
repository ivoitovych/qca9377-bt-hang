/* CO-36 L1 extras: the gap between two links, where a variant that checks
 * the link state (V2) and one that stops the timer at every link end (V3)
 * could differ. Not in TEST-PLAN.md; the same file for every variant. */
/* SPDX-License-Identifier: MIT */

/* the unchanged homework harness, with its main() renamed */
#define main co36_homework_main
#include "test-backend-native.c"
#undef main

/* an incoming SCO link as sco_listen_event() takes it (backend-native.c
 * L3061-3077 at 4cfc4711: fd set, source started, state PENDING); the
 * socket is writable at once, so sco_event() OUT runs sco_ready() with
 * requesting false */
static void incoming_accept(void)
{
	struct spa_bt_transport *t = T();
	struct transport_data *td = t->user_data;
	int sv[2];

	if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0, sv) < 0)
		abort();
	close_sco_peer();
	t->fd = sv[0];
	h.sco_peer = sv[1];
	sco_start_source(t);
	spa_bt_transport_set_state(t, SPA_BT_TRANSPORT_STATE_PENDING);
	mark("in-pending");
	td->sco.rmask = SPA_IO_OUT;
	td->sco.func(&td->sco);
	drain(C_READY);
}

/* the node acquires the incoming link: sco_acquire_cb(optional) */
static void incoming_acquire(void)
{
	spa_bt_transport_impl(T(), acquire, 0, true);
	h.link_up = T()->state == SPA_BT_TRANSPORT_STATE_ACTIVE;
	mark(h.link_up ? "up" : "up-failed");
	drain(C_READY);
}

/* an outgoing link whose connect is still in progress: acquire only */
static void outgoing_start(void)
{
	struct spa_bt_transport *t = T();
	int sv[2];

	if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0, sv) < 0)
		abort();
	close_sco_peer();
	t->fd = sv[0];
	h.sco_peer = sv[1];
	spa_bt_transport_impl(t, acquire, 0, false);
	mark("connecting");
	drain(C_ACQUIRE);
}

/* the connect completes: POLLOUT */
static void outgoing_ready(void)
{
	struct spa_bt_transport *t = T();
	struct transport_data *td = t->user_data;

	td->sco.rmask = SPA_IO_OUT;
	td->sco.func(&td->sco);
	h.link_up = t->state == SPA_BT_TRANSPORT_STATE_ACTIVE;
	mark(h.link_up ? "up" : "up-failed");
	drain(C_READY);
}

/* X01 incoming link accepted at 1400 (PENDING), timer at 1500, acquired at 1600 */
static void x01(void)
{
	SETUP();
	link_up();
	run(100);
	link_release();
	run(1400);
	incoming_accept();
	run(1600);
	incoming_acquire();
	run(3500);
	check_i1();
}

/* X02 outgoing link 2 started at 1400, still connecting at 1500, ready at 1600 */
static void x02(void)
{
	SETUP();
	link_up();
	run(100);
	link_release();
	run(1400);
	outgoing_start();
	run(1600);
	outgoing_ready();
	run(3500);
	check_i1();
}

/* X03 link 2 started at 1000; its first event is a hang-up with socket
 * error 0, so sco_ready() completes the link (send, arm, ACTIVE) and
 * sco_event() closes it in the same call */
static void x03(void)
{
	SETUP();
	link_up();
	run(100);
	link_release();
	run(1000);
	outgoing_start();
	struct transport_data *td = TD();
	close_sco_peer();
	td->sco.rmask = SPA_IO_HUP;
	td->sco.func(&td->sco);
	h.link_up = false;
	mark("hup-at-connect");
	drain(C_READY);
	run(4000);
	check_i1();
}

/* X04 record: is the resend timer still armed 1 ms after a release at 100? */
static void x04(void)
{
	uint64_t dl = 0;
	SETUP();
	link_up();
	run(100);
	link_release();
	run(101);
	bool armed = volume_timer_armed(&dl);
	run(3000);
	result(n_late() == 0, "record: timer armed after release: %s%s%" PRIu64 "; late frames %d; %s",
			armed ? "yes" : "no", armed ? " deadline " : "",
			armed ? (uint64_t)(dl / SPA_NSEC_PER_MSEC) : (uint64_t)0, n_late(), timeline(false));
}

/* X05 keep: hang-up at 1600, after the resend: resend at 1500 while up, nothing after */
static void x05(void)
{
	SETUP();
	link_up();
	run(1600);
	link_drop(SPA_IO_HUP);
	run(3000);
	result(spa_streq(vg_at(1500), "+VGS:6 +VGM:15") && n_late() == 0 &&
			n_vg_between(1600, 3000) == 0, "%s", timeline(false));
}

/* X06 incoming link acquired exactly at 1500, both orders (a: link first) */
static void x06a(void)
{
	SETUP();
	link_up();
	run(100);
	link_release();
	run(1400);
	incoming_accept();
	run(1499);
	fake_now = MS(1500);
	incoming_acquire();
	run(3500);
	check_i1();
}

static void x06b(void)
{
	SETUP();
	link_up();
	run(100);
	link_release();
	run(1400);
	incoming_accept();
	run(1500);
	incoming_acquire();
	run(3500);
	check_i1();
}

static const struct test extras[] = {
	{ "X01", "leak", x01 }, { "X02", "leak", x02 }, { "X03", "leak", x03 },
	{ "X04", "record", x04 }, { "X05", "keep", x05 },
	{ "X06a", "record", x06a }, { "X06b", "record", x06b },
};

int main(int argc, char *argv[])
{
	int n_pass = 0, n_fail = 0;

	setvbuf(stdout, NULL, _IOLBF, 0);
	for (int i = 1; i < argc; i++)
		if (spa_streq(argv[i], "-v"))
			verbose = true;
	fake_log_set_level(verbose ? SPA_LOG_LEVEL_DEBUG : SPA_LOG_LEVEL_ERROR);
	for (size_t i = 0; i < SPA_N_ELEMENTS(extras); i++)
		run_test(&extras[i]) ? n_pass++ : n_fail++;
	printf("# %d extras: %d PASS, %d FAIL\n", n_pass + n_fail, n_pass, n_fail);
	return 0;
}
