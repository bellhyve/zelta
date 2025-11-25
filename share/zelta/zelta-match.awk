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

function pass_flags(flag) {
	PASS_FLAGS = PASS_FLAGS ? (PASS_FLAGS OFS flag) : flag
}

function load_options(	i, o) {
	for (o in ENVIRON) {
		if (sub(/^ZELTA_/,"",o)) {
			Opt[o] = ENVIRON["ZELTA_"o]
		}
	}
	source_defined = (Opt["SRC_ID"] && Opt["SRC_DS"])
	target_defined = (Opt["TGT_ID"] && Opt["TGT_DS"])
	if ((!source_defined) && (!target_defined)) usage("no datasets defined")
		
	split(Opt["ARGS"],args,"\t")
	for (i in args) {
		$0 = args[i]
		if (sub(/^o /,""))		PROPERTIES = $0
		else if (sub(/^d /,""))		ZELTA_DEPTH = $0
		else if (/^dry-?run$/)		dryrun++
		else if (/^n$/)			dryrun++
		else if (/^h$/)			usage()
		else if (/^help$/)		usage()
		else if (/^no-?written$/)	WRITTEN = 0
		else if (/^no-?target$/)	target_defined = ""
		else if (/^H$/)			pass_flags("H")
		else if (/^p$/)			pass_flags("p")
		else if (/^time$/)		pass_flags("time")
		#else if (sub(/^j/,""))		pass_flags("j")
		else usage("unkown option: " $0)
	}
	# Skip "written" in scripting mode (-H) if no written summary or properties will be printed.
	if (WRITTEN && PROPERTIES && (PASS_FLAGS ~ /[H]/) && (PROPERTIES !~ /(all|written|size)/)) {
		WRITTEN = 0
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
	cmd_part[p++]			= Opt["SH_COMMAND_PREFIX"]
	cmd_part[p++]			= Opt["TIME_COMMAND"]
	if (Opt[endpoint "_PREFIX"]) {
		cmd_part[p++]		= Opt["REMOTE_DEFAULT"] " " Opt[endpoint "_PREFIX"]
	}
	cmd_part[p++]			= "zfs"
	cmd_part[p++]			= "list -Hprt all -Screatetxg"
	cmd_part[p++]			= "-o name,guid" (WRITTEN ? ",written" : "")
	if (DEPTH) cmd_part[p++]	= "-d " DEPTH
	cmd_part[p++]			= "'"Opt[endpoint"_DS"]"'"
	cmd_part[p++]			= Opt["SH_COMMAND_SUFFIX"]
	cmd_part[p]			= ALL_OUT
	cmd = join_arr(cmd_part, p)
	if (dryrun) report(LOG_NOTICE, "+ " cmd)
	return cmd
}

function check_parent(endpoint,		p, cmd_part, cmd) {
	ds = Opt[endpoint"_DS"]
	if (!ds) return ""
	# If the dataset is a pool or immediately below it, no need to check for a parent
	if (gsub(/\//, "/", ds) <= 1) {
		return 1
	}
	sub(/\/[^\/]*$/, "", ds)
	p = 1
	#cmd_part[p++]			= Opt["SH_COMMAND_PREFIX"]
	#cmd_part[p++]                   = Opt[endpoint"_ZFS"]
	if (Opt[endpoint "_PREFIX"]) {
		cmd_part[p++]		= Opt["REMOTE_DEFAULT"] " " Opt[endpoint "_PREFIX"]
	}
	cmd_part[p++]			= "zfs"
	cmd_part[p++]                   = "list -Ho name"
	cmd_part[p++]                   = "'"ds"'"
	#cmd_part[p++]			= Opt["SH_COMMAND_SUFFIX"]
	cmd_part[p]                     = ALL_OUT
	cmd = join_arr(cmd_part, p)
	cmd | getline cmd_output
	close(cmd)
	if (cmd_output==ds) return 1
	else return 0
}

BEGIN {
	# Constants
	FS				= "\t"
	OFS				= "\t"
	ALL_OUT				= "2>&1"

	# Defaults
	DEPTH				= 0
	WRITTEN				= 1

	load_options()
	MATCH_COMMAND				= "zelta ipc-run match-pipe"
	if (source_defined) ZFS_LIST_SRC	= zfs_list("SRC")
	if (target_defined) ZFS_LIST_TGT	= zfs_list("TGT")

	if (dryrun) stop()

	# MATCH_COMMAND = "cat" # Test stream

	# Stream to "zelta-match-pipe.awk"
	report(LOG_INFO, "comparing datasets")
	report(LOG_DEBUG, "`"MATCH_COMMAND"`")
	if (PASS_FLAGS) print "PASS_FLAGS:", PASS_FLAGS			| MATCH_COMMAND
	if (PROPERTIES) print "PROPERTIES:", PROPERTIES			| MATCH_COMMAND
	if (DEPTH) print "DEPTH:", DEPTH				| MATCH_COMMAND
	if (target_defined) {
		if (check_parent("TGT")) {
			print "ZFS_LIST_TGT:", ZFS_LIST_TGT 		| MATCH_COMMAND
		} else print "TGT_PARENT:", "no"			| MATCH_COMMAND
	}
	if (source_defined) {
		if (check_parent("SRC")) {
			report(LOG_INFO, "listing source")
			report(LOG_DEBUG, "`"ZFS_LIST_SRC"`")
			print "ZFS_LIST_STREAM:", Opt["SRC_ID"]		| MATCH_COMMAND
			while (ZFS_LIST_SRC | getline) print		| MATCH_COMMAND
			close(ZFS_LIST_SRC)
		} else print "SRC_PARENT:", no				| MATCH_COMMAND
	}
	print "ZFS_LIST_STREAM_END"					| MATCH_COMMAND
	close(MATCH_COMMAND)
}
