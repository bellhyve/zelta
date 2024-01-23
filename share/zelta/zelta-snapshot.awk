#!/usr/bin/awk -f

function make_snapshot_name(snapshot) {
	if (snapshot) return snapshot
	if (ENVIRON["ZELTA_SNAP_NAME"]) {
		ENVIRON["ZELTA_SNAP_NAME"] | getline snapshot
	}
	if (snapshot) return snapshot
	else {
		srand()
		snapshot = srand()
		return snapshot
	}
}

BEGIN {
	FS = "\t"
	exit_code = 0
}

{
	"zelta endpoint "$0 | getline
	endpoint_id = $1
	command_prefix = $2
	user = $3
	host = $4
	volume = $5
	snapshot = make_snapshot_name($6)

	command = (command_prefix?command_prefix" ":"") "zfs snapshot -r " "'"volume"@"snapshot"'"
	last_exit_code = system(command)
	if (!last_exit_code) print "snapshot created: "volume"@"snapshot > "/dev/stderr"
	exit_code = last_exit_code?last_exit_code:exit_code
}

END {
	exit exit_code
}
