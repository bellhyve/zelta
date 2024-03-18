#!/usr/bin/awk -f
#
# zelta reconcile - compares a snapshot list via pipe and command
#
# usage: internal to "zelta match", but most code could be leveraged for other comparison
# operations.
#
# Reports the most recent matching snapshot and the latest snapshot of a dataset and
# its children, which are useful for various zfs operations
#
# Child snapshot names are provided relative to the target using a trimmed dataset
# referred to as a STUB. For example, when zmatch is called with tank/dataset, 
# tank/dataset/child's snapshots will be reported as "/child@snapshot-name".
#
# DEPRECATED FEATURE:
# If only one argument is given, report the amount of data written since the last
# snapshot.

function env(env_name, var_default) {
	return ( (env_name in ENVIRON) ? ENVIRON[env_name] : var_default )
}

function report(level, message) {
	if (!message) return 0
	if ((level <= LOG_LEVEL) && (level <= LOG_WARNING)) {
		error_messages++
		print message > STDERR
	}
	else if (level <= LOG_LEVEL) print message
}

function h_num(num) {
	if (MODE == "PARSE") return num
	suffix = "B"
	divisors = "KMGTPE"
	for (h = 1; h <= length(divisors) && num >= 1024; h++) {
		num /= 1024
		suffix = substr(divisors, h, 1)
	}
	return int(num) suffix
}

# Needed to prevent mawk and gawk from turning length() checked arrays into scalers
function arrlen(array) {
	element_count = 0
	for (key in array) element_count++
	return element_count
}

function get_snapshot_data(ds_name) {
		trim = ds_name_length[ds_name]
		if (/dataset does not exist/) return 0
		else if (/^real[ \t]+[0-9]/) {
			split($0, time_arr, /[ \t]+/)
			zfs_list_time = time_arr[2]
			return 0
		} else if (/(sys|user)[ \t]+[0-9]/) {
			return 0
		} else if (!($1 ~ /@/) && ($2 ~ /[0-9]/)) {
			stub = ($1 == dataset[ds_name]) ? "" : substr($1, trim)
			if (!stub_list[stub]++) stub_order[++stub_num] = stub
			if (!status[stub]) status[stub] = "NOSNAP"
			if (!num_snaps[ds_name,stub]) num_snaps[ds_name,stub] = 0
			stub_written[ds_name,stub] += $3
			total_written[ds_name] += $3
			return 0
		} else if (! /@/) {
			report(LOG_ERROR,$0)
			exit_code = 1
			return 0
		}
#		snapshot_full_name = $1			# full/dataset@snapshot
		snapshot_stub = substr($1, trim)	# [child]@snapshot
		snapshot_guid = $2			# GUID property
		snapshot_written = $3			# written property
		split(snapshot_stub, split_stub, "@")
		stub = split_stub[1]			# [child] (blank for top dataset name)
		snapshot_name = "@" split_stub[2]	# @snapshot
		num_snaps[ds_name,stub]++		# Total snapshots per dataset
		#guid[snapshot_stub] = snapshot_guid
		#written[snapshot_stub] = $3
		return 1
}

function load_target_snapshots() {
	while  (snapshot_list_command | getline) {
		if (!get_snapshot_data(target)) { continue }
		target_guid[snapshot_stub] = snapshot_guid
		target_written[snapshot_stub] = snapshot_written
		if (!(target_ds_count[stub]++)) {
			target_latest[stub] = snapshot_stub
			tgtlast[stub] = snapshot_name
			target_order[++target_num] = stub
			status[stub] = "TGTONLY"
		}
		tgtfirst[stub] = snapshot_name
	}
	close(snapshot_list_command)
}

function check_parent() {
	if (!(snapshot_list_command ~ /zfs list/)) return 0
	parent = dataset[target]
	if (!gsub(/\/[^\/]+$/, "", parent)) {
		report(LOG_ERROR,"invalid target: " parent)
		exit 1
	}
	parent_list_command = snapshot_list_command
	sub(/zfs list.*'/, "zfs list '"parent"'", parent_list_command)
	parent_list_command | getline parent_check
	if (parent_check ~ /dataset does not exist/) {
		report(LOG_DEFAULT, "parent dataset does not exist: " parent)
	}
	close(parent_list_command)
}

function arr_sort(arr) {
    n = arrlen(arr);
    for (i = 2; i <= n; i++) {
        # Store the current value and its key
        value = arr[i];
        j = i - 1;
        while (j >= 1 && arr[j] > value) {
            arr[j + 1] = arr[j];
            j--;
        }
        arr[j + 1] = value;
    }
}

BEGIN {
	FS="\t"
	OFS="\t"
	STDERR = "/dev/stderr"
	LOG_ERROR=-2
	LOG_WARNING=-1
	LOG_DEFAULT=0
	LOG_VERBOSE=1
	LOG_VV=2

	PASS_FLAGS = env("ZELTA_MATCH_FLAGS", "")
	LOG_LEVEL = env("ZELTA_LOG_LEVEL", 0)
	PROPERTIES_DEFAULT = "stub,status,match,srclast,summary"
	PROPERTIES_ALL = PROPERTIES_DEFAULT ",xfer,written,srcfirst,tgtfirst,tgtlast,srcsnaps,tgtsnaps"
	PROPERTIES = env("ZELTA_MATCH_PROPERTIES", PROPERTIES_DEFAULT)
	if (PROPERTIES == "all") PROPERTIES = PROPERTIES_ALL
	split(PROPERTIES, PROPLIST, ",")
	for (i in PROPLIST) {
		if (PROPLIST[i] == "xfer") {
			COL["xfersize"]++
			COL["xfersnaps"]++
		} else if (PROPLIST[i] ~ /srcwr/) COL["srcwritten"]++
		else if (PROPLIST[i] ~ /tgtwr/) COL["tgtwritten"]++
		else if (PROPLIST[i] ~ /wri/) {
			COL["srcwritten"]++
			COL["tgtwritten"]++
		} else COL[PROPLIST[i]]++
	}
	
	MODE = "CHART"
	if (PASS_FLAGS ~ /p/) MODE = "PARSE"
	if (PASS_FLAGS ~ /q/) LOG_LEVEL--
	if (PASS_FLAGS ~ /H/) NOHEADER++
	if (PASS_FLAGS ~ /v/) LOG_LEVEL++
	if (PASS_FLAGS ~ /w/) {
		COL["xfersize"]++
		COL["srcwritten"]++
		COL["tgtcwritten"]++
	}

	exit_code = 0
	LOG_MODE = ZELTA_PIPE ? 0 : 1
	target_zfs_list_time = 0
}

function get_endpoint_info() {
	endpoint = $1
	endpoint_hash[endpoint] = $1
	dataset[endpoint] = $2
	ds_name_length[endpoint] = length(dataset[endpoint]) + 1
	return endpoint
}

function count_snapshot_diff() {
	transfer_size += snapshot_written
	xfersize[stub] += snapshot_written
	xfersnaps[stub]++
}

NR == 1 { source = get_endpoint_info() }

NR == 2 { target = get_endpoint_info() }

NR == 3 {
	zfs_list_time = 0
	transfer_size = 0
	if (!target) next
	snapshot_list_command = $0;
	if ((source == target) || !snapshot_list_command) {
		# Should I suppress unnecessary columns by default?
		if (MODE == "CHART") {
			report(LOG_VERBOSE, "same source and target, suppressing match output")
			delete COL["status"]
			delete COL["match"]
			delete COL["tgtfirst"]
			delete COL["tgtlast"]
			delete COL["tgtnum"]
		}
	} else load_target_snapshots()
	target_zfs_list_time = zfs_list_time
}

NR > 3 {
	if (!get_snapshot_data(source)) { next }
	source_guid[snapshot_stub] = snapshot_guid
	source_written[snapshot_stub] = snapshot_written
	if (!(source_ds_count[stub]++)) {
		source_latest[stub] = snapshot_stub
		srclast[stub] = snapshot_name
		source_order[++source_num] = stub
	}
	# Catch oldest snapshot name to ensure replication completeness
	source_oldest[stub] = snapshot_name

	if (stub in matches) next
	else if (!target_latest[stub] && !(stub in new_dataset)) {
		if (!stub) check_parent()
		new_dataset[stub] = snapshot_name
		if (stub_written[target,stub]) status[stub] = "MISMATCH"
		else if (num_snaps[target,stub] == "0") status[stub] = "NOMATCH"
		else {
			status[stub] = "SRCONLY"
			count_snapshot_diff()
		}
	} else if (target_guid[snapshot_stub]) {
		if (target_guid[snapshot_stub] == source_guid[snapshot_stub]) {
			matches[stub] = snapshot_name
			if (snapshot_stub == source_latest[stub]) {
				#basic_log[stub] = "target has latest source snapshot: " snapshot_stub
				status[stub] = (snapshot_stub==target_latest[stub]) ? "SYNCED" : "AHEAD"
			} else if (guid_error[stub]) {
				# report(LOG_VERBOSE,"latest guid match: " snapshot_stub)
				status[stub] = "MISMATCH"
			} else {
				status[stub] = "BEHIND"
				#basic_log[stub] = "match: " snapshot_stub OFS "latest: " source_latest[stub]
			}
		} else {
			report(LOG_VERBOSE,"guid mismatch: " snapshot_stub)
			#warning_log[stub] = warning_log[stub] "guid mismatch on: " snapshot_stub "\n"
			guid_error[stub]++
		}
	} else count_snapshot_diff()
}

function print_row(col) {
	num_col = arrlen(col)
	for(c=1;c<=num_col;c++) {
		if (MODE=="PARSE") printf ((c>1)?"\t":"") col[c]
		if (MODE=="CHART") printf ((c>1)?"  ":"") pad[c], col[c]
	}
	printf "\n"
}

function make_header_column(title, arr) {
	columns[++c] = NOHEADER?"  ":title
	if (MODE=="CHART") { 
		width = length(title)
		for (w in arr) if (length(arr[w])>width) width = length(arr[w])
		pad[c] = "%-"width"s"
	}
}

function summarize() {
	if (status[stub]=="SYNCED") s = "up-to-date"
	else if (status[stub]=="SRCONLY") s = "syncable, new dataset"
	else if ((status[stub]=="BEHIND") && stub_written[source,stub]) s = "target is written"
	else if (status[stub]=="BEHIND") s = "syncable"
	else if (status[stub]=="TGTONLY") s = "no source dataset"
	else if (status[stub]=="AHEAD") s = "target is ahead"
	else if (status[stub]=="NOSNAP") s = "no source snapshots"
	else if (status[stub]=="NOMATCH") s = "target has no snapshots"
	else if (status[stub]=="ORPHAN") s = "no parent snapshot"
	else if (guid_error[stub]) s = "guid mismatch"
	else s = "match, but latest snapshots differ"
	return s
}

function chart_header() {
	c = 0
	delete columns
	if ((arrlen(stub_order) <= 1) && MODE=="CHART") {
		report(LOG_VERBOSE, "single dataset; hiding stub column")
		delete COL["stub"]
	}
	if ("stub" in COL) make_header_column("STUB", stub_order)
	if ("status" in COL) make_header_column("STATUS", status)
	if ("xfersize" in COL) make_header_column("XFERSIZE", xfersize)
	if ("xfersnaps" in COL) make_header_column("XFERSNAPS", xfersnaps)
	if ("match" in COL) make_header_column("MATCH", matches)
	if ("srcfirst" in COL) make_header_column("SRCFIRST", source_oldest)
	if ("srclast" in COL) make_header_column("SRCLAST", srclast)
	if ("srcwritten" in COL) make_header_column("SRCWRI", stub_written)
	if ("tgtfirst" in COL) make_header_column("TGTFIRST", tgtfirst)
	if ("tgtlast" in COL) make_header_column("TGTLAST", tgtlast)
	if ("srcsnaps" in COL) make_header_column("SRCSNAPS", num_snaps)
	if ("tgtsnaps" in COL) make_header_column("TGTSNAPS", num_snaps)
	if ("tgtwritten" in COL) make_header_column("TGTWRI", stub_written)
	if ("summary" in COL) make_header_column("SUMMARY", summary)
	if (!NOHEADER) print_row(columns)
}

function chart_row(field) {
	if (!ROW++) chart_header()
	c=0
	delete columns
	if ("stub" in COL) columns[++c] = field
	if ("status" in COL) columns[++c] = status[field]
	if ("xfersize" in COL) columns[++c] = h_num(xfersize[field])
	if ("xfersnaps" in COL) columns[++c] = xfersnaps[field]
	if ("match" in COL) columns[++c] = matches[field]
	if ("srcfirst" in COL) columns[++c] = source_oldest[field]
	if ("srclast" in COL) columns[++c] = srclast[field]
	if ("srcwritten" in COL) columns[++c] = h_num(field_written[source,field])
	if ("tgtfirst" in COL) columns[++c] = tgtfirst[field]
	if ("tgtlast" in COL) columns[++c] = tgtlast[field]
	if ("tgtwritten" in COL) columns[++c] = h_num(field_written[target,field])
	if ("srcsnaps" in COL) columns[++c] = num_snaps[source,field]
	if ("tgtsnaps" in COL) columns[++c] = num_snaps[target,field]
	if ("summary" in COL) columns[++c] = summary[field]
	print_row(columns)
}

END {
	for (stub in stub_list) {
		if ((matches[stub] != srclast[stub]) && (matches[stub] != tgtlast[stub])) {
			status[stub] = "MISMATCH"
		}
		if (stub && (status[stub] == "SRCONLY")) {
			parent_stub = stub
			sub(/\/[^\/]+$/, "", parent_stub)
			if (!srclast[parent_stub]) status[stub] = "ORPHAN"
		} else if (status[stub] == "NOSNAP") {
		       if (num_snaps[source,stub] == "") status[stub] = "TGTONLY"
		} else if (status[stub] == "SYNCED") count_synced++
		else if ((status[stub] == "SRCONLY") || (status[stub] == "BEHIND")) count_ready++
		else count_nomatch++
		if ("summary" in COL) summary[stub] = summarize()
		if (srclast[stub] == tgtlast[stub]) xfersnaps[stub] = 0
	}
	if (LOG_LEVEL >= 0) {
		arr_sort(stub_order)
		for (i=1;i<=arrlen(stub_order);i++) chart_row(stub_order[i])
	}
	source_zfs_list_time = zfs_list_time
	count_stub = arrlen(stub_list)
	if (MODE=="PARSE") print "SOURCE_LIST_TIME:", source_zfs_list_time, ":","TARGET_LIST_TIME", target_zfs_list_time
	else {
		if (arrlen(source_latest) == 0) report(LOG_WARNING, "no source snapshots found")
		else if (count_stub == count_synced) report(LOG_DEFAULT, count_stub " datasets synced")
		else if (count_stub == count_ready) report(LOG_DEFAULT, count_stub " datasets syncable")
		else if (count_stub == count_nomatch) report(LOG_WARNING, count_stub " datasets unsyncable")
		else {
			log_msg = count_stub " total datasets"
			log_msg = log_msg (count_synced?", "count_synced" synced":"")
			log_msg = log_msg (count_ready?", "count_ready" syncable":"")
			log_msg = log_msg (count_nomatch?", "count_nomatch" unsyncable":"")
			report(LOG_WARNING, log_msg)
		}
		if (total_written[target]) report(LOG_WARNING, "target dataset has changed: " h_num(total_written[target]))
		if (total_written[source]) report(LOG_WARNING, "source dataset has changed: " h_num(total_written[source]))
		if (transfer_size) report(LOG_DEFAULT, "snapshot syncable transfer size: " h_num(transfer_size))
	}
	if (error_messages) close(STDERR)
}
