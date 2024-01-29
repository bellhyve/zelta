#!/usr/bin/awk -f
#
# zelta sync, zsync, zpull - replicates a snapshot and its descendants
#
# usage: zelta sync [user@][host:]source/dataset [user@][host:]target/dataset
#
# After using zmatch to identify out-of-date snapshots on the target, zpull creates
# individual replication streams for a snapshot and its children. zpull is useful for
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
	if (message) report(LOG_ERROR, message)
	report(LOG_BASIC, "usage: zelta sync [-iIjmnqRvz] [-d#] [user@][host:]source/dataset [user@][host:]target/dataset")
	stop(1,"")
}

function env(env_name, var_default) {
	return ( (env_name in ENVIRON) ? ENVIRON[env_name] : var_default )
}

function q(s) { return "'" s "'" }

function dq(s) { return "\"" s "\"" }

function command_queue(send_dataset, receive_volume, match_snapshot) {
	num_streams++
	if (zfs_send_command ~ /ssh/) {
		sub(/ssh/, "ssh -n", send_dataset)
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
			if (gsub(/c/,"")) CLONE_MODE++
			if (gsub(/i/,"")) INTR_FLAGS = "-i"
			if (gsub(/I/,"")) INTR_FLAGS = "-I"
			if (gsub(/j/,"")) LOG_MODE = LOG_JSON
			if (gsub(/F/,"")) FRIENDLY_FORCE++
			if (gsub(/m/,"")) RECEIVE_FLAGS = "-x mountpoint"
			if (gsub(/M/,"")) RECEIVE_FLAGS = ""
			if (gsub(/n/,"")) DRY_RUN++
			if (gsub(/p/,"")) PROGRESS++
			if (gsub(/q/,"")) LOG_MODE = LOG_QUIET
			if (gsub(/R/,"")) REPLICATE++
			SNAPSHOT_WRITTEN += gsub(/s/,"")
			if (gsub(/S/,"")) SNAPSHOT_ALL++
			if (sub(/v/,"")) {
				if (LOG_MODE == LOG_VERBOSE) VV++
				if (gsub(/v/,"")) VV++
				LOG_MODE = LOG_VERBOSE
			} if (gsub(/z/,"")) LOG_MODE = LOG_PIPE
			# Options with sub-options go last
			if (sub(/d/,"")) DEPTH = opt_var()
			if (sub(/L/,"")) LIMIT_BANDWIDTH = opt_var()
			if (/./) usage("unkown options: " $0)
		} else if (target) {
			usage("too many options: " $0)
		} else if (source) target = $0
		else source = $0
	}
}
	       
function get_config() {
	# Load environemnt variables and options and set up zfs send/receive flags
	SHELL_WRAPPER = env("ZELTA_SHELL", "sh -c ")
	SEND_FLAGS = env("ZELTA_SEND_FLAGS", "-Lcp")
	RECEIVE_PREFIX = env("ZELTA_RECEIVE_PREFIX", "")
	RECEIVE_FLAGS = env("ZELTA_RECEIVE_FLAGS", "-ux mountpoint")
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
	if (PROGRESS) {
		#VERBOSE++
		VV++
		if (!system("which pv")) RECEIVE_PREFIX="pv -ptr |"
		else RECEIVE_PREFIX="dd status=progress |"
		report(LOG_VERBOSE,"using progress pipe: " RECEIVE_PREFIX)
	}

	RPL_CMD_PREFIX = (VV?"":TIME_COMMAND) SHELL_WRAPPER
	RPL_CMD_SUFFIX = (VV?"":ALL_OUT)
	match_flags = "-z "
	zmatch = "zelta match " match_flags DEPTH q(source) " " q(target) ALL_OUT
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
	intr_flags = INTR_FLAGS " "
	#match_flags = ((SNAPSHOT_WRITTEN || VERBOSE)?"-zw":"-z") " "
	create_flags = "-up"(DRY_RUN?"n":"")" "
}

function get_endpoint_info(endpoint) {
	FS = "\t"
	endpoint_command = "zelta endpoint " endpoint
	endpoint_command | getline
	zfs[endpoint] = ($2?"ssh "$2" ":"") "zfs "
	user[endpoint] = $3
	host[endpoint] = $4
	volume[endpoint] = $5
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
	print jpair("sourceVolume",volume[source])
	print jpair("sourceListTime",source_zfs_list_time)
	print jpair("targetUser",user[target])
	print jpair("targetHost",host[target])
	print jpair("targetVolume",volume[target])
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
		else if (/ records (in|out)$/) { } # report(LOG_VERBOSE, $0)
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

BEGIN {
	STDOUT = "cat 1>&2"
	ALL_OUT = " 2>&1"
	TIME_COMMAND = env("TIME_COMMAND", "/usr/bin/time -p") " "
	get_config()
	received_streams = 0
	total_bytes = 0
	total_time = 0
	error_code = 0

	get_endpoint_info(source)
	get_endpoint_info(target)
	zfs_send_command = zfs[source] send_flags
	zfs_receive_command = RECEIVE_PREFIX zfs[target] recv_flags
	time_start = sys_time()
	if (SNAPSHOT_ALL) run_snapshot()
	if (SNAPSHOT_WRITTEN) {
		check_written_command = "zelta match -zw " q(source) ALL_OUT
		while (check_written_command | getline) {
			if ($2 == ":") {
				source_zfs_list_time = $1 ? $1 : 0
			} else if (/^[0-9]+$/) {
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
	while (zmatch |getline) {
		if ($2 == ":") {
			source_zfs_list_time += $1 ? $1 : 0
			target_zfs_list_time = $3 ? $3 : 0
		} else if (/error|Warning/) {
			error_code = 1
			report(LOG_ERROR, $0)
		} else if (/^[0-9]+$/) {
			report(LOG_VERBOSE, source " has written data")
		} else if (! /@/) {
			# If no snapshot is given, create an empty volume
			if (! $0 == $1) stop(3, $0)
			rpl_cmd[++rpl_num] = zfs[target] "create " create_flags q($1)
			create_volume[rpl_num] = $1
		} else if ($5) {
			if (intr_flags ~ "I") {
				command_queue($1, $2)
				command_queue($4, $5, $3)
			} else command_queue($4, $5)
		} else if ($3) command_queue($2, $3, $1)
		else if ($2) command_queue($1, $2)
		else {
			error_code = 1
			report(LOG_ERROR, "unhandled match output")
		}
	}
	close(zmatch)

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
				stop(4, "failed to create parent volume: " create_volume[r])
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
