# EX-078 — co02-code-compare-control-v5-v6-bluez-differs

**Claim.** Positive control for the code comparison tool: the BlueZ test mails of v5 and v6, whose code differs by the 15-line teardown close, are reported as DIFFERING by both methods (diff text and git patch-id), and the printed difference is exactly that block plus the hunk-header offsets it causes. The messages are reported the same.

**Relevance.** A tool that says IDENTICAL is only worth something if it says DIFFERS when the code differs. This is the one real code change between the versions.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ python3 -I /root/exp/qca9377-bt-hang/scripts/patch-code-compare.py /root/exp/qca9377-bt-hang/contributions/CO-02-sco-connect-reuses-closing-link/patch/v5/send/bluez /root/exp/qca9377-bt-hang/contributions/CO-02-sco-connect-reuses-closing-link/patch/v6/send/bluez
```

## Output

Verbatim, 67 line(s), exit status 1.

```
0001  0001-tools-sco-tester-Add-SCO-reconnect-tests.patch
      code text: DIFFERS (617 lines compared, index lines left out)
      patch-id : DIFFERS  4649e0ffe6e71063 / 01df21faf4ee72b4
      message  : same
        --- A
        +++ B
        @@ -49,8 +49,24 @@
          
          static void print_debug(const char *str, void *user_data)
        -@@ -251,6 +277,21 @@ static void test_post_teardown(const void *test_data)
        +@@ -250,6 +276,36 @@ static void test_pre_setup(const void *test_data)
        + static void test_post_teardown(const void *test_data)
          {
          	struct test_data *data = tester_get_data();
        - 
        ++	const struct sco_client_data *scodata = data->test_data;
        ++
        ++	/*
        ++	 * The reconnect tests own their first socket (its channel does not
        ++	 * close it), so a test that timed out may have left it open.
        ++	 */
        ++	if (scodata && scodata->reconnect && data->sk >= 0) {
        ++		if (data->io_id) {
        ++			g_source_remove(data->io_id);
        ++			data->io_id = 0;
        ++		}
        ++
        ++		close(data->sk);
        ++		data->sk = -1;
        ++	}
        ++
         +	if (data->timer_id) {
         +		g_source_remove(data->timer_id);
        @@ -67,9 +83,8 @@
         +		data->sk2 = -1;
         +	}
        -+
        + 
          	hciemu_unref(data->hciemu);
          	data->hciemu = NULL;
        - }
        -@@ -269,13 +310,14 @@ static void test_data_free(void *test_data)
        +@@ -269,13 +325,14 @@ static void test_data_free(void *test_data)
          					_disable_sco_flowctl, _timeout) \
          	do { \
        @@ -87,5 +102,5 @@
          		user->step = 0; \
          		user->disable_esco = _disable_esco; \
        -@@ -329,6 +371,18 @@ static const struct sco_client_data connect_failure_reset = {
        +@@ -329,6 +386,18 @@ static const struct sco_client_data connect_failure_reset = {
          	.expect_err = ECONNRESET
          };
        @@ -106,5 +121,5 @@
          
          static const struct sco_client_data connect_recv_success = {
        -@@ -1309,6 +1363,490 @@ static void test_connect_acl_disc(const void *test_data)
        +@@ -1309,6 +1378,490 @@ static void test_connect_acl_disc(const void *test_data)
          	test_connect(test_data);
          }
        @@ -597,5 +612,5 @@
          {
          	struct test_data *data = tester_get_data();
        -@@ -1526,6 +2064,18 @@ int main(int argc, char *argv[])
        +@@ -1526,6 +2079,18 @@ int main(int argc, char *argv[])
          					&connect_failure_reset, setup_powered,
          					test_connect_acl_disc);
RESULT: the code DIFFERS (above)
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-26T06:48:14+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | none named by the command (it selects by index or not by boot) — see the window above |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `1` |
| redacted | `no` |
