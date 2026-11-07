/* CO-36 L1 harness: fake loop, loop utils, system and log, in virtual time */
/* SPDX-License-Identifier: MIT */

#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/syscall.h>

#include <libusb.h>

#include "harness.h"

uint64_t fake_now;

/* log: stderr, level set by -v */

static enum spa_log_level log_level = SPA_LOG_LEVEL_WARN;

SPA_PRINTF_FUNC(7, 0)
static void flog_logtv(void *object, enum spa_log_level level, const struct spa_log_topic *topic,
		const char *file, int line, const char *func, const char *fmt, va_list args)
{
	static const char lv[] = "-EWIDT";

	fprintf(stderr, "  [%c %8.3f] %s:%d %s: ", lv[SPA_CLAMP((int)level, 0, 5)],
			(double)fake_now / SPA_NSEC_PER_MSEC, file, line, func);
	vfprintf(stderr, fmt, args);
	fputc('\n', stderr);
}

SPA_PRINTF_FUNC(7, 8)
static void flog_logt(void *object, enum spa_log_level level, const struct spa_log_topic *topic,
		const char *file, int line, const char *func, const char *fmt, ...)
{
	va_list args;

	va_start(args, fmt);
	flog_logtv(object, level, topic, file, line, func, fmt, args);
	va_end(args);
}

static void flog_topic_init(void *object, struct spa_log_topic *topic)
{
}

static const struct spa_log_methods flog_methods = {
	.version = SPA_VERSION_LOG_METHODS,
	.logt = flog_logt,
	.logtv = flog_logtv,
	.topic_init = flog_topic_init,
};

struct spa_log fake_log;

void fake_log_set_level(enum spa_log_level level)
{
	log_level = level;
	fake_log.level = level;
}

/* loop: a list of sources; the test dispatches them by hand */

#define MAX_SOURCES	64

static struct spa_source *sources[MAX_SOURCES];
static int n_sources;

static int floop_add(void *object, struct spa_source *s)
{
	if (n_sources == MAX_SOURCES)
		return -ENOSPC;
	sources[n_sources++] = s;
	s->loop = &fake_loop;
	s->priv = NULL;
	s->rmask = 0;
	return 0;
}

static int floop_update(void *object, struct spa_source *s)
{
	spa_assert(s->loop == &fake_loop);
	return 0;
}

static int floop_remove(void *object, struct spa_source *s)
{
	spa_assert(s->loop == &fake_loop);
	for (int i = 0; i < n_sources; i++) {
		if (sources[i] == s) {
			sources[i] = sources[--n_sources];
			break;
		}
	}
	s->loop = NULL;
	s->rmask = 0;
	return 0;
}

static const struct spa_loop_methods floop_methods = {
	.version = SPA_VERSION_LOOP_METHODS,
	.add_source = floop_add,
	.update_source = floop_update,
	.remove_source = floop_remove,
};

struct spa_loop fake_loop;

int fake_loop_n_sources(void)
{
	return n_sources;
}

bool fake_loop_has_data(const void *data)
{
	for (int i = 0; i < n_sources; i++)
		if (sources[i]->data == data)
			return true;
	return false;
}

/* loop utils timers: one-shot, relative or absolute, virtual deadline */

struct vtimer {
	struct spa_source source;
	spa_source_timer_func_t func;
	void *data;
	bool armed;
	uint64_t deadline;
	uint64_t seq;
	struct vtimer *next;
};

static struct vtimer *vtimers;
static uint64_t arm_seq;

static struct spa_source *futils_add_timer(void *object, spa_source_timer_func_t func, void *data)
{
	struct vtimer *vt = calloc(1, sizeof(*vt));

	if (vt == NULL)
		return NULL;
	vt->source.fd = -1;
	vt->source.data = data;
	vt->func = func;
	vt->data = data;
	vt->next = vtimers;
	vtimers = vt;
	return &vt->source;
}

static uint64_t ts_to_deadline(const struct timespec *value, bool absolute)
{
	uint64_t v = SPA_TIMESPEC_TO_NSEC(value);
	return absolute ? v : fake_now + v;
}

static int futils_update_timer(void *object, struct spa_source *source,
		struct timespec *value, struct timespec *interval, bool absolute)
{
	struct vtimer *vt = SPA_CONTAINER_OF(source, struct vtimer, source);

	spa_assert(interval == NULL);	/* not used by backend-native.c */

	if (value == NULL || (value->tv_sec == 0 && value->tv_nsec == 0)) {
		vt->armed = false;
		return 0;
	}
	vt->armed = true;
	vt->deadline = ts_to_deadline(value, absolute);
	vt->seq = ++arm_seq;
	return 0;
}

static void futils_destroy_source(void *object, struct spa_source *source)
{
	struct vtimer **p;

	for (p = &vtimers; *p; p = &(*p)->next) {
		if (&(*p)->source == source) {
			struct vtimer *vt = *p;
			*p = vt->next;
			free(vt);
			return;
		}
	}
	spa_assert_not_reached();
}

static const struct spa_loop_utils_methods futils_methods = {
	.version = SPA_VERSION_LOOP_UTILS_METHODS,
	.add_timer = futils_add_timer,
	.update_timer = futils_update_timer,
	.destroy_source = futils_destroy_source,
};

struct spa_loop_utils fake_loop_utils;

bool fake_timer_armed(struct spa_source *timer, uint64_t *deadline)
{
	struct vtimer *vt;

	if (timer == NULL)
		return false;
	vt = SPA_CONTAINER_OF(timer, struct vtimer, source);
	if (vt->armed && deadline)
		*deadline = vt->deadline;
	return vt->armed;
}

int fake_timers_live(void)
{
	int n = 0;
	for (struct vtimer *vt = vtimers; vt; vt = vt->next)
		n++;
	return n;
}

/* system: timerfds only (codec switch timer); fd numbers never reach the kernel */

#define TFD_BASE	10000
#define MAX_TFDS	16

static struct vtfd {
	bool open, armed, expired;
	uint64_t deadline, seq;
} tfds[MAX_TFDS];

static struct vtfd *tfd_get(int fd)
{
	if (fd < TFD_BASE || fd >= TFD_BASE + MAX_TFDS || !tfds[fd - TFD_BASE].open)
		return NULL;
	return &tfds[fd - TFD_BASE];
}

static int fsys_timerfd_create(void *object, int clockid, int flags)
{
	for (int i = 0; i < MAX_TFDS; i++) {
		if (!tfds[i].open) {
			spa_zero(tfds[i]);
			tfds[i].open = true;
			return TFD_BASE + i;
		}
	}
	return -EMFILE;
}

static int fsys_timerfd_settime(void *object, int fd, int flags,
		const struct itimerspec *new_value, struct itimerspec *old_value)
{
	struct vtfd *t = tfd_get(fd);

	if (t == NULL)
		return -EBADF;
	spa_assert(new_value->it_interval.tv_sec == 0 && new_value->it_interval.tv_nsec == 0);
	t->expired = false;
	if (new_value->it_value.tv_sec == 0 && new_value->it_value.tv_nsec == 0) {
		t->armed = false;
		return 0;
	}
	t->armed = true;
	t->deadline = ts_to_deadline(&new_value->it_value, flags & SPA_FD_TIMER_ABSTIME);
	t->seq = ++arm_seq;
	return 0;
}

static int fsys_timerfd_read(void *object, int fd, uint64_t *expirations)
{
	struct vtfd *t = tfd_get(fd);

	if (t == NULL)
		return -EBADF;
	if (!t->expired)
		return -EAGAIN;
	t->expired = false;
	*expirations = 1;
	return 0;
}

static int fsys_close(void *object, int fd)
{
	struct vtfd *t = tfd_get(fd);

	if (t == NULL)
		return -EBADF;
	t->open = false;
	return 0;
}

static const struct spa_system_methods fsys_methods = {
	.version = SPA_VERSION_SYSTEM_METHODS,
	.close = fsys_close,
	.timerfd_create = fsys_timerfd_create,
	.timerfd_settime = fsys_timerfd_settime,
	.timerfd_read = fsys_timerfd_read,
};

struct spa_system fake_system;

int fake_timerfds_open(void)
{
	int n = 0;
	for (int i = 0; i < MAX_TFDS; i++)
		n += tfds[i].open;
	return n;
}

/* dispatch */

void fake_run_until(uint64_t until, void (*after)(void))
{
	for (;;) {
		struct vtimer *vt, *best_vt = NULL;
		struct vtfd *best_tfd = NULL;
		uint64_t best = UINT64_MAX, best_seq = UINT64_MAX;

		for (vt = vtimers; vt; vt = vt->next) {
			if (vt->armed && vt->deadline <= until &&
			    (vt->deadline < best || (vt->deadline == best && vt->seq < best_seq))) {
				best = vt->deadline;
				best_seq = vt->seq;
				best_vt = vt;
			}
		}
		for (int i = 0; i < MAX_TFDS; i++) {
			struct vtfd *t = &tfds[i];
			if (t->open && t->armed && t->deadline <= until &&
			    (t->deadline < best || (t->deadline == best && t->seq < best_seq))) {
				best = t->deadline;
				best_seq = t->seq;
				best_vt = NULL;
				best_tfd = t;
			}
		}
		if (best == UINT64_MAX)
			break;

		if (best > fake_now)
			fake_now = best;

		if (best_tfd) {
			int fd = TFD_BASE + (int)(best_tfd - tfds);
			best_tfd->armed = false;
			best_tfd->expired = true;
			for (int i = 0; i < n_sources; i++) {
				struct spa_source *s = sources[i];
				if (s->fd == fd) {
					s->rmask = SPA_IO_IN;
					s->func(s);
					break;
				}
			}
		} else {
			best_vt->armed = false;
			best_vt->func(best_vt->data, 1);
		}
		if (after)
			after();
	}
	if (until > fake_now)
		fake_now = until;
}

void fakes_reset(void)
{
	fake_now = 0;
	arm_seq = 0;
	n_sources = 0;
	vtimers = NULL;
	memset(tfds, 0, sizeof(tfds));

	fake_log.iface = SPA_INTERFACE_INIT(SPA_TYPE_INTERFACE_Log, SPA_VERSION_LOG,
			&flog_methods, NULL);
	fake_log.level = log_level;
	fake_loop.iface = SPA_INTERFACE_INIT(SPA_TYPE_INTERFACE_Loop, SPA_VERSION_LOOP,
			&floop_methods, NULL);
	fake_loop_utils.iface = SPA_INTERFACE_INIT(SPA_TYPE_INTERFACE_LoopUtils, SPA_VERSION_LOOP_UTILS,
			&futils_methods, NULL);
	fake_system.iface = SPA_INTERFACE_INIT(SPA_TYPE_INTERFACE_System, SPA_VERSION_SYSTEM,
			&fsys_methods, NULL);
}

/* Guards: the harness never opens a Bluetooth socket or a USB device.
 * The real backend reaches these only through sco_do_connect(),
 * sco_listen() and the USB ALT6 probe, which no test calls. */

int socket(int domain, int type, int protocol)
{
	if (domain == AF_BLUETOOTH) {
		fprintf(stderr, "co36 harness: Bluetooth socket requested, aborting\n");
		abort();
	}
	return (int)syscall(SYS_socket, domain, type, protocol);
}

#define USB_TRAP()	do { fprintf(stderr, "co36 harness: libusb %s called, aborting\n", __func__); abort(); } while (0)

int libusb_init(libusb_context **ctx) { USB_TRAP(); }
void libusb_exit(libusb_context *ctx) { USB_TRAP(); }
ssize_t libusb_get_device_list(libusb_context *ctx, libusb_device ***list) { USB_TRAP(); }
void libusb_free_device_list(libusb_device **list, int unref_devices) { USB_TRAP(); }
int libusb_get_device_descriptor(libusb_device *dev, struct libusb_device_descriptor *desc) { USB_TRAP(); }
int libusb_get_config_descriptor(libusb_device *dev, uint8_t config_index,
		struct libusb_config_descriptor **config) { USB_TRAP(); }
void libusb_free_config_descriptor(struct libusb_config_descriptor *config) { USB_TRAP(); }
const char *libusb_strerror(int errcode) { USB_TRAP(); }
