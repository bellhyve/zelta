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
# snap_ds: A specific snapshot, such as a replication source
# relname: The dataset suffix/child element of the dataset tree (will be renamed 'ds_suffix')
#
# GLOBALS
# Opt: User settings
# DSList: List of "relname" elements in replication order
# NumDS: Number of elements in DSList
# DSProps: Properties of each dataset, indexed by: ("ENDPOINT", relname, element)
# RelProps: Derived properties comparing a dataset and its replica: (relname, element)
# GlobalState: Properties about the global state or overrides
# Summary: Totals and other summary information

## Usage
########

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

# Constructs a command using an action and the passed array
# Special variables:
#   "endpoint": Expands a remote prefix if given
#   "command_prefix": Inserts before command name for an additional pipe or environment variable
function build_command(action, vars,		_remote, _cmd, _num_vars, _var_list, _val, _remote_cmd, _remote_ep) {
	if (CommandRemote[action]&& vars["endpoint"]) {
		_remote_cmd = "REMOTE_" CommandRemote[action]
		_remote_ep = vars["endpoint"] "_REMOTE"
		_cmd = str_add(Opt[_remote_cmd], Opt[_remote_ep])

	}
	_cmd = str_add(_cmd, CommandLine[action])
	_num_vars = split(CommandVars[action], _var_list, " ")
	for (_v = 1; _v <= _num_vars; _v++) {
		_val = vars[_var_list[_v]]
		_cmd = str_add(_cmd, _val)
	}
	_cmd = str_add(_cmd, CommandSuffix[action])
	if (vars["command_prefix"]) _cmd = str_add(vars["command_prefix"], _cmd)
	return _cmd
}

## Loading properties and basic dataset validation
##################################################

# Load zfs properties for an endpoint
function load_properties(ep,		_ds, _cmd_arr, _cmd, _idx, _seen) {
	if (!Opt["PROP_CHECK"]) {
		report(LOG_INFO, "skipping `zfs get` step; will not detect properties")
		return 1
	}
	_ds			= Opt[ep "_DS"]
	_cmd_arr["endpoint"]	= ep
	_cmd_arr["ds"]		= q(_ds)
	if (Opt["DEPTH"]) _cmd_arr["flags"] = "-d" (Depth-1)
	_cmd = build_command("PROPS", _cmd_arr)
	report(LOG_INFO, "checking properties for " Opt[ep"_ID"])
	report(LOG_DEBUG, "`"_cmd"`")
	_cmd = _cmd CAPTURE_OUTPUT
	while (_cmd | getline) {
		if (NF == 3 && match($1, "^" _ds)) {
			_rel_name = substr($1, length(_ds) + 1)
			_idx = ep SUBSEP _rel_name
			# Since NAME is the first column, we add that once
			if (!_seen[_idx]++) DSProps[_idx, "exists"]++
			_prop_key = $2
			_prop_val = ($3 == "off") ? "0" : $3
			DSProps[_idx, _prop_key] = _prop_val
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

# Evaluate properties needed for snapshot decision and sync options
function update_dataset_relationship(		_idx, idx_arr, _relname, _element, _ep_idx, _seen) {
	for (_idx in DSProps) {
		split(_idx, _idx_arr, SUBSEP)
		_endpoint	= _idx_arr[1]
		_relname	= _idx_arr[2]
		_element	= _idx_arr[3]
		_ep_idx		= _endpoint SUBSEP _relname
		if ((_element == "written") && DSProps[_idx]) {
			if (_endpoint = "TGT") {
				RelProps[_relname, "blocked"] = "target is written"
				RelProps[_relname, "target_is_written"] += DSProps[_idx]
			}
			else {
				Summary["total_source_written"] += DSProps[_idx]
				RelProps[_relname, "source_is_written"] += DSProps[_idx]
				if (Opt["SNAP_MODE"] == "IS_NEEDED") GlobalState["snapshot_needed"]++
			}
		}
		if ((_element == "encryption") && DSProps[_idx]) {
				RelProps[_relname, "raw"] = "yes"
		}
	}
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
		RelProps[_relname, "common_snapshot"]	= $2
		DSProps[_src_idx, "earliest_snapshot"]	= $3
		DSProps[_src_idx, "latest_snapshot"]	= $4
		DSProps[_tgt_idx, "latest_snapshot"]	= $5
	}
	else {
		if ($1 == "SOURCE_LIST_TIME:")		source_list_time += $2
		else if ($1 == "TARGET_LIST_TIME:")	target_list_time += $2
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
function compute_snapshot_paths(rel_name, src_idx,	_src_ds, _tgt_ds) {
	_src_ds		= Opt["SRC_DS"] rel_name
	_tgt_ds		= Opt["TGT_DS"] rel_name

	# Determine which source snapshots to sync:
	# first_snapshot: For new replications in -I mode, we do a first pass with the earliest source
	if (DSProps[src_idx, "earliest_snapshot"])
		RelProps[rel_name, "first_snapshot"] = _src_ds DSProps[src_idx, "earliest_snapshot"]
	# source_origin: Incremental sync from this source snapshot (-I/-i) to the final snapshot 
	if (RelProps[rel_name, "common_snapshot"])
		RelProps[rel_name, "source_origin"] = _src_ds RelProps[rel_name, "common_snapshot"]
	else if (DSProps[src_idx, "origin"]) {
		# We didn't find a match, detected that the source was renamed, so try that origin
		RelProps[rel_name, "status_message"] = "source was renamed; using clone origin"
		RelProps[rel_name, "source_origin"] = DSProps[src_idx, "origin"]
	}
	# final_snapshot: The source snapshot argument, a snapshot, or the latest snapshot
	if (GlobalState["final_snapshot"])
		RelProps[rel_name, "final_snapshot"] = _src_ds GlobalState["final_snapshot"]
	else if (DSProps[src_idx, "latest_snapshot"])
		RelProps[rel_name, "final_snapshot"] = _src_ds DSProps[src_idx, "latest_snapshot"]

	# Determine the full target path
	RelProps[rel_name, "target_ds"] = _tgt_ds
}

# Describe a suitable replication action:
function compute_sync_action(rel_name, src_idx, tgt_idx) {
	# States that don't need to be (or can't be) resolved
	if (!DSProps[src_idx, "exists"]) {
		RelProps[rel_name, "sync_action"] = "NONE"
		RelProps[rel_name, "status_message"] = "source does not exist"
	}
	else if (!DSProps[src_idx, "latest_snapshot"]) {
		RelProps[rel_name, "sync_action"] = "NONE"
		RelProps[rel_name, "status_message"] = "source has no snapshots"
	}
	else if (DSProps[src_idx, "latest_snapshot"] == DSProps[tgt_idx, "latest_snapshot"]) {
		RelProps[rel_name, "sync_action"] = "NONE"
		RelProps[rel_name, "status_message"] = "up-to-date"
	}

	# States that require 'zelta rotate', 'zfs rollback', or 'zfs rename'
	else if (DSProps[tgt_idx, "exists"] && !DSProps[tgt_idx, "latest_snapshot"]) {
		RelProps[rel_name, "sync_action"] = "BLOCKED"
		RelProps[rel_name, "status_message"] = "target has no snapshots; consider 'zelta rotate'"
	}
	else if (DSProps[tgt_idx, "exists"] && !RelProps[rel_name, "common_snapshot"]) {
		RelProps[rel_name, "sync_action"] = "BLOCKED"
		RelProps[rel_name, "status_message"] = "endpoints have no common snapshots; consider 'zelta rotate'"
	}
	else if (RelProps[rel_name, "target_is_written"]) {
		RelProps[rel_name, "sync_action"] = "BLOCKED"
		RelProps[rel_name, "status_message"] = "target is written; consider 'zelta rotate' or 'zfs rollback'"
	}
	else if (DSProps[tgt_idx, "latest_snapshot"] != RelProps[rel_name, "common_snapshot"]) {
		RelProps[rel_name, "sync_action"] = "BLOCKED"
		RelProps[rel_name, "status_message"] = "target has new snapshots; consider 'zelta rotate' or 'zfs rollback'"
	}

	# If there are no exceptions, attempt sync
	# No 'status_message' is given here; is determined from the sync action and/or compute_snapshot_paths()
	else RelProps[rel_name, "sync_action"] = "SYNC"
}


## Create snapshot with `zfs snapshot`
######################################

# This function replaces the original 'zelta match' command
function create_snapshot(	_snap_name, _snap_ds, _cmd_arr, _cmd, _snap_failed) {
	if (!GlobalState["snapshot_needed"]) return
	_snap_name = "@" (Opt["SNAP_NAME"] ? Opt["SNAP_NAME"] : Summary["start_time"])
	_snap_ds = Opt["SRC_DS"] _snap_name
	_cmd_arr["endpoint"] = "SRC"
	_cmd_arr["ds_snap"] = _snap_ds
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
	if (!_snap_failed) GlobalState["final_snapshot"] = _snap_name
}


#		
#
#	return 1
#}

## Dataset and properties validation
####################################

# This isn't currently used, but it provides the lightest weight way to make sure
# a dataset exists. We use an EAFP method below by attempting to create the parent
# but we may need a less obtrusive alternative if both CREATE_PARENT and
# CHECK_PROPS options are disabled.
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
	if (!Opt["CREATE_PARENT"]) return 1

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
function get_send_command_incr_snap(relname, idx,	 _intr_snap) {
	# Add the -I/-i argument if we can do perform an incremental/intermediate sync
	if (!DSProps["TGT", relname, "exists"]) return ""
	_intr_snap = Opt["SEND_INTR"] ? "-I" : "-i"
	_intr_snap = str_add(_intr_snap, dq(RelProps[relname, "source_origin"]))
	return _intr_snap
}

# Detect and configure 'final' dataset@snapshot point to replicate
function get_send_command_ds_snap(relname, _ds_snap) {
	# On a new replication in intermediate mode, we send the first snapshot
	# so we can get the entire history in two steps.
	if (!DSProps["TGT", relname, "exists"] && Opt["SEND_INTR"])
		_ds_snap = RelProps[relname, "first_snapshot"]
	# For any other replication, the final argument is the dataset's final snapshot
	else _ds_snap = RelProps[relname, "final_snapshot"]
	_ds_snap = dq(_ds_snap)
	return _ds_snap
}

# Assemble a 'zfs send' command with the helpers above
function create_send_command(rel_name, idx, remote_ep, 		_cmd_arr, _cmd) {
	_cmd_arr["endpoint"]	= remote_ep
	_cmd_arr["flags"]	= get_send_command_flags(idx)
	_cmd_arr["intr_snap"]	= get_send_command_incr_snap(rel_name, idx)
	_cmd_arr["ds_snap"]	= get_send_command_ds_snap(rel_name)
	_cmd			= build_command("SEND", _cmd_arr)
	#RelProps[relname, "zfs_send"] = build_command("SEND", _cmd_arr)
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
function create_recv_command(rel_name, src_idx, remote_ep,		 _cmd_arr, _cmd) {
	_cmd_arr["endpoint"]	= remote_ep
	_cmd_arr["flags"]	= get_recv_command_flags(rel_name, src_idx)
	_cmd_arr["ds"]		= dq(RelProps[rel_name,"target_ds"])
	_cmd			= build_command("RECV", _cmd_arr)
	return _cmd
	#RelProps[relname, "zfs_send"] = build_command("REV", _cmd_arr)
}

#
## Planning and performing sync
###############################

# Runs a sync, collecting "zfs send" output
function run_zfs_sync(command, _cmd) {
	IGNORE_ZFS_SEND_OUTPUT = "(incremental|full)| records (in|out)$|bytes.*transferred|receiving.*stream|ignoring$"
	report(LOG_DEBUG, "`"command"`")
	_cmd = command CAPTURE_OUTPUT
	FS="[[:space:]]*"
	while (_cmd | getline) {
		if ($1 == "size") {
			report(LOG_INFO, "syncing: " h_num($2))
			Summary["total_bytes_send"] += $2
		}
		else if ($1 == "received")
			report(LOG_INFO, "  success: "$0)
		else if ($1 ~ /:/ && $2 ~ /^[0-9]+$/)
			# SIGINFO: Is this still working?
			report(LOG_INFO, $0)
		else if (/cannot receive (mountpoint|canmount)/)
			report(LOG_WARNING, $0)
		else if (/failed to create mountpoint/)
			# This is expected with restricted access
			report(LOG_DEBUG, $0)
		else if (/Warning/ && /mountpoint/)
			report(LOG_INFO, $0)
		else if (/Warning/)
			report(LOG_NOTICE, $0)
		else if ($0 ~ IGNORE_ZFS_SEND_OUTPUT) {}
		else
			report(LOG_WARNING, "unexpected output: " $0)
	}
	close(_cmd)
}


## Construct replication commands
function get_sync_command(rel_name, src_idx, tgt_idx,	_zfs_send, _zfs_recv) {
	if (Opt["SYNC_DIRECTION"] == "PULL" && Opt["TGT_REMOTE"]) {
		_cmd_arr["endpoint"]	= "TGT"
		_cmd_arr["zfs_send"]	= create_send_command(rel_name, src_idx, "SRC")
		_cmd_arr["zfs_recv"]	= "|" create_recv_command(rel_name, src_idx)
		_cmd			= build_command("SYNC", _cmd_arr)
	}
	else if (Opt["SYNC_DIRECTION"] == "PUSH" && Opt["SRC_REMOTE"]) {
		_cmd_arr["endpoint"]	= "SRC"
		_cmd_arr["zfs_send"]	= create_send_command(rel_name, src_idx)
		_cmd_arr["zfs_recv"]	= "|" create_recv_command(rel_name, src_idx, "TGT")
		_cmd			= build_command("SYNC", _cmd_arr)
	}
	else {
		if (Opt["SRC_REMOTE"] && Opt["TGT_REMOTE"])
			report_once(LOG_WARNING, "syncing remote endpoints through localhost; consider --push or --pull")
		_zfs_send 		= create_send_command(rel_name, src_idx, "SRC")
		_zfs_recv		= create_recv_command(rel_name, src_idx, "TGT")
		_cmd			= _zfs_send "|" _zfs_recv
	}	
	return _cmd
}

# 'zelta rotate' planning
#########################

# 'zelta rotate' renames a divergent dataset out of the way
function plan_rotate(rel_name) {
	if (Opt["VERB"] == "rotate") 
		report(LOG_ERROR, "plan_rotate(): not yet implemented")
	else
	       report(LOG_INFO, "'"rel_name"': sync blocked: "RelProps[rel_name,"status_message"])
}

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
# Currently we run the sync here, but this will likely be moved to a separate control loop
function determine_next_sync_action(	_i, _rel_name, _src_idx, _tgt_idx, _cmd) {
	for (_i = 1; _i <= NumDS; _i++) {
		_rel_name	= DSList[_i]
		_src_idx	= "SRC" SUBSEP _rel_name
		_tgt_idx	= "TGT" SUBSEP _rel_name

		compute_snapshot_paths(_rel_name, _src_idx)
		compute_sync_action(_rel_name, _src_idx, _tgt_idx)

		if (RelProps[_rel_name, "sync_action"] == "SYNC") {
			_cmd = get_sync_command(_rel_name, _src_idx, _tgt_idx)
			run_zfs_sync(_cmd)
		}
		else if (RelProps[_rel_name, "sync_action"] == "BLOCKED")
			plan_rotate(_rel_name)
		else if (RelProps[_rel_name, "sync_action"] == "NONE")
			report(LOG_INFO, _rel_name": " RelProps[_rel_name, "status_message"])
		else 
			report(LOG_ERROR, "'"_rel_name"': could not determine sync action " RelProps[_rel_name, "sync_action"])
	}
}

# Overall sync planning function
function run_backup(		_i, _rel_name, _src_idx, _tgt_idx) {
	validate_source_dataset()
	validate_target_dataset()
	if (!GlobalState["target_exists"]) create_parent_dataset("TGT")
	update_dataset_relationship()
	create_snapshot()
	load_snapshot_deltas()
	determine_next_sync_action()
	#create_command_queue()
}

# Main planning function
BEGIN {
	if (Opt["USAGE"]) usage()
	
	# Glboals and overrides
	Summary["start_time"]		= sys_time()
	GlobalState["snapshot_needed"]	= (Opt["SNAP_MODE"] == "ALWAYS")
	GlobalState["final_snapshot"]	= Opt["SRC_SNAP"]
	GlobalState["target_exists"]	= 0
	GlobalState["sync_passes"]	= 0

	load_build_commands()
	if (Opt["VERB"] == "clone")	run_clone()
	else				run_backup()

	# summarize()
}

# Old code for summary
#	report(LOG_NOTICE, h_num(total_bytes) " sent, " received_streams "/" sent_streams " streams received in " zfs_replication_time " seconds")
#	stop(error_code)
