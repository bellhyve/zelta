#!/usr/bin/awk -f
#
# zelta-match.awk
#
# Describes the relationship between two trees of ZFS datasets. Run a "zfs list"
# command on the source endpoint piping to itself for concurrency, run a second
# target endpoint zfs list via 'getline', and comapre the results.
#
# Global: Settings and global telemetry
# Source: The source endpoint
# Target: The target endpoint
# Row: 'zfs list' output
# Dataset: A list of datasets
# Snap: A list of snapshots and bookmarks for each dataset
# NumSnaps: The ordered reference for Snap for each Dataset


## Usage
########

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


## Command Building
###################

# Default to 'zfs list ... -o written', but implicitly avoid since it's slow
function add_written() {
	if (Opt["LIST_WRITTEN"] && Opt["PROPLIST"]) {
		if (Opt["PARSABLE"] && (Opt["PROPLIST"] !~ /(all|written|size)/))
			return ""
	}
	return Opt["LIST_WRITTEN"] ? ",written" : ""
}

# TO-DO: Add this feature to build_command()
function wrap_time_cmd(cmd, _cmd_part, _p) {
	cmd_part[p++]	= Opt["SH_COMMAND_PREFIX"]
	cmd_part[p++]	= Opt["TIME_COMMAND"]
	cmd_part[p++]	= cmd
	cmd_part[p++]	= Opt["SH_COMMAND_SUFFIX"]
	cmd		= arr_join(_cmd_part)
	return cmd
}

# Generate the 'zfs list' command using build_command()
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

#  Send the Source 'zfs list' to a second process for concurrency
#  (Our biggest bottleneck is waiting for the lists to complete and buffer)
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

# After the triggering the pipe phase, fire the Target 'zfs list' and parse the rows
function run_zfs_list_target(		_src_list_cmd) {
	if ((Source["ID"] == Target["ID"])) {
		report(LOG_WARNING, "identical source and target; skipping 'zfs list' for target")
		return
	}
	# Load target snapshots
	_tgt_list_cmd = zfs_list_cmd(Target)
	report(LOG_INFO, "listing target: " Target["ID"])
	report(LOG_DEBUG, "`" _tgt_list_cmd "`")
	_tgt_list_cmd = str_add(_tgt_list_cmd, CAPTURE_OUTPUT)
	while  (_tgt_list_cmd | getline) 
		load_zfs_list_row(Target)
	close(_tgt_list_cmd)
}


## Row parsing
##############

# Identify if the row refers to a dataset, snapshot, or bookmark
function object_type(symbol) {
	if (symbol == "")	return IS_DATASET
	else if (symbol == "@")	return IS_SNAPSHOT
	else if (symbol == "#")	return IS_BOOKMARK
	else {
		report(LOG_WARNING, "unexpected row: " symbol)
		return IS_UNKNOWN
	}
}

# Load each row into memory
function process_row(ep,		_name, _guid, _written, _name_suffix, _ds_suffix, _savepoint,
		     			_type, _ep_id, _ds_id, _ds_snap, _row_id) {
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

	_ep_id			= ep["ID"]
	_ds_id			= _ep_id S _ds_suffix S ""
	_row_id			= _ep_id S _ds_suffix S _savepoint
	_type			= object_type(_type)
	
	Row[_row_id, "exists"] 	= 1
	Row[_row_id, "guid"] 	= _guid
	Row[_row_id, "written"]	= _written
	Row[_row_id, "name"]	= _name
	Row[_row_id, "type"]	= _type
	
	# Snapshots will be used for match GUID over bookmarks
	if (!Guid[_ds_id, _guid] || (_type == IS_SNAPSHOT))
		Guid[_ds_id, _guid] = _row_id

	# Dataset
	if (_type == IS_DATASET) {
		# Ordering by '-S createtxg' gives us a reverse view of datasets;
		# this doesn't actually matter but it's a bit weird for debugging
		_num_ds				= ++ep["num_ds"]
		Dataset[_ep_id, _num_ds]	= _row_id
		Global["written"]		+= $3
	# Snapshot or bookmark
	} else if (_type != IS_UNKOWN) {
		_num_snaps			= ++NumSnaps[_ds_id]
		Snap[_ds_id, _num_snaps]	= _row_id
	}
}

# Check for exceptions or time(1) output, or process the row
function load_zfs_list_row(ep) {
	IGNORE_ZFS_LIST_OUTPUT="(sys|user)[ \t]+[0-9]|/dataset does not exist/"
	if ($0 ~ IGNORE_ZFS_LIST_OUTPUT) return
	if (/^real[ \t]+[0-9]/) {
		split($0, time_arr, /[ \t]+/)
		ep["list_time"] += time_arr[2]
	}
	else if ($2 ~ /^[0-9]+$/) {
		process_row(ep)
	} else {
		report(LOG_WARNING, "stream output unexpected: "$0)
		exit_code = 1
	}
}


## Identifying Replica Relationships
####################################

function compare_datasets(src_ds_id,		_row_arr) {
	split(src_ds_id, _row_arr, S)
	_ds_suffix = _row_arr[2]
	_tgt_ds_id = Target["ID"] S _ds_suffix S ""
	if (Row[_tgt_ds_id, "exists"]) {
		DSPair[_ds_suffix, "status"] = PAIR_EXISTS
		return 1
	} else {
		DSPair[_ds_suffix, "status"] = PAIR_SRC_ONLY
		return 0
	}
}

function validate_match(src_row, tgt_row, ds_suffix, savepoint) {
	# Exclude if the target isn't a snapshot
	if (Row[tgt_row, "type"] != IS_SNAPSHOT)
		return
	if (!DSPair[ds_suffix, "num_matches"]++) {
		# TO-DO: Validate by filter
		DSPair[ds_suffix, "match"] = savepoint
		print savepoint
	}
}

function compare_snapshots(src_row,	_src_row_arr, _ds_suffix, _savepoint, _src_guid, _tgt_ds_id, _tgt_match) {
	# Identify a match candidate by GUID
	split(src_row, _src_row_arr, S)
	_ds_suffix	= _src_row_arr[2]
	_savepoint	= _src_row_arr[3]
	_src_guid	= Row[src_row, "guid"]
	_tgt_ds_id	= Target["ID"] S _ds_suffix S ""
	_tgt_match	= Guid[_tgt_ds_id, _src_guid]
	if (_tgt_match)
		validate_match(src_row, _tgt_match, _ds_suffix, _savepoint)
	else {
		if (!DSPair[_ds_suffix, "match"])
			DSPair[_ds_suffix, "next"] = _savepoint
	}
}

function process_datasets(		_src_id, _tgt_id, _num_src_ds, _num_tgt_ds, _d, _s) {
	_src_id		= Source["ID"]
	_tgt_id		= Target["ID"]
	_num_src_ds	= Source["num_ds"]
	_num_tgt_ds	= Target["num_ds"]
	for (_d = 1; _d <= _num_src_ds; _d++) {
		_src_ds_id = Dataset[_src_id, _d]
		if (compare_datasets(_src_ds_id)) {
			_num_snaps = NumSnaps[_src_ds_id]
			for (_s = 1; _s <= _num_snaps; _s++)
				compare_snapshots(Snap[_src_ds_id,_s])
		}
	}
		
}


## Main Workflow Rules
######################

# Constant setup, validation, and fire concurrent 'zfs list' commands
BEGIN {
	# Row types
	IS_UNKNOWN	= 0
	IS_DATASET	= 1
	IS_SNAPSHOT	= 2
	IS_BOOKMARK	= 3

	# DSPair types
	PAIR_UNKNOWN	= 0
	PAIR_EXISTS	= 1
	PAIR_SRC_ONLY	= 2
	PAIR_TGT_ONLY	= 3

	S		= SUBSEP
	FS		= "\t"
	OFS		= "\t"

	load_endpoint(Operands[1], Source)
	load_endpoint(Operands[2], Target)
	if (Opt["USAGE"]) { usage() }
	if (!Source["DS"] && !Target["DS"]) { usage("no datasets defined") }

	if (Opt["MATCH_PIPE"]) {
		Target["match_bookmarks"]	= 1
		Target["ds_length"]		= length(Target["DS"]) + 1
		Source["ds_length"]		= length(Source["DS"]) + 1
		Source["list_time"] 		= 0
		Target["list_name"] 		= 0
		run_zfs_list_target()
		# Continues to process the incoming pipes 'pipe_zfs_list_source()'
	}
	else {
		pipe_zfs_list_source()
		exit
	}
}

# Process inbound pipe from pipe_zfs_list_source()
# The first piped 'zfs list' row could lock execution of the above, so ignore it.
NR > 1 {
	load_zfs_list_row(Source)
}

END {
	if (Opt["MATCH_PIPE"]) {
		process_datasets()
	}
} 
