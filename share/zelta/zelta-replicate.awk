#!/usr/bin/awk -f
#
# zelta-replicate.awk, zelta (replicate|backup|sync|clone) - replicates remote or local trees
#   of zfs datasets
# 
# After using "zelta match" to identify out-of-date snapshots on the target, this script creates
# replication streams to synchronize the snapshots of a dataset and its children. This script is
# useful for backup and migration operations. It intentionally does not have a rollback feature,
# and instead assumes (or attempts to make) the backup target readonly.
#
# If called with the argument "-z" zelta sync reports an abbreviated output for single-line
# reporting, as provided by the default "zelta policy" output:
#
# 	received_streams, total_bytes, time, error
#
# See the zelta.env.sample and usage output for further details.
#
# ZELTA_PIPE "-z" output key:
# error_code <0: number of failed streams
# error_code 0: replicated or up-to-date
# error_code 1: warnings
# error_code 2: replication error
# error_code 3: target is ahead of source

function track_errors(message) {
	if (!message && !error_count) return 0
	else if (message == last_error) {
		++error_count
		if (error_count >1) return 0
	} else if (error_count > 2) {
		message = "above error repeated "error_count" times"
		error_count = 0
	} else last_error = message
	if (MODE in QUEUE_MODES) error_list[++err_num] = message
	else print message > STDOUT
}

function report(mode, message) {
	if (!message || (LOG_LEVEL <  mode)) return 0
	if (mode < 0) track_errors(message)
	else if (MODE in QUEUE_MODES) buffered_messages = buffered_messages message "\n"
	else print message
}	
function siginfo(message) {
	print buffered_messages message > STDOUT
	buffered_messages = ""
	track_errors()
}

function usage(message) {
	STDERR = "/dev/stderr"
	if (message) print message							> STDERR
	print "usage:"									> STDERR
	print "	backup [-bcDeeFhhLMpuVw] [-iIjnpqRtTv] [-d max]"			> STDERR
	print "	       [initiator] source-endpoint target-endpoint\n"			> STDERR
	print "	sync [-bcDeeFhhLMpuVw] [-iIjnpqRtTv] [-d max]"				> STDERR
	print "	     [initiator] source-endpoint target-endpoint\n"			> STDERR
	print "	clone [-d max] source-dataset target-dataset\n"				> STDERR
	print "For further help on a command or topic, run: zelta help [<topic>]"	> STDERR
	stop(1)
}

function env(env_name, var_default) {
	env_prefix = "ZELTA_"
	if ((env_prefix env_name) in ENVIRON) return ENVIRON[env_prefix env_name] 
	else if (env_name in ENVIRON) return ENVIRON[env_name]
	else return (var_default ? var_default : "")
}

function arr_sum(arr, variable) {
	for (i in arr) {
		split(i, pair, SUBSEP)
		if (pair[2] == variable) sum += arr[i]
	}
	return (sum ? sum : 0)
}

function q(s) { return "'" s "'" }

function dq(s) { return "\"" s "\"" }

function command_queue(send_dataset, receive_dataset, match_snapshot,	target_flags) {
	num_streams++
	if (!dataset) target_flags = " " RECEIVE_FLAGS_TOP " "
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
	if (CLONE_MODE) {
		send_command[++rpl_num] = zfs_send_command q(send_dataset) " " q(receive_dataset)
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

function opt_var() {
	var = ($0 ? $0 : ARGV[++i])
	$0 = ""
	return var
}

function get_options() {
	ZFS_SEND_PASS_OPTS["--dedup"]++
	ZFS_SEND_PASS_OPTS["--large-block"]++
	ZFS_SEND_PASS_OPTS["--parsable"]++
	ZFS_SEND_PASS_OPTS["--proctitle"]++
	ZFS_SEND_PASS_OPTS["--embed"]++
	ZFS_SEND_PASS_OPTS["--backup"]++
	ZFS_SEND_PASS_OPTS["--compressed"]++
	ZFS_SEND_PASS_OPTS["--raw"]++
	ZFS_SEND_PASS_OPTS["--holds"]++
	ZFS_SEND_PASS_OPTS["--props"]++
	ZFS_SEND_PASS_OPTS["--skip-missing"]++
	ZFS_SEND_PASS_OPTLIST = "DLVebcwhp"
	# Handle: -X (pass if using -R otherwise skip if exact match)
	# Handle: --redact, -d
	# Fix: -S for resume
	# Fix: -s for skip missing
	# Fix: -t for resume
	ZFS_RECV_PASS_OPTLIST = "FehMu"
	# Fix: -d for deduplicate
	# Fix: -s for save stream
	for (i=1;i<ARGC;i++) {
		$0 = ARGV[i]
		if ($0 in ZFS_SEND_PASS_OPTS) {
			SEND_FLAGS = (SEND_FLAGS ? " " : "") $0
		} else if (gsub(/^-/,"")) {
			while (/./) {
				# Long options
				if (sub(/^-initiator=?/,""))		INITIATOR = opt_var()
				else if (sub(/^-clone/,""))		CLONE_MODE++
				else if (sub(/^-rotate/,""))		ROTATE++
				else if (sub(/^-replicate/,""))		REPLICATE++
				else if (sub(/^-dryrun/,""))		DRY_RUN++
				else if (sub(/^-detect-options/,""))	DETECT_OPTIONS++
				else if (sub(/^-depth=?/,""))		DEPTH = opt_var()
				else if (sub(/^-rate-limit=?/,""))	LIMIT_BANDWIDTH = opt_var()
				else if ($0 ~ "^["ZFS_SEND_PASS_OPTLIST"]") {
					opt = substr($0, 1, 1)
					SEND_FLAGS = (SEND_FLAGS ? " " : "") "-" opt
					sub(/^./, "", $0)
				}
				else if ($0 ~ "^["ZFS_RECV_PASS_OPTLIST"]") {
					opt = substr($0, 1, 1)
					RECEIVE_FLAGS = (RECEIVE_FLAGS ? " " : "") "-" opt
					sub(/^./, "", $0)
				}
				# Log modes
				# Default output mode: BASIC
				else if (sub(/^j/,"")) MODE = "JSON"
				else if (sub(/^z/,"")) MODE = "PIPE"
				else if (sub(/^p/,"")) MODE = "PROGRESS"
				else if (sub(/^q/,"")) LOG_LEVEL--
				else if (sub(/^v/,"")) LOG_LEVEL++
				# Command modifiers
				# FRIENDLY_FORCE += gsub(/F/,"")
				else if (sub(/^i/,"")) INTR_FLAGS = "-i"
				else if (sub(/^I/,"")) INTR_FLAGS = "-I"
				else if (sub(/^M/,"")) RECEIVE_FLAGS = ""
				else if (sub(/^n/,"")) DRY_RUN++
				else if (sub(/^R/,"")) REPLICATE++
				else if (sub(/^s/,"")) SNAPSHOT_WRITTEN++
				else if (sub(/^S/,"")) SNAPSHOT_ALL++
				else if (sub(/^t/,"")) TRANSFER_FROM_SOURCE
				else if (sub(/^T/,"")) TRANSFER_FROM_TARGET
				else if (sub(/^d/,"")) DEPTH = opt_var()
				else if (/./) usage("unknown or extra options: " $0)
			}
		} else if (target && INITIATOR) {
			usage("too many options: " $0)
		} else if (target) {
			# To-do: Clunky handling of optional initiator
			INITIATOR = source
			source = target
			target = $0
		} else if (source) target = $0
		else source = $0
	}

}
	       
function get_config() {
	# Load environemnt variables and options and set up zfs send/receive flags
	SHELL_WRAPPER = env("WRAPPER", "sh -c")
	SSH_SEND = env("REMOTE_SEND_COMMAND", "ssh -n")
	SSH_RECEIVE = env("REMOTE_RECEIVE_COMMAND", "ssh")
	SEND_FLAGS = env("SEND_FLAGS", "-Lce")
	SEND_FLAGS_NEW = env("SEND_FLAGS_NEW", "-p")
	SEND_FLAGS_ENCRYPTED = env("SEND_FLAGS_ENC", "-w")
	RECEIVE_FLAGS_FS = env("RECEIVE_FLAGS_FS", "-u")
	RECEIVE_FLAGS_NEW_FS = env("RECEIVE_FLAGS_NEW_FS", "-x mountpoint")
	RECEIVE_FLAGS_NEW_VOL = env("RECEIVE_FLAGS_NEW_VOL")
	RECEIVE_FLAGS_TOP = env("RECEIVE_FLAGS_TOP", "-o readonly=on")
	INTR_FLAGS = env("INTR_FLAGS", "-i")
	RECEIVE_PREFIX = env("RECEIVE_PREFIX")

	LOG_LEVEL = 0
	MODE = "BASIC"
	# Don't interactive print:
	QUEUE_MODES["JSON"]++
	#QUEUE_MODES["PROGRESS"]++

	# Change this to a scale:
	LOG_ERROR = -2
	LOG_WARNING = -1
	LOG_BASIC = 0
	LOG_VERBOSE = 1
	LOG_VV = 2

	get_options()
	get_endpoint_info(source)
	get_endpoint_info(target)
	if (DETECT_OPTIONS) detect_send_options()

	if (TRANSFER_FROM_SOURCE) INITIATOR = prefix[source]
	if (TRANSFER_FROM_TARGET) INITIATOR = prefix[target]
	if (INITIATOR) report(LOG_VERBOSE, "transferring via: "INITIATOR)
	if (MODE == "PIPE") LOG_LEVEL--
	if (MODE == "PROGRESS") {
		RPL_CMD_SUFFIX = ""
		TIME_COMMAND = ""
		SEND_COMMAND = "send "
		RECEIVE_COMMAND = "receive "
		if (!system("which pv > /dev/null")) {
			PROGRESS = "pv"
			RECEIVE_PREFIX="pv -pebtrs # | "
		} else RECEIVE_PREFIX="dd status=progress |"
		report(LOG_VERBOSE,"using progress pipe: " RECEIVE_PREFIX)
	} else {
		RPL_CMD_SUFFIX = ALL_OUT
		SEND_COMMAND = "send -P "
		RECEIVE_COMMAND = "receive -v "
	}
	if (LOG_LEVEL >= 2) {
		RPL_CMD_SUFFIX = ""
		TIME_COMMAND = ""
		SEND_COMMAND = "send -v "
	}
	if (INITIATOR) SHELL_WRAPPER = SSH_SEND INITIATOR
	RPL_CMD_PREFIX = TIME_COMMAND SHELL_WRAPPER" "
	if (REPLICATE) DEPTH = 1
	if (DEPTH) PROP_DEPTH = "-d"(DEPTH-1)" "
	if (DEPTH) DEPTH = "-d"DEPTH" "
	match_cols = "relname,synccode,match,srcfirst,srclast,tgtlast,info"
	match_flags = "--no-written -Hpo "match_cols" "DEPTH
	match_command = SHELL_WRAPPER" "dq("zelta match " match_flags q(source) " " q(target))
	if (CLONE_MODE) {
		send_flags = "clone -o readonly=off "
		return 1
	}
	if (FORCE) {
		report(LOG_WARNING,"using 'zfs receive -F'")
		RECEIVE_FLAGS = RECEIVE_FLAGS" -F"
	}
	if (! target) usage()
	SEND_FLAGS = SEND_FLAGS (DRY_RUN?"n":"") (REPLICATE?"R":"")
	send_flags = SEND_COMMAND SEND_FLAGS " "
	recv_flags = RECEIVE_COMMAND RECEIVE_FLAGS " "
	if (INTR_FLAGS ~ "I") INTR++
	if (ROTATE) {
		INTR = 0
		INTR_FLAGS = "-i"
	}
	intr_flags = INTR_FLAGS " "
	create_flags = "-up"(DRY_RUN?"n":"")" "
}

function get_endpoint_info(endpoint) {
	FS = "\t"
	endpoint_command = "zelta endpoint " endpoint
	endpoint_command | getline
	prefix[endpoint]	= $2
	user[endpoint]		= $3
	host[endpoint]		= $4
	ds[endpoint]		= $5
	snapshot[endpoint]	= ($6?"@"$6:"")
	close("zelta endpoint " endpoint)
}

function detect_send_options() {
	cmd = "zelta sendopts " q(prefix[source]) " " q(prefix[target])
	cmd | getline options; close(cmd)
	split(options, optlist, "")
	for (opt in optlist) VALID_SEND_OPT[opt]++
}

function sys_time() {
        srand();
        return srand();
}

function h_num(num) {
	suffix = "B"
	divisors = "KMGTPE"
	for (h = 1; h <= length(divisors) && num >= 1024; h++) {
		num /= 1024
		suffix = substr(divisors, h, 1)
	}
	return int(num) suffix
}

function dry_run(command) {
	if (DRY_RUN) {
		if (command) print "+ "command
		return 1
	} else { return 0 }
}

function get_pipe() {
	if (PROGRESS == "pv") {
		RECEIVE_PREFIX = "pv -pebtrs " stream_size[r] " | "
	}
	pipe = " | " RECEIVE_PREFIX
	return pipe
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
	report(LOG_WARNING, message)
	if (MODE == "JSON") output_json()
	else if (MODE == "PIPE") output_pipe()
	exit error_code
}

function load_properties(endpoint, prop) {
	ZFS_GET_LOCAL="get -Hpr -s local,none -t filesystem,volume -o name,property,value " PROP_DEPTH " all "
	zfs_get_command = RPL_CMD_PREFIX dq(zfs[endpoint] ZFS_GET_LOCAL q(ds[endpoint])) ALL_OUT
	while (zfs_get_command | getline) {
		if (sub(ds[endpoint],"",$1)) prop[$1,$2] = $3
		else if (sub(/^real[ \t]+/,"")) list_time[endpoint] += $0
		else if (/(user|sys)/) {}
		else report(LOG_WARNING,"property loading error: " $0)
	}
}

function run_snapshot() {
	source_is_written = arr_sum(srcprop, "written")
	do_snapshot = (SNAPSHOT_ALL || (SNAPSHOT_WRITTEN && source_is_written))
	if ((SNAPSHOT_WRITTEN > 1) && !do_snapshot) {
		report(LOG_BASIC, "source not written")
		stop(0)
	} else if (!do_snapshot) return 0
	snapshot_command = "zelta snapshot " q(source)
	if (dry_run(snapshot_command)) return
	while (snapshot_command | getline snapline) {
		if (sub(/^snapshot created:[^@]*/,"",snapline)) {
			source_latest = snapline
			report(LOG_BASIC, "source snapshot created: "snapline)
		}
	}
	if (!source_latest) report(LOG_WARNING, "snapshot failed")
	return source_latest
}

function replicate(command) {
	while (command | getline) {
		if ($1 == "incremental" || $1 == "full") sent_streams++
		else if ($1 == "received") {
			report(LOG_VERBOSE, source_stream[r]": "$0)
			received_streams++
		} else if ($1 == "size") {
			report(LOG_VERBOSE, source_stream[r]": sending " h_num($2))
			total_bytes += $2
		} else if ($1 ~ /:/ && $2 ~ /^[0-9]+$/) {
			siginfo(source_stream[r]": "h_num($2) " received")
		} else if (/cannot receive (mountpoint|canmount)/) {
			report(LOG_VERBOSE, $0)
		} else if (/Warning/ && /mountpoint/) {
			report(LOG_VERBOSE, $0)
		} else if (/Warning/) {
			report(LOG_BASIC, $0)
		} else if ($1 == "real") zfs_replication_time += $2
		else if (/^(sys|user)[ \t]+[0-9]/) { }
		else if (/ records (in|out)$/) { }
		else if (/bytes.*transferred/) { }
		else if (/receiving/ && /stream/) { }
		else if (/ignoring$/) { }
		else {
			report(LOG_WARNING, $0)
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
	slast		= $5
	tlast		= $6
	info		= $7 (tgtprop[dataset,"written"] ? "; target is written" : "")

	sourceds	= ds[source] dataset 
	targetds	= ds[target] dataset 
	sfirst_full	= sourceds sfirst
	slast_full	= sourceds slast
	tlast_full	= targetds tlast
	target_match	= targetds match_snap
	source_match	= sourceds match_snap

	sorigin		= srcprop[dataset,"origin"]
	match_origin	= ""
	rotate_name	= ""
	

	# Compute update path
	get_update_option()

	# No match. Was the source renamed?
	if (check_origin) {
		sub(/[#@].*/, "", sorigin)
		sorigin_dataset = (prefix[source] ? prefix[source] ":" : "") sorigin
		clone_match = "zelta match -Hd1 -omatch,sync_code " q(sorigin_dataset) " " q(target dataset)
		while (clone_match | getline) {
			if (/^[@#]/) { 
				match_snap		= $1
				source_match		= sorigin match_snap
				if (ROTATE) tgt_behind	= 1
				else {
					report(LOG_WARNING, sourceds" is a clone of "source_match"; consider --rotate")
					return 0
				}
			}
		}
		close(clone_match)
	}
		

	if (ROTATE) {
		if (tgt_behind && !dataset) {
			torigin_name = ds[target] match_snap
			sub(/[#@]/, "_", torigin_name)
		}
		rotate_name = torigin_name dataset match_snap
	}
	return 1
}

BEGIN {
	STDOUT = "/dev/stdout"
	ALL_OUT = " 2>&1"
	TIME_COMMAND = env("TIME_COMMAND", "/usr/bin/time -p")
	if (TIME_COMMAND) TIME_COMMAND = TIME_COMMAND " "
	get_config()
	received_streams = 0
	total_bytes = 0
	total_time = 0
	error_code = 0
	

	if (INITIATOR) {
		if (INITIATOR == prefix[source]) prefix[source] = ""
		if (INITIATOR == prefix[target]) prefix[target] = ""
	}
	zfs[source] = (prefix[source]?SSH_SEND" "prefix[source]" ":"") "zfs "
	zfs[target] = (prefix[target]?SSH_RECEIVE" "prefix[target]" ":"") "zfs "

	zfs_send_command = zfs[source] send_flags
	zfs_receive_command = zfs[target] recv_flags

	time_start = sys_time()
	load_properties(source, srcprop)
	load_properties(target, tgtprop)
	run_snapshot()
	while (match_command |getline) {
		if (!name_match_row()) {
			if ($3 == ":") {
				source_zfs_list_time += $2
				target_zfs_list_time = $5
			} else if (/error|Warning/) {
				error_code = 1
				report(LOG_WARNING, $0)
			} else if (sub(/^parent dataset does not exist: +/,"")) {
				send_command[++rpl_num] = zfs[target] "create " create_flags q($0)
				create_dataset[rpl_num] = $6
			}
			continue
		}
		if (src_only) {
			if (INTR) {
							command_queue(sfirst_full, targetds)
							command_queue(slast_full, targetds, sfirst)
			} else				command_queue(slast_full, targetds)
		} else if (tgt_behind && !tgt_written) {
							command_queue(slast_full, targetds, source_match)
		} else if (torigin_name && match_snap) {
							command_queue(slast_full, targetds, source_match)
		} else if (up_to_date) {
			report(LOG_VERBOSE, targetds ": "info)
			synced_count++
		} else report(LOG_WARNING, targetds": "info)
	}
	close(match_command)
	
	if (ROTATE) {
		if (!torigin_name) stop(5, "no match available for requested rotation")
		rename_command = zfs[target] " rename " q(ds[target]) " " q(torigin_name)
		if (! dry_run(rename_command)) {
			system(rename_command)
			report(LOG_BASIC, "source renamed to " q(torigin_name))
		}
	}

	if (!num_streams) {
		if (synced_count) report(LOG_BASIC, "nothing to replicate")
		else {
			error_code = 5
			report(LOG_BASIC, "match error")
		}
		stop(error_code, "")
	}
	
	FS = "[ \t]+"
	received_streams = 0
	total_bytes = 0
	if (LOG_MODE == "PROGRESS") {
		report(LOG_VERBOSE, "calculating transfer size")
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
	estimate = (CLONE_MODE ? "cloning " : "replicating ") rpl_num " streams" estimate
	report(LOG_BASIC, estimate)
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
		if (receive_command[r]) replication_command = send_command[r] get_pipe() receive_command[r]
		else replication_command = send_command[r]
		if (dry_run(replication_command)) continue
		full_cmd = RPL_CMD_PREFIX dq(replication_command) RPL_CMD_SUFFIX
		if (stream_size[r]) report(LOG_BASIC, source_stream[r]": sending " h_num(stream_size[r]))
		replicate(full_cmd)
	}

	# Negative errors show the number of missed streams, otherwise show error code
	stream_diff = received_streams - sent_streams
	error_code = (error_code ? error_code : stream_diff)
	track_errors("")

	# Exit if we didn't parse "zfs send"
	if (CLONE_MODE || !RPL_CMD_SUFFIX) exit error_code
	report(LOG_BASIC, h_num(total_bytes) " sent, " received_streams "/" sent_streams " streams received in " zfs_replication_time " seconds")
	stop(error_code, "")
}
