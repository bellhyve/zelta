#!/usr/bin/awk -f
#
# zmatch - compares a source and target datasets for dataset simiddlarity
#
# usage: zmatch [user@][host:]source/dataset [user@][host:]target/dataset
#
# Reports the most recent matching snapshot and the latest snapshot of a volume and
# its children, which are useful for various zfs operations
#
# In interactive mode, child snapshot names are provided relative to the target
# dataset. For example, when zmatch is called with tank/dataset, tank/dataset/child's
# snapshots will be reported as"/child@snapshot-name".
#
# Specifically:
#   - The latest matching snapshot and child snapshots
#   - Missing child volumes on the destination
#   - Matching snapshot names with different GUIDs
#   - Newer target snapshots not on the source
#
# SWITCHES
#
# -d#	Set depth.
# -n	Show the zfs list commands instead of running them.
# -v	Verbose, implies -w.
# -w	Calculates the size of missing target snapshots using the "written" property.
# -z	Pipe mode, see ZELTA_PIPE below.
#
# ENVIRONMENT VARIABLES
#
# ZELTA_PIPE: When set to 1, we provide full snapshot names and simplify the output as
# follows:
#   - Real time in seconds of the "zfs list" operations in the format: 1.01 : 3.51
#   - No other output is provided if no updates are possible/available.
#   - A single volume name indicates a parent volume is missing.
#   - A "source_snapshot target_volume" indicates a source volume needs to be replicated
#   - If two source snapshots are given, an incremental transfer is needed.
#
# ZELTA_DEPTH: Adds "-d $ZELTA_DEPTH" to zfs list commands. Useful for limiting
# replication depth in zpull.

function usage(message) {
	if (message) error(message)
	if (! ZELTA_PIPE) print "usage: zelta match [-nvwz] [-d #] [user@][host:]source/dataset [user@][host:]target/dataset"
	exit 1
}

function env(env_name, var_default) {
	return ( (env_name in ENVIRON) ? ENVIRON[env_name] : var_default )
}

function sub_opt() {
	if (!$0) {
		i++
		$0 = ARGV[i]
	}
	opt = $0
	$0 = ""
	return opt
}

function get_options() {
        for (i=1;i<ARGC;i++) {
                $0 = ARGV[i]
                if (gsub(/^-/,"")) {
                        #if (gsub(/j/,"")) JSON++
                        if (gsub(/d/,"")) ZELTA_DEPTH = sub_opt()
                        if (gsub(/n/,"")) DRY_RUN++
                        if (gsub(/v/,"")) WRITTEN=",written"
                        if (gsub(/w/,"")) WRITTEN=",written"
                        if (gsub(/z/,"")) ZELTA_PIPE++
                        if (/./) {
                                usage("unkown options: " $0)
                        }
                } else if (target) {
                        usage("too many options: " $0)
                } else if (source) target = $0
                else source = $0
        }
}

function get_endpoint_info(endpoint) {
	ssh_user[endpoint] = LOCAL_USER
	ssh_host[endpoint] = LOCAL_HOST
	if (split(endpoint, vol_arr, ":") == 2) {
		ssh_command[endpoint] = "ssh -n " vol_arr[1] " "
		volume[endpoint] = vol_arr[2];
		if (split(vol_arr[1], user_host, "@") == 2) {
			ssh_user[endpoint] = user_host[1]
			ssh_host[endpoint] = user_host[2]
		} else ssh_host[endpoint] = vol_arr[1]

	} else volume[endpoint] = vol_arr[1]
	zfs[endpoint] = ssh_command[endpoint] "zfs "
	gsub(/_/, "-", endpoint)
	gsub(/[^A-Za-z0-9.-]/,"_",endpoint)
	return endpoint
}

function error(string) {
	print "error: "string | "cat 1>&2"
}

function verbose(message) { if (VERBOSE) print message }

BEGIN {
	FS="\t"
	exit_code = 0
	ZELTA_PIPE = env("ZELTA_PIPE", 0)
	ZELTA_DEPTH = env("ZELTA_DEPTH", 0)
	ZMATCH_STREAM = env("ZMATCH_STREAM", 0)
	TIME_COMMAND = env("TIME_COMMAND", "/usr/bin/time -p") " "
	
	get_options()
	ZMATCH_PREFIX = "ZMATCH_STREAM=1 "
	ZMATCH_PREFIX = ZMATCH_PREFIX (ZELTA_DEPTH ? "ZELTA_DEPTH="ZELTA_DEPTH" " : "")
	ZMATCH_PREFIX = ZMATCH_PREFIX (ZELTA_PIPE ? "ZELTA_PIPE="ZELTA_PIPE" " : "")
	ZMATCH_COMMAND = ZMATCH_PREFIX "zelta reconcile"
	ZELTA_DEPTH = ZELTA_DEPTH ? " -d"ZELTA_DEPTH : ""

	ZFS_LIST_FLAGS = "list -Hproname,guid"WRITTEN" -tall -Screatetxg" ZELTA_DEPTH " "
	ALL_OUT =" 2>&1"


	if (!ZELTA_PIPE) { VERBOSE = 1 }

	OFS="\t"

	hash_source = get_endpoint_info(source)
	hash_target = get_endpoint_info(target)
	zfs_list[source] = TIME_COMMAND zfs[source] ZFS_LIST_FLAGS "'"volume[source]"'"ALL_OUT
	zfs_list[target] = TIME_COMMAND zfs[target] ZFS_LIST_FLAGS "'"volume[target]"'"ALL_OUT

	if (DRY_RUN) {
		print "+ "zfs_list[source]
		print "+ "zfs_list[target]
		exit
	}
	print hash_source,volume[source] | ZMATCH_COMMAND
	print hash_target,volume[target] | ZMATCH_COMMAND
	print zfs_list[target] | ZMATCH_COMMAND
	while (zfs_list[source] | getline) print | ZMATCH_COMMAND
}
