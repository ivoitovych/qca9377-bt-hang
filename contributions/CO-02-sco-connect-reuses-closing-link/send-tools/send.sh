#!/bin/bash
# send.sh <package send dir> kernel|bluez [--send|--check]
# CO-02's send, one script for the dry run and the real send, so the command that is sent is the
# command that was dry-run. Without a flag: git send-email --dry-run (nothing leaves the machine).
# With --send: the real send, git send-email --confirm=always (it asks before each mail). The
# real send is the OPERATOR's to run, on their own decision; this script never runs it by itself.
# --check: every guard --send applies, then stop (nothing is sent).
# Recipients and options as tmp/co02-round3/send-dry-run.sh (the operator's decision of
# 2026-10-22): the list; Marcel Holtmann and Luiz Augusto von Dentz; Cen Zhang; Aldo Ariel
# Panzardo; Hitalo Souza; Pauli Virtanen; stable@ from the patches' trailers; the author's own
# address suppressed. BlueZ: the list, Luiz Augusto von Dentz, Pauli Virtanen.
# Order: kernel first. Then fill-bluez-link.sh with the cover's Message-ID, commit, then bluez.
#
# Guards for --send and --check (2026-10-27, after the review of a2b6649):
# - the package is the one named in send-tools/chosen-package (the operator's choice of v6 or v7);
# - the package's files are committed, unchanged and with nothing untracked beside them, so what is
#   sent is what was reviewed and checked;
# - kernel/ holds exactly the cover and patches 1 to 3, bluez/ exactly one mail;
# - the BlueZ mail has no @KERNEL_SERIES_LINK@ left and exactly one lore link to a cover
#   letter of this author (whether it is THE cover stays the operator's check on lore).
# A failed git send-email ends the script with its status, never with a "next step".
set -u
shopt -s nullglob
R=/root/exp/qca9377-bt-hang
CO=$R/contributions/CO-02-sco-connect-reuses-closing-link
AUTHOR=yaroslav.voytovych@gmail.com
usage() { echo "usage: send.sh <package send dir> kernel|bluez [--send|--check]"; exit 2; }
(( $# == 2 || $# == 3 )) || usage
D=$(realpath -e "$1") || usage
WHAT=$2
FLAG=${3:-}
case "$WHAT" in kernel|bluez) ;; *) usage ;; esac
case "$FLAG" in
"") MODE=(--dry-run --confirm=never) ;;
--send|--check) MODE=(--confirm=always) ;;
*) echo "unknown option: $FLAG"; usage ;;
esac

# The mails: exactly the expected files, one per name
if [[ "$WHAT" == kernel ]]; then
	all=("$D"/kernel/*.patch)
	MAILS=("$D"/kernel/0000-cover-letter.patch "$D"/kernel/0001-*.patch "$D"/kernel/0002-*.patch "$D"/kernel/0003-*.patch)
	(( ${#all[@]} == 4 && ${#MAILS[@]} == 4 )) || { echo "refusing: $D/kernel must hold exactly 0000-cover-letter.patch and one each of 0001 to 0003 (found ${#all[@]} .patch files)"; exit 2; }
	# one per number: four files could still be two 0001s and no 0002 (reviewers 3, 4, 2026-10-27)
	for i in 0000 0001 0002 0003; do
		f=("$D"/kernel/$i-*.patch)
		(( ${#f[@]} == 1 )) || { echo "refusing: $D/kernel must hold exactly one $i-*.patch (found ${#f[@]})"; exit 2; }
	done
else
	MAILS=("$D"/bluez/*.patch)
	(( ${#MAILS[@]} == 1 )) || { echo "refusing: $D/bluez must hold exactly one .patch file (found ${#MAILS[@]})"; exit 2; }
fi
for m in "${MAILS[@]}"; do
	[[ -f "$m" && -r "$m" ]] || { echo "refusing: cannot read $m"; exit 2; }
done

echo "package: $D"
for m in "${MAILS[@]}"; do
	echo "  $(basename "$m"): $(grep -m1 '^Subject:' "$m")"
done

if [[ -n "$FLAG" ]]; then
	C=$(cat "$CO/send-tools/chosen-package" 2>/dev/null) || { echo "refusing: no send-tools/chosen-package; the operator has not chosen the package"; exit 2; }
	# the choice itself must be committed, not a local edit (reviewers 2, 5, 2026-10-27)
	git -C "$R" ls-files --error-unmatch -- "$CO/send-tools/chosen-package" > /dev/null 2>&1 || { echo "refusing: send-tools/chosen-package is not tracked in git"; exit 2; }
	[[ -z "$(git -C "$R" status --porcelain -- "$CO/send-tools/chosen-package")" ]] || { echo "refusing: send-tools/chosen-package has uncommitted changes"; exit 2; }
	[[ "$D" == "$(realpath -e "$CO/$C")" ]] || { echo "refusing: $D is not the chosen package ($C)"; exit 2; }
	st=$(git -C "$R" status --porcelain -- "$D") || { echo "refusing: git status failed"; exit 2; }
	[[ -z "$st" ]] || { echo "refusing: the package has uncommitted or untracked files:"; echo "$st"; exit 2; }
	git -C "$R" ls-files --error-unmatch -- "${MAILS[@]}" > /dev/null 2>&1 || { echo "refusing: not every mail is tracked in git"; exit 2; }
fi

if [[ "$WHAT" == bluez ]]; then
	M=${MAILS[0]}
	n=$(grep -c "@KERNEL_SERIES_LINK@" "$M"); rc=$?
	(( rc <= 1 )) || { echo "refusing: cannot read $M"; exit 2; }
	if (( n > 0 )); then
		[[ -n "$FLAG" ]] && { echo "refusing: the BlueZ mail still has @KERNEL_SERIES_LINK@; send the kernel series and run fill-bluez-link.sh first"; exit 2; }
		echo "NOTE: dry run with the link placeholder still in the mail (to be filled after the kernel send)"
	elif [[ -n "$FLAG" ]]; then
		L=$(grep -c -E "^https://lore\.kernel\.org/linux-bluetooth/[0-9]{14}\.[0-9]+-1-${AUTHOR//./[.]}/$" "$M")
		[[ "$L" == 1 ]] || { echo "refusing: expected exactly one lore link to this author's cover letter in $M, found $L"; exit 2; }
		echo "link: $(grep -E '^https://lore\.kernel\.org/linux-bluetooth/' "$M")"
		echo "  (open it: it must show [PATCH 0/3] Bluetooth: hci_conn: fix SCO connection reuse)"
	fi
fi

[[ "$FLAG" == --check ]] && { echo "check: all guards pass for the $WHAT mail(s); nothing sent"; exit 0; }
[[ "$FLAG" == --send ]] && echo "At each prompt answer y. If you answer anything else for any mail, quit (q) and stop: do not rerun until the sent mails are checked on lore."

G=(git -C /root/exp/qca9377-bt-hang/cache/co02-v1)
FROM=(--from "Iaroslav Voitovych <$AUTHOR>")
if [[ "$WHAT" == kernel ]]; then
	"${G[@]}" send-email "${MODE[@]}" --suppress-cc=self "${FROM[@]}" \
		--to "linux-bluetooth@vger.kernel.org" \
		--cc "Marcel Holtmann <marcel@holtmann.org>" \
		--cc "Luiz Augusto von Dentz <luiz.dentz@gmail.com>" \
		--cc "Cen Zhang <zzzccc427@gmail.com>" \
		--cc "Aldo Ariel Panzardo <qwe.aldo@gmail.com>" \
		--cc "Hitalo Souza <enghitalo@gmail.com>" \
		--cc "Pauli Virtanen <pav@iki.fi>" \
		"${MAILS[@]}"
else
	"${G[@]}" send-email "${MODE[@]}" --suppress-cc=self "${FROM[@]}" \
		--to "linux-bluetooth@vger.kernel.org" \
		--cc "Luiz Augusto von Dentz <luiz.dentz@gmail.com>" \
		--cc "Pauli Virtanen <pav@iki.fi>" \
		"${MAILS[@]}"
fi
rc=$?
if (( rc != 0 )) && [[ -z "$FLAG" ]]; then
	echo "FAILED: the dry run (git send-email --dry-run) exited $rc; nothing was sent"
	exit "$rc"
elif (( rc != 0 )); then
	echo "FAILED: git send-email exited $rc. Some mails may already have gone out. Check lore and the"
	echo "Sent folder before anything else; do not rerun the whole series, and do not send the BlueZ mail."
	exit "$rc"
fi
[[ "$WHAT" == kernel && "$FLAG" == --send ]] && echo "Next: the Message-ID printed for the [PATCH 0/3] mail goes to fill-bluez-link.sh."
exit 0
