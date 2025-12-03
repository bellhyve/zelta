#!/usr/bin/awk -f
#
# zelta-backup.awk, zelta (replicate|backup|sync|clone) - replicates remote or local trees
#   of zfs datasets
# 
# After using "zelta match" to identify out-of-date snapshots on the target, this script creates
# replication streams to synchronize the snapshots of a dataset and its children. This script is
# useful for backup, migration, and failover scenarios. It intentionally does not have a rollback
# feature, and instead uses a "rotate" feature to rename and clone the diverged replica.
#
# CONCEPTS
# endpoint or ep: "SRC" or "TGT"
# dataset or ds: A specific dataset
# tree: A dataset and its children
# ds_snap: A specific snapshot, such as a replication source
# relname: The dataset suffix/child element of the dataset tree (will be renamed 'ds_suffix')
#
# GLOBALS
# Opt: User settings (see the 'zelta' sh script and zelta-opts.tsv)
# NumDS: Number of datasets in the tree
# DSList: List of "relname" elements in replication order
# DSProps: Properties of each dataset, indexed by: ("ENDPOINT", relname, element)
# 	[zfsprops]:	ZFS properties from the property-source 'local' or 'none'
#	exists
#	earliest_snapshot
#	latest_snapshot
# RelProps: Derived properties comparing a dataset and its replica: (relname, element)
# 	match:		the common snapshot or bookmark between a pair
# 	source_start:	the incremental or intermediate source snapshot/bookmark
# 	source_end:	the source snapshot intended to be synced
# 	sync_action:	the proposed sync plan based on the current state and snapshots
# GlobalState: Properties about the global state or overrides
# Summary: Totals and other summary information
#
# FOR RELEASE NOTES:
# Dropped: summary message "replicationErrorCode"
# Changed "replicate" terminology to "sync" to avoid confusion with 'zfs send --replicate'

## Usage
########

zfs
# We follow zfs's standard of only showing short options when available
function usage(message) {
	STDERR = "/dev/stderr"
	if (message) print message							> STDERR
	print "usage:"									> STDERR
	if (Opt["VERB"] == "clone") { 
		print " clone [-d max] source-dataset target-dataset\n"			> STDERR
	} else {
		usage_prefix = Opt["VERB"] " "
		print "\t" usage_prefix "[-bcDeeFhhLMpuVw] [-iIjnpqRtTv] [-d max]"	> STDERR
		printf "\t%*s", length(usage_prefix), ""				> STDERR
		print "[initiator] source-endpoint target-endpoint\n"			> STDERR
	}
	
	exit 1
}

## Command builder
##################

# Loads zelta-cmds.tsv which format external 'zelta' and 'zfs' commmands
function load_build_commands(		_action) {
	_tsv = Opt["SHARE"]"/zelta-cmds.tsv"
	FS="\t"
	while (getline < _tsv) {
		if (/^$|^#/) continue
		_action= $1
		CommandRemote[_action]      = $2
		CommandLine[_action]     = str_add($3, $4)
		CommandVars[_action]    = $5
		CommandSuffix[_action]    = $6
	}
	close(_tsv)
}

# Constructs a remote command string
function remote_str(endpoint, type, 	_cmd) {
	type = type ? type : "DEFAULT"
	_cmd = Opt["REMOTE_" type]" "Opt[endpoint "_" "REMOTE"]
	return _cmd
}

# Constructs a command using an action and the passed array
# Special variables:
#   "endpoint": Expands a remote prefix if given
#   "command_prefix": Inserts before command name for an additional pipe or environment variable
function build_command(action, vars,		_remote_prefix, _cmd, _num_vars, _var_list, _val) {
	if (CommandRemote[action] && vars["endpoint"]) {
		_remote_prefix = remote_str(vars["endpoint"], CommandRemote[action])
	}
	_cmd = CommandLine[action]
	_num_vars = split(CommandVars[action], _var_list, " ")
	for (_v = 1; _v <= _num_vars; _v++) {
		_val = vars[_var_list[_v]]
		_cmd = str_add(_cmd, _val)
	}
	_cmd = str_add(_cmd, CommandSuffix[action])
	_cmd = str_add(_remote_prefix, _cmd)
	if (vars["command_prefix"]) _cmd = str_add(vars["command_prefix"], _cmd)
	return _cmd
}

## Loading and setting properties
#################################

function set_endpoint_property(endpoint, prop_key, prop_val,	_i, _rel_name) {
	for (_i in DSList) {
		_rel_name = DSList[_i]
		if (DSProps[endpoint, _rel_name, "exists"])
			DSProps[endpoint, _rel_name, prop_key] = prop_val
	}
}

function update_last_snapshot(endpoint, rel_name, snap_name) {
	DSProps[endpoint, rel_name, "latest_snapshot"] = snap_name
	if ((endpoint == "SRC") && !DSProps[endpoint, rel_name, "earliest_snapshot"])
		DSProps[endpoint, rel_name, "earliest_snapshot"] = snap_name
	else {
		RelProps[rel_name, "match"] = snap_name
	}
}

# Evaluate properties needed for snapshot decision and sync options
function check_snapshot_needed(endpoint, rel_name, prop_key, prop_val) {
	if (endpoint == "SRC") {
		if (DSProps[endpoint, rel_name, "written"]) {
			Summary["sourceWritten"] += prop_val
			RelProps[rel_name, "source_is_written"] += prop_val
			if (Opt["SNAP_MODE"] == "IS_NEEDED")
				GlobalState["snapshot_needed"]++
		}
	}
}


# Load zfs properties for an endpoint
function load_properties(ep,		_ds, _cmd_arr, _cmd, _idx, _seen) {
	_ds			= Opt[ep "_DS"]
	_cmd_arr["endpoint"]	= ep
	_cmd_arr["ds"]		= dq(_ds)
	if (Opt["DEPTH"]) _cmd_arr["flags"] = "-d" (Depth-1)
	_cmd = build_command("PROPS", _cmd_arr)
	report(LOG_INFO, "checking properties for " Opt[ep"_ID"])
	report(LOG_DEBUG, "`"_cmd"`")
	_cmd = _cmd CAPTURE_OUTPUT
	while (_cmd | getline) {
		if (NF == 3 && match($1, "^" _ds)) {
			_rel_name = substr($1, length(_ds) + 1)
			_idx = ep SUBSEP _rel_name
			_prop_key = $2
			_prop_val = ($3 == "off") ? "0" : $3
			DSProps[_idx, _prop_key] = _prop_val

			check_snapshot_needed(ep, _rel_name, _prop_key, _prop_val)
			if (!_seen[_idx]++) DSProps[_idx, "exists"]++
		}
		else if ($0 ~ COMMAND_ERRORS) {
			close(_zfs_get_command)
			report(LOG_ERROR, $0)
			stop(1, "invalid endpoint '"Opt[ep "_ID"]"'")
		}
		else if (/dataset does not exist/) {
			close(_zfs_get_command)
			return 0
		}
		else report(LOG_WARNING,"unexpected 'zfs get' output: " $0)
	}
	close(_cmd)
	return 1
}


## Load snapshot information from `zelta match`
###############################################
	
# Imports a 'zelta match' row into RelProps and DSProps
function parse_zelta_match_row(		_src_idx, _tgt_idx) {
	if (NF == 5) {
		# Indexes
		_relname				= $1
		_src_idx				= "SRC" SUBSEP _relname 
		_tgt_idx				= "TGT" SUBSEP _relname 

		# 'zelta match' columns
		DSList[++NumDS]				= _relname
		RelProps[_relname, "match"]		= $2
		DSProps[_src_idx, "earliest_snapshot"]	= $3
		DSProps[_src_idx, "latest_snapshot"]	= $4
		DSProps[_tgt_idx, "latest_snapshot"]	= $5
		# If there's an empty source dataset with no snapshots, we snaphot
		if (DSProps[_src_idx, "exists"] && !DSProps[_src_idx, "latest_snapshot"]) GlobalState["snapshot_needed"]++
	}
	else {
		if ($1 == "SOURCE_LIST_TIME:")		Summary["sourceListTime"] += $2
		else if ($1 == "TARGET_LIST_TIME:")	Summary["targetListTime"] += $2
		else report(LOG_WARNING, "unexpected `zelta match` output: "$0)
		return
	}
}

# Run 'zfs match' and pass to parser
function load_snapshot_deltas(_cmd_arr, _cmd) {
	FS = "\t"
	if (!GlobalState["target_exists"]) 
		_cmd_arr["command_prefix"]	= "ZELTA_TGT_ID=''"
	if (Opt["DEPTH"])
		_cmd_arr["flags"]		= "-d" Depth
	_cmd					= build_command("MATCH", _cmd_arr)
	report(LOG_INFO, "checking replica deltas")
	report(LOG_DEBUG, "`"_cmd"`")
	_cmd 					= _cmd CAPTURE_OUTPUT
	while (_cmd | getline) parse_zelta_match_row()
	close(_cmd)
}

## Compute derived data from properties and snapshots
#####################################################

# Provide complete path names for sync commands
function compute_snapshot_paths(rel_name, src_idx, tgt_idx,	_src_ds, _tgt_ds, _snap) {
	_src_ds		= Opt["SRC_DS"] rel_name
	_tgt_ds		= Opt["TGT_DS"] rel_name
	# If we made a snnapshot or a replication point was given on the command line, use that
	_final_ds	= GlobalState["final_snapshot"] ? GlobalState["final_snapshot"] : DSProps[src_idx, "latest_snapshot"]

	# If we have a match, we perform one sync pass from the source start to the source end
	if (RelProps[rel_name, "match"]) {
		RelProps[rel_name, "source_start"]	= RelProps[rel_name, "match"]
		RelProps[rel_name, "source_end"]        = _final_ds
	}
	# If we don't have a match in intermediate mode, we perform two sync passes starting with the first snapshot
	else if (Opt["SEND_INTR"])
		RelProps[rel_name, "source_end"]        = DSProps[src_idx, "earliest_snapshot"]
	# But in incremental mode, we jump straight to the end
	else
		RelProps[rel_name, "source_end"]	= _final_ds
}

# Describe a suitable replication action:
function compute_sync_action(rel_name, src_idx, tgt_idx) {
	# States that don't need to be (or can't be) resolved
	if (DSProps[src_idx, "latest_snapshot"] == DSProps[tgt_idx, "latest_snapshot"]) {
		RelProps[rel_name, "sync_action"] = "OK"
		GlobalState["sync_ok"]++
	}
	else if (!DSProps[src_idx, "exists"]) {
		RelProps[rel_name, "sync_action"] = "BLOCKED_NO_SOURCE"
		GlobalState["sync_blocked"]++
	}
	else if (!DSProps[src_idx, "latest_snapshot"]) {
		RelProps[rel_name, "sync_action"] = "NO_SOURCE_SNAPSHOTS"
		GlobalState["snapshot_needed"]++
	}
	# States that require 'zelta rotate', 'zfs rollback', or 'zfs rename'
	else if (DSProps[tgt_idx, "exists"] && !DSProps[tgt_idx, "latest_snapshot"]) {
		RelProps[rel_name, "sync_action"] = "ROTATE_NO_TARGET_SNAPSHOTS"
		GlobalState["rotate_needed"]++
	}
	else if (DSProps[tgt_idx, "latest_snapshot"] != RelProps[rel_name, "match"]) {
		RelProps[rel_name, "sync_action"] = "ROTATE_TARGET_DIVERGED"
		GlobalState["rotate_needed"]++
	}
	else if (RelProps[rel_name, "target_is_written"]) {
		RelProps[rel_name, "sync_action"] = "ROTATE_TARGET_WRITTEN"
		GlobalState["rotate_needed"]++
	}
	else if (DSProps[tgt_idx, "exists"] && !RelProps[rel_name, "match"]) {
		RelProps[rel_name, "sync_action"] = "ROTATE_NO_MATCH"
		GlobalState["rotate_needed"]++
	}
	# If there are no exceptions, attempt sync
	else {
		RelProps[rel_name, "sync_action"] = "SYNC"
		GlobalState["sync_needed"]++
	}
}


## Create snapshot with `zfs snapshot`
######################################

# This function replaces the original 'zelta snapshot' command
function create_snapshot(	_snap_name, _ds_snap, _cmd_arr, _cmd, _snap_failed) {
	if (!Opt["SNAP_MODE"]) return
       	if (GlobalState["snapshot_taken"]) return
       	if (!GlobalState["snapshot_needed"]) return
	GlobalState["snapshot_needed"] = 0
	_snap_name = "@" (Opt["SNAP_NAME"] ? Opt["SNAP_NAME"] : Summary["startTime"])
	_ds_snap = Opt["SRC_DS"] _snap_name
	_cmd_arr["endpoint"] = "SRC"
	_cmd_arr["ds_snap"] = _ds_snap
	_cmd = build_command("SNAP", _cmd_arr)

	report(LOG_INFO, "snapshotting: "_snap_name)
	report(LOG_DEBUG, "`"_cmd"`")
	while (_cmd | getline) {
		if (/./) {
			_snap_failed++
			report(LOG_WARNING, "unexpected `zfs snapshot` output: "$0)
		}
	}
	close(_cmd)
	# If there's unexpected output, rely on `zelta match` to compute a final snapshot
	if (!_snap_failed) {
		# We only want to attempt to take a snapshot at most once
		GlobalState["snapshot_taken"]++
		GlobalState["final_snapshot"] = _snap_name
		for (_i in DSList) {
			update_last_snapshot("SRC", DSList[_i], _snap_name)
		}
		return 1
	}
	else return 0
}

## Dataset and properties validation
####################################

# This isn't currently used, but it provides the lightest weight way to make sure
# a dataset exists.
function validate_dataset(ep, ds,		_cmd_arr, _cmd, _ds_exists) {
	_cmd_arr["endpoint"]	= ep
	_cmd_arr["ds"]		= ds
	_cmd = build_command("CHECK", _cmd_arr)
	report(LOG_INFO, "checking for existence of "ep" dataset: "ds)
	report(LOG_DEBUG, "`"_cmd"`")
	while (_cmd CAPTURE_OUTPUT | getline) {
		if ($0 == ds) _ds_exists++
		else return
	}
	return _ds_exists
}

# We can't perform a sync without a parent dataset, and 'zfs create' produces no output when it succeeds,
# so this is a perfect test and it's a requirement if the CHECK_PARENT option is given. Unfortunately,
# a nasty ZFS bug means that 'zfs create' won't work with readonly datasets, or datasets the user doesn't
# have access to. Thus, we cannot avoid the following gnarly logic.
function create_parent_dataset(ep,		_parent, _cmd, _cmd_arr, _depth, _i, _retry, _null_arr) {
	if (GlobalState["target_exists"] || !Opt["CREATE_PARENT"]) return 1

	_parent = Opt[ep "_DS"]
	sub(/\/[^\/]*$/, "", _parent) # Strip last child element

	_cmd_arr["endpoint"] = ep
	_cmd_arr["ds"]       = _parent
	_cmd = build_command("CREATE", _cmd_arr)
	_cmd = _cmd CAPTURE_OUTPUT

	report(LOG_INFO, "validating "ep" parent dataset: '"_parent"'")
	report(LOG_DEBUG, "`" _cmd "`")

	# # ZFS bug: 'create -up' on read-only hierarchies fails one level at a time
	_depth = split(_parent, _null_arr, "/")
	_attempts = _depth - 1
	while (_attempts-- > 0) {
		_hit_readonly = 0
		_success = 0
		while (_cmd | getline) {
			if (/Read-only file system/) {
				# THE BUG: This error clears one level of directory creation.
				report(LOG_DEBUG, "`zfs create` read-only bug detected")
				_hit_readonly = 1
			}
			else if (/create ancestors/) {
				report(LOG_DEBUG, "attempted to create ancestor(s)")
			}
			else if ($0 ~ "^create "_parent) {
				report(LOG_INFO, "successfully created "ep" parent '"_parent"'")
				_success = 1
			}
			else if (/^[[:space:]].*=/) {
				report(LOG_DEBUG, "property info: '"$0"'")
			}
			else if (/permission denied/) {
				stop(1, "permission denied creating "ep" '"_parent"'")
			}
			else if (/no such pool/) {
				stop(1, "no such "ep" pool in path: '"_parent"'")
			}
			else {
				report(LOG_WARNING, "unexpected `zfs create` output: '"$0"'")
			}
		}
		close(_cmd)
		if (_success || !_hit_readonly) break
		report(LOG_INFO, "incomplete `zfs create`; retrying")
	}
}

# We load the source properties or bail. No source = no 'zelta backup' possible.
function validate_source_dataset() {
	if (!load_properties("SRC")) {
		stop(1, "source dataset '"Opt["SRC_ID"]"' does not exist")
	}
}

# Check the target. We CAN'T have a target for cloning or for a full-history sync
# We might need to add additional parent-checking logic here
function validate_target_dataset(		_idx, _written_sum) {
	if (load_properties("TGT")) GlobalState["target_exists"] = 1
	else report(LOG_INFO, "target dataset '"Opt["TGT_ID"]"' does not exist")
}


## Assemble `zfs send` command
##############################

# Detect and configure send flags
function get_send_command_flags(idx,		_f, _idx, _flags, _flag_list) {
	if (Opt["VERB"] == "replicate")
		_flag_list[++_f]	= Opt["SEND_REPLICATE"]
	else if (DSProps[idx,"encryption"])
     	     _flag_list[++_f]		= Opt["SEND_RAW"]
	else _flag_list[++_f]		= Opt["SEND_DEFAULT"]
	if (NoOpMode)
		_flag_list[++_f]	= "-n"
	_flags = arr_join(_flag_list)
	return _flags
}

# Detect and configure the '-i/-I ds@snap' phrase
function get_send_command_incr_snap(rel_name, idx, remote_ep,	 _flag, _ds_snap, _intr_snap) {
	# Add the -I/-i argument if we can do perform an incremental/intermediate sync
	if (!RelProps[rel_name, "match"]) return ""
	_flag		= Opt["SEND_INTR"] ? "-I" : "-i"
	_ds_snap	= Opt["SRC_DS"] rel_name RelProps[rel_name, "source_start"]
	_ds_snap	= remote_ep ? qq(_ds_snap) : q(_ds_snap)
	_intr_snap = str_add(_flag, _ds_snap)
	return _intr_snap
}

# Assemble a 'zfs send' command with the helpers above
function create_send_command(rel_name, idx, remote_ep, 		_cmd_arr, _cmd, _ds_snap) {
	_ds_snap		= Opt["SRC_DS"] rel_name RelProps[rel_name, "source_end"]
	_cmd_arr["endpoint"]	= remote_ep
	_cmd_arr["flags"]	= get_send_command_flags(idx)
	_cmd_arr["intr_snap"]	= get_send_command_incr_snap(rel_name, idx, remote_ep)
	_cmd_arr["ds_snap"]	= remote_ep ? qq(_ds_snap) : q(_ds_snap)
	_cmd			= build_command("SEND", _cmd_arr)
	return _cmd

}


## Assemble `zfs recv` command
##############################

# Detect and configure recv flags
# Note we need the SOURCE index, not the target's to evaluate some options
function get_recv_command_flags(rel_name, src_idx,	_flag_arr, _flags, _i) {
	if (rel_name == "")
		_flag_arr[++_i]	= Opt["RECV_TOP"]
	if (DSProps[src_idx, "type"] == "volume")
		_flag_arr[++_i]	= Opt["RECV_VOL"]
	if (DSProps[src_idx, "type"] == "filesystem")
		_flag_arr[++_i]	= Opt["RECV_FS"]
	if (Opt["RESUME"])
		_flag_arr[++_i]	= Opt["RECV_PARTIAL"]
	_flags = arr_join(_flag_arr)
	return (_flags)
}

# Assemble a 'zfs recv' command with the help of the flag builder above
function create_recv_command(rel_name, src_idx, remote_ep,		 _cmd_arr, _cmd, _tgt_ds) {
	_tgt_ds			= Opt["TGT_DS"] rel_name
	_cmd_arr["endpoint"]	= remote_ep
	_cmd_arr["flags"]	= get_recv_command_flags(rel_name, src_idx)
	_cmd_arr["ds"]		= remote_ep ? qq(_tgt_ds) : q(_tgt_ds)
	_cmd			= build_command("RECV", _cmd_arr)
	return _cmd
}

#
## Planning and performing sync
###############################

# Runs a sync, collecting "zfs send" output
function run_zfs_sync(rel_name,		_cmd, _stream_info, _message, _ds_snap, _size, _time, _streams) {
	IGNORE_ZFS_SEND_OUTPUT = "(incremental|full)| records (in|out)$|bytes.*transferred|receiving.*stream|create mountpoint|ignoring$"
	_message	= RelProps[rel_name, "source_start"] ? RelProps[rel_name, "source_start"]"::" : ""
	_message	= _message RelProps[rel_name, "source_end"]
	_ds_snap	= Opt["SRC_DS"] rel_name RelProps[rel_name, "source_end"]
	SentStreamsList[++NumStreamsSent] = _message
	Summary["replicationStreamsSent"]++

	_cmd = get_sync_command(rel_name)
	report(LOG_DEBUG, "`"_cmd"`")

	_cmd = _cmd CAPTURE_OUTPUT
	FS="[[:space:]]*"
	while (_cmd | getline) {
		if ($1 == "size") {
			_size = $2
			report(LOG_INFO, "syncing: " h_num($2) " for " _ds_snap)
			Summary["replicationSize"] += $2
		}
		else if ($1 == "received") {
			_streams++
			_time += $5
			Summary["replicationTime"] += $5
			Summary["replicationStreamsReceived"]++
		}
		else if ($1 ~ /:/ && $2 ~ /^[0-9]+$/)
			# SIGINFO: Is this still working?
			report(LOG_INFO, $0)
		else if ($0 ~ IGNORE_ZFS_SEND_OUTPUT) {}
		else if (/cannot receive (mountpoint|canmount)/)
			report(LOG_DEBUG, $0)
		else if (/Warning/ && /mountpoint/)
			report(LOG_INFO, $0)
		else if (/Warning/)
			report(LOG_NOTICE, $0)
		else
			report(LOG_WARNING, "unexpected output: " $0)
	}
	close(_cmd)
	if (_streams) {
		# At least one stream has been received, but was it fully successful?
		_message = h_num(_size) " received in " _time " seconds"
		if (_streams > 1) _message = str_add(_message, "("_streams" streams)")
		report(LOG_INFO, _message)
	}
	update_last_snapshot("TGT", rel_name, RelProps[rel_name, "source_end"])
}
		#jlist("errorMessages", error_list)

## Construct replication commands
function get_sync_command(rel_name, src_idx, tgt_idx,	_zfs_send, _zfs_recv) {
	src_idx = "SRC" SUBSEP rel_name
	tgt_idx = "TGT" SUBSEP rel_name
	if (Opt["SYNC_DIRECTION"] == "PULL" && Opt["TGT_REMOTE"]) {
		zfs_send		= create_send_command(rel_name, src_idx, "SRC")
		zfs_recv		= create_recv_command(rel_name, src_idx)
		_cmd			= str_add(remote_str("TGT"), dq(zfs_send " | " zfs_recv))
	}
	else if (Opt["SYNC_DIRECTION"] == "PUSH" && Opt["SRC_REMOTE"]) {
		zfs_send		= create_send_command(rel_name, src_idx)
		zfs_recv		= create_recv_command(rel_name, src_idx, "TGT")
		_cmd			= str_add(remote_str("SRC"), dq(zfs_send " | " zfs_recv))
	}
	else {
		if (Opt["SRC_REMOTE"] && Opt["TGT_REMOTE"] && !GlobalState["warned_about_proxy"]++)
			report(LOG_WARNING, "syncing remote endpoints through localhost; consider --push or --pull")
		_zfs_send 		= create_send_command(rel_name, src_idx, "SRC")
		_zfs_recv		= create_recv_command(rel_name, src_idx, "TGT")
		_cmd			= Opt["SH_COMMAND_PREFIX"] " " _zfs_send "|" _zfs_recv " " Opt["SH_COMMAND_SUFFIX"] 
	}
	return _cmd
}

# 'zelta rotate' planning
#########################

# 'zelta rotate' renames a divergent dataset out of the way
#function plan_rotate(rel_name) {
#	if (Opt["VERB"] == "rotate") 
#		report(LOG_ERROR, "plan_rotate(): not yet implemented")
#	else
#	       report(LOG_INFO, "'"rel_name"': sync blocked: "RelProps[rel_name,"status_message"])
#}

# Old code related to the 'rotate' function yet to be refactored.
#
# 	We might not need this extra 'zelta match' step because if the source has been renamed, it might
# be more sensible just to attempt the replication with the origin. Instead, we can have extra
# logic to explain the success/failed outcome of the rotate. Or maybe we make that additional check an option.
# 
# 
#	if (torigin_name) target_flags = " -o origin=" q(rotate_name) " " target_flags
#
#	if (check_origin) {
#		sub(/[#@].*/, "", sorigin)
#		sorigin_dataset = (Opt["SRC_REMOTE"] ? Opt["SRC_REMOTE"] ":" : "") sorigin
#		clone_match = "zelta match -Hd1 -omatch,sync_code " q(sorigin_dataset) " " q(Opt["TGT_ID"] dataset)
#		while (clone_match | getline) {
#			if (/^[@#]/) { 
#				match_snap		= $1
#				source_match		= sorigin match_snap
#				if (Opt["VERB"] == "rotate") tgt_behind	= 1
#				else {
#					report(LOG_WARNING, sourceds" is a clone of "source_match"; consider --rotate")
#					return 0
#				}
#			}
#		}
#		close(clone_match)
#	}
#	if ((Opt["VERB"] == "rotate")) {
#		if (tgt_behind && !dataset) {
#			torigin_name = Opt["TGT_DS"] match_snap
#			sub(/[#@]/, "_", torigin_name)
#		}
#		rotate_name = torigin_name dataset match_snap
#	}
#		rename_command = zfs_cmd("TGT","RECV") " rename " q(Opt["TGT_DS"]) " " q(torigin_name)


## Sync planning
################

# Loops through the dataset tree and assembles the sync commands
function compute_next_action(		_i, _rel_name, _src_idx, _tgt_idx, _cmd) {
	for (_i = 1; _i <= NumDS; _i++) {
		_rel_name	= DSList[_i]
		_src_idx	= "SRC" SUBSEP _rel_name
		_tgt_idx	= "TGT" SUBSEP _rel_name

		compute_snapshot_paths(_rel_name, _src_idx, _tgt_idx)
		compute_sync_action(_rel_name, _src_idx, _tgt_idx)
		if (RelProps[_rel_name, "sync_action"] == "SYNC")
			CommandQueue[++NumJobs] = _rel_name
	}
}

# Overall sync planning function
function run_backup(		_i, _rel_name, _src_idx, _tgt_idx) {
	validate_source_dataset()
	validate_target_dataset()
	create_parent_dataset("TGT")
	create_snapshot()
	load_snapshot_deltas()
	# If we have empty snapshots, we'll need to snapshot them and update our state before proceeding
	create_snapshot()
		
	compute_next_action()

	# Sync step one:
	# Get the target dataset as up to date as possible before reviewing exceptions
	if (NumJobs) report(LOG_NOTICE, "syncing " NumDS " datasets")
		else  report(LOG_NOTICE, "nothing to sync")
	if (GlobalState["sync_needed"]) 
		for (_i = 1; _i <= NumJobs; _i++) run_zfs_sync(CommandQueue[_i])

	# Sync step two:
	# If GlobalState["snapshot_needed"], snap and compute next action.
	# If the sync went predictibly, we should update
		# DSProps[_tgt_idx, "latest_snapshot"]
		# RelProps[_relname, "match"]
	
	# Reset
	delete CommandQueue
	NumJobs = 0
	compute_next_action()
	if (GlobalState["sync_needed"]) 
		for (_i = 1; _i <= NumJobs; _i++) run_zfs_sync(CommandQueue[_i])
	
}

function print_summary(		_i) {
	_bytes_sent	= h_num(Summary["replicationSize"])
	_streams	= Summary["replicationStreamsReceived"] "/" NumJobs
	_seconds	= Summary["replicationTime"]
	if (NumJobs) report(_bytes_sent " sent, "_streams" received in "_seconds" seconds")
	if (NumStreamsSent && (Opt["LOG_MODE"] == "json")) {
		json_new_array("sentStreams")
		for (_i = 1; _i <= NumStreamsSent; _i++) json_element(SentStreamsList[_i])
		json_close_array()
	}
}

# Main planning function
BEGIN {
	if (Opt["USAGE"]) usage()
	
	# Glboals and overrides
	GlobalState["vers_major"] = 1
	GlobalState["vers_minor"] = 1
	GlobalState["snapshot_needed"]	= (Opt["SNAP_MODE"] == "ALWAYS")
	GlobalState["final_snapshot"]	= Opt["SRC_SNAP"]
	GlobalState["target_exists"]	= 0
	GlobalState["sync_passes"]	= 0
	Summary["startTime"]		= sys_time()

	load_build_commands()
	if (Opt["VERB"] == "clone")	run_clone()
	else				run_backup()

	Summary["endTime"]		= sys_time()
	Summary["runTime"]		= Summary["endTime"] - Summary["startTime"]

	load_summary_data()
	load_summary_vars()
	print_summary()

	stop()
}

# Old code for summary
#	report(LOG_NOTICE, h_num(total_bytes) " sent, " received_streams "/" sent_streams " streams received in " zfs_replication_time " seconds")
#	stop(error_code)
