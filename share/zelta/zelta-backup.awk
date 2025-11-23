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
	if (opt["VERB"] == "clone") { 
		print " clone [-d max] source-dataset target-dataset\n"			> STDERR
	} else {
		usage_prefix = opt["VERB"] " "
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
	if (! opt[endpoint "_PREFIX"]) return _zfs
	else {
		_ssh = remote_type ? opt["REMOTE_" remote_type] : opt["REMOTE_DEFAULT"]
		_ssh = _ssh " " opt[endpoint "_PREFIX"] " "
	}
	return _ssh _zfs
}

function command_queue(send_dataset, receive_dataset, match_snapshot,	target_flags) {
	num_streams++
	if (!dataset) target_flags = " " opt["RECV_FLAGS_TOP"] " "
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
	if (opt["VERB"] == "clone") {
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

# Create endpoint shortcut variables; delete this probably
function get_endpoint_info(endpoint,	ep) {
	ep			= opt[endpoint "_ID"]
	snapshot[ep]		= opt[endpoint "_PREFIX"]
	ds[ep]			= opt[endpoint "_DS"]
	snapshot[ep]		= opt[endpoint "_SNAP"]
	# zfs[ep]			= opt[endpoint "_ZFS"]
	zfs[ep]			= zfs_cmd(endpoint)
	return ep
}

function load_verb_defaults() {
	if (opt["VERB"] == "backup") {
		opt["SEND_INTR"] 		= "-I"
		opt["SNAP_MODE"]	= "IF_NEEDED"
		opt["SEND_CHECK"]	= "yes"
	}
}

function load_options(o,args) {
	# Load acceptable zfs send/recv flag override lists
	split("-b,--backup,-c,--compressed,-D,--dedup,-e,--embed,-h,--holds,-L,--large-block,-p,--parsable,--proctitle,--props,--raw,--skip-missing,-V,-w",_f,",")
	for (_o in _f) _permitted_zfs_send_flags[_f[_o]]
	split("-e,-h,-M,-u",_f,",")
	for (_o in _f) _permitted_zfs_recv_flags[_f[_o]]

	# Handle: -X (pass if using -R otherwise skip if exact match)
	# Fix: -t for resume
	split(opt["ARGS"],args,"\t")
	for (i in args) {
		$0 = args[i]
		if ($0 in _permitted_zfs_send_flags)			override_send_flags = str_add(override_send_flags)
		else if ($0 in _permitted_zfs_recv_flags)		override_recv_flags = str_add(override_recv_flags)
		else if (sub(/^depth=?/,""))				depth = $0
		else if (sub(/^d ?/,""))				depth = $0
	       	else if (sub(/^exclude=/,""))				exclude_ds_list = $0
	       	else if (sub(/^X ?/,""))				exclude_ds_list = $0
		else if ($0 == "rotate")				opt["VERB"] = "rotate"
		else if ($0 == "replicate")				opt["VERB"] = "replicate"
		else if ($0 == "R")					opt["VERB"] = "replicate"
		else if ($0 ~ /^dry-?run$/)				opt["DRYRUN"] = "yes"
		else if ($0 == "n")					opt["DRYRUN"] = "yes"
		else if ($0 ~ "detect-?options")			opt["SEND_CHECK"] = "yes"
		else if ($0 ~ "send-?check")				opt["SEND_CHECK"] = "yes"
		else if ($0 == "i")					opt["SEND_INTR"] = "-i"
		else if ($0 == "I")					opt["SEND_INTR"] = "-I"
		else if ($0 ~ "^no-?json$")				opt["JSON"] = ""
		else if ($0 == "json")					opt["JSON"] = "yes"
		else if ($0 == "j")					opt["JSON"] = "yes"
		else if ($0 == "resume")				opt["RESUME"] = "yes"
		else if ($0 == "no-?resume")				opt["RESUME"] = ""
		else if ($0 == "snapshot")				opt["SNAP_MODE"] = "IF_NEEDED"
		else if ($0 == "snapshot")				opt["SNAP_MODE"] = "IF_NEEDED"
		else if ($0 == "snapshot[-=]?all")			opt["SNAP_MODE"] = "ALWAYS"
		else if ($0 == "snapshot[-=]?always")			opt["SNAP_MODE"] = "ALWAYS"
		else if ($0 == "snapshot[-=]?written")			opt["SNAP_MODE"] = "ALWAYS"
		else if ($0 == "snapshot[-=]?(or-)?skip")		opt["SNAP_MODE"] = "SKIP"
		else if ($0 == "s"){
			SNAPSHOT_WRITTEN++
			report(LOG_WARNING, "interpreting '-s' as --snapshot")
			report(LOG_WARNING, "option '-s' is ambiguous and will be deprecated; use --snapshot, --skip-missing, or --partial")
		}
		else if ($0 == "S") {
			SNAPSHOT_ALL++
			report(LOG_WARNING, "interpreting '-S' as --snapshot-always")
			report(LOG_WARNING, "option '-S' is ambiguous will be deprecated; use --snapshot-always, --skip-missing, or --partial")
		}
		else if ($0 == "clone") {
			opt["VERB"] = "clone"
			report(LOG_WARNING, "option '--clone' will be deprecated; use 'zelta clone'")
		}
		else if ($0 ~ "^(rate-?limit)|progress$") {
			report(LOG_WARNING, "option '--progress' is deprecated; use '--use-recv-pipe'")
		}
		else if ($0 == "z") {
			report(LOG_WARNING, "option 'z' is deprecated'")
		}
		else if ($0 == "t") {
			sync_direction = "push"
			report(LOG_WARNING, "option '-t' is deprecated; use '--push'")
		}
		else if ($0 == "T") {
			sync_direction = "push"
			report(LOG_WARNING, "option '-T' is deprecated; use '--pull' (default)")
		}
		else if ($0 == "F") {
			override_recv_flags = str_add(override_recv_flags)
			report(LOG_WARNING, "destructive option 'F' detected; consider 'zelta rotate' when possible")
		}
		# Command modifiers
		else usage("invalid option '"$0"'")
	}
}
	       
function get_config() {
	# Load environemnt variables and options and set up zfs send/receive flags
	opt["SEND_DEFAULT"]		= opt["SEND_DEFAULT"]
	opt["RECV_FLAGS_TOP"]		= opt["opt["RECV_FLAGS_TOP"]"]
	RECEIVE_PREFIX		= opt["RECEIVE_PREFIX"]

	source = get_endpoint_info("SRC")
	target = get_endpoint_info("TGT")

	MODE = "BASIC"
	# Don't interactive print:
	QUEUE_MODES["JSON"]++
	#QUEUE_MODES["PROGRESS"]++

	load_options()
	if (DETECT_OPTIONS) detect_send_options()

	if ((MODE == "PIPE") && (opt["LOG_LEVEL"] < 3)) opt["LOG_LEVEL"] = 3

	RPL_CMD_SUFFIX = ALL_OUT
	SEND_COMMAND = "send -P "
	RECEIVE_COMMAND = "receive -v "

	if ((opt["VERB"] == "replicate")) DEPTH = 1
	else if (DEPTH) {
		DEPTH = " -d" DEPTH
		PROP_DEPTH = "-d" (DEPTH-1)
	}
	match_cols = "relname,synccode,match,srcfirst,srclast,tgtlast,info"
	match_flags = "--time --log-level=2 -Hpo " match_cols DEPTH
	match_command = "zelta ipc-run match " match_flags ALL_OUT
	if (opt["VERB"] == "clone") {
		CLONE_FLAGS_TOP = opt["CLONE_FLAGS"]
		send_flags = "clone "
		return 1
	}
	if (! target) usage("target needed for replicaiton plan")
	opt["SEND_DEFAULT"] = opt["SEND_DEFAULT"] (opt["DRYRUN"]?"n":"") ((opt["VERB"] == "replicate")?"R":"")
	send_flags = SEND_COMMAND opt["SEND_DEFAULT"] " "
	recv_flags = RECEIVE_COMMAND RECV_FLAGS " "
	if (opt["SEND_INTR"] ~ "I") INTR++
	if (opt["VERB"] == "rotate") {
		INTR = 0
		opt["SEND_INTR"] = "-i"
	}
	intr_flags = opt["SEND_INTR"] " "
	create_flags = "-up"(opt["DRYRUN"]?"n":"")" "
}

# Exclude default send opitons if they aren't on the source
function detect_send_options() {
	cmd = "zelta sendopts " q(opt["SRC_PREFIX"]) " " q(opt["TGT_PREFIX"])
	cmd | getline options; close(cmd)
	split(options, optlist, "")
	for (opt in optlist) VALID_SEND_OPT[opt]++
	# THIS LOOKS INCOMPLETE!
}

function dry_run(command) {
	if (opt["DRYRUN"]) {
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

function stop(err, message) {
	time_end = sys_time()
	total_time = source_zfs_list_time + target_zfs_list_time + zfs_replication_time
	error_code = err
	if (message) report(LOG_WARNING, message)
	if (MODE == "JSON") output_json()
	else if (MODE == "PIPE") output_pipe()
	if (logged_messages) close(opt["LOG_COMMAND"])
	exit error_code
}

function load_properties(endpoint, prop) {
	ZFS_GET_LOCAL="get -Hpr -s local,none -t filesystem,volume -o name,property,value " PROP_DEPTH " all "
	#zfs_get_command = RPL_CMD_PREFIX dq(zfs[endpoint] " " ZFS_GET_LOCAL q(ds[endpoint])) ALL_OUT
	zfs_get_command = opt["TIME_COMMAND"] " " SH_COMMAND_PREFIX " " zfs[endpoint] " " ZFS_GET_LOCAL q(ds[endpoint]) SH_COMMAND_SUFFIX ALL_OUT
#DJB check this
exit
	while (zfs_get_command | getline) {
		
		if (sub("^"ds[endpoint],"",$1)) prop[$1,$2] = $3
		else if (sub(/^real[ \t]+/,"")) list_time[endpoint] += $0
		else if (/^[ \t]*(user|sys)/) {}
		else if (/dataset does not exist/) NO_DS[endpoint]++
		else report(LOG_WARNING,"property loading error: " $0)
	}
}

function run_snapshot() {
	# Shouldn't we know if the source is written or not by now?
	#source_is_written = arr_sum(srcprop, "written")
	do_snapshot = (SNAPSHOT_ALL || (SNAPSHOT_WRITTEN && source_is_written))
	if ((SNAPSHOT_WRITTEN > 1) && !do_snapshot) {
		report(LOG_NOTICE, "source not written")
		stop(0)
	} else if (!do_snapshot) return 0
	snapshot_command = "zelta ipc-run snapshot"
	if (dry_run(snapshot_command)) return
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
	slast		= (snapshot[source] ? snapshot[source] : $5) 
	tlast		= $6
	info		= $7 (tgtprop[dataset,"written"] ? "; target is written" : "")

	sourceds	= ds[source] dataset 
	targetds	= ds[target] dataset 
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
		sorigin_dataset = (opt["SRC_PREFIX"] ? opt["SRC_PREFIX"] ":" : "") sorigin
		clone_match = "zelta match -Hd1 -omatch,sync_code " q(sorigin_dataset) " " q(target dataset)
		while (clone_match | getline) {
			if (/^[@#]/) { 
				match_snap		= $1
				source_match		= sorigin match_snap
				if (opt["VERB"] == "rotate") tgt_behind	= 1
				else {
					report(LOG_WARNING, sourceds" is a clone of "source_match"; consider --rotate")
					return 0
				}
			}
		}
		close(clone_match)
	}
		

	if ((opt["VERB"] == "rotate")) {
		if (tgt_behind && !dataset) {
			torigin_name = ds[target] match_snap
			sub(/[#@]/, "_", torigin_name)
		}
		rotate_name = torigin_name dataset match_snap
	}
	return 1
}

# We need to know sync state, 
function plan_replication() {
	load_properties(source, srcprop)
	if (NO_DS[source]) stop(1, "source does not exist: "source)
	load_properties(target, tgtprop)
}

function plan_clone() {
	# ensure source and target are the same system or stop
	load_properties(source, srcprop)
	if (NO_DS[source]) stop(1, "source does not exist: "source)
	load_properties(target, tgtprop)
	#if (CLONE_MODE && !NO_DS[target]) stop(1, "cannot clone; target exists: "target)
	# if no snapshot is given find the latest snapshot with zelta match
}


BEGIN {
	STDOUT = "/dev/stdout"
	ALL_OUT = " 2>&1"
	get_config()

	received_streams = 0
	total_bytes = 0
	total_time = 0
	error_code = 0
	time_start = sys_time()
	

	zfs_send_command = zfs[source] " " send_flags
	zfs_receive_command = zfs_cmd("TGT", "RECV") " " recv_flags

	# Update in dev, merge this maybe
	#load_properties(source, srcprop)
	#if (NO_DS[source]) stop(1, "source does not exist: "source)
	#load_properties(target, tgtprop)
	#if (CLONE_MODE && !NO_DS[target]) stop(1, "cannot clone; target exists: "target)

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
				send_command[++rpl_num] = zfs[target] " create " create_flags q($0)
				create_dataset[rpl_num] = $6
			} else  { report(LOG_WARNING, "unexpected line: " $0) }
			continue
		}
		if (src_only) {
			if (INTR && !single_snap) {
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
	
	if (opt["VERB"] == "rotate") {
		if (!torigin_name) stop(5, "no match available for requested rotation")
		rename_command = zfs[target] " rename " q(ds[target]) " " q(torigin_name)
		if (! dry_run(rename_command)) {
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
		stop(error_code, "")
	}
	
	FS = "[ \t]+"
	received_streams = 0
	total_bytes = 0
	if (LOG_MODE == "PROGRESS") {
		report(LOG_INFO, "calculating transfer size")
		for (r = 1; r <= rpl_num; r++) {
			if (full_cmd) close(full_cmd)
			full_cmd = RPL_CMD_PREFIX dq(est_cmd[r]) ALL_OUT
			while (full_cmd | getline) {
				if ($1 == "size") {
					stream_size[r] = $2
					total_transfer_size += $2
				}
			}
		}
		estimate = ", " h_num(total_transfer_size)
	}
	estimate = ((opt["VERB"] == "clone") ? "cloning " : "replicating ") rpl_num " streams" estimate
	report(LOG_NOTICE, estimate)
	for (r = 1; r <= rpl_num; r++) {
		#if (dry_run(send_command[r])) {
		#	if (CLONE_MODE) continue
		#	sub(/ \| .*/, "", send_command[r])
		if (send_command[r] ~ "zfs create") {
			if (dry_run(send_command[r])) continue
			if (system(send_command[r])) {
				stop(4, "failed to create parent dataset: " create_dataset[r])
			}
			continue
		}
		if (full_cmd) close(full_cmd)
		if (receive_command[r]) replication_command = send_command[r] "|" receive_command[r]
		else replication_command = send_command[r]
		if (dry_run(replication_command)) continue
#		full_cmd = opt["TIME_COMMAND"] " " opt["SH_COMMAND_PREFIX"] " " replication_command " " opt["SH_COMMAND_SUFFIX"] ALL_OUT
#		print full_cmd
		#full_cmd = RPL_CMD_PREFIX dq(replication_command) RPL_CMD_SUFFIX
		full_cmd = opt["SH_COMMAND_PREFIX"] " sh -c " dq(replication_command) " " opt["SH_COMMAND_SUFFIX"] " " ALL_OUT
		report(LOG_DEBUG, "running:" full_cmd)
		if (stream_size[r]) report(LOG_NOTICE, source_stream[r]": sending " h_num(stream_size[r]))
		replicate(full_cmd)
	}

	# Negative errors show the number of missed streams, otherwise show error code
	stream_diff = received_streams - sent_streams
	error_code = (error_code ? error_code : stream_diff)
	#track_errors("")

	# Exit if we didn't parse "zfs send"
	if ((opt["VERB"] == "clone") || !RPL_CMD_SUFFIX) exit error_code
	report(LOG_NOTICE, h_num(total_bytes) " sent, " received_streams "/" sent_streams " streams received in " zfs_replication_time " seconds")
	stop(error_code, "")
}
