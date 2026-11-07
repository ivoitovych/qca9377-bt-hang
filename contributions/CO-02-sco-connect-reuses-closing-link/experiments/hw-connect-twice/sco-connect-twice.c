// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * sco-connect-twice - CO-02 patch 1 on real hardware: while a call holds a SCO/eSCO link to a
 * headset, connect() a second SCO socket to the same headset. With patch 1 the connect fails
 * with EBUSY and the call's link stays up; without it, the failed connect drops the call's hold
 * and the link is disconnected about 10 ms later (the emulator's "Connect Twice" case).
 *
 *   sco-connect-twice <hci index> <headset address>
 *
 * Refuses to run unless the kernel lists a connected link to that address of the type
 * sco_connect() will look up: eSCO if the adapter is eSCO-capable and bluetooth.disable_esco is
 * off, else SCO (HCIGETCONNLIST and HCIGETDEVINFO: queries of the kernel's tables, no command
 * to the controller). A call link the controller downgraded to plain SCO would not be found by
 * that lookup, and the connect would set up a new link; this refuses that case. The socket is
 * bound to the inspected adapter. Then: one connect(), the socket closed at once, and the link
 * table read every second for 10 s. Prints handles and times, never the address.
 *
 * Limits, which the HCI capture of the window settles: the call's link can still end between the
 * check and the connect() (the connect would then set up a link of its own), and reading the
 * table once a second cannot see a short drop that comes back with the same handle.
 * Exit 0 PASS (EBUSY, link kept), 1 FAIL, 2 usage, 3 no suitable call link.
 *
 * Build: cc -O2 -Wall -I<bluez tree>/lib -o sco-connect-twice sco-connect-twice.c
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
#include <bluetooth/sco.h>

static void stamp(const char *what)
{
	struct timespec ts;
	struct tm tm;
	char buf[32];

	clock_gettime(CLOCK_REALTIME, &ts);
	localtime_r(&ts.tv_sec, &tm);
	strftime(buf, sizeof(buf), "%F %T", &tm);
	printf("%s.%06ld  %s\n", buf, ts.tv_nsec / 1000, what);
	fflush(stdout);
}

static int parse_addr(const char *s, bdaddr_t *ba)
{
	unsigned int b[6];

	if (sscanf(s, "%2x:%2x:%2x:%2x:%2x:%2x", &b[5], &b[4], &b[3], &b[2],
					&b[1], &b[0]) != 6)
		return -1;
	for (int i = 0; i < 6; i++)
		ba->b[i] = b[i];
	return 0;
}

/* The link type sco_connect() looks up on this adapter (sco.c: eSCO if capable and not disabled) */
static int wanted_type(const struct hci_dev_info *di)
{
	char c = 'N';
	FILE *f = fopen("/sys/module/bluetooth/parameters/disable_esco", "r");

	if (f) {
		if (fscanf(f, " %c", &c) != 1)
			c = 'N';
		fclose(f);
	}
	if ((di->features[3] & LMP_ESCO) && c != 'Y')
		return ESCO_LINK;
	return SCO_LINK;
}

/* The handle of a connected link of the given type to dst, or -1 */
static int sco_handle(int hci, int dev, const bdaddr_t *dst, int want, int *type)
{
	struct hci_conn_list_req *cl;
	int n = 20, h = -1;

	cl = calloc(1, sizeof(*cl) + n * sizeof(struct hci_conn_info));
	if (!cl)
		return -1;
	cl->dev_id = dev;
	cl->conn_num = n;
	if (ioctl(hci, HCIGETCONNLIST, cl) < 0) {
		perror("HCIGETCONNLIST");
		free(cl);
		return -1;
	}
	for (int i = 0; i < cl->conn_num; i++) {
		struct hci_conn_info *ci = &cl->conn_info[i];

		if (ci->type == want && ci->state == BT_CONNECTED &&
				!memcmp(&ci->bdaddr, dst, sizeof(*dst))) {
			h = ci->handle;
			*type = ci->type;
		}
	}
	free(cl);
	return h;
}

int main(int argc, char *argv[])
{
	struct sockaddr_sco addr;
	struct hci_dev_info di;
	struct timeval tv = { .tv_sec = 5 };
	bdaddr_t dst;
	int dev, hci, sk, h0, h, want, type = -1, ret, err, kept = 1;
	char line[96];

	if (argc != 3 || parse_addr(argv[2], &dst) < 0) {
		fprintf(stderr, "usage: %s <hci index> <headset address>\n", argv[0]);
		return 2;
	}
	dev = atoi(argv[1]);

	hci = socket(AF_BLUETOOTH, SOCK_RAW | SOCK_CLOEXEC, BTPROTO_HCI);
	if (hci < 0) {
		perror("HCI socket");
		return 1;
	}

	memset(&di, 0, sizeof(di));
	di.dev_id = dev;
	if (ioctl(hci, HCIGETDEVINFO, &di) < 0) {
		perror("HCIGETDEVINFO");
		return 1;
	}
	want = wanted_type(&di);

	h0 = sco_handle(hci, dev, &dst, want, &type);
	if (h0 < 0) {
		printf("no connected %s link to that headset (the type the kernel will look up): "
			"start a call first\n", want == ESCO_LINK ? "eSCO" : "SCO");
		return 3;
	}
	snprintf(line, sizeof(line), "call's link: handle %d, %s", h0,
					type == ESCO_LINK ? "eSCO" : "SCO");
	stamp(line);

	sk = socket(AF_BLUETOOTH, SOCK_SEQPACKET | SOCK_CLOEXEC, BTPROTO_SCO);
	if (sk < 0) {
		perror("SCO socket");
		return 1;
	}
	setsockopt(sk, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

	/* Bound to the inspected adapter, so the connect goes through it */
	memset(&addr, 0, sizeof(addr));
	addr.sco_family = AF_BLUETOOTH;
	bacpy(&addr.sco_bdaddr, &di.bdaddr);
	if (bind(sk, (struct sockaddr *) &addr, sizeof(addr)) < 0) {
		perror("bind to the adapter");
		return 1;
	}

	memset(&addr, 0, sizeof(addr));
	addr.sco_family = AF_BLUETOOTH;
	bacpy(&addr.sco_bdaddr, &dst);

	stamp("second connect()");
	ret = connect(sk, (struct sockaddr *) &addr, sizeof(addr));
	err = ret < 0 ? errno : 0;
	snprintf(line, sizeof(line), "second connect() returned %d (%s)", ret,
					ret < 0 ? strerror(err) : "success");
	stamp(line);
	close(sk);
	stamp("second socket closed");

	for (int s = 1; s <= 10; s++) {
		sleep(1);
		h = sco_handle(hci, dev, &dst, want, &type);
		snprintf(line, sizeof(line), "+%2d s: %s", s,
				h == h0 ? "call's link still up" :
				h < 0 ? "NO SCO link to the headset" :
					"a DIFFERENT SCO link");
		stamp(line);
		if (h != h0)
			kept = 0;
	}
	close(hci);

	if (ret < 0 && err == EBUSY && kept) {
		printf("PASS: EBUSY, and the call's link (handle %d) stayed up for 10 s\n", h0);
		return 0;
	}
	printf("FAIL: %s, link %s\n", ret < 0 ? strerror(err) : "connect succeeded",
					kept ? "kept" : "NOT kept");
	return 1;
}
