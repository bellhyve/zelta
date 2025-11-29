#!/usr/bin/awk -f

#
# zelta-match.awk
#
# Called via "zelta match", "zelta list", or "zmatch", describes the
# relationship between two trees of ZFS datasets. This script processes
# arguments and runs a "zfs list" command on the source endpoint, then passes
# the output and instructions to zfs-match-pipe.awk to compare the lists
# (which allows for parallel processing with only AWK calls).

function usage(message) {
	STDERR = "/dev/stderr"
	usage_table = "\t%-13s%s\n"
	print (message ? message "\n" : "") "usage:"						> STDERR
	print "\tmatch [-Hp] [-d max] [-o field[,...]] source-endpoint target-endpoint\n"	> STDERR
	print "The following fields are supported:\n"						> STDERR
	printf usage_table"\n",	"FIELD",	"VALUES"					> STDERR
	printf usage_table,	"rel_name",	"'' for top or relative ds name"		> STDERR
	printf usage_table,	"sync_code",	"octal bits describing ds sync state"		> STDERR
	printf usage_table,	"match",	"matching snapshot (or source bookmark)"	> STDERR
	printf usage_table,	"xfer_size",	"sum of unreplicated source snapshots"		> STDERR
	printf usage_table,	"xfer_num",	"count of unreplicated source snapshots"	> STDERR
	printf usage_table,	"src_name",	"full source ds name"				> STDERR
	printf usage_table,	"src_first",	"first available source snapshot"		> STDERR
	printf usage_table,	"src_next",	"source snapshot following 'match'"		> STDERR
	printf usage_table,	"src_last",	"most recent source snapshot"			> STDERR
	printf usage_table,	"src_written",	"data written after last source snapshot"	> STDERR
	printf usage_table,	"src_snaps",	"total source snapshots and bookmarks"		> STDERR
	printf usage_table,	"tgt_name",	"full target ds name"				> STDERR
	printf usage_table,	"tgt_first",	"first available target snapshot"		> STDERR
	printf usage_table,	"tgt_next",	"target snapshot following 'match'"		> STDERR
	printf usage_table,	"tgt_last",	"most recent target snapshot"			> STDERR
	printf usage_table,	"tgt_written",	"data written after last target snapshot"	> STDERR
	printf usage_table,	"tgt_snaps",	"total target snapshots and bookmarks"		> STDERR
	printf usage_table"\n",	"info",		"description of the ds sync state"		> STDERR
	print "Sizes are specified in bytes with standard units such as K, M, G, etc.\n"	> STDERR
	print "For further help on a command or topic, run: zelta help [<topic>]"		> STDERR
	exit 1
}

function validate_options(	i, o) {
	if (Opt["USAGE"]) usage()
	source_defined = (Opt["SRC_ID"] && Opt["SRC_DS"])
	target_defined = (Opt["TGT_ID"] && Opt["TGT_DS"])
	if ((!source_defined) && (!target_defined)) usage("no datasets defined")
	# Skip "written" in scripting mode (-H) if no written summary or properties will be printed.
	if (Opt["LIST_WRITTEN"] && Opt["PROPLIST"] && Opt["PARSABLE"] && (Opt["PROPLIST"] !~ /(all|written|size)/)) {
		Opt["LIST_WRITTEN"] = 0
	}
}

function join_arr(arr, len,		i, str) {
	for ( i=1; i<=len; i++ ) {
		if (! arr[i]) continue
		str = str sprintf("%s%s", arr[i], (i<len ? " " : ""))
	}
	return str
}

function zfs_list(endpoint,		p, cmd, cmd_part) {
	if (! Opt[endpoint"_DS"]) return ""
	p = 1
	if (Opt["TIME"]) {
		cmd_part[p++]			= Opt["SH_COMMAND_PREFIX"]
		cmd_part[p++]			= Opt["TIME_COMMAND"]
	}
	if (Opt[endpoint "_REMOTE"]) {
		cmd_part[p++]		= Opt["REMOTE_DEFAULT"] " " Opt[endpoint "_REMOTE"]
	}
	cmd_part[p++]			= "zfs"
	cmd_part[p++]			= "list -Hprt all -Screatetxg"
	cmd_part[p++]			= "-o name,guid" (Opt["LIST_WRITTEN"] ? ",written" : "")
	if (Opt["DEPTH"]) cmd_part[p++]	= "-d " Opt["DEPTH"]
	cmd_part[p++]			= "'"Opt[endpoint"_DS"]"'"
	if (Opt["TIME"]) cmd_part[p++]	= Opt["SH_COMMAND_SUFFIX"]
	cmd_part[p]			= CAPTURE_OUTPUT
	cmd = join_arr(cmd_part, p)
	if (Opt["DRYRUN"]) report(LOG_NOTICE, "+ " cmd)
	return cmd
}

function check_parent(endpoint,		_ds, _p, _cmd_part, _cmd, _cmd_output) {
	_ds = Opt[endpoint"_DS"]
	if (!_ds) return ""
	# If the dataset is a pool or immediately below it, no need to check for a parent
	if (gsub(/\//, "/", _ds) <= 1) {
		return 1
	}
	sub(/\/[^\/]*$/, "", _ds)
	_p = 1
	if (Opt[endpoint "_REMOTE"]) {
		_cmd_part[_p++]		= Opt["REMOTE_DEFAULT"] " " Opt[endpoint "_REMOTE"]
	}
	_cmd_part[_p++]			= "zfs"
	_cmd_part[_p++]                   = "list -Ho name"
	_cmd_part[_p++]                   = "'"_ds"'"
	_cmd_part[_p]                     = CAPTURE_OUTPUT
	_cmd = join_arr(_cmd_part, _p)
	_cmd | getline _cmd_output
	close(_cmd)
	if (_cmd_output == _ds) return 1
	else return 0
}

BEGIN {
	# Constants
	FS				= "\t"
	OFS				= "\t"

	validate_options()
	MatchCommand				= "zelta ipc-run match-pipe"
	if (source_defined) ZFS_LIST_SRC	= zfs_list("SRC")
	if (target_defined) ZFS_LIST_TGT	= zfs_list("TGT")

	if (Opt["DRYRUN"]) stop()

	# MatchCommand = "cat" # Test stream

	# Stream to "zelta-match-pipe.awk"
	report(LOG_INFO, "comparing datasets")
	report(LOG_DEBUG, "`"MatchCommand"`")
	if (target_defined) {
		if (check_parent("TGT")) {
			print "ZFS_LIST_TGT:", ZFS_LIST_TGT 		| MatchCommand
		} else print "TGT_PARENT:", "no"			| MatchCommand
	}
	if (source_defined) {
		if (check_parent("SRC")) {
			report(LOG_INFO, "listing source")
			report(LOG_DEBUG, "`"ZFS_LIST_SRC"`")
			print "ZFS_LIST_STREAM:", Opt["SRC_ID"]		| MatchCommand
			while (ZFS_LIST_SRC | getline) print		| MatchCommand
			close(ZFS_LIST_SRC)
		} else print "SRC_PARENT:", no				| MatchCommand
	}
	print "ZFS_LIST_STREAM_END"					| MatchCommand
	close(MatchCommand)
}
