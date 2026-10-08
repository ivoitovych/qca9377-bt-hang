#!/bin/bash
# smtp-login-check.sh — is an app password still alive? LOGIN ONLY: connects to
# the SMTP server in the repository's sendemail config (STARTTLS on 587 or
# implicit TLS on 465, as the config says), AUTH, QUIT.
# Sends nothing. The password comes from the environment and is never written.
#
#   BT_SMTP_PASS='xxxx xxxx xxxx xxxx' scripts/smtp-login-check.sh [port encryption]
#
# The optional port and encryption override the config, e.g. "587 tls": on
# 2026-10-08 Gmail closed every 465 login check mid-AUTH (INCONCLUSIVE) while
# 587 STARTTLS answered 535 for revoked passwords.
#
# Exit 0 and "ALIVE" if the login is accepted (the password must still be
# revoked); exit 1 and "REVOKED" with the server's code (Gmail: 535) if refused.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${BT_SMTP_PASS:?set BT_SMTP_PASS}"
HOST=$(git -C "$REPO" config sendemail.smtpserver) || exit 2
PORT=$(git -C "$REPO" config sendemail.smtpserverport) || exit 2
USER_=$(git -C "$REPO" config sendemail.smtpuser) || exit 2
# tls = STARTTLS on a plain connection (587); ssl = TLS from the first byte
# (465). Since 2026-10-02 the config says 465/ssl: 587 timed out on the
# operator's network, and a STARTTLS check against 465 only ever sees the
# server hang up before any verdict.
ENC=$(git -C "$REPO" config sendemail.smtpencryption 2>/dev/null || echo tls)
if [ $# -eq 2 ]; then
    PORT=$1
    ENC=$2
fi
export HOST PORT USER_ ENC
python3 - <<'PYEOF'
import os, smtplib, sys
if os.environ["ENC"] == "ssl":
    s = smtplib.SMTP_SSL(os.environ["HOST"], int(os.environ["PORT"]), timeout=30)
    s.ehlo()
else:
    s = smtplib.SMTP(os.environ["HOST"], int(os.environ["PORT"]), timeout=30)
    s.ehlo(); s.starttls(); s.ehlo()
try:
    s.login(os.environ["USER_"], os.environ["BT_SMTP_PASS"].replace(" ", ""))
except smtplib.SMTPAuthenticationError as e:
    print(f"REVOKED — server refused the login: {e.smtp_code} {e.smtp_error[:60]!r}")
    s.quit(); sys.exit(1)
except smtplib.SMTPServerDisconnected as e:
    # Not a verdict: the server hung up mid-AUTH. Say so; never read it as REVOKED.
    print(f"INCONCLUSIVE — server closed the connection during AUTH: {e}")
    sys.exit(3)
print("ALIVE — the login was accepted; nothing was sent")
s.quit()
PYEOF
