// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Reproducer for the MGMT Mesh Send handle leak on hci_cmd_sync_queue()
 * failure (net/bluetooth/mgmt.c: mesh_send()).
 *
 * Runs inside the BlueZ test-runner guest. The controller is BlueZ's
 * emulated controller (hciemu/btdev over /dev/vhci). A glib main loop
 * thread services the emulator while a worker thread drives a raw MGMT
 * control socket synchronously and records:
 *
 *   - MGMT command statuses (Mesh Send, Read Mesh Features)
 *   - Mesh Packet Complete events
 *   - HCI commands seen by the emulated controller that carry a
 *     request's tagged advertising data, and advertising enables
 *   - kprobe hits on mesh_send_sync() / mgmt_mesh_remove() per handle
 *
 * Usage: mesh-leak-check <scenario> <legacy|ext>
 * Build: see build-repro.sh
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/syscall.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <glib.h>

#include "bluetooth/bluetooth.h"
#include "bluetooth/hci.h"
#include "bluetooth/mgmt.h"
#include "monitor/bt.h"
#include "emulator/hciemu.h"
#include "src/shared/util.h"

#define TAG0 'M'
#define TAG1 'T'
#define TAG2 'X'

static GMainLoop *loop;
static struct hciemu *emu;
static enum hciemu_type emu_type;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static unsigned int tag_data[256];	/* tagged adv data writes per tag */
static unsigned int adv_enables;	/* adv enable commands with enable=1 */
static unsigned int adv_disables;
static int result = 0;

#define say(fmt, ...) do { printf(fmt "\n", ##__VA_ARGS__); fflush(stdout); } while (0)
#define fail(fmt, ...) do { say("ERROR: " fmt, ##__VA_ARGS__); result = 2; } while (0)

/* ---- emulator side (main loop thread) ---- */

static void cmd_hook(uint16_t opcode, const void *data, uint8_t len,
							void *user_data)
{
	const uint8_t *p = data;
	int i;

	pthread_mutex_lock(&lock);

	switch (opcode) {
	case BT_HCI_CMD_LE_SET_ADV_DATA:
	case BT_HCI_CMD_LE_SET_EXT_ADV_DATA:
		for (i = 0; i + 3 < len; i++) {
			if (p[i] == TAG0 && p[i + 1] == TAG1 &&
						p[i + 2] == TAG2) {
				tag_data[p[i + 3]]++;
				break;
			}
		}
		break;
	case BT_HCI_CMD_LE_SET_ADV_ENABLE:
	case BT_HCI_CMD_LE_SET_EXT_ADV_ENABLE:
		if (len && p[0])
			adv_enables++;
		else
			adv_disables++;
		break;
	}

	pthread_mutex_unlock(&lock);
}

static gboolean create_emu(gpointer user_data)
{
	emu = hciemu_new(emu_type);
	if (!emu) {
		fail("hciemu_new failed");
		g_main_loop_quit(loop);
		return FALSE;
	}

	hciemu_add_central_post_command_hook(emu, cmd_hook, NULL);
	return FALSE;
}

static gboolean remove_emu(gpointer user_data)
{
	say("emulator: removing controller");
	hciemu_unref(emu);
	emu = NULL;
	say("emulator: controller removed");
	return FALSE;
}

/* ---- MGMT socket helpers (worker thread) ---- */

struct sock_state {
	int fd;
	const char *name;
	uint8_t completes[64];
	int ncompletes;
	int index_removed;
};

static int mgmt_open(struct sock_state *s, const char *name)
{
	struct sockaddr_hci addr;

	memset(s, 0, sizeof(*s));
	s->name = name;
	s->fd = socket(PF_BLUETOOTH, SOCK_RAW | SOCK_CLOEXEC, BTPROTO_HCI);
	if (s->fd < 0)
		return -errno;

	memset(&addr, 0, sizeof(addr));
	addr.hci_family = AF_BLUETOOTH;
	addr.hci_dev = HCI_DEV_NONE;
	addr.hci_channel = HCI_CHANNEL_CONTROL;

	if (bind(s->fd, (struct sockaddr *) &addr, sizeof(addr)) < 0)
		return -errno;

	return 0;
}

static void mgmt_close(struct sock_state *s)
{
	say("%s: close socket", s->name);
	close(s->fd);
	s->fd = -1;
}

static void handle_event(struct sock_state *s, uint16_t ev, uint16_t idx,
					const uint8_t *p, uint16_t len,
					uint16_t *new_index)
{
	switch (ev) {
	case MGMT_EV_MESH_PACKET_CMPLT:
		if (len >= 1 && s->ncompletes < 64) {
			s->completes[s->ncompletes++] = p[0];
			say("%s: event Mesh Packet Complete handle %u",
							s->name, p[0]);
		}
		break;
	case MGMT_EV_INDEX_ADDED:
		if (new_index)
			*new_index = idx;
		break;
	case MGMT_EV_INDEX_REMOVED:
		s->index_removed = 1;
		say("%s: event Index Removed hci%u", s->name, idx);
		break;
	}
}

/* Read one message, wait at most ms. Returns 1 if read, 0 on timeout. */
static int read_msg(struct sock_state *s, int ms, uint16_t *ev, uint16_t *idx,
					uint8_t *buf, uint16_t *len)
{
	struct pollfd pfd = { .fd = s->fd, .events = POLLIN };
	uint8_t raw[1024];
	struct mgmt_hdr *hdr = (void *) raw;
	ssize_t n;

	if (poll(&pfd, 1, ms) <= 0)
		return 0;

	n = read(s->fd, raw, sizeof(raw));
	if (n < (ssize_t) sizeof(*hdr))
		return 0;

	*ev = le16_to_cpu(hdr->opcode);
	*idx = le16_to_cpu(hdr->index);
	*len = n - sizeof(*hdr);
	memcpy(buf, raw + sizeof(*hdr), *len);
	return 1;
}

static void pump(struct sock_state *s, int ms)
{
	uint8_t buf[1024];
	uint16_t ev, idx, len;
	struct timespec t0, t;

	clock_gettime(CLOCK_MONOTONIC, &t0);
	for (;;) {
		long el;

		clock_gettime(CLOCK_MONOTONIC, &t);
		el = (t.tv_sec - t0.tv_sec) * 1000 +
					(t.tv_nsec - t0.tv_nsec) / 1000000;
		if (el >= ms)
			break;
		if (read_msg(s, ms - el, &ev, &idx, buf, &len))
			handle_event(s, ev, idx, buf, len, NULL);
	}
}

/* Returns MGMT status, or -1 on timeout. */
static int mgmt_cmd(struct sock_state *s, uint16_t op, uint16_t index,
			const void *param, uint16_t plen,
			uint8_t *rsp, uint16_t *rlen)
{
	uint8_t raw[1024], buf[1024];
	struct mgmt_hdr *hdr = (void *) raw;
	uint16_t ev, idx, len;
	int tries;

	hdr->opcode = cpu_to_le16(op);
	hdr->index = cpu_to_le16(index);
	hdr->len = cpu_to_le16(plen);
	if (plen)
		memcpy(raw + sizeof(*hdr), param, plen);

	if (write(s->fd, raw, sizeof(*hdr) + plen) < 0) {
		fail("%s: write op 0x%04x: %s", s->name, op, strerror(errno));
		return -1;
	}

	for (tries = 0; tries < 200; tries++) {
		if (!read_msg(s, 30000, &ev, &idx, buf, &len))
			break;

		if ((ev == MGMT_EV_CMD_COMPLETE || ev == MGMT_EV_CMD_STATUS) &&
						len >= 3 && get_le16(buf) == op) {
			if (rsp && rlen) {
				*rlen = len - 3;
				memcpy(rsp, buf + 3, len - 3);
			}
			return buf[2];
		}

		handle_event(s, ev, idx, buf, len, NULL);
	}

	fail("%s: no response to op 0x%04x", s->name, op);
	return -1;
}

static const char *st(int status)
{
	switch (status) {
	case MGMT_STATUS_SUCCESS: return "Success";
	case MGMT_STATUS_BUSY: return "Busy";
	case MGMT_STATUS_FAILED: return "Failed";
	case MGMT_STATUS_REJECTED: return "Rejected";
	case MGMT_STATUS_NOT_SUPPORTED: return "Not Supported";
	case MGMT_STATUS_INVALID_INDEX: return "Invalid Index";
	case -1: return "timeout";
	default: return "other";
	}
}

static uint16_t hci_index;

static int set_mode(struct sock_state *s, uint16_t op, uint8_t val)
{
	return mgmt_cmd(s, op, hci_index, &val, 1, NULL, NULL);
}

static int set_powered(struct sock_state *s, uint8_t val)
{
	int status = set_mode(s, MGMT_OP_SET_POWERED, val);

	say("%s: Set Powered %u -> %s", s->name, val, st(status));
	return status;
}

static const uint8_t mesh_uuid[16] = {
	0x76, 0x6e, 0xf3, 0xe8, 0x24, 0x5f, 0x05, 0xbf,
	0x8d, 0x4d, 0x03, 0x7a, 0xd7, 0x63, 0xe4, 0x2c,
};

static int enable_mesh(struct sock_state *s)
{
	uint8_t p[17];
	int status;

	status = set_mode(s, MGMT_OP_SET_LE, 1);
	say("%s: Set LE 1 -> %s", s->name, st(status));
	if (status)
		return status;

	memcpy(p, mesh_uuid, 16);
	p[16] = 1;
	status = mgmt_cmd(s, MGMT_OP_SET_EXP_FEATURE, hci_index, p, 17,
								NULL, NULL);
	say("%s: Set Exp Feature mesh 1 -> %s", s->name, st(status));
	return status;
}

/* Returns status; *handle receives the handle on success. */
static int mesh_send(struct sock_state *s, uint8_t tag, uint8_t *handle)
{
	uint8_t p[sizeof(struct mgmt_cp_mesh_send) + 24];
	struct mgmt_cp_mesh_send *cp = (void *) p;
	static const uint8_t ad[24] = {
		0x17, 0x2b, TAG0, TAG1, TAG2, 0x00, 0x2d, 0xda,
		0x0c, 0x24, 0x91, 0x53, 0x7a, 0xe2, 0x00, 0x00,
		0x00, 0x00, 0x9d, 0xe2, 0x12, 0x0a, 0x72, 0x50,
	};
	uint8_t rsp[16];
	uint16_t rlen = 0;
	int status;

	memset(p, 0, sizeof(p));
	cp->addr.type = BDADDR_LE_RANDOM;
	cp->cnt = 3;
	cp->adv_data_len = sizeof(ad);
	memcpy(cp->adv_data, ad, sizeof(ad));
	cp->adv_data[5] = tag;

	status = mgmt_cmd(s, MGMT_OP_MESH_SEND, hci_index, p, sizeof(p),
								rsp, &rlen);
	if (!status && rlen >= 1) {
		if (handle)
			*handle = rsp[0];
		say("%s: Mesh Send tag %u -> Success handle %u", s->name, tag,
								rsp[0]);
	} else {
		say("%s: Mesh Send tag %u -> %s (0x%02x)", s->name, tag,
						st(status), status & 0xff);
	}

	return status;
}

/* Prints and returns the number of outstanding handles for this socket. */
static int read_features(struct sock_state *s, const char *label)
{
	uint8_t rsp[64];
	uint16_t rlen = 0;
	int status, used, i;
	char list[64] = "";

	status = mgmt_cmd(s, MGMT_OP_MESH_READ_FEATURES, hci_index, NULL, 0,
								rsp, &rlen);
	if (status || rlen < 4) {
		say("%s: Read Mesh Features -> %s", s->name, st(status));
		return -1;
	}

	used = rsp[3];
	for (i = 0; i < used && 4 + i < rlen; i++)
		snprintf(list + strlen(list), sizeof(list) - strlen(list),
					"%s%u", i ? "," : "", rsp[4 + i]);

	say("%s: Read Mesh Features [%s] max_handles %u used_handles %u "
				"handles [%s]", s->name, label, rsp[2], used,
				list);
	say("RESULT %s outstanding=%d handles=%s", label, used,
						used ? list : "-");
	return used;
}

/* ---- sysfs / debugfs helpers ---- */

static int write_file(const char *path, const char *val)
{
	int fd = open(path, O_WRONLY);
	ssize_t n;

	if (fd < 0) {
		fail("open %s: %s", path, strerror(errno));
		return -1;
	}
	n = write(fd, val, strlen(val));
	if (n < 0)
		fail("write %s <- %s: %s", path, val, strerror(errno));
	close(fd);
	return n < 0 ? -1 : 0;
}

static void dump_file(const char *path, const char *prefix)
{
	FILE *f = fopen(path, "r");
	char line[512];

	if (!f) {
		say("%s(cannot open %s)", prefix, path);
		return;
	}
	while (fgets(line, sizeof(line), f))
		printf("%s%s", prefix, line);
	fflush(stdout);
	fclose(f);
}

static void dmesg_marker(const char *msg)
{
	int fd = open("/dev/kmsg", O_WRONLY);

	if (fd >= 0) {
		dprintf(fd, "mesh-leak-check: %s\n", msg);
		close(fd);
	}
}

/* Find [start, end) of a kernel text symbol from /proc/kallsyms. */
static bool sym_range(const char *name, unsigned long *start,
							unsigned long *end)
{
	FILE *f = fopen("/proc/kallsyms", "r");
	unsigned long addr, s = 0, e = ~0UL;
	char type, sym[256];

	if (!f)
		return false;

	while (fscanf(f, "%lx %c %255s%*[^\n]", &addr, &type, sym) == 3) {
		if (!s && !strcmp(sym, name) && (type == 't' || type == 'T'))
			s = addr;
	}
	if (!s) {
		fclose(f);
		return false;
	}
	rewind(f);
	while (fscanf(f, "%lx %c %255s%*[^\n]", &addr, &type, sym) == 3) {
		if (addr > s && addr < e)
			e = addr;
	}
	fclose(f);
	*start = s;
	*end = e;
	return true;
}

#define FS "/sys/kernel/debug/failslab/"

static void failslab_setup(void)
{
	unsigned long ms, me, as, ae;
	char buf[64];

	if (!sym_range("mesh_send", &ms, &me) ||
				!sym_range("mgmt_mesh_add", &as, &ae)) {
		fail("kallsyms lookup failed");
		return;
	}
	say("failslab: require mesh_send [%lx,%lx) reject mgmt_mesh_add "
						"[%lx,%lx)", ms, me, as, ae);

	write_file(FS "probability", "100");
	write_file(FS "interval", "1");
	write_file(FS "space", "0");
	write_file(FS "verbose", "2");
	write_file(FS "task-filter", "Y");
	write_file(FS "ignore-gfp-wait", "N");
	write_file(FS "cache-filter", "N");
	write_file(FS "stacktrace-depth", "32");
	snprintf(buf, sizeof(buf), "%lu", ms);
	write_file(FS "require-start", buf);
	snprintf(buf, sizeof(buf), "%lu", me);
	write_file(FS "require-end", buf);
	snprintf(buf, sizeof(buf), "%lu", as);
	write_file(FS "reject-start", buf);
	snprintf(buf, sizeof(buf), "%lu", ae);
	write_file(FS "reject-end", buf);
	write_file(FS "times", "0");
}

/* Arm exactly one injected kmalloc failure for the calling thread. */
static void failslab_arm(bool on)
{
	char path[64];

	snprintf(path, sizeof(path), "/proc/self/task/%ld/make-it-fail",
						(long) syscall(SYS_gettid));
	write_file(FS "times", on ? "1" : "0");
	write_file(path, on ? "1" : "0");
}

#define TR "/sys/kernel/tracing/"

static void kprobes_setup(void)
{
	struct stat sb;
	int fd;

	if (stat(TR "kprobe_events", &sb) < 0)
		mount("nodev", "/sys/kernel/tracing", "tracefs", 0, NULL);

	/* mgmt_mesh_tx.handle is at offset 40 on x86_64 */
	fd = open(TR "kprobe_events", O_WRONLY | O_TRUNC);
	if (fd < 0) {
		fail("kprobe_events: %s", strerror(errno));
		return;
	}
	dprintf(fd, "p:meshleak/mesh_send_sync mesh_send_sync "
						"handle=+40(%%si):u8\n");
	dprintf(fd, "p:meshleak/mgmt_mesh_remove mgmt_mesh_remove "
						"handle=+40(%%di):u8\n");
	dprintf(fd, "r:meshleak/mgmt_mesh_add mgmt_mesh_add "
						"handle=+40($retval):u8\n");
	/* Teardown: controller memory released, MGMT socket destroyed */
	dprintf(fd, "p:meshleak/hci_release_dev hci_release_dev\n");
	dprintf(fd, "p:meshleak/hci_sock_destruct hci_sock_destruct\n");
	close(fd);

	write_file(TR "trace", "");
	write_file(TR "events/meshleak/enable", "1");
	write_file(TR "tracing_on", "1");
}

/* Count kprobe hits for a given handle from the trace buffer. */
static void kprobe_report(const char *label)
{
	FILE *f = fopen(TR "trace", "r");
	char line[512];
	unsigned int sync[256] = { 0 }, rem[256] = { 0 }, add[256] = { 0 };
	unsigned int release_dev = 0, sock_destruct = 0;
	int i;

	if (!f) {
		say("kprobe trace unavailable");
		return;
	}
	while (fgets(line, sizeof(line), f)) {
		char *h = strstr(line, "handle=");
		unsigned int v;

		if (line[0] == '#')
			continue;
		if (strstr(line, "hci_release_dev:"))
			release_dev++;
		if (strstr(line, "hci_sock_destruct:"))
			sock_destruct++;
		if (!h || sscanf(h, "handle=%u", &v) != 1)
			continue;
		v &= 0xff;
		if (strstr(line, "mesh_send_sync:"))
			sync[v]++;
		else if (strstr(line, "mgmt_mesh_remove:"))
			rem[v]++;
		else if (strstr(line, "mgmt_mesh_add:"))
			add[v]++;
	}
	fclose(f);

	for (i = 1; i < 256; i++) {
		if (!sync[i] && !rem[i] && !add[i])
			continue;
		say("RESULT %s kprobe handle=%d added=%u mesh_send_sync=%u "
				"removed=%u", label, i, add[i], sync[i], rem[i]);
	}
	say("RESULT %s kprobe hci_release_dev=%u hci_sock_destruct=%u", label,
						release_dev, sock_destruct);
}

static void hci_report(const char *label, int ntags)
{
	int t;

	pthread_mutex_lock(&lock);
	for (t = 1; t <= ntags; t++)
		say("RESULT %s hci tag=%d adv_data_writes=%u", label, t,
								tag_data[t]);
	say("RESULT %s hci adv_enable=%u adv_disable=%u", label, adv_enables,
								adv_disables);
	pthread_mutex_unlock(&lock);
}

static void completes_report(struct sock_state *s, const char *label)
{
	char list[256] = "";
	int i;

	for (i = 0; i < s->ncompletes; i++)
		snprintf(list + strlen(list), sizeof(list) - strlen(list),
				"%s%u", i ? "," : "", s->completes[i]);
	say("RESULT %s %s packet_complete_handles=%s", label, s->name,
					s->ncompletes ? list : "-");
}

/* ---- scenario plumbing ---- */

static int wait_index(struct sock_state *s)
{
	uint8_t buf[1024];
	uint16_t ev, idx, len, newidx = MGMT_INDEX_NONE;
	int i;

	for (i = 0; i < 100 && newidx == MGMT_INDEX_NONE; i++) {
		if (read_msg(s, 30000, &ev, &idx, buf, &len))
			handle_event(s, ev, idx, buf, len, &newidx);
		else
			break;
	}
	if (newidx == MGMT_INDEX_NONE) {
		fail("controller did not appear");
		return -1;
	}
	hci_index = newidx;
	say("controller hci%u added (%s)", hci_index,
		emu_type == HCIEMU_TYPE_BREDRLE50 ? "extended advertising" :
						"legacy advertising");
	return 0;
}

/* Whether the controller is actually up (HCI_UP), as opposed to MGMT's view. */
static bool hci_up(void)
{
	struct hci_dev_info di;
	int sk = socket(AF_BLUETOOTH, SOCK_RAW | SOCK_CLOEXEC, BTPROTO_HCI);
	bool up;

	if (sk < 0)
		return false;
	memset(&di, 0, sizeof(di));
	di.dev_id = hci_index;
	up = !ioctl(sk, HCIGETDEVINFO, &di) && (di.flags & (1 << HCI_UP));
	close(sk);
	say("controller hci%u HCI_UP=%d", hci_index, up);
	return up;
}

static int bring_up(struct sock_state *s)
{
	if (mgmt_open(s, "sockA") < 0) {
		fail("mgmt socket");
		return -1;
	}
	g_idle_add(create_emu, NULL);
	if (wait_index(s) < 0)
		return -1;
	/*
	 * A newly registered controller stays up (HCI_RUNNING) during the
	 * auto power-off window even though MGMT reports it powered off, so
	 * Set Powered 0 alone does not bring it down. Power it on and off.
	 */
	set_powered(s, 1);
	set_powered(s, 0);
	if (hci_up())
		fail("controller still up after Set Powered 0");
	if (enable_mesh(s))
		return -1;
	return 0;
}

static void remove_controller(void)
{
	g_idle_add(remove_emu, NULL);
	/* Wait for the main loop to finish the removal. */
	while (1) {
		bool gone;

		usleep(100000);
		gone = !__atomic_load_n(&emu, __ATOMIC_SEQ_CST);
		if (gone)
			break;
	}
}

/* Set from the optional third argument (comma list: stackoff,shrink). */
static bool kmemleak_stack_off;
static bool kmemleak_shrink;
static bool kmemleak_noscan;	/* leave scanning to a later process */

/*
 * Shrink every slab cache. This flushes the per-CPU sheaves and frees
 * cached empty sheaves, whose object arrays can still hold stale pointers
 * to objects that have since been allocated; kmemleak scans those arrays
 * and would count such a stale pointer as a reference.
 */
static void shrink_slabs(void)
{
	GDir *d = g_dir_open("/sys/kernel/slab", 0, NULL);
	const char *name;
	int n = 0;

	if (!d) {
		fail("cannot open /sys/kernel/slab");
		return;
	}
	while ((name = g_dir_read_name(d))) {
		char path[256];
		int fd;

		snprintf(path, sizeof(path), "/sys/kernel/slab/%s/shrink", name);
		fd = open(path, O_WRONLY);
		if (fd < 0)
			continue;
		if (write(fd, "1", 1) == 1)
			n++;
		close(fd);
	}
	g_dir_close(d);
	say("kmemleak: shrank %d slab caches", n);
}

static void kmemleak_read(const char *label, int round, bool print)
{
	FILE *f;
	char line[512];
	int objs = 0, mesh = 0, sk = 0;
	bool in_obj = false, obj_mesh = false, obj_sk = false;

	f = fopen("/sys/kernel/debug/kmemleak", "r");
	if (!f) {
		fail("kmemleak not available");
		return;
	}
	while (fgets(line, sizeof(line), f)) {
		if (print)
			printf("KMEMLEAK %s", line);
		if (!strncmp(line, "unreferenced object", 19)) {
			if (in_obj) {
				mesh += obj_mesh;
				sk += obj_sk;
			}
			objs++;
			in_obj = true;
			obj_mesh = obj_sk = false;
		}
		if (strstr(line, "mgmt_mesh_add"))
			obj_mesh = true;
		if (strstr(line, "sk_prot_alloc") ||
					strstr(line, "hci_sock_create"))
			obj_sk = true;
	}
	if (in_obj) {
		mesh += obj_mesh;
		sk += obj_sk;
	}
	fclose(f);
	fflush(stdout);
	say("RESULT %s kmemleak round=%d stack_scan=%s slab_shrink=%s "
		"unreferenced=%d from_mgmt_mesh_add=%d from_hci_sock_create=%d",
		label, round, kmemleak_stack_off ? "off" : "on",
		kmemleak_shrink ? "yes" : "no", objs, mesh, sk);
}

/*
 * Objects younger than 5 s are never reported, and a stale copy of a
 * pointer (for example in a task stack) hides an object from a scan, so
 * scan several times and report after each round.
 */
static void kmemleak_report(const char *label)
{
	int round;

	if (kmemleak_stack_off)
		write_file("/sys/kernel/debug/kmemleak", "stack=off");

	for (round = 1; round <= 5; round++) {
		say("kmemleak: round %d: waiting for object aging, scanning",
									round);
		sleep(6);
		if (kmemleak_shrink)
			shrink_slabs();
		write_file("/sys/kernel/debug/kmemleak", "scan");
		kmemleak_read(label, round, round == 5);
	}
}

/* ---- scenarios ---- */

/* Normal operation: two accepted sends, nothing injected. */
static void sc_baseline(void)
{
	struct sock_state a;
	uint8_t h;

	if (bring_up(&a) < 0)
		return;
	set_powered(&a, 1);
	mesh_send(&a, 1, &h);
	pump(&a, 3000);
	mesh_send(&a, 2, &h);
	pump(&a, 3000);
	read_features(&a, "after");
	completes_report(&a, "after");
	hci_report("after", 2);
	kprobe_report("after");
}

/* Mesh Send while powered off (-ENETDOWN), then power on and send. */
static void sc_offline(void)
{
	struct sock_state a;
	uint8_t h;

	if (bring_up(&a) < 0)
		return;
	dmesg_marker("offline: Mesh Send while powered off");
	mesh_send(&a, 1, NULL);
	read_features(&a, "after_failure");
	set_powered(&a, 1);
	mesh_send(&a, 2, &h);
	pump(&a, 4000);
	read_features(&a, "after_next");
	completes_report(&a, "after_next");
	hci_report("after_next", 2);
	kprobe_report("after_next");
}

/* Three consecutive powered-off failures, then a fourth send. */
static void sc_offline_busy(void)
{
	struct sock_state a;
	int i;

	if (bring_up(&a) < 0)
		return;
	for (i = 1; i <= 3; i++)
		mesh_send(&a, i, NULL);
	read_features(&a, "after_3_failures");
	say("RESULT fourth_send_offline status=%s", st(mesh_send(&a, 4, NULL)));
	set_powered(&a, 1);
	say("RESULT fifth_send_powered status=%s", st(mesh_send(&a, 5, NULL)));
	pump(&a, 3000);
	read_features(&a, "end");
	completes_report(&a, "end");
	kprobe_report("end");
}

/* Injected kmalloc failure in hci_cmd_sync_queue(), then send again. */
static void sc_enomem(void)
{
	struct sock_state a;
	uint8_t h;

	if (bring_up(&a) < 0)
		return;
	failslab_setup();
	set_powered(&a, 1);
	dmesg_marker("enomem: Mesh Send with injected kmalloc failure");
	failslab_arm(true);
	mesh_send(&a, 1, NULL);
	failslab_arm(false);
	read_features(&a, "after_failure");
	mesh_send(&a, 2, &h);
	pump(&a, 4000);
	read_features(&a, "after_next");
	completes_report(&a, "after_next");
	hci_report("after_next", 2);
	kprobe_report("after_next");
}

/* Three consecutive injected failures, then a fourth send. */
static void sc_enomem_busy(void)
{
	struct sock_state a;
	int i;

	if (bring_up(&a) < 0)
		return;
	failslab_setup();
	set_powered(&a, 1);
	for (i = 1; i <= 3; i++) {
		failslab_arm(true);
		mesh_send(&a, i, NULL);
		failslab_arm(false);
	}
	read_features(&a, "after_3_failures");
	say("RESULT fourth_send status=%s", st(mesh_send(&a, 4, NULL)));
	pump(&a, 3000);
	read_features(&a, "end");
	completes_report(&a, "end");
	kprobe_report("end");
}

/*
 * Does closing the socket release a failed entry? Socket A fails a send
 * while powered off and is closed; socket B then sends after power on.
 */
static void sc_close_reuse(void)
{
	struct sock_state a, b;
	uint8_t h;

	if (bring_up(&a) < 0)
		return;
	mesh_send(&a, 1, NULL);
	read_features(&a, "sockA_after_failure");
	mgmt_close(&a);
	sleep(1);
	mgmt_open(&b, "sockB");
	set_powered(&b, 1);
	mesh_send(&b, 2, &h);
	pump(&b, 4000);
	read_features(&b, "sockB_after_send");
	completes_report(&b, "sockB");
	hci_report("sockB", 2);
	kprobe_report("sockB");
}

/*
 * Can another socket's traffic clear a Busy socket? Socket A collects
 * three failed sends while powered off; after power on, socket B sends
 * repeatedly. Completion picks the first pending entry on the controller
 * regardless of socket, so B's transmissions may complete A's entries.
 */
static void sc_busy_drain(void)
{
	struct sock_state a, b;
	char label[32];
	uint8_t h;
	int i;

	if (bring_up(&a) < 0)
		return;
	for (i = 1; i <= 3; i++)
		mesh_send(&a, i, NULL);
	read_features(&a, "sockA_after_3_failures");
	set_powered(&a, 1);
	say("RESULT sockA_send_after_power_on status=%s",
						st(mesh_send(&a, 4, NULL)));
	mgmt_open(&b, "sockB");
	for (i = 1; i <= 4; i++) {
		mesh_send(&b, 10 + i, &h);
		pump(&b, 3000);
		snprintf(label, sizeof(label), "sockA_after_sockB_send_%d", i);
		read_features(&a, label);
	}
	say("RESULT sockA_send_after_drain status=%s",
						st(mesh_send(&a, 20, NULL)));
	pump(&a, 3000);
	read_features(&a, "sockA_end");
	completes_report(&b, "end");
	/* Which requests' advertising data reached the controller */
	pthread_mutex_lock(&lock);
	for (i = 1; i <= 20; i++)
		if (i <= 4 || (i >= 11 && i <= 14) || i == 20)
			say("RESULT end hci tag=%d adv_data_writes=%u", i,
								tag_data[i]);
	say("RESULT end hci adv_enable=%u adv_disable=%u", adv_enables,
								adv_disables);
	pthread_mutex_unlock(&lock);
	kprobe_report("end");
}

/* kmemleak: fail one send, close socket, remove controller, scan. */
static void sc_kmemleak(const char *how)
{
	struct sock_state a;

	if (bring_up(&a) < 0)
		return;

	if (!strcmp(how, "enetdown")) {
		mesh_send(&a, 1, NULL);
	} else if (!strcmp(how, "enomem")) {
		failslab_setup();
		set_powered(&a, 1);
		failslab_arm(true);
		mesh_send(&a, 1, NULL);
		failslab_arm(false);
	} else if (!strcmp(how, "enodev")) {
		set_powered(&a, 1);
		write_file("/sys/module/bluetooth/parameters/"
					"mesh_send_test_delay_ms", "1500");
		/* Remove the controller while mesh_send() is sleeping. */
		g_timeout_add(300, remove_emu, NULL);
		dmesg_marker("enodev: Mesh Send while controller is removed");
		mesh_send(&a, 1, NULL);
		write_file("/sys/module/bluetooth/parameters/"
					"mesh_send_test_delay_ms", "0");
		while (__atomic_load_n(&emu, __ATOMIC_SEQ_CST))
			usleep(100000);
	}

	if (strcmp(how, "enodev"))
		read_features(&a, "after_failure");

	kprobe_report("before_teardown");
	mgmt_close(&a);
	if (emu)
		remove_controller();
	sleep(1);
	kprobe_report("after_teardown");
	if (kmemleak_noscan)
		say("kmemleak: not scanning (noscan), exiting");
	else
		kmemleak_report(how);
}

static const char *scenario;

static void *worker(void *arg)
{
	if (!strcmp(scenario, "baseline"))
		sc_baseline();
	else if (!strcmp(scenario, "offline"))
		sc_offline();
	else if (!strcmp(scenario, "offline-busy"))
		sc_offline_busy();
	else if (!strcmp(scenario, "enomem"))
		sc_enomem();
	else if (!strcmp(scenario, "enomem-busy"))
		sc_enomem_busy();
	else if (!strcmp(scenario, "close-reuse"))
		sc_close_reuse();
	else if (!strcmp(scenario, "busy-drain"))
		sc_busy_drain();
	else if (!strncmp(scenario, "kmemleak-", 9))
		sc_kmemleak(scenario + 9);
	else
		fail("unknown scenario %s", scenario);

	g_main_loop_quit(loop);
	return NULL;
}

int main(int argc, char *argv[])
{
	pthread_t th;

	if (argc < 3) {
		fprintf(stderr, "usage: %s <baseline|offline|offline-busy|"
			"enomem|enomem-busy|close-reuse|busy-drain|kmemleak-enetdown|"
			"kmemleak-enomem|kmemleak-enodev> <legacy|ext>\n",
			argv[0]);
		return 1;
	}
	scenario = argv[1];
	kmemleak_stack_off = argc > 3 && strstr(argv[3], "stackoff");
	kmemleak_shrink = argc > 3 && strstr(argv[3], "shrink");
	kmemleak_noscan = argc > 3 && strstr(argv[3], "noscan");
	emu_type = !strcmp(argv[2], "ext") ? HCIEMU_TYPE_BREDRLE50 :
							HCIEMU_TYPE_BREDRLE;

	say("=== scenario %s, %s advertising ===", scenario, argv[2]);
	dump_file("/proc/version", "KERNEL ");
	kprobes_setup();
	if (!access("/sys/kernel/debug/kmemleak", F_OK))
		write_file("/sys/kernel/debug/kmemleak", "clear");

	loop = g_main_loop_new(NULL, FALSE);
	pthread_create(&th, NULL, worker, NULL);
	g_main_loop_run(loop);
	pthread_join(th, NULL);
	if (emu)
		hciemu_unref(emu);

	say("=== end scenario %s (%s) ===", scenario, result ? "ERROR" : "ok");
	return result;
}
