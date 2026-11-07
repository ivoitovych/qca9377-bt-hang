// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * CO-03 L1 harness: profiles/audio/transport.c of a BlueZ tree, included
 * into this program and driven through its D-Bus method table, with the
 * A2DP/AVDTP layer, gdbus and the rest of bluetoothd replaced by stubs
 * that record calls and let a test complete each AVDTP operation (START,
 * SUSPEND) by hand, in any order, with any result.
 *
 * The same file is compiled against every tree (base, backport) unchanged;
 * it only uses what both trees have.
 *
 * Output: one line per test, "RESULT <id> PASS|FAIL <detail>", and a
 * summary line. Exit status 0 even if tests fail (the runner compares).
 */

#include "profiles/audio/transport.c"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <unistd.h>

/* ------------------------------------------------------------------ */
/* World                                                                */

#define MAX_OPS 64
#define MAX_CALLS 64
#define MAX_WATCHES 32

enum op_kind { OP_RESUME, OP_SUSPEND };

struct fake_op {
	unsigned int id;
	enum op_kind kind;
	a2dp_stream_cb_t cb;
	void *user_data;
	int active;
};

struct fake_call {
	char member[32];
	char sender[32];
	DBusMessage *msg;
	dbus_uint32_t serial;
	int replies;
	char error[128];
};

struct fake_watch {
	guint id;
	char name[32];
	GDBusWatchFunction func;
	void *user_data;
	int active;
};

static struct {
	struct fake_op ops[MAX_OPS];
	int n_ops;
	unsigned int next_id;
	int resume_fail;	/* a2dp_resume returns 0 */
	int suspend_fail;	/* a2dp_suspend returns 0 */
	int stream_null;	/* a2dp_sep_get_stream returns NULL */
	int cancels;		/* a2dp_cancel calls */
	unsigned int cancel_ids[MAX_OPS];
	int locked;
	int lock_calls, unlock_calls;

	struct fake_call calls[MAX_CALLS];
	int n_calls;
	dbus_uint32_t serial;

	struct fake_watch watches[MAX_WATCHES];
	int n_watches;
	guint next_watch;

	const GDBusMethodTable *methods;
	void *iface_data;
	GDBusDestroyFunction iface_destroy;
	int registered;

	sink_state_cb sink_cb;
	void *sink_cb_data;
	int sink_cb_registered;

	int sv[2];
	int stray_replies;
} W;

static int fake_session_obj, fake_sep_obj, fake_stream_obj, fake_service_obj;
static int fake_device_obj, fake_endpoint_obj, fake_conn_obj;

#define FAKE_SESSION ((struct avdtp *) &fake_session_obj)
#define FAKE_SEP ((struct a2dp_sep *) &fake_sep_obj)
#define FAKE_STREAM ((struct avdtp_stream *) &fake_stream_obj)
#define FAKE_SERVICE ((struct btd_service *) &fake_service_obj)
#define FAKE_DEVICE ((struct btd_device *) &fake_device_obj)
#define FAKE_ENDPOINT ((struct media_endpoint *) &fake_endpoint_obj)
#define FAKE_CONN ((DBusConnection *) &fake_conn_obj)

static int verbose;

static void world_reset(void)
{
	int i;

	for (i = 0; i < W.n_calls; i++)
		if (W.calls[i].msg)
			dbus_message_unref(W.calls[i].msg);

	memset(&W, 0, sizeof(W));
	W.next_id = 100;
	W.next_watch = 1;
	W.serial = 1;
	socketpair(AF_UNIX, SOCK_SEQPACKET, 0, W.sv);
}

static void run_idle(void)
{
	int n = 0;

	while (g_main_context_iteration(NULL, FALSE) && n < 1000)
		n++;
}

/* ------------------------------------------------------------------ */
/* Stubs: logging                                                       */

void info(const char *format, ...)
{
	va_list ap;

	if (!verbose)
		return;
	va_start(ap, format);
	fprintf(stderr, "  info: ");
	vfprintf(stderr, format, ap);
	fprintf(stderr, "\n");
	va_end(ap);
}

void btd_error(uint16_t index, const char *format, ...)
{
	va_list ap;

	if (!verbose)
		return;
	va_start(ap, format);
	fprintf(stderr, "  error: ");
	vfprintf(stderr, format, ap);
	fprintf(stderr, "\n");
	va_end(ap);
}

void btd_debug(uint16_t index, const char *format, ...)
{
	va_list ap;

	if (!verbose)
		return;
	va_start(ap, format);
	fprintf(stderr, "  debug: ");
	vfprintf(stderr, format, ap);
	fprintf(stderr, "\n");
	va_end(ap);
}

extern struct btd_debug_desc __start___debug[];
extern struct btd_debug_desc __stop___debug[];

static void enable_debug(void)
{
	struct btd_debug_desc *d;

	for (d = __start___debug; d < __stop___debug; d++)
		d->flags |= BTD_DEBUG_FLAG_PRINT;
}

void *util_malloc(size_t size)
{
	void *p = malloc(size);

	if (!p)
		abort();
	return p;
}

/* ------------------------------------------------------------------ */
/* Stubs: D-Bus                                                         */

DBusConnection *btd_get_dbus_connection(void)
{
	return FAKE_CONN;
}

static struct fake_call *call_by_msg(DBusMessage *msg)
{
	int i;

	for (i = 0; i < W.n_calls; i++)
		if (W.calls[i].msg == msg)
			return &W.calls[i];
	return NULL;
}

static struct fake_call *call_by_serial(dbus_uint32_t serial)
{
	int i;

	for (i = 0; i < W.n_calls; i++)
		if (W.calls[i].serial == serial)
			return &W.calls[i];
	return NULL;
}

static void record_reply(DBusMessage *reply)
{
	struct fake_call *c = call_by_serial(dbus_message_get_reply_serial(reply));

	if (!c) {
		W.stray_replies++;
		return;
	}

	c->replies++;
	if (dbus_message_get_type(reply) == DBUS_MESSAGE_TYPE_ERROR)
		snprintf(c->error, sizeof(c->error), "%s",
					dbus_message_get_error_name(reply));
}

DBusMessage *g_dbus_create_error(DBusMessage *message, const char *name,
						const char *format, ...)
{
	char buf[256];
	va_list ap;

	va_start(ap, format);
	vsnprintf(buf, sizeof(buf), format, ap);
	va_end(ap);

	return dbus_message_new_error(message, name, buf);
}

DBusMessage *g_dbus_create_reply(DBusMessage *message, int type, ...)
{
	return dbus_message_new_method_return(message);
}

gboolean g_dbus_send_message(DBusConnection *connection, DBusMessage *message)
{
	record_reply(message);
	dbus_message_unref(message);
	return TRUE;
}

gboolean g_dbus_send_reply(DBusConnection *connection,
				DBusMessage *message, int type, ...)
{
	struct fake_call *c = call_by_msg(message);

	if (c)
		c->replies++;
	else
		W.stray_replies++;
	return TRUE;
}

DBusMessage *btd_error_not_authorized(DBusMessage *msg)
{
	return dbus_message_new_error(msg, ERROR_INTERFACE ".NotAuthorized",
							"Operation Not Authorized");
}

DBusMessage *btd_error_in_progress(DBusMessage *msg)
{
	return dbus_message_new_error(msg, ERROR_INTERFACE ".InProgress",
							"In Progress");
}

DBusMessage *btd_error_not_available(DBusMessage *msg)
{
	return dbus_message_new_error(msg, ERROR_INTERFACE ".NotAvailable",
							"Operation currently not available");
}

gboolean g_dbus_register_interface(DBusConnection *connection,
					const char *path, const char *name,
					const GDBusMethodTable *methods,
					const GDBusSignalTable *signals,
					const GDBusPropertyTable *properties,
					void *user_data,
					GDBusDestroyFunction destroy)
{
	W.methods = methods;
	W.iface_data = user_data;
	W.iface_destroy = destroy;
	W.registered = 1;
	return TRUE;
}

gboolean g_dbus_unregister_interface(DBusConnection *connection,
					const char *path, const char *name)
{
	if (!W.registered)
		return FALSE;
	W.registered = 0;
	if (W.iface_destroy)
		W.iface_destroy(W.iface_data);
	return TRUE;
}

guint g_dbus_add_disconnect_watch(DBusConnection *connection, const char *name,
				GDBusWatchFunction function,
				void *user_data, GDBusDestroyFunction destroy)
{
	struct fake_watch *w = &W.watches[W.n_watches++];

	w->id = W.next_watch++;
	snprintf(w->name, sizeof(w->name), "%s", name);
	w->func = function;
	w->user_data = user_data;
	w->active = 1;
	return w->id;
}

gboolean g_dbus_remove_watch(DBusConnection *connection, guint tag)
{
	int i;

	for (i = 0; i < W.n_watches; i++)
		if (W.watches[i].id == tag && W.watches[i].active) {
			W.watches[i].active = 0;
			return TRUE;
		}
	return FALSE;
}

void g_dbus_emit_property_changed(DBusConnection *connection,
				const char *path, const char *interface,
				const char *name)
{
}

void g_dbus_pending_property_success(GDBusPendingPropertySet id)
{
}

void g_dbus_pending_property_error(GDBusPendingReply id, const char *name,
						const char *format, ...)
{
}

void dict_append_entry(DBusMessageIter *dict, const char *key, int type,
								void *val)
{
}

void dict_append_array(DBusMessageIter *dict, const char *key, int type,
							void *val, int n_elements)
{
}

/* ------------------------------------------------------------------ */
/* Stubs: device, adapter, endpoint, AVRCP                             */

const char *device_get_path(const struct btd_device *device)
{
	return "/org/bluez/hci0/dev_00_11_22_33_44_55";
}

const char *adapter_get_path(struct btd_adapter *adapter)
{
	return "/org/bluez/hci0";
}

struct btd_service *btd_device_get_service(struct btd_device *dev,
						const char *remote_uuid)
{
	return FAKE_SERVICE;
}

void btd_device_set_volume(struct btd_device *dev, int8_t volume)
{
}

int8_t btd_device_get_volume(struct btd_device *dev)
{
	return -1;
}

int avrcp_set_volume(struct btd_device *dev, int8_t volume, bool notify)
{
	return 0;
}

struct a2dp_sep *media_endpoint_get_sep(struct media_endpoint *endpoint)
{
	return FAKE_SEP;
}

const char *media_endpoint_get_uuid(struct media_endpoint *endpoint)
{
	return A2DP_SOURCE_UUID;
}

uint8_t media_endpoint_get_codec(struct media_endpoint *endpoint)
{
	return 0;
}

struct btd_adapter *media_endpoint_get_btd_adapter(
					struct media_endpoint *endpoint)
{
	return NULL;
}

bool media_endpoint_is_broadcast(struct media_endpoint *endpoint)
{
	return false;
}

unsigned int sink_add_state_cb(struct btd_service *service, sink_state_cb cb,
							void *user_data)
{
	W.sink_cb = cb;
	W.sink_cb_data = user_data;
	W.sink_cb_registered = 1;
	return 1;
}

gboolean sink_remove_state_cb(unsigned int id)
{
	W.sink_cb_registered = 0;
	return TRUE;
}

unsigned int source_add_state_cb(struct btd_service *service,
					source_state_cb cb, void *user_data)
{
	return 2;
}

gboolean source_remove_state_cb(unsigned int id)
{
	return TRUE;
}

/* ------------------------------------------------------------------ */
/* Stubs: A2DP / AVDTP (the operations the tests complete by hand)      */

struct avdtp *a2dp_avdtp_get(struct btd_device *device)
{
	return FAKE_SESSION;
}

void avdtp_unref(struct avdtp *session)
{
}

static unsigned int add_op(enum op_kind kind, a2dp_stream_cb_t cb,
							void *user_data)
{
	struct fake_op *op = &W.ops[W.n_ops++];

	op->id = W.next_id++;
	op->kind = kind;
	op->cb = cb;
	op->user_data = user_data;
	op->active = 1;
	return op->id;
}

unsigned int a2dp_resume(struct avdtp *session, struct a2dp_sep *sep,
				a2dp_stream_cb_t cb, void *user_data)
{
	if (W.resume_fail)
		return 0;
	return add_op(OP_RESUME, cb, user_data);
}

unsigned int a2dp_suspend(struct avdtp *session, struct a2dp_sep *sep,
				a2dp_stream_cb_t cb, void *user_data)
{
	if (W.suspend_fail)
		return 0;
	return add_op(OP_SUSPEND, cb, user_data);
}

gboolean a2dp_cancel(unsigned int id)
{
	int i;

	W.cancel_ids[W.cancels++] = id;
	for (i = 0; i < W.n_ops; i++)
		if (W.ops[i].id == id && W.ops[i].active) {
			W.ops[i].active = 0;
			return TRUE;
		}
	return FALSE;
}

gboolean a2dp_sep_lock(struct a2dp_sep *sep, struct avdtp *session)
{
	W.lock_calls++;
	if (W.locked)
		return FALSE;
	W.locked = 1;
	return TRUE;
}

gboolean a2dp_sep_unlock(struct a2dp_sep *sep, struct avdtp *session)
{
	W.unlock_calls++;
	W.locked = 0;
	return TRUE;
}

struct avdtp_stream *a2dp_sep_get_stream(struct a2dp_sep *sep)
{
	return W.stream_null ? NULL : FAKE_STREAM;
}

gboolean avdtp_stream_get_transport(struct avdtp_stream *stream, int *sock,
					uint16_t *imtu, uint16_t *omtu,
					GSList **caps)
{
	*sock = W.sv[0];
	*imtu = 672;
	*omtu = 672;
	return TRUE;
}

/* ------------------------------------------------------------------ */
/* Stubs never reached on the A2DP paths: abort if they are            */

#define NEVER(what) do { fprintf(stderr, "unexpected call: %s\n", what); \
					abort(); } while (0)

gboolean bt_io_get(GIOChannel *io, GError **err, BtIOOption opt1, ...)
{ NEVER("bt_io_get"); }
int io_get_fd(struct io *io) { NEVER("io_get_fd"); }
unsigned int bt_bap_state_register(struct bt_bap *bap,
				bt_bap_state_func_t func,
				bt_bap_connecting_func_t connecting,
				void *user_data, bt_bap_destroy_func_t destroy)
{ NEVER("bt_bap_state_register"); }
bool bt_bap_state_unregister(struct bt_bap *bap, unsigned int id)
{ NEVER("bt_bap_state_unregister"); }
const char *bt_bap_stream_statestr(uint8_t state)
{ NEVER("bt_bap_stream_statestr"); }
struct bt_bap *bt_bap_stream_get_session(struct bt_bap_stream *stream)
{ NEVER("bt_bap_stream_get_session"); }
uint8_t bt_bap_stream_get_state(struct bt_bap_stream *stream)
{ NEVER("bt_bap_stream_get_state"); }
uint8_t bt_bap_stream_get_type(struct bt_bap_stream *stream)
{ NEVER("bt_bap_stream_get_type"); }
unsigned int bt_bap_stream_enable(struct bt_bap_stream *stream,
					bool enable_links,
					struct iovec *metadata,
					bt_bap_stream_func_t func,
					void *user_data)
{ NEVER("bt_bap_stream_enable"); }
unsigned int bt_bap_stream_disable(struct bt_bap_stream *stream,
					bool disable_links,
					bt_bap_stream_func_t func,
					void *user_data)
{ NEVER("bt_bap_stream_disable"); }
uint32_t bt_bap_stream_get_location(struct bt_bap_stream *stream)
{ NEVER("bt_bap_stream_get_location"); }
struct bt_bap_qos *bt_bap_stream_get_qos(struct bt_bap_stream *stream)
{ NEVER("bt_bap_stream_get_qos"); }
struct iovec *bt_bap_stream_get_metadata(struct bt_bap_stream *stream)
{ NEVER("bt_bap_stream_get_metadata"); }
struct io *bt_bap_stream_get_io(struct bt_bap_stream *stream)
{ NEVER("bt_bap_stream_get_io"); }
int bt_bap_stream_cancel(struct bt_bap_stream *stream, unsigned int id)
{ NEVER("bt_bap_stream_cancel"); }
struct bt_bap_stream *bt_bap_stream_io_get_link(struct bt_bap_stream *stream)
{ NEVER("bt_bap_stream_io_get_link"); }
uint8_t bt_bap_stream_io_dir(struct bt_bap_stream *stream)
{ NEVER("bt_bap_stream_io_dir"); }

/* ------------------------------------------------------------------ */
/* Driving the transport                                               */

static struct media_transport *T;

static struct media_transport *make_transport(void)
{
	uint8_t conf[4] = { 0x21, 0x15, 2, 53 };

	T = media_transport_create(FAKE_DEVICE, NULL, conf, sizeof(conf),
						FAKE_ENDPOINT, NULL);
	return T;
}

static void destroy_transport(void)
{
	if (W.registered)
		media_transport_destroy(T);
	T = NULL;
}

/* Calls method <member> as <sender>; returns the call record */
static struct fake_call *call(const char *member, const char *sender)
{
	const GDBusMethodTable *m;
	struct fake_call *c = &W.calls[W.n_calls++];
	DBusMessage *reply;

	snprintf(c->member, sizeof(c->member), "%s", member);
	snprintf(c->sender, sizeof(c->sender), "%s", sender);
	c->msg = dbus_message_new_method_call("org.bluez", T->path,
					MEDIA_TRANSPORT_INTERFACE, member);
	dbus_message_set_sender(c->msg, sender);
	c->serial = W.serial++;
	dbus_message_set_serial(c->msg, c->serial);

	for (m = W.methods; m && m->name; m++) {
		if (strcmp(m->name, member))
			continue;
		reply = m->function(FAKE_CONN, c->msg, T);
		if (reply) {
			record_reply(reply);
			dbus_message_unref(reply);
		}
		break;
	}

	run_idle();
	return c;
}

static struct fake_op *last_op(enum op_kind kind)
{
	int i;

	for (i = W.n_ops - 1; i >= 0; i--)
		if (W.ops[i].kind == kind)
			return &W.ops[i];
	return NULL;
}

static int active_ops(enum op_kind kind)
{
	int i, n = 0;

	for (i = 0; i < W.n_ops; i++)
		if (W.ops[i].kind == kind && W.ops[i].active)
			n++;
	return n;
}

/* The AVDTP operation completes (START_RSP/SUSPEND_RSP, or an error) */
static int complete(struct fake_op *op, int err)
{
	if (!op || !op->active)
		return -1;
	op->active = 0;
	op->cb(FAKE_SESSION, err, op->user_data);
	run_idle();
	return 0;
}

static void owner_exit(const char *sender)
{
	int i;

	for (i = 0; i < W.n_watches; i++) {
		struct fake_watch *w = &W.watches[i];

		if (w->active && !strcmp(w->name, sender)) {
			w->active = 0;
			w->func(FAKE_CONN, w->user_data);
		}
	}
	run_idle();
}

static void sink_state(sink_state_t old, sink_state_t new)
{
	if (W.sink_cb_registered)
		W.sink_cb(FAKE_SERVICE, old, new, W.sink_cb_data);
	run_idle();
}

/* ------------------------------------------------------------------ */
/* Test framework                                                       */

static int n_pass, n_fail;
static char detail[512];

#define CHECK(cond, ...) do { if (!(cond)) { \
		snprintf(detail, sizeof(detail), __VA_ARGS__); return 1; } \
	} while (0)

static void run(const char *id, const char *title, int (*fn)(void))
{
	int r;

	world_reset();
	detail[0] = '\0';
	if (verbose)
		fprintf(stderr, "== %s %s\n", id, title);
	make_transport();
	r = fn();
	destroy_transport();
	run_idle();
	close(W.sv[0]);
	close(W.sv[1]);
	if (r == 0)
		n_pass++;
	else
		n_fail++;
	printf("RESULT %s %s %s%s%s\n", id, r ? "FAIL" : "PASS", title,
					detail[0] ? " :: " : "", detail);
}

#define OWNER ":1.10"
#define OTHER ":1.11"

/* Acquire on an idle transport, START pending */
static struct fake_call *acquire_pending(void)
{
	return call("Acquire", OWNER);
}

/* ------------------------------------------------------------------ */
/* Tests: normal order (keep)                                          */

static int t_u101(void)
{
	struct fake_call *a = acquire_pending();

	CHECK(a->replies == 0, "Acquire answered at once (%d, %s)", a->replies, a->error);
	CHECK(active_ops(OP_RESUME) == 1, "resume ops %d", active_ops(OP_RESUME));
	CHECK(W.locked, "sep not locked");
	CHECK(T->state == TRANSPORT_STATE_REQUESTING, "state %d", T->state);
	CHECK(T->owner != NULL, "no owner");
	return 0;
}

static int t_u102(void)
{
	struct fake_call *a = acquire_pending();

	complete(last_op(OP_RESUME), 0);
	CHECK(a->replies == 1 && !a->error[0], "Acquire replies %d err '%s'", a->replies, a->error);
	CHECK(T->state == TRANSPORT_STATE_ACTIVE, "state %d", T->state);
	CHECK(T->fd == W.sv[0], "fd %d", T->fd);
	return 0;
}

static int t_u103(void)
{
	struct fake_call *a = acquire_pending();

	complete(last_op(OP_RESUME), -EIO);
	CHECK(a->replies == 1 && a->error[0], "Acquire replies %d err '%s'", a->replies, a->error);
	CHECK(T->owner == NULL, "owner kept");
	CHECK(T->state == TRANSPORT_STATE_IDLE, "state %d", T->state);
	CHECK(!W.locked, "sep still locked");
	return 0;
}

static int t_u104(void)
{
	struct fake_call *a = acquire_pending(), *r;

	complete(last_op(OP_RESUME), 0);
	r = call("Release", OWNER);
	CHECK(r->replies == 0, "Release answered before SUSPEND completed");
	CHECK(active_ops(OP_SUSPEND) == 1, "suspend ops %d", active_ops(OP_SUSPEND));
	complete(last_op(OP_SUSPEND), 0);
	CHECK(r->replies == 1 && !r->error[0], "Release replies %d err '%s'", r->replies, r->error);
	CHECK(T->state == TRANSPORT_STATE_IDLE, "state %d", T->state);
	CHECK(T->owner == NULL, "owner kept");
	CHECK(!W.locked, "sep still locked");
	CHECK(W.cancels == 0, "a2dp_cancel called %d", W.cancels);
	CHECK(a->replies == 1, "Acquire replies %d", a->replies);
	return 0;
}

static int t_u105(void)
{
	/* SUSPEND completes with an error: Release still succeeds */
	struct fake_call *r;

	acquire_pending();
	complete(last_op(OP_RESUME), 0);
	r = call("Release", OWNER);
	complete(last_op(OP_SUSPEND), -EIO);
	CHECK(r->replies == 1 && !r->error[0], "Release replies %d err '%s'", r->replies, r->error);
	CHECK(T->state == TRANSPORT_STATE_IDLE, "state %d", T->state);
	return 0;
}

static int t_u106(void)
{
	/* two Acquire/Release cycles in a row */
	int i;

	for (i = 0; i < 2; i++) {
		struct fake_call *a = acquire_pending(), *r;

		CHECK(complete(last_op(OP_RESUME), 0) == 0, "cycle %d: no resume op", i);
		CHECK(a->replies == 1 && !a->error[0], "cycle %d: Acquire %d '%s'", i, a->replies, a->error);
		r = call("Release", OWNER);
		CHECK(complete(last_op(OP_SUSPEND), 0) == 0, "cycle %d: no suspend op", i);
		CHECK(r->replies == 1 && !r->error[0], "cycle %d: Release %d '%s'", i, r->replies, r->error);
	}
	CHECK(W.cancels == 0, "a2dp_cancel called %d", W.cancels);
	return 0;
}

static int t_u107(void)
{
	/* Acquire while acquired by the same owner */
	struct fake_call *b;

	acquire_pending();
	complete(last_op(OP_RESUME), 0);
	b = call("Acquire", OWNER);
	CHECK(b->replies == 1 && !strcmp(b->error, ERROR_INTERFACE ".NotAuthorized"), "second Acquire '%s'", b->error);
	return 0;
}

static int t_u108(void)
{
	/* Acquire by another client while acquired */
	struct fake_call *b;

	acquire_pending();
	complete(last_op(OP_RESUME), 0);
	b = call("Acquire", OTHER);
	CHECK(b->replies == 1 && !strcmp(b->error, ERROR_INTERFACE ".NotAuthorized"), "other Acquire '%s'", b->error);
	return 0;
}

static int t_u109(void)
{
	/* Release by a client that is not the owner */
	struct fake_call *r;

	acquire_pending();
	complete(last_op(OP_RESUME), 0);
	r = call("Release", OTHER);
	CHECK(r->replies == 1 && !strcmp(r->error, ERROR_INTERFACE ".NotAuthorized"), "Release '%s'", r->error);
	CHECK(T->state == TRANSPORT_STATE_ACTIVE, "state %d", T->state);
	return 0;
}

static int t_u110(void)
{
	/* Release with no owner */
	struct fake_call *r = call("Release", OWNER);

	CHECK(r->replies == 1 && !strcmp(r->error, ERROR_INTERFACE ".NotAuthorized"), "Release '%s'", r->error);
	return 0;
}

static int t_u111(void)
{
	/* a2dp_resume fails at once: Acquire refused, lock released */
	struct fake_call *a;

	W.resume_fail = 1;
	a = acquire_pending();
	CHECK(a->replies == 1 && !strcmp(a->error, ERROR_INTERFACE ".NotAuthorized"), "Acquire '%s'", a->error);
	CHECK(!W.locked, "sep still locked");
	CHECK(T->owner == NULL, "owner set");
	return 0;
}

static int t_u112(void)
{
	/* TryAcquire on an idle transport: not available */
	struct fake_call *a = call("TryAcquire", OWNER);

	CHECK(a->replies == 1 && !strcmp(a->error, ERROR_INTERFACE ".NotAvailable"), "TryAcquire '%s'", a->error);
	return 0;
}

static int t_u113(void)
{
	/* remote starts (sink PLAYING): pending; TryAcquire works */
	struct fake_call *a;

	sink_state(SINK_STATE_CONNECTED, SINK_STATE_PLAYING);
	CHECK(T->state == TRANSPORT_STATE_PENDING, "state %d", T->state);
	a = call("TryAcquire", OWNER);
	CHECK(a->replies == 0, "TryAcquire answered at once '%s'", a->error);
	complete(last_op(OP_RESUME), 0);
	CHECK(a->replies == 1 && !a->error[0], "TryAcquire %d '%s'", a->replies, a->error);
	CHECK(T->state == TRANSPORT_STATE_ACTIVE, "state %d", T->state);
	return 0;
}

static int t_u114(void)
{
	/* Release during a pending TryAcquire: InProgress (only Acquire is
	 * cancelled by Release) */
	struct fake_call *a, *r;

	sink_state(SINK_STATE_CONNECTED, SINK_STATE_PLAYING);
	a = call("TryAcquire", OWNER);
	r = call("Release", OWNER);
	CHECK(r->replies == 1 && !strcmp(r->error, ERROR_INTERFACE ".InProgress"), "Release '%s'", r->error);
	CHECK(W.cancels == 0, "a2dp_cancel called %d", W.cancels);
	complete(last_op(OP_RESUME), 0);
	CHECK(a->replies == 1 && !a->error[0], "TryAcquire %d '%s'", a->replies, a->error);
	return 0;
}

static int t_u115(void)
{
	/* remote suspends while active: owner removed */
	acquire_pending();
	complete(last_op(OP_RESUME), 0);
	sink_state(SINK_STATE_PLAYING, SINK_STATE_CONNECTED);
	CHECK(T->owner == NULL, "owner kept");
	CHECK(T->state == TRANSPORT_STATE_IDLE, "state %d", T->state);
	CHECK(!W.locked, "sep still locked");
	return 0;
}

static int t_u116(void)
{
	/* second Release while the first waits for SUSPEND: InProgress */
	struct fake_call *r1, *r2, *a2;

	acquire_pending();
	complete(last_op(OP_RESUME), 0);
	r1 = call("Release", OWNER);
	r2 = call("Release", OWNER);
	CHECK(r2->replies == 1 && !strcmp(r2->error, ERROR_INTERFACE ".InProgress"), "second Release '%s'", r2->error);
	a2 = call("Acquire", OWNER);
	CHECK(a2->replies == 1 && !strcmp(a2->error, ERROR_INTERFACE ".NotAuthorized"), "Acquire while suspending '%s'", a2->error);
	complete(last_op(OP_SUSPEND), 0);
	CHECK(r1->replies == 1 && !r1->error[0], "first Release %d '%s'", r1->replies, r1->error);
	return 0;
}

static int t_u117(void)
{
	/* owner exits while active: suspended, owner gone */
	acquire_pending();
	complete(last_op(OP_RESUME), 0);
	owner_exit(OWNER);
	CHECK(T->owner == NULL, "owner kept");
	CHECK(W.cancels == 0, "a2dp_cancel called %d", W.cancels);
	CHECK(T->state == TRANSPORT_STATE_IDLE, "state %d", T->state);
	return 0;
}

static int t_u118(void)
{
	/* owner exits while Release waits for SUSPEND: a2dp_cancel of the
	 * suspend, as before */
	acquire_pending();
	complete(last_op(OP_RESUME), 0);
	call("Release", OWNER);
	owner_exit(OWNER);
	CHECK(T->owner == NULL, "owner kept");
	CHECK(W.cancels == 1 && W.cancel_ids[0] == last_op(OP_SUSPEND)->id, "cancels %d", W.cancels);
	return 0;
}

static int t_u119(void)
{
	/* stream gone when START completes: Acquire fails */
	struct fake_call *a = acquire_pending();

	W.stream_null = 1;
	complete(last_op(OP_RESUME), 0);
	CHECK(a->replies == 1 && a->error[0], "Acquire %d '%s'", a->replies, a->error);
	CHECK(T->owner == NULL, "owner kept");
	return 0;
}

/* ------------------------------------------------------------------ */
/* Tests: Release during a pending Acquire (the U12 path)              */

static int t_u120(void)
{
	/* no AVDTP ABORT (no a2dp_cancel of the START) */
	acquire_pending();
	call("Release", OWNER);
	CHECK(W.cancels == 0, "a2dp_cancel called %d time(s) (ABORT)", W.cancels);
	return 0;
}

static int t_u121(void)
{
	/* the cancelled Acquire is answered, with an error */
	struct fake_call *a = acquire_pending();

	call("Release", OWNER);
	CHECK(a->replies == 1, "Acquire replies %d", a->replies);
	CHECK(a->error[0], "Acquire answered without error");
	return 0;
}

static int t_u122(void)
{
	/* Release waits for START, then SUSPEND, then answers */
	struct fake_call *r;

	acquire_pending();
	r = call("Release", OWNER);
	CHECK(r->replies == 0, "Release answered before START completed '%s'", r->error);
	CHECK(complete(last_op(OP_RESUME), 0) == 0, "START no longer pending (cancelled)");
	CHECK(r->replies == 0, "Release answered before SUSPEND '%s'", r->error);
	CHECK(active_ops(OP_SUSPEND) == 1, "suspend ops %d", active_ops(OP_SUSPEND));
	complete(last_op(OP_SUSPEND), 0);
	CHECK(r->replies == 1 && !r->error[0], "Release %d '%s'", r->replies, r->error);
	CHECK(T->state == TRANSPORT_STATE_IDLE, "state %d", T->state);
	CHECK(T->owner == NULL, "owner kept");
	CHECK(!W.locked, "sep still locked");
	return 0;
}

static int t_u123(void)
{
	/* after the cancelled Acquire, a new Acquire starts and succeeds */
	struct fake_call *a2;

	acquire_pending();
	call("Release", OWNER);
	complete(last_op(OP_RESUME), 0);
	complete(last_op(OP_SUSPEND), 0);
	a2 = call("Acquire", OWNER);
	CHECK(complete(last_op(OP_RESUME), 0) == 0, "no resume op for the new Acquire (%s)", a2->error);
	CHECK(a2->replies == 1 && !a2->error[0], "new Acquire %d '%s'", a2->replies, a2->error);
	CHECK(W.cancels == 0, "a2dp_cancel called %d", W.cancels);
	return 0;
}

static int t_u124(void)
{
	/* Acquire while the cancelled START is still pending: refused */
	struct fake_call *a2;

	acquire_pending();
	call("Release", OWNER);
	a2 = call("Acquire", OWNER);
	CHECK(a2->replies == 1 && a2->error[0], "Acquire during cancel %d '%s'", a2->replies, a2->error);
	return 0;
}

static int t_u125(void)
{
	/* START fails while Release waits: Release answered (error), owner
	 * gone, lock released, no ABORT */
	struct fake_call *r;

	acquire_pending();
	r = call("Release", OWNER);
	CHECK(complete(last_op(OP_RESUME), -EIO) == 0, "START no longer pending (cancelled)");
	CHECK(r->replies == 1, "Release replies %d", r->replies);
	CHECK(T->owner == NULL, "owner kept");
	CHECK(W.cancels == 0, "a2dp_cancel called %d", W.cancels);
	return 0;
}

static int t_u126(void)
{
	/* START ok but SUSPEND cannot start (stream closed meanwhile):
	 * Release answered with an error, owner gone */
	struct fake_call *r;

	acquire_pending();
	r = call("Release", OWNER);
	W.suspend_fail = 1;
	CHECK(complete(last_op(OP_RESUME), 0) == 0, "START no longer pending (cancelled)");
	CHECK(r->replies == 1, "Release replies %d", r->replies);
	CHECK(T->owner == NULL, "owner kept");
	return 0;
}

static int t_u127(void)
{
	/* owner exits during the pending Acquire (no Release): the START
	 * is cancelled (ABORT), as before */
	acquire_pending();
	owner_exit(OWNER);
	CHECK(T->owner == NULL, "owner kept");
	CHECK(W.cancels == 1, "a2dp_cancel calls %d", W.cancels);
	return 0;
}

static int t_u128(void)
{
	/* owner exits while Release waits for the cancelled START: nothing
	 * left behind; START cancelled */
	acquire_pending();
	call("Release", OWNER);
	owner_exit(OWNER);
	CHECK(T->owner == NULL, "owner kept");
	CHECK(active_ops(OP_RESUME) == 0, "resume op still active");
	return 0;
}

static int t_u129(void)
{
	/* owner exits between START completing and the deferred SUSPEND
	 * (idle callback): no use after free, no SUSPEND for a gone owner */
	acquire_pending();
	call("Release", OWNER);
	/* complete START without running the idle loop */
	{
		struct fake_op *op = last_op(OP_RESUME);

		if (op && op->active) {
			op->active = 0;
			op->cb(FAKE_SESSION, 0, op->user_data);
		}
	}
	owner_exit(OWNER);
	run_idle();
	CHECK(T->owner == NULL, "owner kept");
	CHECK(active_ops(OP_SUSPEND) == 0, "suspend issued for a gone owner");
	return 0;
}

static int t_u130(void)
{
	/* transport destroyed (device gone) during the pending Acquire */
	acquire_pending();
	destroy_transport();
	CHECK(W.cancels >= 1, "START not cancelled (%d)", W.cancels);
	return 0;
}

static int t_u131(void)
{
	/* transport destroyed while Release waits for the cancelled START */
	struct fake_call *r;

	acquire_pending();
	r = call("Release", OWNER);
	destroy_transport();
	CHECK(active_ops(OP_RESUME) == 0, "resume op left active");
	CHECK(r->replies <= 1, "Release replies %d", r->replies);
	return 0;
}

static int t_u132(void)
{
	/* transport destroyed between START completing and the deferred
	 * SUSPEND: no use after free (ASan) */
	acquire_pending();
	call("Release", OWNER);
	{
		struct fake_op *op = last_op(OP_RESUME);

		if (op && op->active) {
			op->active = 0;
			op->cb(FAKE_SESSION, 0, op->user_data);
		}
	}
	destroy_transport();
	run_idle();
	CHECK(active_ops(OP_SUSPEND) == 0, "suspend issued after destroy");
	return 0;
}

static int t_u133(void)
{
	/* two cancel cycles back to back, then a normal one */
	int i;
	struct fake_call *a;

	for (i = 0; i < 2; i++) {
		struct fake_call *r;

		acquire_pending();
		r = call("Release", OWNER);
		complete(last_op(OP_RESUME), 0);
		complete(last_op(OP_SUSPEND), 0);
		CHECK(r->replies == 1 && !r->error[0], "cycle %d Release %d '%s'", i, r->replies, r->error);
	}
	a = acquire_pending();
	complete(last_op(OP_RESUME), 0);
	CHECK(a->replies == 1 && !a->error[0], "final Acquire %d '%s'", a->replies, a->error);
	CHECK(W.cancels == 0, "a2dp_cancel called %d", W.cancels);
	return 0;
}

static int t_u134(void)
{
	/* every call is answered exactly once, and no reply to an unknown
	 * call, across the U12 sequence */
	int i;

	acquire_pending();
	call("Release", OWNER);
	complete(last_op(OP_RESUME), 0);
	complete(last_op(OP_SUSPEND), 0);
	for (i = 0; i < W.n_calls; i++)
		CHECK(W.calls[i].replies == 1, "%s replies %d", W.calls[i].member, W.calls[i].replies);
	CHECK(W.stray_replies == 0, "stray replies %d", W.stray_replies);
	return 0;
}

static int t_u135(void)
{
	/* remote suspends (sink CONNECTED) while Release waits for the
	 * cancelled START: no crash, owner eventually gone */
	acquire_pending();
	call("Release", OWNER);
	sink_state(SINK_STATE_PLAYING, SINK_STATE_CONNECTED);
	complete(last_op(OP_RESUME), 0);
	complete(last_op(OP_SUSPEND), 0);
	CHECK(T->owner == NULL, "owner kept");
	return 0;
}

int main(int argc, char *argv[])
{
	verbose = getenv("CO03_VERBOSE") != NULL;
	if (verbose)
		enable_debug();

	run("U101", "Acquire on idle: START requested, no reply yet", t_u101);
	run("U102", "START completes: Acquire answered with fd, active", t_u102);
	run("U103", "START fails: Acquire error, owner gone, unlocked", t_u103);
	run("U104", "Release while active: SUSPEND, then reply", t_u104);
	run("U105", "SUSPEND fails: Release still succeeds", t_u105);
	run("U106", "two Acquire/Release cycles", t_u106);
	run("U107", "Acquire while acquired (same owner): NotAuthorized", t_u107);
	run("U108", "Acquire while acquired (other client): NotAuthorized", t_u108);
	run("U109", "Release by a non-owner: NotAuthorized", t_u109);
	run("U110", "Release with no owner: NotAuthorized", t_u110);
	run("U111", "a2dp_resume refuses: Acquire NotAuthorized, unlocked", t_u111);
	run("U112", "TryAcquire on idle: NotAvailable", t_u112);
	run("U113", "remote start then TryAcquire", t_u113);
	run("U114", "Release during pending TryAcquire: InProgress", t_u114);
	run("U115", "remote suspend while active: owner removed", t_u115);
	run("U116", "second Release / Acquire while suspending", t_u116);
	run("U117", "owner exits while active", t_u117);
	run("U118", "owner exits while Release waits for SUSPEND", t_u118);
	run("U119", "stream gone when START completes: Acquire fails", t_u119);
	run("U120", "Release during pending Acquire: no ABORT", t_u120);
	run("U121", "Release during pending Acquire: Acquire answered (error)", t_u121);
	run("U122", "Release during pending Acquire: waits START, SUSPEND, reply", t_u122);
	run("U123", "after the cancelled Acquire, a new Acquire works", t_u123);
	run("U124", "Acquire while the cancelled START is pending: refused", t_u124);
	run("U125", "START fails while Release waits", t_u125);
	run("U126", "SUSPEND cannot start after the cancelled START", t_u126);
	run("U127", "owner exits during pending Acquire: START cancelled", t_u127);
	run("U128", "owner exits while Release waits for cancelled START", t_u128);
	run("U129", "owner exits between START done and deferred SUSPEND", t_u129);
	run("U130", "transport destroyed during pending Acquire", t_u130);
	run("U131", "transport destroyed while Release waits", t_u131);
	run("U132", "transport destroyed before the deferred SUSPEND", t_u132);
	run("U133", "two cancel cycles then a normal one", t_u133);
	run("U134", "every call answered exactly once", t_u134);
	run("U135", "remote suspend while Release waits", t_u135);

	printf("SUMMARY pass=%d fail=%d\n", n_pass, n_fail);
	return 0;
}
