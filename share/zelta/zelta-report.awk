#!/usr/bin/awk -f
#
# zelta-report.awk - send a Slack hook message with a list of out of date snapshots
#   in "zelta policy"'s BACKUP_ROOT.
#
# Note that this script has not been designed for public use. Contributions are welcome.

## Initialization
#################

function init_report(	_endpoint_str) {
	# Get backup root from options or first operand
	_endpoint_str = Opt["BACKUP_ROOT"]
	if (!_endpoint_str && NumOperands >= 1)
		_endpoint_str = Operands[1]
	if (!_endpoint_str)
		stop(1, "BACKUP_ROOT not set")

	# Parse the endpoint to handle remote targets
	load_endpoint(_endpoint_str, BackupRoot)

	# Get Slack hook from options
	SlackHook = Opt["SLACK_HOOK"]
	if (!SlackHook)
		stop(1, "SLACK_HOOK not set")

	# Calculate the age threshold (24 hours ago)
	TooOld = sys_time() - 86400
}

## ZFS List
###########

# Build and run the zfs list command for the backup root
function get_snapshot_ages(	_cmd_arr, _cmd, _remote) {
	_remote = get_remote_cmd(BackupRoot)
	_cmd = "zfs list -t filesystem,volume -Hpr -o name,snapshots_changed -S snapshots_changed"
	_cmd = str_add(_cmd, qq(BackupRoot["DS"]))
	if (_remote) _cmd = _remote " " dq(_cmd)
	return _cmd
}

# Parse zfs list output and categorize datasets
function parse_snapshot_list(	_cmd, _ds, _changed, _rel_name) {
	_cmd = get_snapshot_ages()
	FS = "[\t]+"
	while ((_cmd | getline) > 0) {
		_ds = $1
		_changed = $2
		# Skip if we've already seen this dataset
		if (_ds in SeenDS) continue
		SeenDS[_ds] = 1
		# Skip datasets without snapshot info
		if (_changed == "-") continue
		# Get relative name by removing backup root prefix
		_rel_name = _ds
		sub("^" BackupRoot["DS"] "/?", "", _rel_name)
		if (!_rel_name) _rel_name = BackupRoot["LEAF"]
		# Categorize by age
		if (_changed < TooOld) {
			OldList[++OutOfDateCount] = _rel_name
		} else {
			UpToDateCount++
		}
	}
	close(_cmd)
}

## Slack Notification
#####################

# Build the Slack message based on snapshot status
function build_slack_message(	_msg, _i) {
	_msg = "*" BackupRoot["HOST"] ":" BackupRoot["DS"] " "
	if (!UpToDateCount && !OutOfDateCount) {
		_msg = _msg "⚠️ no snapshots found.*"
	} else if (!UpToDateCount) {
		_msg = _msg "🛑 ALL snapshots are out of date!*"
	} else if (OutOfDateCount > 0) {
		_msg = _msg "❗️ some snapshots are out of date:* "
		for (_i = 1; _i <= OutOfDateCount; _i++) {
			_msg = _msg OldList[_i] " "
		}
	} else {
		_msg = _msg "✅ snapshots are up to date.*"
	}
	return _msg
}

# Send the message to Slack
function send_slack_message(message,	_curl) {
	_curl = "curl -s -X POST -H 'Content-type: application/json; charset=utf-8' " \
		"--data '{ \"username\": \"zeport\", \"icon_emoji\": \":camera_with_flash:\", \"text\": \"" \
		message "\" }' " SlackHook
print _curl
	_curl | getline
	close(_curl)
}

## Main
#######

BEGIN {
	init_report()
	parse_snapshot_list()
	SlackMessage = build_slack_message()
	report(LOG_NOTICE, SlackMessage)
	send_slack_message(SlackMessage)
}
