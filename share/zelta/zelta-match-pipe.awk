#!/usr/bin/awk -f
#
# zelta-match-pipe.awk - compares a snapshot list
#
# usage: compares two "zfs list" commands; one "zfs list" is piped for parrallel
# processing.

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
	if (PARSABLE) return num
	suffix = "B"
	divisors = "KMGTPE"
	for (h = 1; h <= length(divisors) && num >= 1024; h++) {
		num /= 1024
		suffix = substr(divisors, h, 1)
	}
	return int(num) suffix
}

function arrlen(array) {
	element_count = 0
	for (key in array) element_count++
	return element_count
}

function input_has_dataset() {
	if (/^real[ \t]+[0-9]/) {
		split($0, time_arr, /[ \t]+/)
		zfs_list_time += time_arr[2]
		return 0
	} else if (/(sys|user)[ \t]+[0-9]/) return 0
	else if (/dataset does not exist/) return 0
	else if ($2 ~ /^[0-9]+$/) return 1
	else {
		report(LOG_ERROR,$0)
		exit_code = 1
		return 0
	}
}

function process_dataset(endpoint) {
	rel_name = ($1 == dataset[endpoint]) ? "" : substr($1, ds_name_length[endpoint])
	name[endpoint,rel_name] = $1
	if (!rel_name_list[rel_name]++) rel_name_order[++rel_name_num] = rel_name
	if (!status[rel_name]) status[rel_name] = "NOSNAP"
	if (!num_snaps[endpoint,rel_name]) num_snaps[endpoint,rel_name] = 0
	written[endpoint,rel_name] += $3
	total_written[endpoint] += $3
}

function process_snapshot(endpoint) {
	snapshot_rel_name = substr($1, ds_name_length[endpoint])	# [child]@snapshot
	guid_to_name[endpoint,guid] =  snapshot_rel_name
	name_to_guid[endpoint,snapshot_rel_name] = guid	# GUID property
	written[endpoint,snapshot_rel_name] = $3	# written property
	split(snapshot_rel_name, split_rel_name, "@")
	rel_name = split_rel_name[1]			# [child] (blank for top dataset name)
	snapshot_name = "@" split_rel_name[2]	# @snapshot
	# First, Last, and Count of snapshots
	if (!num_snaps[endpoint,rel_name]++) last[endpoint,rel_name] = snapshot_name
	first[endpoint,rel_name] = snapshot_name
}

function process_bookmark(endpoint) {
	bookmark_rel_name = substr($1, ds_name_length[endpoint])
	snapshot_rel_name = bookmark_rel_name
	if (guid_to_name[endpoint,guid]) return
	guid_to_name[endpoint,guid] = bookmark_rel_name
	name_to_guid[endpoint,bookmark_rel_name] = guid
	match(bookmark_rel_name,/[@#]/)
	rel_name = substr(bookmark_rel_name, 1, RSTART - 1)
	snapshot_name = substr(bookmark_rel_name, RSTART)
}

function get_snapshot_data(endpoint) {
	if (input_has_dataset()) {
		guid = $2
		if ($1 ~ /@/) { 
			process_snapshot(endpoint)
			return 1
		} else if ($1 ~ /#/) { 
			process_bookmark(endpoint)
			return 1
		} else process_dataset(endpoint)
	}
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

function add_prop_col(prop) {
	PROP_LIST[++PROP_NUM] = prop
	PROP_DICT[prop] = PROP_NUM
}
	
function check_prop_col(prop) {
	prop = tolower(prop)
	gsub(/_/, "", prop)
	if (prop ~ /^(relname|name|rel_name)/) add_prop_col("REL_NAME")
	else if (prop == "status") add_prop_col("STATUS")
	else if (prop == "action") add_prop_col("ACTION")
	else if (prop == "match") add_prop_col("MATCH")
	else if (prop == "xfersize") add_prop_col("XFER_SIZE")
	else if (prop == "xfernum") add_prop_col("XFER_NUM")
	else if (prop == "nummatches") add_prop_col("NUM_MATCHES")
	else if (prop == "srcname") add_prop_col("SRC_NAME")
	else if (prop == "srcfirst") add_prop_col("SRC_FIRST")
	else if (prop == "srcnext") add_prop_col("SRC_NEXT")
	else if (prop == "srclast") add_prop_col("SRC_LAST")
	else if (prop == "srcwritten") add_prop_col("SRC_WRITTEN")
	else if (prop == "srcsnaps") add_prop_col("SRC_SNAPS")
	else if (prop == "tgtname") add_prop_col("TGT_NAME")
	else if (prop == "tgtfirst") add_prop_col("TGT_FIRST")
	else if (prop == "tgtnext") add_prop_col("TGT_NEXT")
	else if (prop == "tgtlast") add_prop_col("TGT_LAST")
	else if (prop == "tgtwritten") add_prop_col("TGT_WRITTEN")
	else if (prop == "tgtsnaps") add_prop_col("TGT_SNAPS")
	else if (prop == "info") add_prop_col("INFO")
	else print "error: unknown property " prop
}
	
function property_list() {
	PROPERTIES_ALL = "rel_name,status,action,match,xfer_size,xfer_num,num_matches,src_name,src_first,src_next,src_last,src_snaps,src_written,tgt_name,tgt_first,tgt_next,tgt_last,tgt_written"
	PROPERTIES_LIST_DEFAULT = "rel_name,status,action,match,src_first,src_next,src_last,tgt_last"
	PROPERTIES_MATCH_DEFAULT = "rel_name,info"
	properties = env("ZELTA_MATCH_PROPERTIES", PROPERTIES_MATCH_DEFAULT)
	if (properties == "all") properties = PROPERTIES_ALL
	else if (properties == "list") properties = PROPERTIES_LIST_DEFAULT
	prop_num = split(properties, prop_list, /,/)
	for (p=1;p<=prop_num;p++) check_prop_col(prop_list[p])
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
	LOG_LEVEL = env("ZELTA_LOG_LEVEL", 0)

	MODE = "CHART"
	PASS_FLAGS = env("ZELTA_MATCH_FLAGS", "")
	if (PASS_FLAGS ~ /p/) PARSABLE++
	if (PASS_FLAGS ~ /q/) LOG_LEVEL--
	if (PASS_FLAGS ~ /H/) {
		NOHEADER++
		MODE = "ONETAB"
	}
	if (PASS_FLAGS ~ /v/) LOG_LEVEL++

	property_list()

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
	xfersize[rel_name] += snapshot_written
	xfersnaps[rel_name]++
}

NR == 1 { source = get_endpoint_info() }

NR == 2 { target = get_endpoint_info() }

NR == 3 {
	zfs_list_time = 0
	transfer_size = 0
	if (!target) next
	snapshot_list_command = $0;
	if ((source == target) || !snapshot_list_command) {
		report(LOG_WARNING, "identical source and target")
	} else {
		# Load target snapshots
		while  (snapshot_list_command | getline) get_snapshot_data(target)
		close(snapshot_list_command)
	}
	target_zfs_list_time = zfs_list_time
}

NR > 3 {
	if (!get_snapshot_data(source)) { next }
	if (rel_name in matches) next
	else if (!last[target,rel_name] && !(rel_name in new_dataset)) {
		if (!rel_name) check_parent()
		new_dataset[rel_name] = snapshot_name
		if (written[target,rel_name]) status[rel_name] = "MISMATCH"
		else if (num_snaps[target,rel_name] == "0") status[rel_name] = "NO_MATCH"
		else {
			status[rel_name] = "SRC_ONLY"
			count_snapshot_diff()
		}
	} else if (guid_to_name[target,guid]) {
		matches[rel_name] = snapshot_name
		if (snapshot_name == last[source,rel_name]) {
			status[rel_name] = (snapshot_name == last[target,rel_name]) ? "SYNCED" : "AHEAD"
		} else {
			status[rel_name] = "BEHIND"
		}
		#if (name_to_guid[target,snapshot_rel_name] == name_to_guid[source,snapshot_rel_name]) {
		#	if (snapshot_rel_name == last[source,rel_name]) {
		#		#basic_log[rel_name] = "target has latest source snapshot: " snapshot_rel_name
		#	} else if (guid_error[rel_name]) {
		#		# report(LOG_VERBOSE,"latest guid match: " snapshot_rel_name)
		#		status[rel_name] = "MISMATCH"
		#	} else {
		#		status[rel_name] = "BEHIND"
		#		#basic_log[rel_name] = "match: " snapshot_rel_name OFS "latest: " source_latest[rel_name]
		#	}
		#} else {
		#	report(LOG_VERBOSE,"guid mismatch: " snapshot_rel_name)
		#	#warning_log[rel_name] = warning_log[rel_name] "guid mismatch on: " snapshot_rel_name "\n"
		#	guid_error[rel_name]++
		#}
	} else count_snapshot_diff()
}

function summarize() {
	if (status[rel_name]=="SYNCED") s = "up-to-date"
	else if (status[rel_name]=="SRC_ONLY") s = "syncable, new dataset"
	else if ((status[rel_name]=="BEHIND") && written[source,rel_name]) s = "target is written"
	else if (status[rel_name]=="BEHIND") s = "syncable"
	else if (status[rel_name]=="TGT_ONLY") s = "no source dataset"
	else if (status[rel_name]=="AHEAD") s = "target is ahead"
	else if (status[rel_name]=="NOSNAP") s = "no source snapshots"
	else if (status[rel_name]=="NOMATCH") s = "target has no snapshots"
	else if (status[rel_name]=="ORPHAN") s = "no parent snapshot"
	else if (guid_error[rel_name]) s = "guid mismatch"
	else s = "match, but latest snapshots differ"
	return s
}

function print_row(cols) {
	num_col = arrlen(cols)
	for(c=1;c<=num_col;c++) {
		if (MODE=="ONETAB") printf ((c>1)?"\t":"") cols[c]
		if (MODE=="CHART") printf ((c>1)?"  ":"") pad[c], cols[c]
	}
	printf "\n"
}

function make_header_column(title, arr, endpoint) {
	columns[cnum] = NOHEADER?"  ":toupper(title)
	if (MODE=="CHART") { 
		width = length(title)
		for (w in arr) {
			if (!endpoint || index(w, endpoint) == 1) {
				if (length(arr[w])>width) width = length(arr[w])
			}
		}
		pad[cnum] = "%-"width"s"
	}
}

function chart_header() {
	for (cnum=1;cnum<=PROP_NUM;cnum++) {
		col = PROP_LIST[cnum]
		if ("REL_NAME" == col) make_header_column(col, rel_name_order)
		if ("STATUS" == col) make_header_column(col, status)
		if ("ACTION" == col) make_header_column(col, action)
		if ("XFER_SIZE" == col) make_header_column(col, xfersize)
		if ("XFER_NUM" == col) make_header_column(col, xfersnaps)
		if ("MATCH" == col) make_header_column(col, matches)
		if ("NUM_MATCHES" == col) make_header_column(col, num_matches)
		if ("SRC_NAME" == col) make_header_column(col, name, source)
		if ("SRC_FIRST" == col) make_header_column(col, first, source)
		if ("SRC_NEXT" == col) make_header_column(col, src_next)
		if ("SRC_LAST" == col) make_header_column(col, last, source)
		if ("SRC_WRITTEN" == col) make_header_column(col, written, source)
		if ("SRC_SNAPS" == col) make_header_column(col, num_snaps)
		if ("TGT_NAME" == col) make_header_column(col, name, target)
		if ("TGT_FIRST" == col) make_header_column(col, first, target)
		if ("TGT_NEXT" == col) make_header_column(col, tgt_next)
		if ("TGT_LAST" == col) make_header_column(col, last, target)
		if ("TGT_WRITTEN" == col) make_header_column(col, written, target)
		if ("TGT_SNAPS" == col) make_header_column(col, num_snaps, target)
		if ("INFO" == col) make_header_column(col, summary)
	}
	print_row(columns)
}

function chart_row(field) {
	if (!ROW++ && !(MODE == "ONETAB")) chart_header()
	delete columns
	for (cnum=1;cnum<=PROP_NUM;cnum++) {
		col = PROP_LIST[cnum]
		if ("REL_NAME" == col) columns[cnum] = field
		if ("STATUS" == col) columns[cnum] = status[field]
		if ("ACTION" == col) columns[cnum] = action[field]
		if ("XFER_SIZE" == col) columns[cnum] = h_num(xfersize[field])
		if ("XFER_NUM" == col) columns[cnum] = xfersnaps[field]
		if ("MATCH" == col) columns[cnum] = matches[field]
		if ("NUM_MATCHES" == col) columns[cnum] = num_matches[field]
		if ("SRC_NAME" == col) columns[cnum] = name[source,field]
		if ("SRC_FIRST" == col) columns[cnum] = first[source,field]
		if ("SRC_NEXT" == col) columns[cnum] = src_next[field]
		if ("SRC_LAST" == col) columns[cnum] = last[source,field]
		if ("SRC_WRITTEN" == col) columns[cnum] = h_num(written[source,field])
		if ("SRC_SNAPS" == col) columns[cnum] = num_snaps[source,field]
		if ("TGT_NAME" == col) columns[cnum] = name[target,field]
		if ("TGT_FIRST" == col) columns[cnum] = first[target,field]
		if ("TGT_NEXT" == col) columns[cnum] = tgt_next[field]
		if ("TGT_LAST" == col) columns[cnum] = last[target,field]
		if ("TGT_WRITTEN" == col) columns[cnum] = h_num(written[target,field])
		if ("TGT_SNAPS" == col) columns[cnum] = num_snaps[target,field]
		if ("INFO" == col) columns[cnum] = summary[field]
	}
	print_row(columns)
}

END {
	for (rel_name in rel_name_list) {
		if ((matches[rel_name] != last[source,rel_name]) && (matches[rel_name] != last[target,rel_name])) {
			status[rel_name] = "MISMATCH"
		}
		if (rel_name && (status[rel_name] == "SRC_ONLY")) {
			parent_rel_name = rel_name
			sub(/\/[^\/]+$/, "", parent_rel_name)
			if (!last[source,parent_rel_name]) status[rel_name] = "ORPHAN"
		} else if (status[rel_name] == "NOSNAP") {
		       if (num_snaps[source,rel_name] == "") status[rel_name] = "TGT_ONLY"
		} else if (status[rel_name] == "SYNCED") count_synced++
		else if ((status[rel_name] == "SRC_ONLY") || (status[rel_name] == "BEHIND")) count_ready++
		else count_nomatch++
		summary[rel_name] = summarize()
		if (last[source,rel_name] == last[target,rel_name]) xfersnaps[rel_name] = 0
	}
	if (LOG_LEVEL >= 0) {
		arr_sort(rel_name_order)
		for (i=1;i<=arrlen(rel_name_order);i++) chart_row(rel_name_order[i])
	}
	source_zfs_list_time = zfs_list_time
	count_rel_name = arrlen(rel_name_list)
	if (MODE=="ONETAB") print "SOURCE_LIST_TIME:", source_zfs_list_time, ":","TARGET_LIST_TIME", target_zfs_list_time
	else {
		if (arrlen(source_latest) == 0) report(LOG_WARNING, "no source snapshots found")
		else if (count_rel_name == count_synced) report(LOG_DEFAULT, count_rel_name " datasets synced")
		else if (count_rel_name == count_ready) report(LOG_DEFAULT, count_rel_name " datasets syncable")
		else if (count_rel_name == count_nomatch) report(LOG_WARNING, count_rel_name " datasets unsyncable")
		else {
			log_msg = count_rel_name " total datasets"
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
