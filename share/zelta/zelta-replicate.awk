#!/usr/bin/awk -f
#
# zelta-replicate.awk - replicates a zfs endpoint/volume
#
# After using match_command to identify out-of-date snapshots on the target, this script creates
# individual replication streams for a snapshot and its children. This script is useful for
# migrations in that it will recursively replicate the latest parent snapshot and its
# children, unlike the "zfs send -R" option.
#
# If called with the argument "-z" zelta sync reports an abbreviated output for reporting:
#
# 	received_streams, total_bytes, time, error
#
# Additional flags can be set with the environmental variables ZELTA_SEND_FLAGS and
# ZELTA_RECEIVE_FLAGS.
#
# Note that as zelta sync is used as both a backup and migration tool, the default behavior
# for new replicas is to only copy the latest snapshots from the source heirarchy, while the
# behavior for updating existing replicas is to copy intermediate snapshots. You can use
# "-R" to replicate the source's snapshot history. Use the -I flag to replicate incremental
# snapshots.
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
	usage_command = "zelta usage replicate"
	while (usage_command |getline) print
	close(usage_command)
	stop(1,message)
}

function env(env_name, var_default) {
	return ( (env_name in ENVIRON) ? ENVIRON[env_name] : var_default )
}

function q(s) { return "'" s "'" }

function dq(s) { return "\"" s "\"" }

function run_zfs_command(cmd_args, qarg1, qarg2) {
	# Future: Help wrap commands so I don't have to do this everywhere inline
	rzc_prefix = TIME_COMMAND SHELL_WRAPPER
        rzc_args = cmd_args q(qarg1) (qarg2?" "q(qarg2):"")
	rzc_cmd = rzc_prefix " " dq(rzc_args) ALL_OUT
	return rzc_cmd
}

function command_queue(send_dataset, receive_volume, match_snapshot) {
	num_streams++
	if (zfs_send_command ~ /ssh/) {
		gsub(/ /, "\\ ", send_dataset)
		gsub(/ /, "\\ ", match_snapshot)
	}
	if (zfs_receive_command ~ /ssh/) gsub(/ /, "\\ ", receive_volume)
	#if (receive_volume) receive_part = " | " receive_prefix() zfs_receive_command q(receive_volume)
	if (receive_volume) receive_part = zfs_receive_command q(receive_volume)
	if (CLONE_MODE) {
		send_command[++rpl_num] = zfs_send_command q(send_dataset) " " q(receive_volume)
		source_stream[rpl_num] = send_dataset
	} else if (match_snapshot) {
		send_part = intr_flags q(match_snapshot) " " q(send_dataset)
		send_command[++rpl_num] = zfs_send_command send_part
		receive_command[rpl_num] = receive_part
		est_cmd[rpl_num] = zfs_send_command "-Pn " send_part
		source_stream[rpl_num] = match_snapshot "::" send_dataset
		stream_size[rpl_num] = xfersize
	} else {
		send_command[++rpl_num] = zfs_send_command q(send_dataset)
		receive_command[rpl_num] = receive_part
		est_cmd[rpl_num] = zfs_send_command "-Pn " q(send_dataset)
		source_stream[rpl_num] = send_dataset
		stream_size[rpl_num] = xfersize
	}
}

function opt_var() {
	var = ($0 ? $0 : ARGV[++i])
	$0 = ""
	return var
}

function get_options() {
	for (i=1;i<ARGC;i++) {
		$0 = ARGV[i]
		if (gsub(/^-/,"")) {
			while (/./) {
				# Long options
				if (sub(/^-initiator=?/,"")) INITIATOR = opt_var()
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
				else if (sub(/^m/,"")) RECEIVE_FLAGS = "-x mountpoint -o readonly=on"
				else if (sub(/^c/,"")) CLONE_MODE++
				else if (sub(/^n/,"")) DRY_RUN++
				else if (sub(/^R/,"")) REPLICATE++
				else if (sub(/^s/,"")) SNAPSHOT_WRITTEN++
				else if (sub(/^S/,"")) SNAPSHOT_ALL++
				else if (sub(/^t/,"")) TRANSFER_FROM_SOURCE
				else if (sub(/^T/,"")) TRANSFER_FROM_TARGET
				else if (sub(/^d/,"")) DEPTH = opt_var()
				else if (sub(/L/,"")) LIMIT_BANDWIDTH = opt_var()
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
	SHELL_WRAPPER = env("ZELTA_SHELL", "sh -c")
	SSH_SEND = env("REMOTE_SEND_COMMAND", "ssh -n")
	SSH_RECEIVE = env("REMOTE_RECEIVE_COMMAND", "ssh")
	SEND_FLAGS = env("ZELTA_SEND_FLAGS", "-Lcpw")
	RECEIVE_PREFIX = env("ZELTA_RECEIVE_PREFIX", "")
	RECEIVE_FLAGS = env("ZELTA_RECEIVE_FLAGS", "-ux mountpoint -o readonly=on")
	INTR_FLAGS = env("ZELTA_INTR_FLAGS", "-i")
	LOG_LEVEL = 0
	MODE = "BASIC"
	# Don't interactivey print:
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
	if (DEPTH) DEPTH = "-d"DEPTH" "
	match_cols = "stub,status,match,srcfirst,srclast,tgtlast" (PROGRESS?",xfersize":"")
	match_flags = "-po "match_cols" "DEPTH
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
	intr_flags = INTR_FLAGS " "
	create_flags = "-up"(DRY_RUN?"n":"")" "
}

function get_endpoint_info(endpoint) {
	FS = "\t"
	endpoint_command = "zelta endpoint " endpoint
	endpoint_command | getline
	prefix[endpoint] = $2
	user[endpoint] = $3
	host[endpoint] = $4
	ds[endpoint] = $5
	snapshot[endpoint] = $6
	close("zelta endpoint " endpoint)
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
	if (length(e) == 0) return "null"
	else if (e ~ /^-?[0-9\.]+$/) return e
	else return "\""e"\""
}

function jpair(l, r) {
	printf "  "j(l)": "j(r)
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

function run_snapshot() {
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
		} else if (($1 == "size") && $2) {
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

function get_match_header() {
	for (i=0;i<=NF;++i) {
		mcol[$i] = i
	}
	dataset = $mcol["STUB"]
}

function name_match_row() {
	# STUB STATUS XFERSIZE MATCH SRCFIRST SRCLAST TGTLAST
	dataset = $mcol["STUB"]
	sourceds = ds[source] dataset 
	targetds = ds[target] dataset 
	status = $mcol["STATUS"]
	match_snap = $mcol["MATCH"]
	sfirst = $mcol["SRCFIRST"]
	sfirst_full = sourceds sfirst
	slast = $mcol["SRCLAST"]
	slast_full = sourceds slast
	tlast = $mcol["TGTLAST"]
	tlast_full = targetds tlast
	target_match = targetds match_snap
	source_match = sourceds match_snap
	xfersize = (mcol["XFERSIZE"]?$mcol["XFERSIZE"]:0)
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
	if (SNAPSHOT_ALL) run_snapshot()
	if (SNAPSHOT_WRITTEN) {
		# This could also be just a "zfs list -Hprt filesystem,volume -o written"
		# but we use zelta match for endpoint handling and timer. We probably
		# need an arbitrary "zelta run" to just run stuff and handle quotes
		# and tiemrs and crap.
		check_written_command = "zelta match -Hpo srcwritten " DEPTH q(source)
		while (check_written_command | getline) {
			if ($1 == "SOURCE_LIST_TIME:") source_zfs_list_time = $2
			else if (/^[0-9]+$/) {
				if ($1) {
					report(LOG_VERBOSE, source " has written data")
					run_snapshot()
					break
				}
			} else report(LOG_VERBOSE, "unexpected list output: " $0)
		}
		close(check_written_command)
		if ((SNAPSHOT_WRITTEN>1) && !source_latest) {
			report(LOG_BASIC, "source not written")
			stop(0)
		}
	}
	match_command | getline
	get_match_header()
	while (match_command |getline) {
		name_match_row()
		if ($3 == ":") {
			source_zfs_list_time += $2
			target_zfs_list_time = $5
		} else if (/error|Warning/) {
			error_code = 1
			report(LOG_WARNING, $0)
		} else if (/^[0-9]+$/) {
			report(LOG_VERBOSE, source " has written data")
		} else if (sub(/^parent dataset does not exist: +/,"")) {
			send_command[++rpl_num] = zfs[target] "create " create_flags q($0)
			create_volume[rpl_num] = $6
		} else if (! /@/) {
			if (! $0 == $1) stop(3, $0)
		} else if (status == "SRCONLY") {
			if (INTR) {
				command_queue(sfirst_full, targetds)
				command_queue(slast_full, targetds, sfirst)
			} else command_queue(slast_full, targetds)
		} else if (status == "BEHIND") command_queue(slast_full, targetds, match_snap)
		else if (status == "TGTONLY") report(LOG_VERBOSE, "snapshot only exists on target: "targetds)
		else if (status == "MISMATCH") {
			error_code = 3
			report(LOG_BASIC, "datasets differ: "targetds)
			if (target_match) report(LOG_VERBOSE, "  consider target rollback: "target_match )
		} else if (status == "AHEAD") {
			error_code = 3
			report(LOG_BASIC, "target snapshot ahead of source: "tlast_full)
			report(LOG_VERBOSE, "  reverse replication or rollback target to: "target_match)
		} else if (status == "SYNCED") {
			synced_count++
			report(LOG_VERBOSE, "target is up to date: "tlast_full)
		} else if (status == "NOSNAP") report(LOG_VERBOSE, "no snapshot for dataset "dataset)
		else report(LOG_WARNING, "match error: "$0)
	}
	close(match_command)

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
	if (LOG_MODE = "PROGRESS") {
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
	estimate = "replicating " rpl_num " streams" estimate
	report(LOG_BASIC, estimate)
	for (r = 1; r <= rpl_num; r++) {
		if (dry_run(send_command[r])) {
			if (CLONE_MODE) continue
			sub(/ \| .*/, "", send_command[r])
		} else if (send_command[r] ~ "zfs create") {
			if (system(send_command[r])) {
				stop(4, "failed to create parent dataset: " create_volume[r])
			}
			continue
		}
		if (full_cmd) close(full_cmd)
		if (receive_command[r]) replication_command = dq(send_command[r] get_pipe() receive_command[r])
		else replication_command = dq(send_command[r])
		full_cmd = RPL_CMD_PREFIX replication_command RPL_CMD_SUFFIX
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
