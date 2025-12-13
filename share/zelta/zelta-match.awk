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

function validate_datasets() {
	if (Opt["USAGE"]) { usage() }
	if (!Source["DS"] && !Target["DS"]) { usage("no datasets defined") }
}

function add_written() {
	if (Opt["LIST_WRITTEN"] && Opt["PROPLIST"]) {
		if (Opt["PARSABLE"] && (Opt["PROPLIST"] !~ /(all|written|size)/))
			return ""
	}
	return Opt["LIST_WRITTEN"] ? ",written" : ""
}

#function check_parent(endpoint,		_ds, _p, _cmd_part, _cmd, _cmd_output) {
#	_ds = Opt[endpoint"_DS"]
#	if (!_ds) return ""
#	# If the dataset is a pool or immediately below it, no need to check for a parent
#	if (gsub(/\//, "/", _ds) <= 1) {
#		return 1
#	}
#	sub(/\/[^\/]*$/, "", _ds)
#	_p = 1
#	if (Opt[endpoint "_REMOTE"]) {
#		_cmd_part[_p++]		= Opt["REMOTE_DEFAULT"] " " Opt[endpoint "_REMOTE"]
#	}
#	_cmd_part[_p++]			= "zfs"
#	_cmd_part[_p++]		   = "list -Ho name"
#	_cmd_part[_p++]		   = rq(Opt[endpoint "_REMOTE"], _ds)
#	_cmd_part[_p]		     = CAPTURE_OUTPUT
#	_cmd = join_arr(_cmd_part, _p)
#	_cmd | getline _cmd_output
#	close(_cmd)
#	if (_cmd_output == _ds) return 1
#	else return 0
#}

## Row parsing
##############

function depth_too_high() {
	return (Opt["DEPTH"] && (split(rel_name, depth_arr, "/") > Opt["DEPTH"]))
}

function process_dataset(ep,	_ds_suffix, _id) {
	_ds_suffix				= (ep["DS"] == $1) ? "" : substr($1, ep["ds_name_length"])
	if (depth_too_high()) return 0
	_id					= (_ds_suffix SUBSEP rel_name)
	Row["name"]				= $1
	Row["written"]				= $3
	if (!rel_name_list[rel_name]++) {
		rel_name_order[++rel_name_num]	= rel_name
	}
	if (!num_snaps[endpoint_id]) {
		num_snaps[endpoint_id]		= 0
	}
}

function process_savepoint(endpoint) {
	savepoint_rel_name				= substr($1, ds_name_length[endpoint])
	savepoint_id					= (endpoint SUBSEP savepoint_rel_name)
	guid						= $2
	guid_to_name[endpoint,guid]			= savepoint_rel_name
	name_to_guid[savepoint_id]			= guid
	written[savepoint_id]				= $3
	match(savepoint_rel_name,/[@#]/)
	rel_name					= substr(savepoint_rel_name, 1, RSTART - 1)
	savepoint					= substr(savepoint_rel_name, RSTART)
	dataset_id					= (endpoint SUBSEP rel_name)
	if (!num_snaps[dataset_id]++) {
		last[dataset_id]			= savepoint
		LastGUID[dataset_id]			= guid
	}
	first[dataset_id]	= savepoint
	first_guid[dataset_id]	= guid
}

function should_process_row(ep) {
}

function object_type(symbol) {
	if (symbol == "")	return IS_DATASET
	else if (symbol == "@")	return IS_SNAPSHOT
	else if (symbol == "#")	return IS_BOOKMARK
	else report(LOG_WARNING, "unexpected row: " symbol)
}

function process_row(ep,		_name, _guid, _written, _name_suffix, _ds_suffix, _savepoint,
		     			_type, _id, _ds_id, _ds_snap, _row_id) {
	# Read the row data
	_name			= $1
	_guid			= $2
	_written		= $3

	# Get the relative dataset suffix and then split to dataset and snapshot/bookmark name
	_name_suffix		= substr(_name, ep["ds_length"])
	match(_name_suffix,/[@#]/)
	if (RSTART) {
		_ds_suffix		= substr(_name_suffix, 1, RSTART - 1)
		_savepoint		= substr(_name_suffix, RSTART)
		_type			= substr(_savepoint, 1, 1)
	} else 	_ds_suffix		= _name_suffix

	_id			= ep["ID"]
	_ds_id			= _id SUBSEP _ds_suffix				# Unique dataset
	_ds_snap		= _ds_suffix SUBSEP _savepoint			# Unique to endpoint
	_row_id			= _id SUBSEP _ds_suffix SUBSEP _savepoint	# Unique
	
	Row[_row_id, "guid"] 	= _guid
	Row[_row_id, "written"]	= _written
	Row[_row_id, "name"]	= _name
	Row[_row_id, "type"]	= object_type(_type)
	Guid[_id, _guid]	= _ds_snap

	if (Row[_row_id, "type"] == "dataset") {
		ep["num_datasets"]++
		Dataset[_ds_id, "name"]	= _name
		Dataset[_id, _ds_suffix, "guid"]	= _guid
		Dataset[_id, _ds_suffix, "written"]	= _written
		Guid[_id, _guid]			= _ds_suffix
		Global["written"]	+= $3
	} else {
		_num_items = ++Dataset[_id, _ds_suffix, "num_savepoints"]
		DSSnap[_ds_id, _num_items] = _savepoint
		Dataset[_ds_id, "snap_written"] += _written
	}
}

function load_zfs_list_row(ep) {
	IGNORE_ZFS_LIST_OUTPUT="(sys|user)[ \t]+[0-9]|/dataset does not exist/"
	if ($0 ~ IGNORE_ZFS_LIST_OUTPUT) return
	if (/^real[ \t]+[0-9]/) {
		split($0, time_arr, /[ \t]+/)
		ep["list_time"] += time_arr[2]
	}
	else if ($2 ~ /^[0-9]+$/) {
		process_row()
	} else {
		report(LOG_WARNING, "stream output unexpected: "$0)
		exit_code = 1
	}
}

## Command building functions
#############################

function wrap_time_cmd(cmd, _cmd_part, _p) {
	cmd_part[p++]	= Opt["SH_COMMAND_PREFIX"]
	cmd_part[p++]	= Opt["TIME_COMMAND"]
	cmd_part[p++]	= cmd
	cmd_part[p++]	= Opt["SH_COMMAND_SUFFIX"]
	cmd		= arr_join(_cmd_part)
	return cmd
}
	
function zfs_list_cmd(endpoint,		_ep, _ds, _remote, _cmd) {
	if (!endpoint["DS"]) return
	_ep			= endpoint["ID"]
	_ds			= endpoint["DS"]
	_remote			= endpoint["REMOTE"]
	_cmd_arr["props"]	= "name,guid" add_written()
	_cmd_arr["ds"]		= rq(_remote, _ds)
	_cmd			= build_command("LIST", _cmd_arr, endpoint)
	if (Opt["DRYRUN"]) _cmd	= report(LOG_NOTICE, "+ " _cmd)
	if (Opt["TIME"]) _cmd	= wrap_time_cmd(_cmd)
	_cmd			= str_add(_cmd, CAPTURE_OUTPUT)
	return _cmd
}

function pipe_zfs_list_source(		_match_cmd, _src_list_cmd) {
	_match_cmd	= "ZELTA_MATCH_PIPE=yes zelta ipc-run match"
	_src_list_cmd	= zfs_list_cmd(Source)
	if (Opt["DRYRUN"]) {
		zfs_list_cmd(Target)
		stop()
	}
	report(LOG_DEBUG, "`"_match_cmd"`")
	report(LOG_INFO, "listing source: " Source["ID"])
	report(LOG_DEBUG, "`" _src_list_cmd "`")

	# The blank line piped below allows the target awk stream to run its 
	# BEGIN block without waiting for first line of 'zfs list' output.
	print "" | _match_cmd
	while (_src_list_cmd | getline) print | _match_cmd
	close(_src_list_cmd)
	close(_match_cmd)
}

function run_zfs_list_target(		_src_list_cmd) {
	if ((Source["ID"] == Target["ID"])) {
		report(LOG_WARNING, "identical source and target; skipping 'zfs list' for target")
		return
	}
	# Load target snapshots
	report(LOG_INFO, "listing target: " Target["ID"])
	_tgt_list_cmd	= zfs_list_cmd(Target)
	while  (_tgt_list_cmd | getline) 
		load_zfs_list_row(Target)
	close(_tgt_list_cmd)
}

BEGIN {
	IS_DATASET		= 0
	IS_SNAPSHOT		= 1
	IS_BOOKMARK		= 2
	FS			= "\t"
	OFS			= "\t"
	load_endpoint(Operands[1], Source)
	load_endpoint(Operands[2], Target)
	validate_datasets()
	if (Opt["MATCH_PIPE"]) {
		Target["match_bookmarks"]	= 1
		Target["ds_length"]		= length(Target["DS"]) + 1
		Source["ds_length"]		= length(Source["DS"]) + 1
		Source["list_time"] 		= 0
		Target["list_name"] 		= 0
		run_zfs_list_target()
	}
	else {
		pipe_zfs_list_source()
		exit
	}
}

{
	load_zfs_list_row(Source)
}

END {
	if (Opt["MATCH_PIPE"]) {
		print "do end stuff"
	}
}
