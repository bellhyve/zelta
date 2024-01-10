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
# ENVIRONMENT VARIABLES
#
# ZELTA_PIPE: When set to 1, we provide full snapshot names and simplify the output as
# follows:
#   - No output is provided for an up-to-date match.
#   - A single snapshot indicates the volume is missing on the target.
#   - A tab separated pair of snapshots indicates the out-of-date match and the latest.
#
# ZELTA_DEPTH: Adds "-d $ZELTA_DEPTH" to zfs list commands. Useful for limiting
# replication depth in zpull.

function usage(message) {
	if (message) error(message)
	if (! ZELTA_PIPE) print "usage: zelta match [-zv] [-d #] [user@][host:]source/dataset [user@][host:]target/dataset"
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
                        if (gsub(/z/,"")) ZELTA_PIPE++
                        if (gsub(/d/,"")) ZELTA_DEPTH = sub_opt()
                        if (/./) {
                                usage("unkown options: " $0)
                        }
                } else if (target) {
                        usage("too many options: " $0)
                } else if (source) target = $0
                else source = $0
        }
}

function make_ord() { for(n=0;n<256;n++) ord[sprintf("%c",n)] = n }

function hash(text) {
	text = text ? text : $0
	_prime = 104729;
	_modulo = 1099511627775;
	_ax = 0;
	split(text, _chars, "");
	for (_i=1; _i <= length(text); _i++) {
		_ax = (_ax * _prime + ord[_chars[_i]]) % _modulo;
	};
	return sprintf("%010x", _ax)
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
	return hash(endpoint)
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
	TIME_COMMAND = env("TIME_COMMAND", "/usr/bin/time") " "
	
	get_options()
	ZMATCH_PREFIX = "ZMATCH_STREAM=1 "
	ZMATCH_PREFIX = ZMATCH_PREFIX (ZELTA_DEPTH ? "ZELTA_DEPTH="ZELTA_DEPTH" " : "")
	ZMATCH_PREFIX = ZMATCH_PREFIX (ZELTA_PIPE ? "ZELTA_PIPE="ZELTA_PIPE" " : "")
	ZMATCH_COMMAND = ZMATCH_PREFIX "zelta reconcile"
	ZELTA_DEPTH = ZELTA_DEPTH ? " -d"ZELTA_DEPTH : ""


	#ZFS_LIST_FLAGS = "-Hproname,guid,written -Htsnap -Screation" ZELTA_DEPTH
	ZFS_LIST_FLAGS = "list -Hproname,guid -tsnap -Screatetxg" ZELTA_DEPTH " "
	STDOUT=" 2>&1"


	if (!ZELTA_PIPE) { VERBOSE = 1 }

	OFS="\t"
	make_ord()

	hash_source = get_endpoint_info(source)
	hash_target = get_endpoint_info(target)
	zfs_list[source] = TIME_COMMAND zfs[source] ZFS_LIST_FLAGS "'"volume[source]"'"STDOUT
	zfs_list[target] = TIME_COMMAND zfs[target] ZFS_LIST_FLAGS "'"volume[target]"'"STDOUT
	print hash_source,volume[source] | ZMATCH_COMMAND
	print hash_target,volume[target] | ZMATCH_COMMAND
	print zfs_list[target] | ZMATCH_COMMAND
	while (zfs_list[source] | getline) print | ZMATCH_COMMAND
}
