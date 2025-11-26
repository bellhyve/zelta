#!/usr/bin/awk -f
#
# zelta-backup.awk, zelta (replicate|backup|sync|clone) - replicates remote or local trees
#   of zfs datasets
# 
# After using "zelta match" to identify out-of-date snapshots on the target, this script creates
# replication streams to synchronize the snapshots of a dataset and its children. This script is
# useful for backup, migration, and failover scenarios. It intentionally does not have a rollback
# feature, and instead uses a "rotate" feature to rename and clone the diverged replica.

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
	print "For further help on a command or topic, run: zelta help [<topic>]"	> STDERR
	exit 1
}

# Do I even need this?
function zfs_cmd(endpoint, remote_type,		_ssh, _zfs) {
	_zfs = "zfs"
	if (! Opt[endpoint "_PREFIX"]) return _zfs
	else {
		_ssh = remote_type ? Opt["REMOTE_" remote_type] : Opt["REMOTE_DEFAULT"]
		_ssh = _ssh " " Opt[endpoint "_PREFIX"] " "
	}
	return _ssh _zfs
}

function command_queue(send_dataset, receive_dataset, match_snapshot,	target_flags) {
	num_streams++
	if (!dataset) target_flags = " " Opt["RECV_FLAGS_TOP"] " "
	if (torigin_name) target_flags = " -o origin=" q(rotate_name) " " target_flags
	if (zfs_send_command ~ /ssh/) {
		gsub(/ /, "\\ ", send_dataset)
		gsub(/ /, "\\ ", match_snapshot)
	}
	if (zfs_receive_command ~ /ssh/) {
		gsub(/ /, "\\ ", receive_dataset)
		gsub(/ /, "\\ ", target_flags)
	}
	if (receive_dataset) receive_part = zfs_receive_command target_flags q(receive_dataset)
	if (Opt["VERB"] == "clone") {
		if (!dataset) target_flags = " " CLONE_FLAGS_TOP " "
		send_command[++rpl_num] = zfs_send_command target_flags q(send_dataset) " " q(receive_dataset)
		source_stream[rpl_num] = send_dataset
	} else if (match_snapshot) {
		send_part = intr_flags q(match_snapshot) " " q(send_dataset)
		send_command[++rpl_num] = zfs_send_command send_part
		receive_command[rpl_num] = receive_part
		est_cmd[rpl_num] = zfs_send_command "-Pn " send_part
		source_stream[rpl_num] = match_snapshot "::" send_dataset
		# zfs list xfersize sucks so find xfersize from a zfs send -n instead
		# stream_size[rpl_num] = xfersize
	} else {
		send_command[++rpl_num] = zfs_send_command source_flags q(send_dataset)
		receive_command[rpl_num] = receive_part
		est_cmd[rpl_num] = zfs_send_command "-Pn " q(send_dataset)
		source_stream[rpl_num] = send_dataset
		#stream_size[rpl_num] = xfersize
	}
}

function get_config() {
	SEND_COMMAND = "send -P "
	RECEIVE_COMMAND = "receive -v "

	if ((Opt["VERB"] == "replicate")) DEPTH = 1
	else if (DEPTH) {
		DEPTH = " -d" DEPTH
		PROP_DEPTH = "-d" (DEPTH-1)
	}
	match_cols = "relname,synccode,match,srcfirst,srclast,tgtlast,info"
	match_flags = "--time --log-level=2 -Hpo " match_cols DEPTH
	match_command = "zelta ipc-run match " match_flags CAPTURE_OUTPUT
	if (Opt["VERB"] == "clone") {
		CLONE_FLAGS_TOP = Opt["CLONE_FLAGS"]
		send_flags = "clone "
		return 1
	}
	if (! Opt["TGT_DS"]) usage("target needed for replicaiton plan")
	Opt["SEND_DEFAULT"] = Opt["SEND_DEFAULT"] (Opt["DRYRUN"]?"n":"") ((Opt["VERB"] == "replicate")?"R":"")
	send_flags = SEND_COMMAND Opt["SEND_DEFAULT"] " "
	recv_flags = RECEIVE_COMMAND RECV_FLAGS " "

	intr_flags = Opt["SEND_INTR"] ? "-I" : "-i"
	create_flags = "-up"(Opt["DRYRUN"]?"n":"")" "
}

function dryrun(command) {
	if (Opt["DRYRUN"]) {
		if (command) print "+ "command
		return 1
	} else { return 0 }
}

function j(e) {
	if (e == "") return "null"
	else if (e ~ /^-?[0-9\.]+$/) return e
	else return "\""e"\""
}

function jpair(name, val) {
	printf "  "j(name)": "j(val)
	return ","
}

function jlist(name, msg_list) {
	printf "  \""name"\": ["
	list_len = 0
	for (n in msg_list) list_len++
	if (list_len) {
		print ""
		for (n=1;n<=list_len;n++) {
			gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", msg_list[n])
			gsub(/\n/, "; ", msg_list[n])
			gsub(/"/, "'", msg_list[n])
			printf "    \""msg_list[n]"\""
			if (n<list_len) print ","
		}
		printf "\n  "
	}
	printf "]"
	return ",\n"
}

function output_json() {
	print "{"
	print jpair("startTime",time_start)
	print jpair("endTime",time_end)
	print jpair("sourceUser",user[source])
	print jpair("sourceHost",host[source])
	print jpair("sourceDataset",ds[source])
	print jpair("sourceListTime",source_zfs_list_time)
	print jpair("targetUser",user[target])
	print jpair("targetHost",host[target])
	print jpair("targetDataset",ds[target])
	print jpair("targetListTime",target_zfs_list_time)
	print jpair("replicationSize",total_bytes)
	print jpair("replicationStreamsSent",sent_streams)
	print jpair("replicationStreamsReceived",received_streams)
	print jpair("replicationErrorCode",error_code)
	print jpair("replicationTime",zfs_replication_time)
	printf jlist("sentStreams", source_stream)
	jlist("errorMessages", error_list)
	print "\n}"
}

function output_pipe() {
	print received_streams, total_bytes, total_time, error_code 
	return error_code
}

# Load properties for an endpoint
function load_properties(ep, props,	_ds, _zfs_get_arr, _zfs_get_cmd, _idx) {
	_ds = Opt[ep "_DS"]
	_zfs_get_arr[++_idx] = zfs_cmd(ep)
	_zfs_get_arr[++_idx] = "get -Hpr -s local,none -t filesystem,volume -o name,property,value"
	if (Depth) _zfs_get_arr[++_idx] = "-d" (Depth-1)
	_zfs_get_arr[++_idx] = "all"
	_zfs_get_arr[++_idx] = q(_ds)
	_zfs_get_cmd = str_join(_zfs_get_arr)
	report(LOG_INFO, "checking properties for " Opt[ep"_ID"])
	report(LOG_DEBUG, "`"_zfs_get_cmd"`")
	while (_zfs_get_cmd CAPTURE_OUTPUT | getline) {
		if (sub("^"_ds,"",$1)) props[$1,$2] = $3
		else if (/dataset does not exist/) {
			close(_zfs_get_command)
			return 0
		}
		else report(LOG_WARNING,"unexpected 'zfs get' output: " $0)
	}
	return 1
}

# Do this right before sending using a no-op
function zfs_send_options_check() {
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
}

function load_zelta_match_variable() {
	if ($1 == "SOURCE_LIST_TIME:")		source_list_time += $2
	else if ($1 == "TARGET_LIST_TIME:")	target_list_time += $2
	else return 0
	return 1
}

function load_dataset_relationship(zm_row) {
	delete zm_row
	zm_row["name"]		= $1
	zm_row["match"]		= $2
	zm_row["srcfirst"]	= $3
	zm_row["srclast"]	= Opt["SRC_SNAP"] ? Opt["SRC_SNAP"] : $4
	zm_row["tgtlast"]	= $5
	zm_row["status"]	= $6
	zm_row["tgtwritten"]	= tgtprops[$1,"written"]
}

function load_snapshot_deltas(_zelta_match_arr, _zelta_match_command, _idx) {
	FS = "\t"
	_zelta_match_arr[++_idx]		= "zelta ipc-run match"
	_zelta_match_arr[++_idx]		= "--time --log-level=2"
	if (Depth) _zelta_match_arr[++_idx]	= "-d" Depth
	_zelta_match_arr[++_idx]		= "-Hpo relname,match,srcfirst,srclast,tgtlast,status"
	_zelta_match_command			= str_join(_zelta_match_arr)
	report(LOG_INFO, "checking replica deltas")
	report(LOG_DEBUG, "`"_zelta_match_command"`")
        while (_zelta_match_command | getline) {
		if (!$6) {
			load_zelta_match_variable()
		} else { 
			load_dataset_relationship(zm_row)
		}
	}

#                if (!name_match_row()) {
#                        if ($1 == "SOURCE_LIST_TIME:") {
#                                source_zfs_list_time += $2
#                        } else if ($1 == "TARGET_LIST_TIME:") {
#                                target_zfs_list_time += $2
#                        } else if (/error|Warning/) {
#                                error_code = 1
#                                report(LOG_WARNING, $0)
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
#        close(_zelta_match_command)
	exit
}

function run_snapshot() {
	# Shouldn't we know if the source is written or not by now?
	#source_is_written = arr_sum(srcprop, "written")
	do_snapshot = (SNAPSHOT_ALL || (SNAPSHOT_WRITTEN && source_is_written))
	if ((SNAPSHOT_WRITTEN > 1) && !do_snapshot) {
		report(LOG_NOTICE, "source not written")
		stop()
	} else if (!do_snapshot) return 0
	snapshot_command = "zelta ipc-run snapshot"
	if (dryrun(snapshot_command)) return
	while (snapshot_command | getline snapline) {
		if (sub(/^snapshot created:[^@]*/,"",snapline)) {
			source_latest = snapline
			report(LOG_NOTICE, "source snapshot created: "snapline)
		}
	}
	if (!source_latest) report(LOG_WARNING, "snapshot failed")
	return source_latest
}

function replicate(command) {
	while (command | getline) {
		if ($1 == "incremental" || $1 == "full") sent_streams++
		else if ($1 == "received") {
			report(LOG_INFO, source_stream[r]": "$0)
			received_streams++
		} else if ($1 == "size") {
			report(LOG_INFO, source_stream[r]": sending " h_num($2))
			total_bytes += $2
		} else if ($1 ~ /:/ && $2 ~ /^[0-9]+$/) {
			# Is this still working?
			siginfo(source_stream[r]": "h_num($2) " received")
		} else if (/cannot receive (mountpoint|canmount)/) {
			report(LOG_WARNING, $0)
		} else if (/failed to create mountpoint/) {
			# This is expected with restricted access
			report(LOG_DEBUG, $0)
		} else if (/Warning/ && /mountpoint/) {
			report(LOG_INFO, $0)
		} else if (/Warning/) {
			report(LOG_NOTICE, $0)
		} else if ($1 == "real") zfs_replication_time += $2
		else if (/^(sys|user)[ \t]+[0-9]/) { }
		else if (/ records (in|out)$/) { }
		else if (/bytes.*transferred/) { }
		else if (/receiving/ && /stream/) { }
		else if (/ignoring$/) { }
		else {
			report(LOG_WARNING, "unexpected output in replication stream: " $0)
			error_code = 2
		}
	}
	close(command)
}

function initialize_sync_code(	i,j) {
	for (i = 1; i <= length(sync_code); i++) {
		digit = substr(sync_code, i, 1)
		for (j = 0; j < 3; j++) {
			bit[3*(i-1) + j + 1] = int(digit / (2^(2-j))) % 2
		}
	}
	src_written		= bit[1]
	src_has_snap		= bit[2]
	src_exists		= bit[3]
	tgt_latest_match	= bit[4]
	src_latest_match	= bit[5]
	trees_match		= bit[6]
	tgt_written		= bit[7]
	tgt_has_snap		= bit[8]
	tgt_exists		= bit[9]
}

function get_update_option() {
	initialize_sync_code()
	tgt_written	= (tgt_written || tgtprop[dataset,"written"])
	src_only	= (src_has_snap && !tgt_exists)
	tgt_behind	= (tgt_latest_match && !src_latest_match)
	tgt_blocked	= (!tgt_latest_match || tgt_written)
	up_to_date	= (src_latest_match && tgt_latest_match)
	check_origin	= (src_has_snap && !trees_match && tgt_has_snap && sorigin)
}

function name_match_row() {
	# match_cols = "relname,synccode,match,srcfirst,srclast,tgtlast,info"
	if ($2 !~ /^[0-9][0-7][0-7]$/) return 0

	dataset		= $1
	sync_code	= $2
	match_snap	= $3
	sfirst		= $4
	slast		= (Opt["SRC_SNAP"] ? Opt["SRC_SNAP"] : $5) 
	tlast		= $6
	info		= $7 (tgtprop[dataset,"written"] ? "; target is written" : "")

	sourceds	= Opt["SRC_DS"] dataset 
	targetds	= Opt["TGT_DS"] dataset 
	sfirst_full	= sourceds sfirst
	slast_full	= sourceds slast
	tlast_full	= targetds tlast
	target_match	= targetds match_snap
	source_match	= sourceds match_snap

	single_snap	= (sfirst && (sfirst == slast))
	sorigin		= srcprop[dataset,"origin"]
	match_origin	= ""
	rotate_name	= ""
	
	# Compute update path
	get_update_option()

	# No match. Was the source renamed?
	if (check_origin) {
		sub(/[#@].*/, "", sorigin)
		sorigin_dataset = (Opt["SRC_PREFIX"] ? Opt["SRC_PREFIX"] ":" : "") sorigin
		clone_match = "zelta match -Hd1 -omatch,sync_code " q(sorigin_dataset) " " q(Opt["TGT_ID"] dataset)
		while (clone_match | getline) {
			if (/^[@#]/) { 
				match_snap		= $1
				source_match		= sorigin match_snap
				if (Opt["VERB"] == "rotate") tgt_behind	= 1
				else {
					report(LOG_WARNING, sourceds" is a clone of "source_match"; consider --rotate")
					return 0
				}
			}
		}
		close(clone_match)
	}
		

	if ((Opt["VERB"] == "rotate")) {
		if (tgt_behind && !dataset) {
			torigin_name = Opt["TGT_DS"] match_snap
			sub(/[#@]/, "_", torigin_name)
		}
		rotate_name = torigin_name dataset match_snap
	}
	return 1
}

function validate_source_dataset() {
	if (!load_properties("SRC",srcprops)) {
		report(LOG_ERROR, "source dataset '"Opt["SRC_ID"]"' does not exist")
		stop(1)
	}
}

function plan_clone() {
	if (Opt["SRC_PREFIX"] != Opt["TGT_PREFIX"]) {
		report(LOG_ERROR, "clone target endpoint must use the same user, host, and zfs pool as the source")
		stop(1)
	}
	if (load_properties("TGT", tgtprops)) {
		report(LOG_ERROR, "cannot clone; target dataset '"Opt["TGT_ID"]"' exists")
		stop(1)
	}
}

function plan_backup() {
	if (Opt["PROP_CHECK"] && !load_properties("TGT", tgtprops)) taret_does_not_exist++
	load_snapshot_deltas()

	#zfs_send_options_check() # do this during dryrun step
}

BEGIN {
	CAPTURE_OUTPUT = " 2>&1"
	if (Opt["USAGE"]) usage()
	validate_source_dataset()
	if (Opt["VERB"] == "clone")		plan_clone()
	else					plan_backup()

	get_config()	# Drop this
	received_streams = 0
	total_bytes = 0
	total_time = 0
	error_code = 0
	time_start = sys_time()
	
	zfs_send_command = zfs_cmd("SRC", "SEND") " " send_flags
	zfs_receive_command = zfs_cmd("TGT", "RECV") " " recv_flags

	run_snapshot()
	FS = "[\t]"
	report(LOG_DEBUG, "running: " match_command)
	while (match_command | getline) {
		if (!name_match_row()) {
			if ($1 == "SOURCE_LIST_TIME:") {
				source_zfs_list_time += $2
			} else if ($1 == "TARGET_LIST_TIME:") {
				target_zfs_list_time += $2
			} else if (/error|Warning/) {
				error_code = 1
				report(LOG_WARNING, $0)
			} else if (sub(/^parent dataset does not exist: +/,"")) {
				send_command[++rpl_num] = zfs_cmd("TGT", "RECV") " create " create_flags q($0)
				create_dataset[rpl_num] = $6
			} else  { report(LOG_WARNING, "unexpected line: " $0) }
			continue
		}
		if (src_only) {
			if (Opt["SEND_INTR"] && !single_snap) {
							command_queue(sfirst_full, targetds)
							command_queue(slast_full, targetds, sfirst)
			} else				command_queue(slast_full, targetds)
		} else if (tgt_behind && !tgt_written) {
							command_queue(slast_full, targetds, source_match)
		} else if (torigin_name && match_snap) {
							command_queue(slast_full, targetds, source_match)
		} else if (up_to_date) {
			report(LOG_INFO, targetds ": "info)
			synced_count++
		} else report(LOG_WARNING, targetds": "info)
	}
	close(match_command)
	
	if (Opt["VERB"] == "rotate") {
		if (!torigin_name) {
			report(LOG_ERROR, "no match available for requested rotation")
			stop(5)
		}
		rename_command = zfs_cmd("TGT","RECV") " rename " q(Opt["TGT_DS"]) " " q(torigin_name)
		if (! dryrun(rename_command)) {
			system(rename_command)
			report(LOG_NOTICE, "target renamed to " q(torigin_name))
		}
	}

	if (!num_streams) {
		if (synced_count) report(LOG_NOTICE, "nothing to replicate")
		else {
			error_code = 5
			report(LOG_NOTICE, "match error")
		}
		stop(error_code)
	}
	
	FS = "[ \t]+"
	received_streams = 0
	total_bytes = 0
	if (LOG_MODE == "PROGRESS") {
		report(LOG_INFO, "calculating transfer size")
		for (r = 1; r <= rpl_num; r++) {
			if (full_cmd) close(full_cmd)
			full_cmd = RPL_CMD_PREFIX dq(est_cmd[r]) CAPTURE_OUTPUT
			while (full_cmd | getline) {
				if ($1 == "size") {
					stream_size[r] = $2
					total_transfer_size += $2
				}
			}
		}
		estimate = ", " h_num(total_transfer_size)
	}
	estimate = ((Opt["VERB"] == "clone") ? "cloning " : "replicating ") rpl_num " streams" estimate
	report(LOG_NOTICE, estimate)
	for (r = 1; r <= rpl_num; r++) {
		#if (dryrun(send_command[r])) {
		#	if (CLONE_MODE) continue
		#	sub(/ \| .*/, "", send_command[r])
		if (send_command[r] ~ "zfs create") {
			if (dryrun(send_command[r])) continue
			if (system(send_command[r])) {
				report(LOG_ERROR, "failed to create parent dataset: " create_dataset[r])
				stop(4)
			}
			continue
		}
		if (full_cmd) close(full_cmd)
		if (receive_command[r]) replication_command = send_command[r] "|" receive_command[r]
		else replication_command = send_command[r]
		if (dryrun(replication_command)) continue
#		full_cmd = Opt["TIME_COMMAND"] " " Opt["SH_COMMAND_PREFIX"] " " replication_command " " Opt["SH_COMMAND_SUFFIX"] CAPTURE_OUTPUT
#		print full_cmd
		#full_cmd = RPL_CMD_PREFIX dq(replication_command) CAPTURE_OUTPUT
		full_cmd = Opt["SH_COMMAND_PREFIX"] " sh -c " dq(replication_command) " " Opt["SH_COMMAND_SUFFIX"] " " CAPTURE_OUTPUT
		report(LOG_DEBUG, "running:" full_cmd)
		if (stream_size[r]) report(LOG_NOTICE, source_stream[r]": sending " h_num(stream_size[r]))
		replicate(full_cmd)
	}

	# Negative errors show the number of missed streams, otherwise show error code
	stream_diff = received_streams - sent_streams
	error_code = (error_code ? error_code : stream_diff)
	#track_errors("")

	# Exit if we didn't parse "zfs send"
	if ((Opt["VERB"] == "clone") || !CAPTURE_OUTPUT) exit error_code
	report(LOG_NOTICE, h_num(total_bytes) " sent, " received_streams "/" sent_streams " streams received in " zfs_replication_time " seconds")
	stop(error_code)
}
