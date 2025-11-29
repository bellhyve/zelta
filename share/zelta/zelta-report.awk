#!/usr/bin/awk -f
#
# zelta-report.awk - send a Slack hook message with a list of out of date snapshots
#   in "zelta policy"'s BACKUP_ROOT.
#
# Note that this script has not been designed for public use. Contributions are welcome.

function init(	  o) {
	for (o in ENVIRON) {
		if (sub(/^ZELTA_/,"",o)) {
			Opt[o] = ENVIRON["ZELTA_" o]
		}
	}
}

function err(msg) {
	print msg
	exit 1
}

BEGIN {
	get_backup_root_command = "awk '/^BACKUP_ROOT: /{print $2}' " Opt["CONFIG"]
	get_backup_root_command | getline BACKUP_ROOT
	HOOK_FILE = ENVIRON["HOME"] "/.zeport-hook"
	getline SLACK_HOOK < HOOK_FILE
	if (! SLACK_HOOK || ! BACKUP_ROOT) err("please correctly set BACKUP_ROOT and SLACK_HOOK")
	"hostname" | getline HOSTNAME
	too_old = systime() - 86400
	#too_old = systime() - 8640
	trim = length(BACKUP_ROOT) + 1
	FS = "[@\t]+"
	# This seems to be faster than trying to limit the list in any way:
	zfs_list = "zfs list -Hprt snap -oname,creation -S creation "BACKUP_ROOT

	while (zfs_list | getline) {
		if (snaplist[$1]) continue
		snaplist[$1]++
		sub(BACKUP_ROOT"/", "")
		if ($3 < too_old) {
			old_list[$1]++
			outofdate_count++
		} else uptodate_count++
	}

	SLACK_MESSAGE = "\*" HOSTNAME ":" BACKUP_ROOT " "
	if (!uptodate_count) {
		SLACK_MESSAGE = SLACK_MESSAGE "ALL snapshots are out of date!\* "
	} else if (outofdate_count++) {
		SLACK_MESSAGE = SLACK_MESSAGE "some snapshots are out of date:\* "
		for (s in old_list) { SLACK_MESSAGE = SLACK_MESSAGE s" " }
	} else { SLACK_MESSAGE = SLACK_MESSAGE "snapshots are up to date.\*" }

	curl = 	"curl -s -X POST -H 'Content-type: application/json; charset=utf-8' " \
	     	"--data '{ \"username\": \"zeport\", \"icon_emoji\": \":camera_with_flash:\", \"text\": \"" \
		SLACK_MESSAGE "\" }' " SLACK_HOOK

	curl | getline
}
