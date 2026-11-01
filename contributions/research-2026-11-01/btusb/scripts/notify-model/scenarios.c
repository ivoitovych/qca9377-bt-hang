/* Scripted core for the notify model: the order in which net/bluetooth
 * calls hdev->notify() (hci_conn.c hci_conn_add()/hci_conn_cleanup(),
 * hci_event.c hci_sync_conn_complete_evt()), and the SCO connection count
 * hci_conn_num() returns at that moment. btusb_work() runs after each
 * notification that scheduled it. Each scenario starts from an idle driver.
 */
static int links_up;

static void run_work(void)
{
	if (the_data.work.pending) {
		the_data.work.pending = 0;
		btusb_work(&the_data.work);
	}
}

static void show(const char *what)
{
	printf("  %-34s core-sco %u  drv sco_num %u air_mode %u  alt %d%s  refused-urbs %d\n",
	       what, core_sco_num, the_data.sco_num, the_data.air_mode,
	       the_data.isoc_altsetting,
	       links_up && the_data.isoc_altsetting == 0 ? "  <== LINK UP ON ALT 0" : "",
	       submit_failures);
}

static void notify(unsigned int evt) { btusb_notify(&the_hdev, evt); run_work(); }
static void sco_setup(void) { core_sco_num++; show("SCO setup pending (no notify)"); }
static void sco_up(int transp) { links_up++; notify(transp ? HCI_NOTIFY_ENABLE_SCO_TRANSP : HCI_NOTIFY_ENABLE_SCO_CVSD); show(transp ? "SCO up, transparent" : "SCO up, CVSD"); }
static void sco_fail(int ev_air) { if (ev_air == 2) notify(HCI_NOTIFY_ENABLE_SCO_CVSD); if (ev_air == 3) notify(HCI_NOTIFY_ENABLE_SCO_TRANSP); core_sco_num--; notify(HCI_NOTIFY_DISABLE_SCO); show("SCO setup failed, deleted"); }
static void sco_down(void) { links_up--; core_sco_num--; notify(HCI_NOTIFY_DISABLE_SCO); show("SCO link down"); }
static void acl_add(void) { notify(HCI_NOTIFY_CONN_ADD); show("ACL/LE connection added"); }
static void acl_del(void) { notify(HCI_NOTIFY_CONN_DEL); show("ACL/LE connection deleted"); }

static void reset(const char *name)
{
	memset(&the_data, 0, sizeof(the_data));
	the_data.hdev = &the_hdev;
	core_sco_num = 0;
	links_up = 0;
	submit_failures = 0;
	printf("%s\n", name);
}

int main(void)
{
	reset("S1 one mSBC link");
	sco_setup(); sco_up(1); sco_down();

	reset("S2 one mSBC link; an ACL/LE connection is deleted while its setup is pending (the 2026-09-02 shape)");
	sco_setup(); acl_del(); sco_up(1); sco_down();

	reset("S3 one CVSD link; an ACL/LE connection is added while its setup is pending");
	sco_setup(); acl_add(); sco_up(0); sco_down();

	reset("S4 two CVSD links (two headsets); one goes down");
	sco_setup(); sco_up(0); sco_setup(); sco_up(0); sco_down(); sco_down();

	reset("S5 two mSBC links (two headsets); one goes down");
	sco_setup(); sco_up(1); sco_setup(); sco_up(1); sco_down(); sco_down();

	reset("S6 mSBC link up; a second headset's setup fails (event air mode transparent)");
	sco_setup(); sco_up(1); sco_setup(); sco_fail(3); sco_down();

	reset("S7 CVSD link up; a second headset's setup is pending when the first goes down; it comes up mSBC");
	sco_setup(); sco_up(0); sco_setup(); sco_down(); sco_up(1); sco_down();
	return 0;
}
