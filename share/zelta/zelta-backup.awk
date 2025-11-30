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
# relname: The relative child element in a dataset tree
#
# GLOBALS
# Opt: User settings
# DSList: List of "relname" elements in replication order
# NumDS: Number of elements in DSList
# DSProps: Properties of each dataset, indexed by: ("ENDPOINT", relname, element)
# RelProps: Derived properties comparing a dataset and its replica: (relname, element)
# Summary: Totals and other summary information

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

#function command_queue(send_dataset, receive_dataset, match_snapshot,	target_flags) {
#	num_streams++
#	if (!dataset) target_flags = " " Opt["RECV_FLAGS_TOP"] " "
#	if (torigin_name) target_flags = " -o origin=" q(rotate_name) " " target_flags
#	if (zfs_send_command ~ /ssh/) {
#		gsub(/ /, "\\ ", send_dataset)
#		gsub(/ /, "\\ ", match_snapshot)
#	}
#	if (zfs_receive_command ~ /ssh/) {
#		gsub(/ /, "\\ ", receive_dataset)
#		gsub(/ /, "\\ ", target_flags)
#	}
#	if (receive_dataset) receive_part = zfs_receive_command target_flags q(receive_dataset)
#	if (Opt["VERB"] == "clone") {
#		if (!dataset) target_flags = " " CLONE_FLAGS_TOP " "
#		send_command[++rpl_num] = zfs_send_command target_flags q(send_dataset) " " q(receive_dataset)
#		source_stream[rpl_num] = send_dataset
#	} else if (match_snapshot) {
#		send_part = intr_flags q(match_snapshot) " " q(send_dataset)
#		send_command[++rpl_num] = zfs_send_command send_part
#		receive_command[rpl_num] = receive_part
#		est_cmd[rpl_num] = zfs_send_command "-Pn " send_part
#		source_stream[rpl_num] = match_snapshot "::" send_dataset
#		# zfs list xfersize sucks so find xfersize from a zfs send -n instead
#		# stream_size[rpl_num] = xfersize
#	} else {
#		send_command[++rpl_num] = zfs_send_command source_flags q(send_dataset)
#		receive_command[rpl_num] = receive_part
#		est_cmd[rpl_num] = zfs_send_command "-Pn " q(send_dataset)
#		source_stream[rpl_num] = send_dataset
#		#stream_size[rpl_num] = xfersize
#	}
#}

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
			if (!_seen[_idx]) {
				DSProps[_idx, "name"] = $1
				DSProps[_idx, "exists"]++
			}
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

	
#	_zfs_send_check_command = zfs_cmd("SRC") " " send " " CAPTURE_OUTPUT
#	while (_zfs_send_check_command | getline)
#		if (/usage:/) _in_usage = 1
#		else if (!/^[[:space:]]) _in_usage = 0
#		else if (_in_usage) {
#			# Look for [-Something]
#			if (match($0, /\[-[a-zA-Z0-9]+\]/)) {
#				# Strip the leading "[-" (2 chars) and trailing "]" (1 char)
#				flags = substr($0, RSTART+2, RLENGTH-3)
#				print flags
#				found=1
#				exit 0
#			}
#		}
#
#}

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

function load_snapshot_deltas(_cmd_arr, _cmd) {
	FS = "\t"
	if (TargetDoesNotExist) 
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
				if (Opt["SNAP_MODE"] == "IS_NEEDED") SnapshotIsNeeded++
			}
		}
		if ((_element == "encryption") && DSProps[_idx]) {
				RelProps[_relname, "raw"] = "yes"
		}
	}
	if (Opt["SNAP_MODE"] == "ALWAYS") SnapshotIsNeeded++
}

function update_snapshot_relationship() {
	for (_i = 1; _i <= NumDS; _i++) {
		_relname = DSList[_i]
		_src_idx = "SRC" SUBSEP _relname
		_tgt_idx = "TGT" SUBSEP _relname

		# Figure out which snapshots to sync
		if (Opt["SRC_SNAP"]) RelProps[_relname, "final_snapshot"] = Opt["SRC_SNAP"]
		else RelProps[_relname, "final_snapshot"] = DSProps[_src_idx, "latest_snapshot"]
		RelProps[_relname, "first_snapshot"] = DSProps[_src_idx, "earliest_snapshot"]

		# States that don't need to be (or can't be) resolved
		if (!DSProps[_src_idx, "exists"]) {
			RelProps[_relname, "replication_style"] = "NONE"
			RelProps[_relname, "status_message"] = "source does not exist"
		}
		else if (!DSProps[_src_idx, "most_recent_snapshot"]) {
			RelProps[_relname, "replication_style"] = "NONE"
			RelProps[_relname, "status_message"] = "source has no snapshots"
		}
		else if (DSProps[_src_idx, "most_recent_snapshot"] == DSProps[_src_idx, "common_snapshot"]) {
			RelProps[_relname, "replication_style"] = "NONE"
			RelProps[_relname, "status_message"] = "up-to-date"
		}

		# States that require 'zelta rotate', 'zfs rollback', or 'zfs rename'
		else if (DSProps[_tgt_idx, "exists"] && !DSProps[_tgt_idx, "most_recent_snapshot"])
			RelProps[_relname, "blocked"] = "target has no snapshots; consider 'zelta rotate'"
		else if (!DSProps[_tgt_idx, "common_snapshot"])
			RelProps[_relname, "blocked"] = "endpoints have no common snapshots; consider 'zelta rotate'"
		else if (RelProps[_relname, "target_is_written"])
			RelProps[_relname, "blocked"] = "target is written; consider 'zelta rotate' or 'zfs rollback'"
		else if (DSProps[_tgt_idx, "most_recent_snapshot"] == RelProps[_relname, "common_snapshot"])
			RelProps[_relname, "blocked"] = "target is written; consider 'zelta rotate' or 'zfs rollback'"

		# If there are no exceptions, describe the replication style
		else if (DSProps[_tgt_idx, "exists"])
			RelProps[_relname, "replication_style"] = "NEW"
		else RelProps[_relname, "replication_style"] = "SYNC"
	}
}


function create_snapshot(	_snap_name, _cmd_arr, _cmd, _snap_failed) {
	if (!SnapshotIsNeeded) return
	_snap_name = "@" (Opt["SNAP_NAME"] ? Opt["SNAP_NAME"] : Summary["start_time"])
	_cmd_arr["endpoint"] = "SRC"
	_cmd_arr["ds_snap"] = Opt["SRC_DS"] _snap_name
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
}

#function replicate(command) {
#	while (command | getline) {
#		if ($1 == "incremental" || $1 == "full") sent_streams++
#		else if ($1 == "received") {
#			report(LOG_INFO, source_stream[r]": "$0)
#			received_streams++
#		} else if ($1 == "size") {
#			report(LOG_INFO, source_stream[r]": sending " h_num($2))
#			total_bytes += $2
#		} else if ($1 ~ /:/ && $2 ~ /^[0-9]+$/) {
#			# Is this still working?
#			siginfo(source_stream[r]": "h_num($2) " received")
#		} else if (/cannot receive (mountpoint|canmount)/) {
#			report(LOG_WARNING, $0)
#		} else if (/failed to create mountpoint/) {
#			# This is expected with restricted access
#			report(LOG_DEBUG, $0)
#		} else if (/Warning/ && /mountpoint/) {
#			report(LOG_INFO, $0)
#		} else if (/Warning/) {
#			report(LOG_NOTICE, $0)
#		} else if ($1 == "real") zfs_replication_time += $2
#		else if (/^(sys|user)[ \t]+[0-9]/) { }
#		else if (/ records (in|out)$/) { }
#		else if (/bytes.*transferred/) { }
#		else if (/receiving/ && /stream/) { }
#		else if (/ignoring$/) { }
#		else {
#			report(LOG_WARNING, "unexpected output in replication stream: " $0)
#			error_code = 2
#		}
#	}
#	close(command)
#}
#
#	# Compute update path
#	get_update_option()
#
#	# No match. Was the source renamed?
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
#		
#
#	if ((Opt["VERB"] == "rotate")) {
#		if (tgt_behind && !dataset) {
#			torigin_name = Opt["TGT_DS"] match_snap
#			sub(/[#@]/, "_", torigin_name)
#		}
#		rotate_name = torigin_name dataset match_snap
#	}
#	return 1
#}

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

function validate_source_dataset() {
	if (!load_properties("SRC")) {
		stop(1, "source dataset '"Opt["SRC_ID"]"' does not exist")
	}
}

function validate_target_dataset(		_idx, _written_sum) {
	if (!load_properties("TGT")) {
		TargetDoesNotExist++
		report(LOG_INFO, "target dataset '"Opt["TGT_ID"]"' does not exist")
		return 0
	}
}

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

function get_send_command_ds_snap(relname, _ds_snap) {
	# On a new replication in intermediate mode, we send the first snapshot
	# so we can get the entire history in two steps.
	if (!DSProps["TGT", relname, "exists"] && Opt["SEND_INTR"])
		_ds_snap = RelProps[relname, "first_snapshot"]
	# For any other replication, the final argument is the dataset's final snapshot
	else _ds_snap = RelProps[_relname, "final_snapshot"]
	_ds_snap = dq(DSProps["SRC_DS"] _relname _ds_snap)
	return _ds_snap
}

function get_send_command_incr_snap(relname, idx,	 _intr_snap) {
	# Add the -I/-i argument if we can do perform an incremental/intermediate sync
	if (!DSProps["TGT", relname, "exists"]) return ""
	_intr_snap = Opt["SEND_INTR"] ? "-I" : "-i"
	_intr_snap = str_add(_incr_snap, dq(Opt["SRC_DS"] RelProps[relname, "common_snapshot"]))
	return _intr_snap
}

function create_send_command(ds_num, remote_ep, 	_cmd_arr, _cmd) {
	_relname		= DSList[ds_num]
	_idx			= "SRC" SUBSEP _relname
	_cmd_arr["endpoint"]	= remote_ep
	_cmd_arr["flags"]	= get_send_command_flags(_idx)
	_cmd_arr["intr_snap"]	= get_sync_command_incr_snap(_relname, _idx)
	_cmd_arr["ds_snap"]	= get_new_source_snapshot_name(_relname)
	_cmd = build_command("SEND", _cmd_arr)
	return _cmd
}

function recv_flags(ds_num, 	_flag_arr, _flags, _relname, _i) {
	_relname		= DSList[ds_num]
	_idx                    = "TGT" SUBSEP _relname
	if (ds_num == 1)
		_flag_arr[++_i]	= Opt["RECV_TOP"]
	if (DSProps[_idx, "type"] == "volume")
		_flag_arr[++_i]	= Opt["RECV_VOL"]
	if (DSProps[_idx, "filesystem"] == "filesystem")
		_flag_arr[++_i]	= Opt["RECV_FS"]
	if (Opt["RESUME"])
		_flag_arr[++_i]	= Opt["RECV_PARTIAL"]
	_flags = arr_join(_flag_arr)
	return (_flags)
}

function action_recv(ds_num, remote_ep,		_cmd_arr) {
	_relname		= DSList[ds_num]
	_ds			= Opt["TGT_DS"] _relname
	_idx                    = "TGT" SUBSEP _relname
	_cmd_arr["endpoint"]	= remote_ep
	_cmd_arr["flags"]	= recv_flags(ds_num)
	_cmd_arr["ds"]		= dq(_ds)
	_cmd = build_command("RECV", _cmd_arr)
	return _cmd
}

# Gathers `zfs send` output in an array
function get_zfs_send_output(command, output) {
	IGNORE_ZFS_SEND_OUTPUT = "^(sys|user)[ \t]+[0-9]|( records (in|out)$|bytes.*transferred|receiving.*stream|ignoring$"
	cmd = cmd CAPTURE_OUTPUT
	while (cmd | getline) {
		if ($0 ~ IGNORE_ZFS_SEND_OUTPUT) {}
		else print
	}
	close(cmd)
}

function create_sync_command(ds_num, remote_ep, extra_flag,	_cmd_arr) {
	_idx			= "SRC" SUBSEP DSList[ds_num]
	_relname		= DSList[ds_num]
	_cmd_arr["endpoint"]	= remote_ep
	_cmd_arr["flags"]	= str_add(get_send_flags(_idx), Opt["SEND_NEW"])
	_cmd_arr["flags"]	= str_add(_cmd_arr["flags"], extra_flag)
	_ds			= DSProps[_idx, "dataset"]
	_cmd_arr["ds_snap"]	= get_new_source_snapshot_name(_relname)
	_cmd = build_command("SEND", _cmd_arr)
	return _cmd
}

function recv_flags(ds_num, 	_flag_arr, _flags, _relname, _i) {
	_relname		= DSList[ds_num]
	_idx                    = "TGT" SUBSEP _relname
	if (ds_num == 1)
		_flag_arr[++_i]	= Opt["RECV_TOP"]
	if (DSProps[_idx, "type"] == "volume")
		_flag_arr[++_i]	= Opt["RECV_VOL"]
	if (DSProps[_idx, "filesystem"] == "filesystem")
		_flag_arr[++_i]	= Opt["RECV_FS"]
	if (Opt["RESUME"])
		_flag_arr[++_i]	= Opt["RECV_PARTIAL"]
	_flags = arr_join(_flag_arr)
	return (_flags)
}

function action_recv(ds_num, remote_ep,		_cmd_arr) {
	_relname		= DSList[ds_num]
	_ds			= Opt["TGT_DS"] _relname
	_idx                    = "TGT" SUBSEP _relname
	_cmd_arr["endpoint"]	= remote_ep
	_cmd_arr["flags"]	= recv_flags(ds_num)
	_cmd_arr["ds"]		= dq(_ds)
	_cmd = build_command("RECV", _cmd_arr)
	return _cmd
}

# Gathers `zfs send` output in an array
function get_zfs_send_output(command, output) {
	IGNORE_ZFS_SEND_OUTPUT = "^(sys|user)[ \t]+[0-9]|( records (in|out)$|bytes.*transferred|receiving.*stream|ignoring$"
	cmd = cmd CAPTURE_OUTPUT
	while (cmd | getline) {
		if ($0 ~ IGNORE_ZFS_SEND_OUTPUT) {}
		else print
	}
	close(cmd)
}

function get_sync_command(ds_num,	_zfs_send, _zfs_recv) {
	if (Opt["SYNC_DIRECTION"] == "PULL" && Opt["TGT_REMOTE"]) {
		_cmd_arr["endpoint"]	= "TGT"
		_cmd_arr["zfs_send"]	= action_sync_new(ds_num, "SRC")
		_cmd_arr["zfs_recv"]	= "|" action_recv(ds_num)
		_cmd			= build_command("SYNC", _cmd_arr)
	}
	else if (Opt["SYNC_DIRECTION"] == "PUSH" && Opt["SRC_REMOTE"]) {
		_cmd_arr["endpoint"]	= "SRC"
		_cmd_arr["zfs_send"]	= action_sync_new(ds_num)
		_cmd_arr["zfs_recv"]	= "|" action_recv(ds_num, "TGT")
		_cmd			= build_command("SYNC", _cmd_arr)
	}
	else {
		if (Opt["SRC_REMOTE"] && Opt["TGT_REMOTE"])
			report_once(LOG_WARNING, "syncing remote endpoints through the local network; consider --push or --pull")
		_zfs_send 		= action_sync_new(ds_num, "SRC")
		_zfs_recv		= action_recv(ds_num, "TGT")
		_cmd			= _zfs_send "|" _zfs_recv
	}	
	return _cmd
}

function create_command_queue(_cmd, _i) {
	for (_i = 1; _i <= NumDS; _i++) {
		_cmd = get_sync_command(_i)
		report(LOG_DEBUG, "`"_cmd"`")
		sync(_cmd)
	}
}

function plan_backup(		_i, _relname) {
	validate_source_dataset()
	validate_target_dataset()
	if (TargetDoesNotExist) create_parent_dataset("TGT")
	update_dataset_relationship()
	create_snapshot()
	load_snapshot_deltas()
	update_snapshot_relationship()

	create_command_queue()

	#tgt_written	= (tgt_written || tgtprop[dataset,"written"])
	#src_only	= (src_has_snap && !tgt_exists)
	#tgt_behind	= (tgt_latest_match && !src_latest_match)
	#tgt_blocked	= (!tgt_latest_match || tgt_written)
	#up_to_date	= (src_latest_match && tgt_latest_match)
	#check_origin	= (src_has_snap && !trees_match && tgt_has_snap && sorigin)
#                        } else if (sub(/^parent dataset does not exist: +/,"")) {
#                                send_command[++rpl_num] = zfs_cmd("TGT", "RECV") " create " create_flags q($0)
#                                create_dataset[rpl_num] = $6
#                        } else  { report(LOG_WARNING, "unexpected line: " $0) }
#                        continue
#                }
#                if (src_only) {
#                        if (INTR && !single_snap) {
#                                                        command_queue(sfirst_full, targetds)
#                                                        command_queue(slast_full, targetds, sfirst)
#                        } else                          command_queue(slast_full, targetds)
#                } else if (tgt_behind && !tgt_written) {
#                                                        command_queue(slast_full, targetds, source_match)
#                } else if (torigin_name && match_snap) {
#                                                        command_queue(slast_full, targetds, source_match)
#                } else if (up_to_date) {
#                        report(LOG_INFO, targetds ": "info)
#                        synced_count++
#                } else report(LOG_WARNING, targetds": "info)
#
	#zfs_send_options_check() # do this during dryrun step
}



BEGIN {
	if (Opt["USAGE"]) usage()
	Summary["start_time"] = sys_time()
	load_build_commands()
	if (Opt["VERB"] == "clone")	plan_clone()
	else				plan_backup()
	
#		if (src_only) {
#			if (Opt["SEND_INTR"] && !single_snap) {
#							command_queue(sfirst_full, targetds)
#							command_queue(slast_full, targetds, sfirst)
#			} else				command_queue(slast_full, targetds)
#		} else if (tgt_behind && !tgt_written) {
#							command_queue(slast_full, targetds, source_match)
#		} else if (torigin_name && match_snap) {
#							command_queue(slast_full, targetds, source_match)
#		} else if (up_to_date) {
#			report(LOG_INFO, targetds ": "info)
#			synced_count++
#		} else report(LOG_WARNING, targetds": "info)
#	}
#	close(match_command)
#	
#	if (Opt["VERB"] == "rotate") {
#		if (!torigin_name) {
#			report(LOG_ERROR, "no match available for requested rotation")
#			stop(5)
#		}
#		rename_command = zfs_cmd("TGT","RECV") " rename " q(Opt["TGT_DS"]) " " q(torigin_name)
#		if (! dryrun(rename_command)) {
#			system(rename_command)
#			report(LOG_NOTICE, "target renamed to " q(torigin_name))
#		}
#	}
#
#	if (!num_streams) {
#		if (synced_count) report(LOG_NOTICE, "nothing to replicate")
#		else {
#			error_code = 5
#			report(LOG_NOTICE, "match error")
#		}
#		stop(error_code)
#	}
#	
#	FS = "[ \t]+"
#	received_streams = 0
#	total_bytes = 0
#	if (LOG_MODE == "PROGRESS") {
#		report(LOG_INFO, "calculating transfer size")
#		for (r = 1; r <= rpl_num; r++) {
#			if (full_cmd) close(full_cmd)
#			full_cmd = RPL_CMD_PREFIX dq(est_cmd[r]) CAPTURE_OUTPUT
#			while (full_cmd | getline) {
#				if ($1 == "size") {
#					stream_size[r] = $2
#					total_transfer_size += $2
#				}
#			}
#		}
#		estimate = ", " h_num(total_transfer_size)
#	}
#	estimate = ((Opt["VERB"] == "clone") ? "cloning " : "replicating ") rpl_num " streams" estimate
#	report(LOG_NOTICE, estimate)
#	for (r = 1; r <= rpl_num; r++) {
#		#if (dryrun(send_command[r])) {
#		#	if (CLONE_MODE) continue
#		#	sub(/ \| .*/, "", send_command[r])
#		if (send_command[r] ~ "zfs create") {
#			if (dryrun(send_command[r])) continue
#			if (system(send_command[r])) {
#				report(LOG_ERROR, "failed to create parent dataset: " create_dataset[r])
#				stop(4)
#			}
#			continue
#		}
#		if (full_cmd) close(full_cmd)
#		if (receive_command[r]) replication_command = send_command[r] "|" receive_command[r]
#		else replication_command = send_command[r]
#		if (dryrun(replication_command)) continue
##		full_cmd = Opt["TIME_COMMAND"] " " Opt["SH_COMMAND_PREFIX"] " " replication_command " " Opt["SH_COMMAND_SUFFIX"] CAPTURE_OUTPUT
##		print full_cmd
#		#full_cmd = RPL_CMD_PREFIX dq(replication_command) CAPTURE_OUTPUT
#		full_cmd = Opt["SH_COMMAND_PREFIX"] " sh -c " dq(replication_command) " " Opt["SH_COMMAND_SUFFIX"] " " CAPTURE_OUTPUT
#		report(LOG_DEBUG, "running:" full_cmd)
#		if (stream_size[r]) report(LOG_NOTICE, source_stream[r]": sending " h_num(stream_size[r]))
#		replicate(full_cmd)
#	}
#
#	# Negative errors show the number of missed streams, otherwise show error code
#	stream_diff = received_streams - sent_streams
#	error_code = (error_code ? error_code : stream_diff)
#	#track_errors("")
#
#	# Exit if we didn't parse "zfs send"
#	if ((Opt["VERB"] == "clone") || !CAPTURE_OUTPUT) exit error_code
#	report(LOG_NOTICE, h_num(total_bytes) " sent, " received_streams "/" sent_streams " streams received in " zfs_replication_time " seconds")
#	stop(error_code)
}
