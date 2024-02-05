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

function track_errors(message) {
	if (!message && !error_count) return 0
	else if (message == last_error) {
		++error_count
		if (error_count >1) return 0
	} else if (error_count > 2) {
		message = "above error repeated "error_count" times"
		error_count = 0
	} else last_error = message
	if (LOG_MODE == LOG_JSON) error_list[++err_num] = message
	else print message | STDOUT 
}

function report(mode, message) {
	if (!message) return 0
	if (LOG_ERROR == mode) track_errors(message)
	else if ((LOG_BASIC == mode) && ((LOG_MODE == LOG_BASIC) || LOG_MODE == LOG_VERBOSE)) { print message }
	else if ((LOG_VERBOSE == mode) && (LOG_MODE == LOG_VERBOSE)) { print message }
	else if (LOG_VERBOSE == mode) { buffer_verbose = buffer_verbose message"\n" }
	else if (LOG_SIGINFO == mode) {
		print buffer_verbose message | STDOUT
		buffer_verbose = ""
	}
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

function command_queue(send_dataset, receive_volume, match_snapshot) {
	num_streams++
	if (zfs_send_command ~ /ssh/) {
		gsub(/ /, "\\ ", send_dataset)
		gsub(/ /, "\\ ", match_snapshot)
	}
	if (zfs_receive_command ~ /ssh/) gsub(/ /, "\\ ", receive_volume)
	if (receive_volume) receive_part = " | " zfs_receive_command q(receive_volume)
	if (CLONE_MODE) {
		rpl_cmd[++rpl_num] = zfs_send_command q(send_dataset) " " q(receive_volume)
		source_stream[rpl_num] = send_dataset
	} else if (match_snapshot) {
		send_part = zfs_send_command intr_flags q(match_snapshot) " " q(send_dataset)
		rpl_cmd[++rpl_num] = send_part receive_part
		source_stream[rpl_num] = match_snapshot "::" send_dataset
	} else {
		send_part = zfs_send_command q(send_dataset)
		rpl_cmd[++rpl_num] = send_part receive_part
		source_stream[rpl_num] = send_dataset
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
			# Long options
			if (sub(/^-initiator=?/,"")) INITIATOR = opt_var()

			# Log modes
			if (gsub(/j/,"")) LOG_MODE = LOG_JSON
			if (gsub(/q/,"")) LOG_MODE = LOG_QUIET
			if (gsub(/z/,"")) LOG_MODE = LOG_PIPE
			VERBOSE += gsub(/v/,"")

			# Command modifiers
			CLONE_MODE += gsub(/c/,"")
			#FRIENDLY_FORCE += gsub(/F/,"")
			DRY_RUN += gsub(/n/,"")
			PROGRESS += gsub(/p/,"")
			REPLICATE += gsub(/R/,"")
			SNAPSHOT_WRITTEN += gsub(/s/,"")
			SNAPSHOT_ALL += gsub(/S/,"")
			TRANSFER_FROM_SOURCE += gsub(/T/,"")
			TRANSFER_FROM_TARGET += gsub(/t/,"")

			# Flags
			if (gsub(/i/,"")) INTR_FLAGS = "-i"
			if (gsub(/I/,"")) INTR_FLAGS = "-I"
			if (gsub(/M/,"")) RECEIVE_FLAGS = ""
			if (gsub(/m/,"")) RECEIVE_FLAGS = "-x mountpoint -o readonly=on"

			# Options
			if (sub(/d/,"")) DEPTH = opt_var()
			if (sub(/L/,"")) LIMIT_BANDWIDTH = opt_var()

			if (/./) usage("unknown or extra options: " $0)
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
	SEND_FLAGS = env("ZELTA_SEND_FLAGS", "-Lcp")
	RECEIVE_PREFIX = env("ZELTA_RECEIVE_PREFIX", "")
	RECEIVE_FLAGS = env("ZELTA_RECEIVE_FLAGS", "-ux mountpoint -o readonly=on")
	INTR_FLAGS = env("ZELTA_INTR_FLAGS", "-i")
	LOG_QUIET = -2
	LOG_ERROR = -1
	LOG_PIPE = 0
	LOG_BASIC = 1
	LOG_VERBOSE = 2
	LOG_JSON = 3
	LOG_SIGINFO = 4
	LOG_MODE = LOG_BASIC
	get_options()
	get_endpoint_info(source)
	get_endpoint_info(target)
	if (TRANSFER_FROM_SOURCE) INITIATOR = prefix[source]
	if (TRANSFER_FROM_TARGET) INITIATOR = prefix[target]
	if (VERBOSE) LOG_MODE = LOG_VERBOSE
	if (VERBOSE>1) VV++
	if (VERBOSE && INITIATOR) report(LOG_VERBOSE, "transferring via: "INITIATOR)
	if (PROGRESS) {
		VV++
		if (!system("which pv")) RECEIVE_PREFIX="pv -ptr |"
		else RECEIVE_PREFIX="dd status=progress |"
		report(LOG_VERBOSE,"using progress pipe: " RECEIVE_PREFIX)
	}
	if (INITIATOR) SHELL_WRAPPER = "ssh -n "INITIATOR
	RPL_CMD_PREFIX = (VV?"":TIME_COMMAND" ") SHELL_WRAPPER" "
	RPL_CMD_SUFFIX = (VV?"":ALL_OUT)
	match_flags = "-Hpo stub,status,match,srcfirst,srclast,tgtlast "
	match_command = SHELL_WRAPPER" "dq("zelta match " match_flags DEPTH q(source) " " q(target)) ALL_OUT
	if (CLONE_MODE) {
		send_flags = "clone -o readonly=off "
		return 1
	}
	if (FORCE) {
		report(LOG_ERROR,"using 'zfs receive -F'")
		RECEIVE_FLAGS = RECEIVE_FLAGS" -F"
	}
	if (! target) usage()
	SEND_FLAGS = SEND_FLAGS (DRY_RUN?"n":"") (REPLICATE?"R":"")
	if (DEPTH) DEPTH = "-d"DEPTH" "
	send_flags = "send -P " SEND_FLAGS " " 
	recv_flags = "receive -v " RECEIVE_FLAGS " "
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
	if (LOG_MODE != LOG_JSON) return 0
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
	if (LOG_MODE == LOG_PIPE) print received_streams, total_bytes, total_time, error_code 
	return error_code
}

function stop(err, message) {
	time_end = sys_time()
	total_time = source_zfs_list_time + target_zfs_list_time + zfs_replication_time
	error_code = err
	report(LOG_ERROR, message)
	if (LOG_MODE == LOG_JSON) output_json()
	else if (LOG_MODE == LOG_PIPE) output_pipe()
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
	if (!source_latest) report(LOG_ERROR, "snapshot failed")
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
			report(LOG_SIGINFO, source_stream[r]": "h_num($2) " received")
			track_errors("")
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
			report(LOG_ERROR, $0)
			error_code = 2
		}

	}
	close(command)
}

function name_row() {
	dataset = $1
	sourceds = ds[source] dataset 
	targetds = ds[target] dataset 
	status = $2
	match_snap = $3 
	sfirst = $4
	sfirst_full = sourceds sfirst
	slast = $5
	slast_full = sourceds slast
	tlast = $6
	tlast_full = targetds tlast
	target_match = targetds match_snap
	source_match = sourceds match_snap
}

BEGIN {
	STDOUT = "cat 1>&2"
	ALL_OUT = " 2>&1"
	TIME_COMMAND = env("TIME_COMMAND", "/usr/bin/time -p")
	get_config()
	received_streams = 0
	total_bytes = 0
	total_time = 0
	error_code = 0
	

	if (INITIATOR) {
		if (INITIATOR == prefix[source]) prefix[source] = ""
		if (INITIATOR == prefix[target]) prefix[target] = ""
	}
	zfs[source] = (prefix[source]?"ssh -n "prefix[source]" ":"") "zfs "
	zfs[target] = (prefix[target]?"ssh "prefix[target]" ":"") "zfs "

	zfs_send_command = zfs[source] send_flags
	zfs_receive_command = RECEIVE_PREFIX zfs[target] recv_flags

	time_start = sys_time()
	if (SNAPSHOT_ALL) run_snapshot()
	if (SNAPSHOT_WRITTEN) {
		check_written_command = "zelta match -pqw " q(source)
		while (check_written_command | getline) {
			if ($1 == "SOURCE_LIST_TIME:") source_zfs_list_time = $2
			else if (/^source volume has changed/) {
				report(LOG_VERBOSE, source " has written data")
				run_snapshot()
			}
		}
		close(check_written_command)
		if ((SNAPSHOT_WRITTEN>1) && !source_latest) {
			report(LOG_BASIC, "source not written")
			stop(0)
		}
	}

	while (match_command |getline) {
		name_row()
		if ($3 == ":") {
			source_zfs_list_time += $2
			target_zfs_list_time = $5
		} else if (/error|Warning/) {
			error_code = 1
			report(LOG_ERROR, $0)
		} else if (/^[0-9]+$/) {
			report(LOG_VERBOSE, source " has written data")
		} else if (sub(/^parent dataset does not exist: +/,"")) {
			rpl_cmd[++rpl_num] = zfs[target] "create " create_flags q($0)
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
		else if (status == "MIXED") {
			report(LOG_BASIC, "latest target snapshot not on source: "tlast_full)
			report(LOG_BASIC, "  consider target rollback: "target_match )
			report(LOG_BASIC, "  or source rollback to: "source_match)
		} else if (status == "AHEAD") {
			report(LOG_BASIC, "target snapshot ahead of source: "tlast_full)
			report(LOG_BASIC, "  reverse replication or rollback target to: "target_match)
		} else if (status == "SYNCED") report(LOG_VERBOSE, "target is up to date: "tlast_full)
		else if (status == "NOSNAP") report(LOG_VERBOSE, "no snapshot for dataset "dataset)
		else report(LOG_ERROR, "match error: "$0)
	}
	close(match_command)

	if (!num_streams) {
		report(LOG_BASIC, "nothing to replicate")
		stop(error_code, "")
	}
	
	FS = "[ \t]+";
	received_streams = 0
	total_bytes = 0
	for (r = 1; r <= rpl_num; r++) {
		if (dry_run(rpl_cmd[r])) {
			if (CLONE_MODE) continue
			sub(/ \| .*/, "", rpl_cmd[r])
		} else if (rpl_cmd[r] ~ "zfs create") {
			if (system(rpl_cmd[r])) {
				stop(4, "failed to create parent dataset: " create_volume[r])
			}
			continue
		}
		if (full_cmd) close(full_cmd)
		full_cmd = RPL_CMD_PREFIX dq(rpl_cmd[r]) RPL_CMD_SUFFIX
		replicate(full_cmd)
	}

	# Negative errors show the number of missed streams, otherwise show error code
	stream_diff = received_streams - sent_streams
	error_code = (error_code ? error_code : stream_diff)
	track_errors("")
	if (VV || CLONE_MODE) exit error_code
	report(LOG_BASIC, h_num(total_bytes) " sent, " received_streams "/" sent_streams " streams received in " zfs_replication_time " seconds")
	stop(error_code, "")
}
