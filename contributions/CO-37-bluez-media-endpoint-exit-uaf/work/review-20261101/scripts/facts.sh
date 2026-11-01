#!/bin/bash
# Source and record facts for the report, each with its command, into
# results/facts.txt.
W=/root/exp/agent-work/co23-co37-review-20261101
R=$W/repo
F=$W/fetch/fedora-bluez
out=$W/results/facts.txt
mkdir -p $W/results
run() {
	echo "\$ $*"
	"$@" 2>&1
	echo "[exit $?]"
	echo
}
{
	echo "# facts, $(date '+%F %T %Z')"
	run git -C $R log -1 --format='%H %ci %s' 14bd6ab65
	run git -C $R grep -n -e 'context="default"' -e send_destination 14bd6ab65 5.72 -- src/bluetooth.conf
	run grep -n -e policy -e send_destination /usr/share/dbus-1/system.d/bluetooth.conf
	run dpkg-query -W bluez
	run git -C $R grep -n -e 'g_dbus_register_security(' 14bd6ab65
	run git -C $R grep -n -e '^static gboolean check_privilege' 14bd6ab65 -- gdbus/object.c
	run git -C $R grep -n -e '^static DBusMessage \*register_endpoint' -e '^static DBusMessage \*unregister_endpoint' -e '^static DBusMessage \*register_app' -e '^static DBusMessage \*unregister_app' -e 'GDBUS_METHOD("RegisterEndpoint"' -e 'GDBUS_ASYNC_METHOD("RegisterApplication"' 14bd6ab65 5.72 -- profiles/audio/media.c
	run git -C $R grep -n -e 'Only allow switching sep from the same sender' -e '^static struct a2dp_sep \*find_sep(' -e '^static DBusMessage \*set_configuration' -e 'lsep = find_sep(chan->server' 14bd6ab65 5.72 -- profiles/audio/a2dp.c
	run git -C $R grep -n -e '^static DBusMessage \*acquire' -e 'if (transport->owner != NULL)' -e 'g_strcmp0(owner->name, sender) != 0' 14bd6ab65 5.72 -- profiles/audio/transport.c
	run git -C $R grep -n -e '^static DBusMessage \*disconnect_profile' 14bd6ab65 5.72 -- src/device.c
	run git -C $R grep -n -e '#define REQ_TIMEOUT' -e '#define ABORT_TIMEOUT' -e 'rejecting since close is already initiated' 14bd6ab65 5.72 -- profiles/audio/avdtp.c
	run git -C $R grep -n -e 'Disconnected from D-Bus' -e 'plugin_cleanup();' -e 'adapter_shutdown();' -e '#define SHUTDOWN_GRACE_SECONDS' 14bd6ab65 5.72 -- src/main.c
	run git -C $R grep -n -e '^static void index_removed' -e '^static void adapter_remove(' -e '^static void unload_drivers' 14bd6ab65 5.72 -- src/adapter.c
	run git -C $R grep -n -e '^static void path_free' -e '^static void release_endpoint' -e '^static void clear_endpoint' -e '^static void a2dp_destroy_endpoint' -e '^static void media_endpoint_exit' -e '^static void client_disconnect_cb' 14bd6ab65 5.72 -- profiles/audio/media.c
	run git -C $R grep -n -e '^gboolean a2dp_sep_unlock' -e 'Unregister sep if it was removed' -e '^static void a2dp_unregister_sep' -e '^void a2dp_remove_sep' 14bd6ab65 5.72 -- profiles/audio/a2dp.c
	run git -C $R grep -n -e '^static void a2dp_suspend_complete' -e '^static guint transport_a2dp_suspend' -e '^static void media_transport_free' 14bd6ab65 5.72 -- profiles/audio/transport.c
	run git -C $R grep -n -e 'only attempt to acquire if transport is configured with a local' 14bd6ab65 -- client/player.c
	run git -C $R log -1 --format='%h %ad %s' --date=short 14bd6ab65 -- SECURITY.md
	run git -C $R show 14bd6ab65:SECURITY.md
	run git -C $R log -1 --format='%H %an %ad %s' rfc
	run git -C $F log --format='%h %ad %an %s' --date=iso -n 12 origin/rawhide
	run git -C $F grep -n -e '^Version' -e '^Release' -e '^Patch' fadb768 -- bluez.spec
	run git -C $F show ab04c8e -- bluez.spec
	run git -C $F grep -n -e '^From 7482aceece70' ab04c8e -- 5.87-bug-fixes-1.patch
	run git -C $R merge-base --is-ancestor 7482aceece70 30db66dc971bd1cd95d4a7b0eea296367ab65b3b
	run git -C $F branch -r --contains ab04c8e
} > $out
echo "written $out ($(grep -c '^\$ ' $out) commands)"
