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

function env(env_name, var_default) {
	return ( (env_name in ENVIRON) ? ENVIRON[env_name] : var_default )
}

function pass_flags(flag) {
	PASS_FLAGS = PASS_FLAGS flag
}

function error(string) {
	print "error: "string > "/dev/stderr"
}

function load_options() {
	for (o in ENVIRON) {
		if (sub(/^ZELTA_/,"",o)) {
			option[o] = ENVIRON["ZELTA_"o]
		}
	}
	split(option["ARGS"],args,"\t")
	for (i in args) {
		$0 = args[i]
		if (sub(/^o /,""))		PROPERTIES = $0
		else if (sub(/^d /,""))		ZELTA_DEPTH = $0
		else if (/^dry-?run$/)		DRY_RUN++
		else if (/^n$/)			DRY_RUN++
		else if (/^h$/)			usage()
		else if (/^help$/)		usage()
		else if (/^no-?written$/)	WRITTEN = 0
		else if (/^H$/)			pass_flags("H")
		else if (/^p$/)			pass_flags("p")
		else if (/^q$/)			pass_flags("q")
		#else if (sub(/^j/,""))		pass_flags("j")
		#else if (sub(/^v/,""))		pass_flags("v")
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

function zfs_list(zfs_cmd, ds,		p, cmd, cmd_part) {
	if (!ds) return ""
	p = 1
	cmd_part[p++]			= option["SH_COMMAND_PREFIX"]
	cmd_part[p++]			= option["TIME_COMMAND"]
	cmd_part[p++]			= zfs_cmd
	cmd_part[p++]			= "list -Hprt all -Screatetxg"
	cmd_part[p++]			= "-o name,guid" (WRITTEN ? ",written" : "")
	if (DEPTH) cmd_part[p++]	= "-d " DEPTH
	cmd_part[p++]			= "'"ds"'"
	cmd_part[p++]			= option["SH_COMMAND_SUFFIX"]
	cmd_part[p]			= ALL_OUT
	cmd = join_arr(cmd_part, p)
	return cmd
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
	MATCH_COMMAND			= ENVIRON["AWK"] " -f " option["SHARE"] "/zelta-match-pipe.awk"
	ZFS_LIST_SRC			= zfs_list(option["SRC_ZFS"], option["SRC_DS"])
	ZFS_LIST_TGT			= zfs_list(option["TGT_ZFS"], option["TGT_DS"])

	if (DRY_RUN) {
		print "+ " ZFS_LIST_SRC
		if (ZFS_LIST_TGT) print "+ " ZFS_LIST_TGT
		exit 1
	}

	# Stream to "zelta-match-pipe.awk"
	if (PASS_FLAGS) print "PASS_FLAGS: " PASS_FLAGS		| MATCH_COMMAND
	if (PROPERTIES) print "PROPERTIES: " PROPERTIES		| MATCH_COMMAND
	if (DEPTH) print "DEPTH: " DEPTH			| MATCH_COMMAND
	print "ZFS_LIST_TGT: " ZFS_LIST_TGT			| MATCH_COMMAND
	print "ZFS_LIST_STREAM: " option["SRC_ID"]		| MATCH_COMMAND
	while (ZFS_LIST_SRC | getline) print			| MATCH_COMMAND
	close(ZFS_LIST_SRC)
	print "ZFS_LIST_STREAM_END"				| MATCH_COMMAND
	close(MATCH_COMMAND)
}
