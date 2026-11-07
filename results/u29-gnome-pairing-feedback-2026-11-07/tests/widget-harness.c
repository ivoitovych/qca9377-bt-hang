/* Headless driver for the real BluetoothSettingsWidget (gnome-bluetooth master).
 *
 * usage: widget-harness OUTDIR TAG
 *
 * 1. shows the widget in an AdwApplicationWindow (display: Xvfb)
 * 2. waits for the first device row, dumps the widget tree and a screenshot (BEFORE)
 * 3. activates that row programmatically (the "row-activated" signal of the
 *    device list, exactly what a click does): start_pairing() ->
 *    bluetooth_client_setup_device() -> Device1.Pair() -> create_callback()
 * 4. waits, dumps the tree and a screenshot again (AFTER), lists toplevels
 *
 * Output lines start with "HARNESS " so the test can grep them.
 */
#include <gtk/gtk.h>
#include <adwaita.h>
#include <bluetooth-settings-widget.h>

static GMainLoop *loop;
static GtkWidget *window;
static const char *outdir;
static const char *tag;

static void
run_for (guint ms)
{
	GMainContext *ctx = g_main_context_default ();
	gint64 end = g_get_monotonic_time () + (gint64) ms * 1000;
	while (g_get_monotonic_time () < end)
		g_main_context_iteration (ctx, FALSE);
}

static GtkWidget *
find_by_buildable_id (GtkWidget *w, const char *id)
{
	GtkWidget *c, *r;
	if (GTK_IS_BUILDABLE (w)) {
		const char *bid = gtk_buildable_get_buildable_id (GTK_BUILDABLE (w));
		if (g_strcmp0 (bid, id) == 0)
			return w;
	}
	for (c = gtk_widget_get_first_child (w); c; c = gtk_widget_get_next_sibling (c)) {
		r = find_by_buildable_id (c, id);
		if (r)
			return r;
	}
	return NULL;
}

/* toasts actually shown: the overlay puts each one in an AdwToastWidget child.
 * The original "AdwToast*" prefix counter also matches the AdwToastOverlay itself
 * (kept unchanged so earlier runs stay comparable); these two are the exact ones. */
static int n_toast_widget, n_toast_overlay;

static void
toast_texts (GtkWidget *w, const char *phase)
{
	GtkWidget *c;
	if (GTK_IS_LABEL (w))
		g_print ("HARNESS TOAST %s text=\"%s\"\n", phase, gtk_label_get_label (GTK_LABEL (w)));
	for (c = gtk_widget_get_first_child (w); c; c = gtk_widget_get_next_sibling (c))
		toast_texts (c, phase);
}

static void
dump_tree (GtkWidget *w, int depth, const char *phase, int *n_dialog, int *n_toast,
	   int *n_banner, int *n_alert)
{
	GtkWidget *c;
	const char *tn = G_OBJECT_TYPE_NAME (w);
	g_autofree char *text = NULL;

	if (g_strcmp0 (tn, "AdwToastWidget") == 0) {
		n_toast_widget++;
		toast_texts (w, phase);
	}
	if (ADW_IS_TOAST_OVERLAY (w))
		n_toast_overlay++;

	if (GTK_IS_LABEL (w))
		text = g_strdup (gtk_label_get_label (GTK_LABEL (w)));
	else if (GTK_IS_BUTTON (w) && gtk_button_get_label (GTK_BUTTON (w)))
		text = g_strdup (gtk_button_get_label (GTK_BUTTON (w)));

	if (ADW_IS_DIALOG (w)) (*n_dialog)++;
	if (ADW_IS_ALERT_DIALOG (w)) (*n_alert)++;
	if (ADW_IS_TOAST_OVERLAY (w)) { /* overlay itself is not a toast */ }
	if (ADW_IS_BANNER (w)) (*n_banner)++;
	if (g_str_has_prefix (tn, "AdwToast")) (*n_toast)++;

	g_print ("HARNESS TREE %s %*s%s mapped=%d visible=%d%s%s%s\n", phase, depth * 2, "", tn,
		 gtk_widget_get_mapped (w), gtk_widget_get_visible (w),
		 text ? " text=\"" : "", text ? text : "", text ? "\"" : "");

	for (c = gtk_widget_get_first_child (w); c; c = gtk_widget_get_next_sibling (c))
		dump_tree (c, depth + 1, phase, n_dialog, n_toast, n_banner, n_alert);
}

static void
row_labels (GtkWidget *w, const char *phase, const char *what)
{
	GtkWidget *c;
	if (GTK_IS_LABEL (w))
		g_print ("HARNESS ROW %s label=\"%s\" visible=%d mapped=%d\n", phase,
			 gtk_label_get_label (GTK_LABEL (w)), gtk_widget_get_visible (w),
			 gtk_widget_get_mapped (w));
	if (ADW_IS_SPINNER (w))
		g_print ("HARNESS ROW %s spinner visible=%d mapped=%d\n", phase,
			 gtk_widget_get_visible (w), gtk_widget_get_mapped (w));
	for (c = gtk_widget_get_first_child (w); c; c = gtk_widget_get_next_sibling (c))
		row_labels (c, phase, what);
}

static void
screenshot (const char *phase)
{
	GdkPaintable *p = gtk_widget_paintable_new (window);
	int w = gtk_widget_get_width (window), h = gtk_widget_get_height (window);
	GtkSnapshot *snap = gtk_snapshot_new ();
	GskRenderNode *node;
	GskRenderer *renderer = gtk_native_get_renderer (GTK_NATIVE (window));
	g_autofree char *path = g_strdup_printf ("%s/%s-%s.png", outdir, tag, phase);
	GdkTexture *tex;

	gdk_paintable_snapshot (p, snap, w, h);
	node = gtk_snapshot_free_to_node (snap);
	if (node && renderer) {
		tex = gsk_renderer_render_texture (renderer, node, NULL);
		if (tex && gdk_texture_save_to_png (tex, path))
			g_print ("HARNESS SCREENSHOT %s %s (%dx%d)\n", phase, path, w, h);
		else
			g_print ("HARNESS SCREENSHOT %s FAILED\n", phase);
		g_clear_object (&tex);
		gsk_render_node_unref (node);
	}
	g_object_unref (p);
}

static void
snapshot_state (GtkWidget *widget, GtkWidget *row, const char *phase)
{
	int d = 0, t = 0, b = 0, a = 0;
	GListModel *tl = gtk_window_get_toplevels ();
	guint i, n = g_list_model_get_n_items (tl);

	n_toast_widget = n_toast_overlay = 0;
	dump_tree (window, 0, phase, &d, &t, &b, &a);
	if (row)
		row_labels (row, phase, "row");
	g_print ("HARNESS SUMMARY %s AdwDialog=%d AdwAlertDialog=%d AdwToast*=%d AdwBanner=%d toplevels=%u ToastWidgets=%d ToastOverlays=%d\n",
		 phase, d, a, t, b, n, n_toast_widget, n_toast_overlay);
	for (i = 0; i < n; i++) {
		GObject *o = g_list_model_get_item (tl, i);
		g_print ("HARNESS TOPLEVEL %s %s visible=%d\n", phase, G_OBJECT_TYPE_NAME (o),
			 gtk_widget_get_visible (GTK_WIDGET (o)));
		g_object_unref (o);
	}
	screenshot (phase);
}

int
main (int argc, char **argv)
{
	GtkWidget *widget, *list, *row = NULL;
	int i;
	guint wait_ms = argc > 3 ? (guint) atoi (argv[3]) : 3000;

	if (argc < 3) {
		g_printerr ("usage: %s OUTDIR TAG [WAIT_MS]\n", argv[0]);
		return 2;
	}
	outdir = argv[1];
	tag = argv[2];

	adw_init ();
	window = adw_application_window_new (NULL);
	gtk_window_set_default_size (GTK_WINDOW (window), 700, 700);
	widget = bluetooth_settings_widget_new ();
	adw_application_window_set_content (ADW_APPLICATION_WINDOW (window), widget);
	gtk_window_present (GTK_WINDOW (window));

	list = NULL;
	for (i = 0; i < 100 && !row; i++) {
		run_for (100);
		list = find_by_buildable_id (widget, "device_list");
		if (list)
			row = gtk_widget_get_first_child (list);
		while (row && !GTK_IS_LIST_BOX_ROW (row))
			row = gtk_widget_get_next_sibling (row);
	}
	if (!row) {
		g_print ("HARNESS ERROR no device row appeared (list=%p)\n", (void *) list);
		return 3;
	}
	run_for (500);
	/* keep the row object alive even if the widget drops it (device removed) */
	g_object_ref (row);
	g_print ("HARNESS START activating row type=%s\n", G_OBJECT_TYPE_NAME (row));
	snapshot_state (widget, row, "before");

	if (g_strcmp0 (g_getenv ("HARNESS_CONTROL_TOAST"), "1") == 0) {
		/* positive control for the toast counter: show a toast ourselves, no pairing */
		GtkWidget *ov = find_by_buildable_id (widget, "overlay");
		g_print ("HARNESS CONTROL overlay=%p\n", (void *) ov);
		if (ov)
			adw_toast_overlay_add_toast (ADW_TOAST_OVERLAY (ov), adw_toast_new ("CONTROL TOAST"));
	} else {
		/* what a click on the row does */
		g_signal_emit_by_name (list, "row-activated", row);
	}

	if (g_strcmp0 (g_getenv ("HARNESS_PRESS_CANCEL"), "1") == 0) {
		/* wait for the pairing dialog and press its Cancel button */
		GtkWidget *btn = NULL;
		for (i = 0; i < 100 && !btn; i++) {
			run_for (100);
			btn = find_by_buildable_id (window, "cancel");
			if (btn && !gtk_widget_get_mapped (btn))
				btn = NULL;
		}
		if (btn) {
			g_print ("HARNESS DIALOG cancel button found after %d ms\n", i * 100);
			run_for (300);
			snapshot_state (widget, row, "dialog");
			g_signal_emit_by_name (btn, "clicked");
			g_print ("HARNESS DIALOG cancel pressed\n");
		} else {
			g_print ("HARNESS DIALOG no cancel button appeared\n");
		}
	}

	run_for (200);
	snapshot_state (widget, row, "during");
	run_for (wait_ms);
	snapshot_state (widget, row, "after");
	g_print ("HARNESS DONE\n");
	return 0;
}
