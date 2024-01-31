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
# -d#	Limi depth to #.
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
	FS = "\t"
	endpoint_command = "zelta endpoint " endpoint
	endpoint_command | getline
	#endpoint_id[endpoint] = $1
	zfs[endpoint] = ($2?"ssh -n "$2" ":"") "zfs "
	gsub(/^ssh/,"ssh -n", zfs[endpoint])
	#user[endpoint] = $3
	#host[endpoint] = $4
	volume[endpoint] = $5
	#snapshot[endpoint] = $6
	close("zelta endpoint " endpoint)
	return $1
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
	if (target) {
		ZFS_LIST_FLAGS = "list -Hproname,guid"WRITTEN" -tall -Screatetxg" ZELTA_DEPTH " "
	} else ZFS_LIST_FLAGS = "list -Hproname,guid,written -tfilesystem,volume" ZELTA_DEPTH " "
	ALL_OUT =" 2>&1"


	if (!ZELTA_PIPE) { VERBOSE = 1 }

	OFS="\t"


	hash_source = get_endpoint_info(source)
	if (target) hash_target = get_endpoint_info(target)

	zfs_list[source] = TIME_COMMAND zfs[source] ZFS_LIST_FLAGS "'"volume[source]"'"ALL_OUT
	zfs_list[target] = TIME_COMMAND zfs[target] ZFS_LIST_FLAGS "'"volume[target]"'"ALL_OUT

	if (DRY_RUN) {
		print "+ "zfs_list[source]
		print "+ "zfs_list[target]
		exit
	}
	print hash_source,volume[source] | ZMATCH_COMMAND
	print hash_target,volume[target] | ZMATCH_COMMAND
	if (target) print zfs_list[target] | ZMATCH_COMMAND
	else print "" | ZMATCH_COMMAND
	while (zfs_list[source] | getline) print | ZMATCH_COMMAND
	close(zfs_list[source])
}
