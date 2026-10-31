/* CO-36 L1 harness: stubs for the bluez5 monitor symbols backend-native.c links to */
/* SPDX-License-Identifier: MIT */

#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>

#include "harness.h"
#include "hfp-codec-caps.h"
#include "telephony.h"
#include "upower.h"

int stub_connect_profile_calls;
int stub_transports_live;

void stubs_reset(void)
{
	stub_connect_profile_calls = 0;
	stub_transports_live = 0;
}

/* codecs: only what backend-native.c reads (id, kind, codec_id, names) */

static const struct media_codec codec_msbc = {
	.id = SPA_BLUETOOTH_AUDIO_CODEC_MSBC,
	.kind = MEDIA_CODEC_HFP,
	.codec_id = HFP_AUDIO_CODEC_MSBC,
	.name = "msbc",
	.description = "mSBC",
};

static const struct media_codec codec_cvsd = {
	.id = SPA_BLUETOOTH_AUDIO_CODEC_CVSD,
	.kind = MEDIA_CODEC_HFP,
	.codec_id = HFP_AUDIO_CODEC_CVSD,
	.name = "cvsd",
	.description = "CVSD",
};

/* best first, as codec_list_best() expects */
const struct media_codec * const stub_codecs[] = { &codec_msbc, &codec_cvsd, NULL };

const struct media_codec * const *spa_bt_get_media_codecs(struct spa_bt_monitor *monitor)
{
	return stub_codecs;
}

const struct media_codec *spa_bt_get_hfp_codec(struct spa_bt_monitor *monitor, unsigned int hfp_codec_id)
{
	for (int i = 0; stub_codecs[i]; i++)
		if (stub_codecs[i]->kind == MEDIA_CODEC_HFP && stub_codecs[i]->codec_id == hfp_codec_id)
			return stub_codecs[i];
	return NULL;
}

/* transports: as bluez5-dbus.c, minus D-Bus, keepalive, release timer and media players */

struct spa_bt_transport *spa_bt_transport_create(struct spa_bt_monitor *monitor, char *path, size_t extra)
{
	struct spa_bt_transport *t = calloc(1, sizeof(struct spa_bt_transport) + extra);

	if (t == NULL)
		return NULL;
	t->monitor = monitor;
	t->path = path;
	t->fd = -1;
	t->delay_us = SPA_BT_UNKNOWN_DELAY;
	t->latency_us = SPA_BT_UNKNOWN_DELAY;
	t->user_data = SPA_PTROFF(t, sizeof(struct spa_bt_transport), void);
	spa_hook_list_init(&t->listener_list);
	spa_list_init(&t->link);
	spa_list_init(&t->bap_transport_linked);
	stub_transports_live++;
	return t;
}

void spa_bt_transport_set_state(struct spa_bt_transport *t, enum spa_bt_transport_state state)
{
	enum spa_bt_transport_state old = t->state;

	if (old == state)
		return;
	t->state = state;
	spa_bt_transport_emit_state_changed(t, old, state);

	/* bluez5-dbus.c transport_sync_volume() */
	if (state >= SPA_BT_TRANSPORT_STATE_PENDING && old < SPA_BT_TRANSPORT_STATE_PENDING &&
	    t->device && (t->device->hw_volume_profiles & t->profile)) {
		for (int i = 0; i < SPA_BT_VOLUME_ID_TERM; ++i)
			spa_bt_transport_set_volume(t, i, t->volumes[i].volume);
		spa_bt_transport_emit_volume_changed(t);
	}
}

void spa_bt_transport_free(struct spa_bt_transport *t)
{
	spa_bt_transport_set_state(t, SPA_BT_TRANSPORT_STATE_IDLE);
	spa_bt_transport_emit_destroy(t);

	if (t->sco_io) {
		spa_bt_sco_io_destroy(t->sco_io);
		t->sco_io = NULL;
	}

	spa_bt_transport_destroy(t);

	if (t->fd >= 0) {
		shutdown(t->fd, SHUT_RDWR);
		close(t->fd);
		t->fd = -1;
	}

	spa_list_remove(&t->link);
	if (t->device) {
		struct spa_bt_transport *o;
		uint32_t disconnected = t->profile;

		spa_list_remove(&t->device_link);
		spa_list_for_each(o, &t->device->transport_list, device_link)
			disconnected &= ~o->profile;
		t->device->connected_profiles &= ~disconnected;
		spa_bt_device_emit_profiles_changed(t->device, t->profile);
	}
	spa_list_remove(&t->bap_transport_linked);

	free(t->path);
	free(t);
	stub_transports_live--;
}

void spa_bt_sco_io_destroy(struct spa_bt_sco_io *io)
{
}

/* devices and adapters */

int spa_bt_adapter_has_msbc(struct spa_bt_adapter *adapter)
{
	return 1;
}

struct spa_bt_device *spa_bt_device_find(struct spa_bt_monitor *monitor, const char *path)
{
	return NULL;
}

int spa_bt_device_add_profile(struct spa_bt_device *device, enum spa_bt_profile profile)
{
	device->profiles |= profile;
	return 0;
}

int spa_bt_device_connect_profile(struct spa_bt_device *device, enum spa_bt_profile profile)
{
	stub_connect_profile_calls++;
	device->connected_profiles |= profile;
	return 0;
}

int spa_bt_device_check_profiles(struct spa_bt_device *device, bool force)
{
	return 0;
}

int spa_bt_device_report_battery_level(struct spa_bt_device *device, uint8_t percentage)
{
	return 0;
}

int spa_bt_profiles_from_json_array(const char *str)
{
	return 0;
}

int spa_bt_quirks_get_features(const struct spa_bt_quirks *quirks,
		const struct spa_bt_adapter *adapter,
		const struct spa_bt_device *device,
		uint32_t *features)
{
	return -ENOENT;
}

/* upower, telephony: never reached in the AG tests (no telephony object) */

void *upower_register(struct spa_log *log, void *dbus_connection,
		void (*set_battery_level)(unsigned int level, void *user_data), void *user_data)
{
	return NULL;
}

void upower_unregister(void *data)
{
}

struct spa_bt_telephony *telephony_new(struct spa_log *log, struct spa_dbus *dbus,
		const struct spa_dict *info)
{
	return NULL;
}

void telephony_free(struct spa_bt_telephony *telephony)
{
}

void telephony_send_dbus_method_reply(struct spa_bt_telephony *telephony,
		DBusMessage *m, enum spa_bt_telephony_error err, uint8_t cme_error)
{
}

struct spa_bt_telephony_ag *telephony_ag_new(struct spa_bt_telephony *telephony, size_t user_data_size)
{
	return NULL;
}

void telephony_ag_destroy(struct spa_bt_telephony_ag *ag)
{
}

void telephony_ag_set_callbacks(struct spa_bt_telephony_ag *ag,
		const struct spa_bt_telephony_ag_callbacks *cbs, void *data)
{
}

void telephony_ag_notify_updated_props(struct spa_bt_telephony_ag *ag)
{
}

void telephony_ag_transport_notify_updated_props(struct spa_bt_telephony_ag *ag)
{
}

int telephony_ag_register(struct spa_bt_telephony_ag *ag)
{
	return -ENOTSUP;
}

struct spa_bt_telephony_call *telephony_call_new(struct spa_bt_telephony_ag *ag, size_t user_data_size)
{
	return NULL;
}

void telephony_call_destroy(struct spa_bt_telephony_call *call)
{
}

void *telephony_call_get_user_data(struct spa_bt_telephony_call *call)
{
	return NULL;
}

int telephony_call_register(struct spa_bt_telephony_call *call)
{
	return -ENOTSUP;
}

void telephony_call_notify_updated_props(struct spa_bt_telephony_call *call)
{
}

void telephony_call_set_callbacks(struct spa_bt_telephony_call *call,
		const struct spa_bt_telephony_call_callbacks *cbs, void *data)
{
}
