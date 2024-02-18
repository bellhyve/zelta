#!/usr/bin/awk -f
#
# zelta-snapshot.awk - quick and dirty snapshot tool for zelta-defined endpoints

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
	get_endpoint_info = "zelta endpoint " $0
	get_endpoint_info | getline
	endpoint_id = $1
	zfs = ($2?"ssh -n "$2" ":"") "zfs "
	user = $3
	host = $4
	dataset = $5
	snapshot = make_snapshot_name($6)
	close(get_endpoint_info)

	command = zfs "snapshot -r " "'"dataset"@"snapshot"'"
	last_exit_code = system(command)
	if (!last_exit_code) print "snapshot created: "dataset"@"snapshot
	exit_code = last_exit_code?last_exit_code:exit_code
}

END {
	exit exit_code
}
