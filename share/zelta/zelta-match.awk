#!/usr/bin/awk -f
#
# zmatch - compares a source and target datasets for dataset similarity
#
# usage: zmatch [user@][host:]source/dataset [user@][host:]target/dataset
#
# Reports the most recent matching snapshot and the latest snapshot of a dataset and
# its children, which are useful for various zfs operations
#
# In interactive mode, child snapshot names are provided relative to the target
# dataset. For example, when zmatch is called with tank/dataset, tank/dataset/child's
# snapshots will be reported as"/child@snapshot-name".
#
# Specifically:
#   - The latest matching snapshot and child snapshots
#   - Missing child dataset on the destination
#   - Matching snapshot names with different GUIDs
#   - Newer target snapshots not on the source
#
# ZFS LIST SWITCHES
#
# -d#	limit recursion depth to #.
# -H    hide header
# -n	show the zfs list commands instead of running them
# -o    "all" or a list of properties to show
# -p    single tab delimited output
# -v	verbose, tell the user if output is being suppressed.

function usage(message) {
	usage_command = "zelta usage match"
	while (usage_command |getline) print
	close(usage_command)
	if (message) error(message)
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
			if (sub(/^-no-written/,"")) WRITTEN = 0
                        if (gsub(/n/,"")) DRY_RUN++
                        if (gsub(/H/,"")) PASS_FLAGS = PASS_FLAGS "H" 
                        if (gsub(/p/,"")) PASS_FLAGS = PASS_FLAGS "p"
                        if (gsub(/q/,"")) PASS_FLAGS = PASS_FLAGS "q"
                        if (gsub(/W/,"")) WRITTEN = 0
                        #if (gsub(/j/,"")) PASS_FLAGS = PASS_FLAGS "j" # Future
                        #if (gsub(/v/,"")) PASS_FLAGS = PASS_FLAGS "v" # Future
			if (gsub(/o/,"")) PROPERTIES = sub_opt()
                        if (gsub(/d/,"")) ZELTA_DEPTH = sub_opt()
                        if (/./) usage("unkown options: " $0)
                } else if (target) {
                        usage("too many options: " $0)
                } else if (source) target = $0
                else source = $0
        }
	if (!source) usage()
}

function get_endpoint_info(endpoint) {
	FS = "\t"
	endpoint_command = "zelta endpoint " endpoint
	endpoint_command | getline
	#endpoint_id[endpoint] = $1
	zfs[endpoint] = $2
	#user[endpoint] = $3
	#host[endpoint] = $4
	ds[endpoint] = $5
	#snapshot[endpoint] = $6
	close(endpoint_command)
	return $1
}

function error(string) {
	print "error: "string > "/dev/stderr"
}

BEGIN {
	FS="\t"
	exit_code = 0
	WRITTEN = 1
	REMOTE_COMMAND_NOPIPE = env("REMOTE_COMMAND_NOPIPE", "ssh -n") " "
	TIME_COMMAND = env("TIME_COMMAND", "/usr/bin/time -p") " "
	ZELTA_MATCH_COMMAND = "zelta match-pipe"
	ZFS_LIST_PROPERTIES = env("ZFS_LIST_PROPERTIES", "name,guid")
	ZELTA_DEPTH = env("ZELTA_DEPTH", 0)
	ZFS_LIST_PREFIX = "list -Hprt all -Screatetxg -o "
	ZFS_LIST_PREFIX_WRITECHECK = "list -Hprt filesystem,volume -o "
	
	get_options()
	if (PASS_FLAGS) PASS_FLAGS = "ZELTA_MATCH_FLAGS='"PASS_FLAGS"' "
	# "zfs list -o written" can slow things down, skip if possible
	if (PROPERTIES && split(PROPERTIES, PROPLIST, ",")) {
		for (p in PROPLIST) {
			$0 = PROPLIST[p]
			if ((/^x/ && !/xfersn/) || /wri/ || /all/) WRITTEN++
		}
	}
	ZFS_LIST_PROPERTIES_DEFAULT = "name,guid" (WRITTEN?",written":"")
	ZFS_LIST_PROPERTIES = env("ZFS_LIST_PROPERTIES", ZFS_LIST_PROPERTIES_DEFAULT)

	MATCH_PREFIX = (PROPERTIES?"ZELTA_MATCH_PROPERTIES='"PROPERTIES"' ":"") PASS_FLAGS
	MATCH_PREFIX = MATCH_PREFIX (ZELTA_DEPTH ? "ZELTA_DEPTH="ZELTA_DEPTH" " : "")
	MATCH_COMMAND = MATCH_PREFIX "zelta match-pipe"
	ZFS_LIST_DEPTH = ZELTA_DEPTH ? " -d"ZELTA_DEPTH : ""

	if (target) ZFS_LIST_FLAGS = ZFS_LIST_PREFIX ZFS_LIST_PROPERTIES ZFS_LIST_DEPTH " "
	else ZFS_LIST_FLAGS = ZFS_LIST_PREFIX_WRITECHECK ZFS_LIST_PROPERTIES ZFS_LIST_DEPTH " "

	ALL_OUT =" 2>&1"
	OFS="\t"

	hash_source = get_endpoint_info(source)
	zfs[source] = ($2 ? REMOTE_COMMAND_NOPIPE $2 " " : "") "zfs "
	if (target) {
		hash_target = get_endpoint_info(target)
		zfs[target] = ($2 ? REMOTE_COMMAND_NOPIPE $2 " " : "") "zfs "
	}
	

	zfs_list[source] = zfs[source] ZFS_LIST_FLAGS "'"ds[source]"'"
	zfs_list[target] = zfs[target] ZFS_LIST_FLAGS "'"ds[target]"'"

	if (DRY_RUN) {
		print "+ "zfs_list[source]
		print "+ "zfs_list[target]
		exit 1
	}

	zfs_list[source] = TIME_COMMAND zfs_list[source] ALL_OUT
	zfs_list[target] = TIME_COMMAND zfs_list[target] ALL_OUT

	print hash_source,ds[source] | MATCH_COMMAND
	print hash_target,ds[target] | MATCH_COMMAND
	# Single volume "matches" are deprecated (use "zfs list" instead)
	print (target ? zfs_list[target] : "") | MATCH_COMMAND
	while (zfs_list[source] | getline zfs_list_output) print zfs_list_output | MATCH_COMMAND
	close(zfs_list[source])
	close(MATCH_COMMAND)
}
