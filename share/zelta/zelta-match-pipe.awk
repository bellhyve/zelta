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
	else if ($2 ~ /^[0-9]+$/) {
		is_snapshot	= /@/ ? 1 : 0
		is_bookmark	= /#/ ? 1 : 0
		is_dataset	= !(is_snapshot || is_bookmark)
		return 1
	} else {
		report(LOG_ERROR,$0)
		exit_code = 1
		return 0
	}
}

function process_dataset(endpoint) {
	rel_name				= (dataset[endpoint] == $1) ? "" : substr($1, ds_name_length[endpoint])
	endpoint_id				= (endpoint SUBSEP rel_name)
	name[endpoint_id]			= $1
	written[endpoint_id]			= $3
	total_written[endpoint]			+= $3
	if (!rel_name_list[rel_name]++) {
		rel_name_order[++rel_name_num]	= rel_name
	}
	if (!num_snaps[endpoint_id]) {
		num_snaps[endpoint_id]		= 0
	}
}

function process_checkpoint(endpoint) {
	checkpoint_rel_name				= substr($1, ds_name_length[endpoint])
	checkpoint_id					= (endpoint SUBSEP checkpoint_rel_name)
	guid						= $2
	guid_to_name[endpoint,guid]			= checkpoint_rel_name
	name_to_guid[checkpoint_id]			= guid
	written[checkpoint_id]				= $3
	match(checkpoint_rel_name,/[@#]/)
	rel_name					= substr(checkpoint_rel_name, 1, RSTART - 1)
	checkpoint					= substr(checkpoint_rel_name, RSTART)
	dataset_id					= (endpoint SUBSEP rel_name)
	if (!num_snaps[dataset_id]++) {
		last[dataset_id]			= checkpoint
		last_guid[dataset_id]			= guid
	}
	first[dataset_id]	= checkpoint
	first_guid[dataset_id]	= guid
}

function get_checkpoint_data(endpoint) {
	if (input_has_dataset()) {
		if (is_dataset) process_dataset(endpoint)
		else if ((guid_to_name[endpoint,$2]) && is_bookmark) return
		else process_checkpoint(endpoint)
	}
}

function check_parent() {
	if (!rel_name) return
	#if (!(snapshot_list_command ~ /zfs list/)) return
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
	if (prop ~ /^(relname|name)$/)	add_prop_col("REL_NAME")
	else if (prop == "status")	add_prop_col("STATUS")
	else if (prop == "synccode")	add_prop_col("SYNC_CODE")
	else if (prop == "match")	add_prop_col("MATCH")
	else if (prop == "xfersize")	add_prop_col("XFER_SIZE")
	else if (prop == "xfernum")	add_prop_col("XFER_NUM")
	#else if (prop == "nummatches")	add_prop_col("NUM_MATCHES")
	else if (prop == "srcname")	add_prop_col("SRC_NAME")
	else if (prop == "srcfirst")	add_prop_col("SRC_FIRST")
	else if (prop == "srcnext")	add_prop_col("SRC_NEXT")
	else if (prop == "srclast")	add_prop_col("SRC_LAST")
	else if (prop == "srcwritten")	add_prop_col("SRC_WRITTEN")
	else if (prop == "srcsnaps")	add_prop_col("SRC_SNAPS")
	else if (prop == "tgtname")	add_prop_col("TGT_NAME")
	else if (prop == "tgtfirst")	add_prop_col("TGT_FIRST")
	else if (prop == "tgtnext")	add_prop_col("TGT_NEXT")
	else if (prop == "tgtlast")	add_prop_col("TGT_LAST")
	else if (prop == "tgtwritten")	add_prop_col("TGT_WRITTEN")
	else if (prop == "tgtsnaps")	add_prop_col("TGT_SNAPS")
	else if (prop == "info")	add_prop_col("INFO")
	else print "error: unknown property " prop
}

function load_property_list(props,	_prop_list, _p, _prop_num) {
	_prop_num = split(props, _prop_list, /,/)
	for (_p = 1; _p <= _prop_num; _p++) {
		if (_prop_list[_p] == "all")		load_property_list(PROPERTIES_ALL)
		else if (_prop_list[_p] == "list")	load_property_list(PROPERTIES_LIST)
		else check_prop_col(_prop_list[_p])
	}
}
	
BEGIN {
	FS			= "\t"
	OFS			= "\t"
	STDERR			= "/dev/stderr"
	LOG_ERROR		= -2
	LOG_WARNING		= -1
	LOG_DEFAULT		= 0
	LOG_VERBOSE		= 1
	LOG_VV			= 2
	LOG_LEVEL		= env("ZELTA_LOG_LEVEL", 0)

	PROPERTIES_ALL		= "relname,xfersize,xfernum,match,srcfirst,srclast,srcsnaps,srcwritten,tgtlast,tgtwritten,tgtsnaps"
	PROPERTIES_LIST		= "relname,match,srcfirst,srcnext,srclast,tgtlast"
	PROPERTIES_DEFAULT	= "relname,match,srclast,tgtlast,info"
	load_property_list(env("ZELTA_MATCH_PROPERTIES", PROPERTIES_DEFAULT))

	MODE			= "CHART"
	PASS_FLAGS		= env("ZELTA_MATCH_FLAGS", "")

	if (PASS_FLAGS ~ /p/) PARSABLE++
	if (PASS_FLAGS ~ /q/) LOG_LEVEL--
	if (PASS_FLAGS ~ /H/) {
		NOHEADER++
		MODE = "ONETAB"
	}
	if (PASS_FLAGS ~ /v/) LOG_LEVEL++


	exit_code = 0
	LOG_MODE = ZELTA_PIPE ? 0 : 1
	target_zfs_list_time = 0
}

function get_endpoint_info() {
	endpoint = $1
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
		ds_trim_length = ds_name_length[target]
		while  (snapshot_list_command | getline) get_checkpoint_data(target)
		close(snapshot_list_command)
	}
	target_zfs_list_time = zfs_list_time
}

NR > 3 {
	get_checkpoint_data(source)
	if (!(is_snapshot || is_bookmark)) next
	if (rel_name in last_match) {
		if (guid_to_name[target,guid]) num_matches[rel_name]++
	} else if (!last[target,rel_name] && !(rel_name in new_dataset)) {
		check_parent()
		new_dataset[rel_name]	= checkpoint
	} else if (guid_to_name[target,guid]) {
		last_match[rel_name]		= checkpoint
		last_match_guid[rel_name]	= guid
	} else count_snapshot_diff()
}

function dataset_is_orphan() {
	parent_rel_name = rel_name
	sub(/\/[^\/]+$/, "", parent_rel_name)
	return (!last[source,parent_rel_name])
}

function get_sync_code() {
	if (name[source_id]) {
		s		= 1
		s		+= last[source_id] ? 2 : 0
		s		+= written[source_id] ? 4 : 0
	} else	s		= 0
	m			= last_match_guid[rel_name] ? 1 : 0
	m			+= source_latest_match ? 2 : 0
	m			+= target_latest_match ? 4 : 0
	if (name[target_id]) {
		t		= 1
		t		+= last[target_id] ? 2 : 0
		t		+= written[target_id] ? 4 : 0
	} else	t		= 0
	return (s m t)
}

function get_status() {
	if (m >= 6)				return	"UP_TO_DATE"
	else if (!s)				return	"NO_SOURCE"
	else if (!last[source_id])		return	"NO_SOURCE_SNAPSHOT"
	else if (!t)				return	"SYNCABLE_NEW"
	else if (m == 5)			return	"SYNCABLE_UPDATE"
	else if (!source_latest_match)		return	"BLOCKED_BY_SNAPSHOT"
	else if (written[target_id])		return	"BLOCKED_BY_WRITTEN"
	else 					return	"UNSYNCABLE"
}

function get_info() {
	if (!name[target_id] && name[source_id]) { 
		if (dataset_is_orphan())	return	"source parent has no snapshots"
		else if (last[source_id])	return	"source only; no target dataset"
		else 				return	"no source snapshots; no target dataset"
	} else if (!name[source_id] && name[target_id]) {
		if (last[target_id])		return	"no source dataset; target dataset exists"
		else 				return	"no source dataset; no target snapshots"
	} else if (source_latest_match && target_latest_match) {
		if (written[target_id])		return	"up-to-date but cannot sync: target is written"
		else if (written[source_id])	return	"up-to-date; source is written"
		else 				return	"up-to-date"
	} else if (!source_latest_match && target_latest_match) {
		if (written[target_id])		return	"target is out-of-date; warning: target is written"
		if (written[source_id])		return	"target is out-of-date; source is written"
		else				return	"target is out-of-date"
	} else if (source_latest_match && !target_latest_match) {
						return	"cannot sync: target has newer snapshots than source"
	} else if (last_match[rel_name]) {
						return	"cannot sync: source and target have diverged"
	} else					return	"cannot determine sync state"
}

function get_summary() {
	target_id				= (target SUBSEP rel_name)
	source_id				= (source SUBSEP rel_name)
	if (last_match_guid[rel_name]) {
		source_latest_match		= (last_match_guid[rel_name] == last_guid[source_id])
		target_latest_match		= (last_match_guid[rel_name] == last_guid[target_id])
	} else {
		source_latest_match		= 0
		target_latest_match		= 0
	}
	sync_code[rel_name]			= get_sync_code()
	status[rel_name]			= get_status()
	info[rel_name]				= get_info()
	if (status[rel_name] ~ /^SYNCABLE/)	count_ready++
	else if (m >= 6)			count_synced++
	else					count_blocked++
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
		if ("SYNC_CODE" == col) make_header_column(col, sync_code)
		if ("XFER_SIZE" == col) make_header_column(col, xfersize)
		if ("XFER_NUM" == col) make_header_column(col, xfersnaps)
		#if ("NUM_MATCHES" == col) make_header_column(col, num_matches)
		if ("MATCH" == col) make_header_column(col, last_match)
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
		if ("INFO" == col) make_header_column(col, info)
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
		if ("SYNC_CODE" == col) columns[cnum] = sync_code[field]
		if ("XFER_SIZE" == col) columns[cnum] = h_num(xfersize[field])
		if ("XFER_NUM" == col) columns[cnum] = xfersnaps[field]
		if ("MATCH" == col) columns[cnum] = last_match[field]
		#if ("NUM_MATCHES" == col) columns[cnum] = num_last_match[field]
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
		if ("INFO" == col) columns[cnum] = info[field]
	}
	print_row(columns)
}

function summarize() {
	if (LOG_LEVEL >= 0) {
		arr_sort(rel_name_order)
		for (i=1; i <= rel_name_num; i++) chart_row(rel_name_order[i])
	}
	if (MODE=="ONETAB") {
		source_zfs_list_time = zfs_list_time
		print "SOURCE_LIST_TIME:", source_zfs_list_time, ":","TARGET_LIST_TIME", target_zfs_list_time
	} else {
		#count_rel_name = arrlen(rel_name_list)
		count_rel_name = rel_name_num
		#if (arrlen(source_latest) == 0) report(LOG_WARNING, "no source snapshots found")
		if (count_rel_name == count_synced) report(LOG_DEFAULT, count_rel_name " datasets synced")
		else if (count_rel_name == count_ready) report(LOG_DEFAULT, count_rel_name " datasets syncable")
		else if (count_rel_name == count_blocked) report(LOG_WARNING, count_rel_name " datasets unsyncable")
		else {
			log_msg = count_rel_name " total datasets"
			log_msg = log_msg (count_synced?", "count_synced" synced":"")
			log_msg = log_msg (count_ready?", "count_ready" syncable":"")
			log_msg = log_msg (count_blocked?", "count_blocked" unsyncable":"")
			report(LOG_WARNING, log_msg)
		}
		if (total_written[target]) report(LOG_WARNING, "target dataset has changed: " h_num(total_written[target]))
		if (total_written[source]) report(LOG_WARNING, "source dataset has changed: " h_num(total_written[source]))
		if (transfer_size) report(LOG_DEFAULT, "snapshot syncable transfer size: " h_num(transfer_size))
	}
}

END {
	for (rel_name in rel_name_list) get_summary()
	summarize()
	if (error_messages) close(STDERR)
}
