/* CO-36 L1: backend-native.c volume resend, in virtual time */
/* SPDX-License-Identifier: MIT */

/* The file under test, unmodified, so its static functions are reachable. */
#include "backend-native.c"

#include <dirent.h>
#include <stdio.h>
#include <sys/wait.h>

#include "harness.h"

enum cause { C_HF, C_ACQUIRE, C_READY, C_TIMER, C_USER, C_END };

struct ev {
	uint64_t t;
	bool mark;		/* harness marker, not a frame */
	bool vg;		/* +VGS / +VGM */
	bool late;		/* written by a timer while no link was up */
	char text[48];
};

#define MAX_EV	256

static bool verbose;

static struct {
	struct impl backend;
	struct spa_bt_adapter adapter;
	struct spa_bt_device device;
	struct rfcomm *rfcomm;		/* NULL once freed */
	int rf_peer;			/* headset's end of RFCOMM */
	int sco_peer;			/* headset's end of SCO, -1 if none */
	bool link_up;
	char rx[4096];
	size_t rxlen;
	struct ev ev[MAX_EV];
	int n_ev;
	char verdict[2048];
} h;

/* event log */

static void add_ev(bool mark, const char *text, enum cause cause)
{
	struct ev *e;

	if (h.n_ev == MAX_EV)
		return;
	e = &h.ev[h.n_ev++];
	e->t = fake_now;
	e->mark = mark;
	snprintf(e->text, sizeof(e->text), "%s", text);
	if (!mark) {
		e->vg = spa_strstartswith(text, "+VGS") || spa_strstartswith(text, "+VGM");
		e->late = e->vg && cause == C_TIMER && !h.link_up;
	}
	if (verbose)
		fprintf(stderr, "  %s %s @%.3f%s\n", mark ? "--" : "AG>>", text,
				(double)fake_now / SPA_NSEC_PER_MSEC, e->late ? " LATE" : "");
}

SPA_PRINTF_FUNC(1, 2)
static void mark(const char *fmt, ...)
{
	char buf[48];
	va_list args;

	va_start(args, fmt);
	vsnprintf(buf, sizeof(buf), fmt, args);
	va_end(args);
	add_ev(true, buf, C_END);
}

/* read what the AG wrote: \r\n<frame>\r\n */
static void drain(enum cause cause)
{
	size_t pos = 0;

	while (h.rxlen < sizeof(h.rx) - 1) {
		ssize_t n = read(h.rf_peer, h.rx + h.rxlen, sizeof(h.rx) - 1 - h.rxlen);
		if (n <= 0)
			break;
		h.rxlen += n;
	}
	for (;;) {
		char text[48], *end;
		size_t len;

		while (pos < h.rxlen && (h.rx[pos] == '\r' || h.rx[pos] == '\n'))
			pos++;
		end = memmem(h.rx + pos, h.rxlen - pos, "\r\n", 2);
		if (end == NULL)
			break;
		len = SPA_MIN((size_t)(end - (h.rx + pos)), sizeof(text) - 1);
		memcpy(text, h.rx + pos, len);
		text[len] = '\0';
		add_ev(false, text, cause);
		pos = (size_t)(end - h.rx) + 2;
	}
	memmove(h.rx, h.rx + pos, h.rxlen - pos);
	h.rxlen -= pos;
}

static void after_timer(void)
{
	drain(C_TIMER);
}

static void run(uint64_t ms)
{
	fake_run_until(MS(ms), after_timer);
}

/* headset side */

SPA_PRINTF_FUNC(1, 2)
static void hf_cmd(const char *fmt, ...)
{
	char buf[128];
	va_list args;
	int n;

	va_start(args, fmt);
	n = vsnprintf(buf, sizeof(buf) - 1, fmt, args);
	va_end(args);
	buf[n++] = '\r';
	if (write(h.rf_peer, buf, n) != n)
		abort();
	h.rfcomm->source.rmask = SPA_IO_IN;
	h.rfcomm->source.func(&h.rfcomm->source);
	drain(C_HF);
}

static struct spa_bt_transport *T(void)
{
	return h.rfcomm ? h.rfcomm->transport : NULL;
}

static struct transport_data *TD(void)
{
	return T()->user_data;
}

static void close_sco_peer(void)
{
	if (h.sco_peer >= 0)
		close(h.sco_peer);
	h.sco_peer = -1;
}

/* setup: mirrors profile_new_connection() L3511-L3593 (no D-Bus), then the SLC over the socketpair */

struct opts {
	bool hsp;		/* HSP headset instead of HFP */
	bool cvsd_only;		/* HF without codec negotiation: CVSD transport made at AT+CMER */
	bool no_remote_volume;	/* AT+BRSF without the remote volume control bit */
	bool hw_volume_off;	/* hardware volume off for the headset profiles */
	bool no_vgs, no_vgm;	/* headset does not report AT+VGS / AT+VGM */
};

static struct rfcomm *new_rfcomm(enum spa_bt_profile profile, int fd)
{
	struct impl *backend = &h.backend;
	struct spa_bt_device *d = &h.device;
	struct rfcomm *rfcomm = calloc(1, sizeof(struct rfcomm));

	rfcomm->backend = backend;
	rfcomm->profile = profile;
	rfcomm->device = d;
	rfcomm->path = strdup(d->path);
	rfcomm->source.func = rfcomm_event;
	rfcomm->source.data = rfcomm;
	rfcomm->source.fd = fd;
	rfcomm->source.mask = SPA_IO_IN;
	rfcomm->source.rmask = 0;
	spa_list_init(&rfcomm->cmd_send_queue);
	spa_list_init(&rfcomm->updated_call_list);
	rfcomm->cind_enabled_indicators = 0xFFFFFFFF;
	spa_list_init(&rfcomm->available_codec_list);
	spa_list_init(&rfcomm->supported_codec_list);

	for (int i = 0; i < SPA_BT_VOLUME_ID_TERM; ++i) {
		if (rfcomm->profile & SPA_BT_PROFILE_HEADSET_AUDIO_GATEWAY)
			rfcomm->volumes[i].active = true;
		rfcomm->volumes[i].hw_volume = SPA_BT_VOLUME_INVALID;
	}

	spa_bt_device_add_listener(d, &rfcomm->device_listener, &device_events, rfcomm);
	spa_loop_add_source(backend->main_loop, &rfcomm->source);
	spa_list_append(&backend->rfcomm_list, &rfcomm->link);

	if (profile == SPA_BT_PROFILE_HSP_HS) {
		if (rfcomm_new_transport(rfcomm, HFP_AUDIO_CODEC_CVSD) < 0)
			abort();
		rfcomm->has_volume = rfcomm_hw_volume_enabled(rfcomm);
		spa_bt_device_connect_profile(rfcomm->device, profile);
	} else if (profile == SPA_BT_PROFILE_HFP_HF) {
		make_available_codec_list(backend, rfcomm->device, &rfcomm->available_codec_list);
	}

	if (rfcomm_hw_volume_enabled(rfcomm)) {
		uint32_t device_features;
		if (spa_bt_quirks_get_features(backend->quirks, d->adapter, d, &device_features) == 0)
			rfcomm->broken_mic_hw_volume = !(device_features & SPA_BT_FEATURE_HW_VOLUME_MIC);
	}
	return rfcomm;
}

SPA_PRINTF_FUNC(2, 3)
static void result(bool pass, const char *fmt, ...)
{
	int n = snprintf(h.verdict, sizeof(h.verdict), "%s ", pass ? "PASS" : "FAIL");
	va_list args;

	va_start(args, fmt);
	vsnprintf(h.verdict + n, sizeof(h.verdict) - n, fmt, args);
	va_end(args);
}

static bool setup(const struct opts *o)
{
	enum spa_bt_profile profile = o->hsp ? SPA_BT_PROFILE_HSP_HS : SPA_BT_PROFILE_HFP_HF;
	enum spa_bluetooth_audio_codec want;
	int sv[2];

	memset(&h, 0, sizeof(h));
	h.rf_peer = h.sco_peer = -1;
	fakes_reset();
	stubs_reset();

	h.backend.log = &fake_log;
	h.backend.main_loop = &fake_loop;
	h.backend.main_system = &fake_system;
	h.backend.loop_utils = &fake_loop_utils;
	h.backend.monitor = (struct spa_bt_monitor *)&h;	/* opaque; the stubs never read it */
	h.backend.codecs = stub_codecs;
	h.backend.enabled_profiles = DEFAULT_ENABLED_PROFILES;
	h.backend.hfphsp_sco_datapath = HFP_SCO_DEFAULT_DATAPATH;
	spa_list_init(&h.backend.rfcomm_list);

	/* documentation-range addresses */
	h.adapter.path = "/org/bluez/hci0";
	h.adapter.address = "00:00:5E:00:53:00";
	h.adapter.bus_type = BUS_TYPE_OTHER;	/* no USB ALT6 probe; SCO waits for POLLOUT */
	spa_list_init(&h.adapter.remote_endpoint_list);

	h.device.adapter = &h.adapter;
	h.device.path = "/org/bluez/hci0/dev_00_00_5E_00_53_01";
	h.device.address = "00:00:5E:00:53:01";
	h.device.hw_volume_profiles = o->hw_volume_off ? 0 :
		(SPA_BT_PROFILE_HFP_HF | SPA_BT_PROFILE_HSP_HS);
	spa_list_init(&h.device.remote_endpoint_list);
	spa_list_init(&h.device.transport_list);
	spa_list_init(&h.device.codec_switch_list);
	spa_list_init(&h.device.set_membership_list);
	spa_hook_list_init(&h.device.listener_list);

	if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, sv) < 0)
		abort();
	h.rf_peer = sv[1];
	fcntl(h.rf_peer, F_SETFL, O_NONBLOCK);
	h.rfcomm = new_rfcomm(profile, sv[0]);

	if (!o->hsp) {
		unsigned int features = 0;
		if (!o->no_remote_volume)
			features |= SPA_BT_HFP_HF_FEATURE_REMOTE_VOLUME_CONTROL;
		if (!o->cvsd_only)
			features |= SPA_BT_HFP_HF_FEATURE_CODEC_NEGOTIATION;
		hf_cmd("AT+BRSF=%u", features);
		if (!o->cvsd_only)
			hf_cmd("AT+BAC=1,2");
		hf_cmd("AT+CIND=?");
		hf_cmd("AT+CIND?");
		hf_cmd("AT+CMER=3,0,0,1");
		if (!o->cvsd_only)
			hf_cmd("AT+BCS=2");	/* answers the AG's +BCS: 2 */
	}
	if (!o->no_vgs)
		hf_cmd("AT+VGS=6");
	if (!o->no_vgm)
		hf_cmd("AT+VGM=15");

	want = (o->hsp || o->cvsd_only) ? SPA_BLUETOOTH_AUDIO_CODEC_CVSD : SPA_BLUETOOTH_AUDIO_CODEC_MSBC;
	if (T() == NULL || T()->media_codec->id != want) {
		result(false, "setup: no %s transport after SLC", want == SPA_BLUETOOTH_AUDIO_CODEC_CVSD ? "CVSD" : "mSBC");
		return false;
	}
	if (verbose)
		fprintf(stderr, "  -- setup done, clock starts\n");
	h.n_ev = 0;
	return true;
}

/* link control */

/* the AG opens the link; the socketpair end stands in for sco_do_connect()'s
 * socket (t->fd set, so sco_acquire_cb() takes it), then it turns writable */
static void link_ready_fd(int fd, int peer)
{
	struct spa_bt_transport *t = T();
	struct transport_data *td = t->user_data;

	close_sco_peer();
	t->fd = fd;
	h.sco_peer = peer;
	spa_bt_transport_impl(t, acquire, 0, false);
	drain(C_ACQUIRE);
	spa_assert(td->sco.loop == &fake_loop);
	td->sco.rmask = SPA_IO_OUT;
	td->sco.func(&td->sco);
	h.link_up = t->state == SPA_BT_TRANSPORT_STATE_ACTIVE;
	mark(h.link_up ? "up" : "up-failed");
	drain(C_READY);
}

static void link_up(void)
{
	int sv[2];

	if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0, sv) < 0)
		abort();
	link_ready_fd(sv[0], sv[1]);
}

/* the AG releases it: sco_release_cb() */
static void link_release(void)
{
	spa_bt_transport_impl(T(), release, 0);
	h.link_up = false;
	mark("rel");
	drain(C_END);
	close_sco_peer();
}

/* the headset or the radio drops it: sco_event() HUP or ERR */
static void link_drop(uint32_t rmask)
{
	struct transport_data *td = TD();

	close_sco_peer();
	spa_assert(td->sco.loop == &fake_loop);
	td->sco.rmask = rmask;
	td->sco.func(&td->sco);
	h.link_up = false;
	mark(rmask & SPA_IO_ERR ? "err" : "hup");
	drain(C_END);
}

/* the RFCOMM connection drops: rfcomm_event() HUP -> rfcomm_free() */
static void rfcomm_drop(void)
{
	drain(C_HF);
	h.rfcomm->source.rmask = SPA_IO_HUP;
	h.rfcomm->source.func(&h.rfcomm->source);
	h.rfcomm = NULL;
	h.link_up = false;
	mark("rfcomm-lost");
	drain(C_END);
	close_sco_peer();
}

/* the monitor frees the transport (device profile gone), RFCOMM stays */
static void transport_free_external(void)
{
	spa_bt_transport_free(T());
	h.link_up = false;
	mark("tfree");
	drain(C_END);
	close_sco_peer();
}

/* a user volume change: spa_bt_transport_set_volume() -> sco_set_volume_cb() */
static int user_volume(int id, int hw)
{
	float v = (float)spa_bt_volume_hw_to_linear(hw, SPA_BT_VOLUME_HS_MAX);
	int res = spa_bt_transport_set_volume(T(), id, v);

	mark("user-%s=%d", id == SPA_BT_VOLUME_ID_TX ? "vgs" : "vgm", hw);
	drain(C_USER);
	return res;
}

static bool volume_timer_armed(uint64_t *deadline)
{
	return h.rfcomm && fake_timer_armed(h.rfcomm->volume_sync_timer, deadline);
}

/* queries */

static void compact(char *dst, size_t sz, const char *src)
{
	size_t j = 0;
	for (size_t i = 0; src[i] && j + 1 < sz; i++)
		if (!(src[i] == ' ' && i > 0 && src[i - 1] == ':'))
			dst[j++] = src[i];
	dst[j] = '\0';
}

static void fmt_ms(char *buf, size_t sz, uint64_t t)
{
	if (t % SPA_NSEC_PER_MSEC)
		snprintf(buf, sz, "%.3f", (double)t / SPA_NSEC_PER_MSEC);
	else
		snprintf(buf, sz, "%" PRIu64, (uint64_t)(t / SPA_NSEC_PER_MSEC));
}

/* markers and +VG frames (all frames if `all`); '!' = late */
static const char *timeline(bool all)
{
	static char buf[1536];
	size_t n = 0;

	buf[0] = '\0';
	for (int i = 0; i < h.n_ev && n < sizeof(buf) - 64; i++) {
		struct ev *e = &h.ev[i];
		char text[48], ms[16];

		if (!e->mark && !e->vg && !all)
			continue;
		compact(text, sizeof(text), e->text);
		fmt_ms(ms, sizeof(ms), e->t);
		n += snprintf(buf + n, sizeof(buf) - n, "%s%s@%s%s", n ? " " : "",
				text, ms, e->late ? "!" : "");
	}
	return buf;
}

/* +VG frames written at exactly `ms`, compacted, space separated */
static const char *vg_at(uint64_t ms)
{
	static char buf[256];
	size_t n = 0;

	buf[0] = '\0';
	for (int i = 0; i < h.n_ev; i++) {
		char text[48];
		if (h.ev[i].mark || !h.ev[i].vg || h.ev[i].t != MS(ms))
			continue;
		compact(text, sizeof(text), h.ev[i].text);
		n += snprintf(buf + n, sizeof(buf) - n, "%s%s", n ? " " : "", text);
	}
	return buf;
}

/* +VG frames written in (from, to] ms */
static int n_vg_between(uint64_t from, uint64_t to)
{
	int n = 0;
	for (int i = 0; i < h.n_ev; i++)
		n += !h.ev[i].mark && h.ev[i].vg && h.ev[i].t > MS(from) && h.ev[i].t <= MS(to);
	return n;
}

static int n_vg(void)
{
	int n = 0;
	for (int i = 0; i < h.n_ev; i++)
		n += !h.ev[i].mark && h.ev[i].vg;
	return n;
}

static int n_late(void)
{
	int n = 0;
	for (int i = 0; i < h.n_ev; i++)
		n += h.ev[i].late;
	return n;
}

static bool any_frame(const char *text)
{
	for (int i = 0; i < h.n_ev; i++)
		if (!h.ev[i].mark && spa_streq(h.ev[i].text, text))
			return true;
	return false;
}

/* I1: no frames from the resend after the link ended */
static void check_i1(void)
{
	int late = n_late();
	if (late)
		result(false, "%d late: %s", late, timeline(false));
	else
		result(true, "%s", timeline(false));
}

#define SETUP(...)	struct opts _o = { __VA_ARGS__ }; if (!setup(&_o)) return

/* Link start and the immediate send */

static void t101(void)
{
	uint64_t dl = 0;
	SETUP();
	link_up();
	bool armed = volume_timer_armed(&dl);
	result(spa_streq(vg_at(0), "+VGS:6 +VGM:15") && armed && dl == MS(1500),
			"%s; resend armed %s@%" PRIu64, timeline(false), armed ? "yes" : "no", (uint64_t)(dl / SPA_NSEC_PER_MSEC));
}

static void t102(void)
{
	SETUP(.no_vgm = true);
	link_up();
	result(spa_streq(vg_at(0), "+VGS:6"), "%s", timeline(false));
}

static void t103(void)
{
	SETUP(.no_vgs = true, .no_vgm = true);
	link_up();
	result(spa_streq(vg_at(0), ""), "%s", timeline(false));
}

static void t104(void)
{
	SETUP(.hw_volume_off = true);
	link_up();
	run(2000);
	result(n_vg() == 0 && h.n_ev > 0, "%s (to 2000)", timeline(false));
}

static void t105(void)
{
	SETUP(.no_remote_volume = true);
	link_up();
	run(2000);
	result(n_vg() == 0, "%s (to 2000)", timeline(false));
}

static void t106(void)
{
	SETUP(.hsp = true);
	link_up();
	result(spa_streq(vg_at(0), "+VGS=6 +VGM=15"), "%s", timeline(false));
}

static void t107(void)
{
	int p[2];
	SETUP();
	/* a pipe is not a socket: getsockopt(SO_ERROR) fails, td->err = -ENOTSOCK */
	if (pipe2(p, O_CLOEXEC) < 0)
		abort();
	link_ready_fd(p[1], p[0]);
	int err = TD()->err;
	enum spa_bt_transport_state st = T()->state;
	bool armed = volume_timer_armed(NULL);
	run(2000);
	result(n_vg() == 0 && !armed && st == SPA_BT_TRANSPORT_STATE_ERROR,
			"td->err=%d state=%d resend armed %s; %s (to 2000)", err, st,
			armed ? "yes" : "no", timeline(false));
}

static void t108(void)
{
	uint64_t dl = 0;
	SETUP();
	link_up();
	run(100);
	sco_ready(T());		/* as sco_event() HUP calls it: requesting already false */
	mark("sco_ready");
	drain(C_READY);
	bool armed = volume_timer_armed(&dl);
	result(n_vg_between(0, 100) == 0 && armed && dl == MS(1500),
			"%s; resend still @%" PRIu64, timeline(false), (uint64_t)(dl / SPA_NSEC_PER_MSEC));
}

/* The resend on a long link */

static void t110(void)
{
	SETUP();
	link_up();
	run(1499);
	result(n_vg_between(0, 1499) == 0, "%s (to 1499)", timeline(false));
}

static void t111(void)
{
	SETUP();
	link_up();
	run(1500);
	result(spa_streq(vg_at(1500), "+VGS:6 +VGM:15") && n_late() == 0, "%s", timeline(false));
}

static void t112(void)
{
	SETUP();
	link_up();
	run(10000);
	result(spa_streq(vg_at(1500), "+VGS:6 +VGM:15") && n_vg_between(1500, 10000) == 0,
			"%s (to 10000)", timeline(false));
}

static void t113(void)
{
	SETUP();
	link_up();
	run(1000);
	user_volume(SPA_BT_VOLUME_ID_TX, 10);
	run(2000);
	result(spa_streq(vg_at(1000), "+VGS:10") && spa_streq(vg_at(1500), "+VGS:10 +VGM:15"),
			"%s", timeline(false));
}

static void t114(void)
{
	SETUP();
	link_up();
	run(1000);
	mark("hf-vgs=9");
	hf_cmd("AT+VGS=9");
	run(2000);
	result(spa_streq(vg_at(1500), "+VGS:9 +VGM:15") && n_vg_between(0, 1499) == 0,
			"%s", timeline(false));
}

/* The leak, the AG's release */

static void release_at(uint64_t ms)
{
	SETUP();
	link_up();
	run(ms);
	link_release();
	run(3000);
	check_i1();
}

static void t120(void) { release_at(100); }
static void t121(void) { release_at(1499); }

static void t122(void)
{
	SETUP();
	link_up();
	run(1500);		/* timer fires first */
	link_release();
	run(3000);
	bool once = spa_streq(vg_at(1500), "+VGS:6 +VGM:15");
	result(once && n_late() == 0 && n_vg_between(1500, 3000) == 0, "%s", timeline(false));
}

static void t123(void)
{
	SETUP();
	link_up();
	run(1501);
	link_release();
	run(3000);
	result(spa_streq(vg_at(1500), "+VGS:6 +VGM:15") && n_late() == 0 &&
			n_vg_between(1501, 3000) == 0, "%s", timeline(false));
}

static void t124(void) { release_at(0); }

/* The leak, the headset's hang-up */

static void drop_at(uint64_t ms, uint32_t rmask)
{
	SETUP();
	link_up();
	run(ms);
	link_drop(rmask);
	run(3000);
	check_i1();
}

static void t130(void) { drop_at(100, SPA_IO_HUP); }
static void t131(void) { drop_at(1499, SPA_IO_HUP); }
static void t132(void) { drop_at(100, SPA_IO_ERR); }

static void t133(void)
{
	SETUP();
	link_up();
	run(100);
	link_drop(SPA_IO_HUP);
	run(200);
	link_release();
	run(3000);
	check_i1();
}

/* The RFCOMM connection ends */

static void rfcomm_lost_at(uint64_t ms)
{
	SETUP();
	link_up();
	run(ms);
	rfcomm_drop();
	int live = fake_timers_live();
	run(3000);
	result(n_vg_between(ms, 3000) == 0 && live == 0,
			"%s; timers left after close: %d", timeline(false), live);
}

static void t140(void) { rfcomm_lost_at(100); }
static void t141(void) { rfcomm_lost_at(1499); }

static void t142(void)
{
	SETUP();
	link_up();
	run(100);
	transport_free_external();
	bool cleared = h.rfcomm->transport == NULL;
	run(3000);
	result(cleared && n_vg_between(100, 3000) == 0,
			"%s; rfcomm->transport %s", timeline(false), cleared ? "NULL" : "set");
}

/* A new link before the deadline */

static void t150(void)
{
	SETUP();
	link_up();
	run(100);
	link_release();
	run(1000);
	link_up();
	run(3000);
	result(n_late() == 0 && spa_streq(vg_at(1500), "") && spa_streq(vg_at(2500), "+VGS:6 +VGM:15"),
			"%s", timeline(false));
}

static void t151(void)
{
	SETUP();
	link_up();
	run(100);
	link_release();
	run(1600);
	link_up();
	run(3500);
	check_i1();
}

/* the real loop may dispatch either first in one iteration; both orders */
static void t152a(void)
{
	SETUP();
	link_up();
	run(100);
	link_release();
	run(1499);
	fake_now = MS(1500);	/* no dispatch: the SCO event comes first */
	link_up();
	run(3500);
	check_i1();
}

static void t152b(void)
{
	SETUP();
	link_up();
	run(100);
	link_release();
	run(1500);		/* the timer comes first */
	link_up();
	run(3500);
	check_i1();
}

static void t153(void)
{
	SETUP();
	link_up();
	run(100);
	link_release();
	run(1000);
	link_up();
	run(1100);
	link_release();
	run(3000);
	check_i1();
}

static void t154(void)
{
	SETUP();
	for (int k = 0; k < 10; k++) {
		run(200 * k);
		link_up();
		run(200 * k + 100);
		link_release();
	}
	run(5000);
	check_i1();
}

/* Codec selection */

static void t160(void)
{
	SETUP();
	link_up();
	run(100);
	mark("hf-bcs=2");
	hf_cmd("AT+BCS=2");
	h.link_up = false;	/* the old transport and its SCO socket are gone */
	close_sco_peer();
	bool armed = volume_timer_armed(NULL);
	run(3000);
	result(!armed && n_vg_between(100, 3000) == 0,
			"%s; resend armed after BCS: %s", timeline(false), armed ? "yes" : "no");
}

static void t161(void)
{
	SETUP();
	link_up();
	run(50);
	link_release();
	run(100);
	mark("hf-bcs=2");
	hf_cmd("AT+BCS=2");
	bool armed = volume_timer_armed(NULL);
	run(3000);
	result(!armed && n_vg_between(50, 3000) == 0,
			"%s; resend armed after BCS: %s", timeline(false), armed ? "yes" : "no");
}

static void t162(void)
{
	SETUP();
	link_up();
	struct spa_bt_transport *old = T();
	run(100);
	mark("hf-bcs=2");
	hf_cmd("AT+BCS=2");
	h.link_up = false;
	close_sco_peer();
	struct spa_bt_transport *t = T();
	struct transport_data *td = TD();
	int state = t->state, fd = t->fd, requesting = td->requesting, err = td->err;
	bool in_loop = td->sco.loop != NULL;
	bool fresh = t != old && state == SPA_BT_TRANSPORT_STATE_IDLE && fd == -1 &&
		!requesting && !in_loop && err == 0;
	bool old_source = fake_loop_has_data(old);
	run(200);
	link_up();
	run(3000);
	result(fresh && !old_source && n_late() == 0 && spa_streq(vg_at(200), "+VGS:6 +VGM:15") &&
			spa_streq(vg_at(1500), "") && spa_streq(vg_at(1700), "+VGS:6 +VGM:15"),
			"%s; after BCS: new transport state=%d fd=%d requesting=%d sco-in-loop=%d err=%d, old SCO source in loop: %s",
			timeline(false), state, fd, requesting, in_loop, err, old_source ? "yes" : "no");
}

static void t163(void)
{
	SETUP();
	link_up();
	struct spa_bt_transport *old = T();
	run(100);
	mark("hf-bcs=3");
	hf_cmd("AT+BCS=3");	/* LC3-SWB, not in AT+BAC */
	bool armed = volume_timer_armed(NULL);
	bool same = T() == old;
	run(3000);
	result(!armed && same && any_frame("ERROR") && n_vg_between(100, 3000) == 0,
			"%s; transport kept: %s; resend armed after BCS: %s; link still up",
			timeline(true), same ? "yes" : "no", armed ? "yes" : "no");
}

/* User volume changes */

static void t170(void)
{
	SETUP();
	int res = user_volume(SPA_BT_VOLUME_ID_TX, 10);
	result(res == 0 && spa_streq(vg_at(0), "+VGS:10"), "res=%d; %s", res, timeline(false));
}

static void t171(void)
{
	SETUP();
	int res = user_volume(SPA_BT_VOLUME_ID_RX, 10);
	result(res == 0 && spa_streq(vg_at(0), "+VGM:10"), "res=%d; %s", res, timeline(false));
}

static void t172(void)
{
	SETUP();
	link_up();
	run(500);
	int res = user_volume(SPA_BT_VOLUME_ID_TX, 10);
	result(res == 0 && spa_streq(vg_at(500), "+VGS:10"), "res=%d; %s", res, timeline(false));
}

static void t173(void)
{
	SETUP();
	link_up();
	run(100);
	link_release();
	run(200);
	int res = user_volume(SPA_BT_VOLUME_ID_TX, 10);
	result(res == 0 && spa_streq(vg_at(200), "+VGS:10"), "res=%d; %s", res, timeline(false));
}

static void t174(void)
{
	SETUP();
	int res = user_volume(SPA_BT_VOLUME_ID_TX, 6);
	result(res == 0 && n_vg() == 0, "res=%d; %s", res, timeline(false));
}

static void t175(void)
{
	SETUP(.no_vgm = true);
	int res = user_volume(SPA_BT_VOLUME_ID_RX, 10);
	result(res == -ENOTSUP && n_vg() == 0, "res=%d; %s", res, timeline(false));
}

/* Headset reports */

static void report(int id, const char *cmd)
{
	SETUP(.no_vgs = true, .no_vgm = true);
	hf_cmd("%s", cmd);
	struct rfcomm_volume *v = &h.rfcomm->volumes[id];
	struct spa_bt_transport_volume *tv = &T()->volumes[id];
	bool ok = v->active && v->hw_volume == 7 && tv->active &&
		tv->volume == (float)spa_bt_volume_hw_to_linear(7, SPA_BT_VOLUME_HS_MAX);
	result(ok && any_frame("OK") && n_vg() == 0,
			"%s; active=%d hw=%d transport active=%d volume=%.4f",
			timeline(true), v->active, v->hw_volume, tv->active, tv->volume);
}

static void t180(void) { report(SPA_BT_VOLUME_ID_TX, "AT+VGS=7"); }
static void t181(void) { report(SPA_BT_VOLUME_ID_RX, "AT+VGM=7"); }

static void t182(void)
{
	SETUP();
	link_up();
	run(500);
	mark("hf-vgm=9");
	hf_cmd("AT+VGM=9");
	run(2000);
	result(spa_streq(vg_at(1500), "+VGS:6 +VGM:9"), "%s", timeline(false));
}

static void t183(void)
{
	SETUP();
	mark("hf-vgs=16");
	hf_cmd("AT+VGS=16");
	mark("hf-vgs=-1");
	hf_cmd("AT+VGS=-1");
	mark("hf-vgm=16");
	hf_cmd("AT+VGM=16");
	int errors = 0;
	for (int i = 0; i < h.n_ev; i++)
		errors += !h.ev[i].mark && spa_streq(h.ev[i].text, "ERROR");
	struct rfcomm_volume *tx = &h.rfcomm->volumes[SPA_BT_VOLUME_ID_TX];
	struct rfcomm_volume *rx = &h.rfcomm->volumes[SPA_BT_VOLUME_ID_RX];
	result(errors == 3 && tx->hw_volume == 6 && rx->hw_volume == 15 && n_vg() == 0,
			"%s; gains kept vgs=%d vgm=%d", timeline(true), tx->hw_volume, rx->hw_volume);
}

/* Extra variants, not in TEST-PLAN.md: CVSD without codec negotiation, HSP */

static void t120c(void)
{
	SETUP(.cvsd_only = true);
	link_up();
	run(100);
	link_release();
	run(3000);
	check_i1();
}

static void t130c(void)
{
	SETUP(.cvsd_only = true);
	link_up();
	run(100);
	link_drop(SPA_IO_HUP);
	run(3000);
	check_i1();
}

static void t120h(void)
{
	SETUP(.hsp = true);
	link_up();
	run(100);
	link_release();
	run(3000);
	check_i1();
}

static void t130h(void)
{
	SETUP(.hsp = true);
	link_up();
	run(100);
	link_drop(SPA_IO_HUP);
	run(3000);
	check_i1();
}

/* runner: one child per test, so a crash or sanitizer report stays with its test */

struct test {
	const char *id;
	const char *expect;	/* TEST-PLAN.md: leak (fails on master), keep, record */
	void (*run)(void);
};

static const struct test tests[] = {
	{ "T101", "keep", t101 }, { "T102", "keep", t102 }, { "T103", "keep", t103 },
	{ "T104", "keep", t104 }, { "T105", "keep", t105 }, { "T106", "keep", t106 },
	{ "T107", "keep", t107 }, { "T108", "keep", t108 },
	{ "T110", "keep", t110 }, { "T111", "keep", t111 }, { "T112", "keep", t112 },
	{ "T113", "keep", t113 }, { "T114", "keep", t114 },
	{ "T120", "leak", t120 }, { "T121", "leak", t121 }, { "T122", "keep", t122 },
	{ "T123", "keep", t123 }, { "T124", "leak", t124 },
	{ "T130", "leak", t130 }, { "T131", "leak", t131 }, { "T132", "leak", t132 },
	{ "T133", "leak", t133 },
	{ "T140", "keep", t140 }, { "T141", "keep", t141 }, { "T142", "keep", t142 },
	{ "T150", "keep", t150 }, { "T151", "leak", t151 }, { "T152a", "record", t152a },
	{ "T152b", "record", t152b }, { "T153", "leak", t153 }, { "T154", "leak", t154 },
	{ "T160", "keep", t160 }, { "T161", "keep", t161 }, { "T162", "keep", t162 },
	{ "T163", "keep", t163 },
	{ "T170", "keep", t170 }, { "T171", "keep", t171 }, { "T172", "keep", t172 },
	{ "T173", "keep", t173 }, { "T174", "keep", t174 }, { "T175", "keep", t175 },
	{ "T180", "keep", t180 }, { "T181", "keep", t181 }, { "T182", "keep", t182 },
	{ "T183", "keep", t183 },
	{ "T120c", "extra", t120c }, { "T130c", "extra", t130c },
	{ "T120h", "extra", t120h }, { "T130h", "extra", t130h },
};

static int count_fds(void)
{
	DIR *d = opendir("/proc/self/fd");
	int n = 0;

	if (d == NULL)
		return -1;
	while (readdir(d))
		n++;
	closedir(d);
	return n;
}

/* I8 after every test: free what is left, then nothing may remain */
static void teardown(char *buf, size_t sz)
{
	size_t n = 0;

	buf[0] = '\0';
	if (h.rf_peer >= 0)
		drain(C_END);
	if (h.rfcomm) {
		rfcomm_free(h.rfcomm);
		h.rfcomm = NULL;
	}
	close_sco_peer();
	if (h.rf_peer >= 0)
		close(h.rf_peer);
	h.rf_peer = -1;

#define I8(cond, ...) if (cond) n += snprintf(buf + n, sz - n, __VA_ARGS__)
	I8(fake_loop_n_sources(), " %d loop sources left;", fake_loop_n_sources());
	I8(fake_timers_live(), " %d timers left;", fake_timers_live());
	I8(fake_timerfds_open(), " %d timerfds open;", fake_timerfds_open());
	I8(stub_transports_live, " %d transports left;", stub_transports_live);
	I8(!spa_list_is_empty(&h.device.transport_list), " device transport list not empty;");
	I8(!spa_hook_list_is_empty(&h.device.listener_list), " device listener left;");
#undef I8
}

static void run_child(const struct test *t, int out)
{
	char i8[512], line[4096];
	int fds = count_fds(), n;

	h.verdict[0] = '\0';
	t->run();
	if (h.verdict[0] == '\0')
		result(false, "no verdict");
	teardown(i8, sizeof(i8));
	n = count_fds();
	if (n != fds)
		snprintf(i8 + strlen(i8), sizeof(i8) - strlen(i8), " fds %d -> %d;", fds, n);

	if (i8[0] && spa_strstartswith(h.verdict, "PASS"))
		snprintf(line, sizeof(line), "%s FAIL I8:%s %s", t->id, i8, h.verdict + 5);
	else if (i8[0])
		snprintf(line, sizeof(line), "%s %s | I8:%s", t->id, h.verdict, i8);
	else
		snprintf(line, sizeof(line), "%s %s", t->id, h.verdict);
	if (write(out, line, strlen(line)) < 0)
		abort();
}

static bool run_test(const struct test *t)
{
	char line[4096];
	size_t len = 0;
	int p[2], status;
	pid_t pid;
	bool pass;

	if (pipe(p) < 0)
		abort();
	fflush(stdout);
	fflush(stderr);
	if (verbose)
		fprintf(stderr, "== %s\n", t->id);
	pid = fork();
	if (pid == 0) {
		close(p[0]);
		run_child(t, p[1]);
		close(p[1]);
		exit(0);	/* LeakSanitizer runs here */
	}
	close(p[1]);
	for (;;) {
		ssize_t r = read(p[0], line + len, sizeof(line) - 1 - len);
		if (r <= 0)
			break;
		len += r;
	}
	line[len] = '\0';
	close(p[0]);
	waitpid(pid, &status, 0);

	if (WIFSIGNALED(status) || WEXITSTATUS(status) != 0) {
		char why[64];
		if (WIFSIGNALED(status))
			snprintf(why, sizeof(why), "signal %d", WTERMSIG(status));
		else
			snprintf(why, sizeof(why), "exit %d", WEXITSTATUS(status));
		printf("%s FAIL crash or sanitizer report (%s, see above)%s%s\n", t->id, why,
				len ? "; test said: " : "", len ? line + strlen(t->id) + 1 : "");
		return false;
	}
	printf("%s\n", line);
	pass = strstr(line, " PASS ") != NULL;
	return pass;
}

int main(int argc, char *argv[])
{
	char unexpected[512] = "";
	int n_pass = 0, n_fail = 0, n_run = 0;

	setvbuf(stdout, NULL, _IOLBF, 0);
	for (int i = 1; i < argc; i++)
		if (spa_streq(argv[i], "-v"))
			verbose = true;
	/* warnings expected in every link: getsockopt(SCO_OPTIONS) on a socketpair */
	fake_log_set_level(verbose ? SPA_LOG_LEVEL_DEBUG : SPA_LOG_LEVEL_ERROR);

	for (size_t i = 0; i < SPA_N_ELEMENTS(tests); i++) {
		const struct test *t = &tests[i];
		bool selected = true, pass;

		for (int a = 1; a < argc; a++) {
			if (argv[a][0] == '-')
				continue;
			selected = false;
			if (spa_streq(argv[a], t->id)) {
				selected = true;
				break;
			}
		}
		if (!selected)
			continue;

		pass = run_test(t);
		n_run++;
		pass ? n_pass++ : n_fail++;
		if ((spa_streq(t->expect, "leak") && pass) || (spa_streq(t->expect, "keep") && !pass))
			snprintf(unexpected + strlen(unexpected), sizeof(unexpected) - strlen(unexpected),
					" %s(%s)", t->id, t->expect);
	}
	printf("# %d tests: %d PASS, %d FAIL\n", n_run, n_pass, n_fail);
	printf("# differs from TEST-PLAN.md's master outcome (leak = FAIL, keep = PASS):%s\n",
			unexpected[0] ? unexpected : " none");
	return 0;
}
