/* Stubs that let btusb_notify() and btusb_work(), copied verbatim from a
 * btusb.c, run in user space against a scripted Bluetooth core.
 * Model of the device: the isochronous interface of 13d3:3503 as listed in
 * commit dc16388d45ec (alternate settings 0..5, max packet 0/9/17/25/33/49).
 */
#include <stdio.h>
#include <stdbool.h>
#include <string.h>

#define HCI_NOTIFY_CONN_ADD		1
#define HCI_NOTIFY_CONN_DEL		2
#define HCI_NOTIFY_VOICE_SETTING	3
#define HCI_NOTIFY_ENABLE_SCO_CVSD	4
#define HCI_NOTIFY_ENABLE_SCO_TRANSP	5
#define HCI_NOTIFY_DISABLE_SCO		6
#define SCO_LINK 0x00

#define BTUSB_ISOC_RUNNING	2
#define BTUSB_DID_ISO_RESUME	4
#define BTUSB_USE_ALT3_FOR_WBS	15

#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define min_t(t, a, b) ((t)(a) < (t)(b) ? (t)(a) : (t)(b))
#define container_of(p, t, m) ((t *)((char *)(p) - offsetof(t, m)))
#include <stddef.h>

struct work_struct { int pending; };
struct usb_interface { int dummy; };
struct hci_dev { unsigned int voice_setting; unsigned int sco_mtu; const char *name; };

struct btusb_data {
	struct hci_dev *hdev;
	struct usb_interface *intf, *isoc;
	unsigned long flags;
	struct work_struct work;
	int isoc_anchor;
	unsigned int sco_num;
	unsigned int air_mode;
	int isoc_altsetting;
};

static struct btusb_data the_data;
static struct hci_dev the_hdev = { .voice_setting = 0x0060, .sco_mtu = 64, .name = "hci0" };
static unsigned int core_sco_num;	/* hci_conn_num(hdev, SCO_LINK) */
static int submit_failures;		/* URBs that alt 0 (max packet 0) refuses */
static const int maxp[6] = { 0, 9, 17, 25, 33, 49 };

#define BT_DBG(fmt, ...) do { } while (0)
#define bt_dev_err(hdev, fmt, ...) printf("    [err] " fmt "\n", ##__VA_ARGS__)
static void *hci_get_drvdata(struct hci_dev *hdev) { (void)hdev; return &the_data; }
static unsigned int hci_conn_num(struct hci_dev *hdev, int type) { (void)hdev; (void)type; return core_sco_num; }
static void schedule_work(struct work_struct *w) { w->pending = 1; }
static int test_bit(int nr, unsigned long *f) { return (*f >> nr) & 1; }
static void set_bit(int nr, unsigned long *f) { *f |= 1UL << nr; }
static void clear_bit(int nr, unsigned long *f) { *f &= ~(1UL << nr); }
static int test_and_clear_bit(int nr, unsigned long *f) { int o = test_bit(nr, f); clear_bit(nr, f); return o; }
static int test_and_set_bit(int nr, unsigned long *f) { int o = test_bit(nr, f); set_bit(nr, f); return o; }
static int usb_autopm_get_interface(struct usb_interface *i) { (void)i; return 0; }
static void usb_autopm_put_interface(struct usb_interface *i) { (void)i; }
static void usb_kill_anchored_urbs(int *a) { (void)a; }
static void *btusb_find_altsetting(struct btusb_data *d, int alt) { (void)d; return (alt >= 0 && alt <= 5) ? (void *)1 : NULL; }
static int __set_isoc_interface(struct hci_dev *hdev, int alt) { (void)hdev; the_data.isoc_altsetting = alt; return 0; }
static int btusb_switch_alt_setting(struct hci_dev *hdev, int new_alts)
{
	/* as the real one: change the interface if needed, then (re)start
	 * the receive URBs, which the USB core refuses on max packet 0 */
	if (the_data.isoc_altsetting != new_alts) {
		clear_bit(BTUSB_ISOC_RUNNING, &the_data.flags);
		__set_isoc_interface(hdev, new_alts);
	}
	if (!test_and_set_bit(BTUSB_ISOC_RUNNING, &the_data.flags)) {
		if (maxp[new_alts] == 0) {
			submit_failures++;
			clear_bit(BTUSB_ISOC_RUNNING, &the_data.flags);
		}
	}
	return 0;
}
