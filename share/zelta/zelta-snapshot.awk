#!/usr/bin/awk -f
#
# zelta-snapshot.awk
#
# Make a snapshot using Zelta's endpoint format. Called with "zelta snapshot".

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

	zfs		= (Opt["SRC_PREFIX"] ? "ssh -n " Opt["SRC_PREFIX"] " " : "") "zfs "
	dataset		= Opt["SRC_DS"]
	snapshot	= make_snapshot_name(Opt["SRC_SNAP"])

	command = zfs "snapshot -r " "'"dataset"@"snapshot"'"
	last_exit_code = system(command)
	if (!last_exit_code) print "snapshot created: "dataset"@"snapshot
	exit_code = last_exit_code?last_exit_code:exit_code
}
