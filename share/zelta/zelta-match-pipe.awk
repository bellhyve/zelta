#!/usr/bin/awk -f
#
# zelta-match-pipe.awk - compares a snapshot list
#
# usage: compares two "zfs list" commands; one "zfs list" is piped for parrallel
# processing.

function arrlen(array,		_element_count, _key) {
	for (_key in array) _element_count++
	return _element_count
}

function depth_too_high() {
	return (Opt["DEPTH"] && (split(rel_name, depth_arr, "/") > Opt["DEPTH"]))
}

function process_dataset(endpoint) {
	rel_name				= (dataset[endpoint] == $1) ? "" : substr($1, ds_name_length[endpoint])
	if (depth_too_high()) return 0
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

function process_savepoint(endpoint) {
	savepoint_rel_name				= substr($1, ds_name_length[endpoint])
	savepoint_id					= (endpoint SUBSEP savepoint_rel_name)
	guid						= $2
	guid_to_name[endpoint,guid]			= savepoint_rel_name
	name_to_guid[savepoint_id]			= guid
	written[savepoint_id]				= $3
	match(savepoint_rel_name,/[@#]/)
	rel_name					= substr(savepoint_rel_name, 1, RSTART - 1)
	savepoint					= substr(savepoint_rel_name, RSTART)
	dataset_id					= (endpoint SUBSEP rel_name)
	if (!num_snaps[dataset_id]++) {
		last[dataset_id]			= savepoint
		LastGUID[dataset_id]			= guid
	}
	first[dataset_id]	= savepoint
	first_guid[dataset_id]	= guid
}

# Check for snapshot, bookmark, dataset, or time data
function parse_stream(endpoint) {
	if (endpoint == target) report(LOG_INFO, $0)
	if (/^real[ \t]+[0-9]/) {
		split($0, time_arr, /[ \t]+/)
		zfs_list_time[endpoint] += time_arr[2]
	} else if (/(sys|user)[ \t]+[0-9]/) return
	else if (/dataset does not exist/) return
	else if ($2 ~ /^[0-9]+$/) {
		is_snapshot	= /@/ ? 1 : 0
		is_bookmark	= /#/ ? 1 : 0
		is_dataset	= !(is_snapshot || is_bookmark)
		if (is_dataset) process_dataset(endpoint)
		else if (is_bookmark && (guid_to_name[endpoint,$2] || SKIP_BOOKMARKS)) return
		else process_savepoint(endpoint)
	} else {
		report(LOG_WARNING, "stream output unexpected: "$0)
		exit_code = 1
	}
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


# Properties can be ordered by the user, so we use the explicit hash order for "all properties"
function use_all_properties(hash,	_n, _i, _pair, _tmp_dict) {
	_n = split(hash, _arr, " ")
	for (_i = 1; _i <= _n; _i++) {
		split(_arr[_i], _pair, ":")
		if (!_tmp_dict[_pair[2]]++) {
			PropList[++PropNum] = _pair[2]
		}
	}
}

function use_custom_properties(prop_dict,	_p, _prop_num, _prop_arr) {
	_prop_num = split(Opt["PROPLIST"], _prop_arr, /,/)
	for (_p = 1; _p <= _prop_num; _p++) {
		if (_prop_arr[_p]) {
			PropList[++PropNum] = prop_dict[_prop_arr[_p]]
		} else {
			report(LOG_ERROR, "invalid property '"_prop_arr[_p]"'")
			stop(1)
		}
	}
}

function load_property_list(	_hash, _prop_dict) {
	_hash =	"relname:REL_NAME name:REL_NAME status:STATUS synccode:SYNC_CODE " \
		"match:MATCH xfersize:XFER_SIZE xfernum:XFER_NUM " \
		"srcname:SRC_NAME srcfirst:SRC_FIRST srcnext:SRC_NEXT srclast:SRC_LAST srcwritten:SRC_WRITTEN srcsnaps:SRC_SNAPS " \
		"tgtname:TGT_NAME tgtfirst:TGT_FIRST tgtnext:TGT_NEXT tgtlast:TGT_LAST tgtwritten:TGT_WRITTEN tgtsnaps:TGT_SNAPS " \
		"info:INFO"
	if (Opt["PROPLIST"] == "all") {
		use_all_properties(_hash)
	} else {
		create_dict(_prop_dict, _hash)
		if (!Opt["PROPLIST"]) Opt["PROPLIST"] = "relname,match,srclast,tgtlast,info"
		else gsub(/_/,"",Opt["PROPLIST"])
		use_custom_properties(_prop_dict)
	}
}

BEGIN {
	FS			= "\t"
	OFS			= "\t"

	load_property_list(Opt["PROPLIST"])


	source = Opt["SRC_ID"]
	target = Opt["TGT_ID"]
	dataset[source] = Opt["SRC_DS"]
	dataset[target] = Opt["TGT_DS"]
	ds_name_length[source] = length(Opt["SRC_DS"]) + 1
	ds_name_length[target] = length(Opt["TGT_DS"]) + 1

	exit_code = 0
	zfs_list_time[source] = 0
	zfs_list_time[target] = 0
}

function count_snapshot_diff() {
	transfer_size += snapshot_written
	xfersize[rel_name] += snapshot_written
	xfersnaps[rel_name]++
}

function run_zfs_list() {
	SKIP_BOOKMARKS = 1
	transfer_size = 0
	zfs_list_tgt = $0;
	if ((source == target)) {
		report(LOG_WARNING, "warning: identical source and target")
	} else {
		# Load target snapshots
		ds_trim_length = ds_name_length[target]
		while  (zfs_list_tgt | getline ) { parse_stream(target) }
		#close(zfs_list_tgt)
	}
}

# Load variables from pipe
!LIST_STREAM {
	if (sub(/^TGT_PARENT:\t/,"")) {
		if ($0 == "no") {
			report(LOG_ERROR, "parent dataset does not exist: " Opt["TGT_DS"])
		}
	} else if (sub(/^SRC_PARENT:\t/,"")) {
		if ($0 == "no") {
			report(LOG_ERROR, "parent dataset does not exist: " Opt["SRC_DS"])
		}
	} else if (sub(/^ZFS_LIST_TGT:\t/,"")) run_zfs_list()
	else if (sub(/^ZFS_LIST_STREAM:\t/,"")) {
		# Make sure the environment matches the ID of the incoming stream
		if ($1 != Opt["SRC_ID"]) {
			report(LOG_ERROR, "unexpected zfs list stream")
		}
		# Switch to LIST_STREAM mode
		SKIP_BOOKMARKS = 0
		LIST_STREAM++ 
		next
	}
}

# Load "zfs list" output (and "time -p" data) from pipe
LIST_STREAM {
	# Load ZFS
	# Check for EOF of the current stream
	if (/^ZFS_LIST_STREAM_END$/) {
		LIST_STREAM = 0
		next
	}
	parse_stream(source)
	if (!(is_snapshot || is_bookmark)) next
	if (rel_name in last_match) {
		if (guid_to_name[target,guid]) num_matches[rel_name]++
	} else if (guid_to_name[target,guid]) {
		last_match[rel_name]		= savepoint
		LastMatchGUID[rel_name]	= guid
	} else count_snapshot_diff()
}

function dataset_is_orphan() {
	parent_rel_name = rel_name
	sub(/\/[^\/]+$/, "", parent_rel_name)
	return (!last[source,parent_rel_name])
}

function get_sync_code() {
	if (name[SourceKey]) {
		s		= 1
		s		+= last[SourceKey] ? 2 : 0
		s		+= written[SourceKey] ? 4 : 0
	} else	s		= 0
	m			= LastMatchGUID[rel_name] ? 1 : 0
	m			+= SourceHasLatestMatch ? 2 : 0
	m			+= TargetHasLatestMatch ? 4 : 0
	if (name[TargetKey]) {
		t		= 1
		t		+= last[TargetKey] ? 2 : 0
		t		+= written[TargetKey] ? 4 : 0
	} else	t		= 0
	return (s m t)
}

# Provide a simple relationsihip code/
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
	if (!name[TargetKey] && name[SourceKey]) { 
		if (dataset_is_orphan())	return	"source parent has no snapshots"
		else if (last[SourceKey])	return	"source only; no target dataset"
		else 				return	"no source snapshots; no target dataset"
	} else if (!name[SourceKey] && name[TargetKey]) {
		if (last[TargetKey])		return	"no source dataset; target dataset exists"
		else 				return	"no source dataset; no target snapshots"
	} else if (SourceHasLatestMatch && TargetHasLatestMatch) {
		if (written[TargetKey])		return	"up-to-date but cannot sync: target is written"
		else if (written[SourceKey])	return	"up-to-date; source is written"
		else 				return	"up-to-date"
	} else if (!SourceHasLatestMatch && TargetHasLatestMatch) {
		if (written[TargetKey])		return	"target is out-of-date; warning: target is written"
		if (written[SourceKey])		return	"target is out-of-date; source is written"
		else				return	"target is out-of-date"
	} else if (SourceHasLatestMatch && !TargetHasLatestMatch) {
						return	"cannot sync: target has newer snapshots than source"
	} else if (last_match[rel_name]) {
						return	"cannot sync: source and target have diverged"
	} else if (!TargetHasLatestMatch) {	return	"cannot sync: target has no matching snapshots"
	} else					return	"cannot determine sync state"
}

function get_summary() {
	TargetKey				= (target SUBSEP rel_name)
	SourceKey				= (source SUBSEP rel_name)
	if (LastMatchGUID[rel_name]) {
		SourceHasLatestMatch		= (LastMatchGUID[rel_name] == LastGUID[SourceKey])
		TargetHasLatestMatch		= (LastMatchGUID[rel_name] == LastGUID[TargetKey])
	} else {
		SourceHasLatestMatch		= 0
		TargetHasLatestMatch		= 0
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
		if (Opt["PARSABLE"]) printf ((c>1)?"\t":"") cols[c]
		else printf ((c>1)?"  ":"") pad[c], cols[c]
	}
	printf "\n"
}

function make_header_column(title, arr, endpoint) {
	columns[cnum] = Opt["SCRIPTING_MODE"] ? "  " : toupper(title)
	if (!Opt["PARSABLE"]) { 
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
	for (cnum=1;cnum<=PropNum;cnum++) {
		col = PropList[cnum]
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

function chart_row(field,	cnum, col) {
	if (!ROW++ && !(Opt["SCRIPTING_MODE"])) chart_header()
	delete columns
	for (cnum=1;cnum<=PropNum;cnum++) {
		col = PropList[cnum]
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
	if (Opt["LOG_LEVEL"] >= 0) {
		arr_sort(rel_name_order)
		for (i=1; i <= rel_name_num; i++) chart_row(rel_name_order[i])
	}
	if (Opt["CHECK_TIME"]) {
		print "SOURCE_LIST_TIME:", zfs_list_time[source]
		print "TARGET_LIST_TIME:", zfs_list_time[target]
	} else {
		#count_rel_name = arrlen(rel_name_list)
		count_rel_name = rel_name_num
		#if (arrlen(source_latest) == 0) report(LOG_WARNING, "no source snapshots found")
		if (!count_rel_name) report(LOG_NOTICE, "no datasets on source or target")
		else if (count_rel_name == count_synced) report(LOG_NOTICE, count_rel_name " datasets synced")
		else if (count_rel_name == count_ready) report(LOG_NOTICE, count_rel_name " datasets syncable")
		else if (count_rel_name == count_blocked) report(LOG_NOTICE, count_rel_name " datasets unsyncable")
		else {
			log_msg = count_rel_name " total datasets"
			log_msg = log_msg (count_synced?", "count_synced" synced":"")
			log_msg = log_msg (count_ready?", "count_ready" syncable":"")
			log_msg = log_msg (count_blocked?", "count_blocked" unsyncable":"")
			report(LOG_WARNING, log_msg)
		}
		if (total_written[target]) report(LOG_WARNING, "target dataset has changed: " h_num(total_written[target]))
		if (total_written[source]) report(LOG_WARNING, "source dataset has changed: " h_num(total_written[source]))
		if (transfer_size) report(LOG_NOTICE, "snapshot syncable transfer size: " h_num(transfer_size))
	}
}

END {
	for (rel_name in rel_name_list) get_summary()
	# Print a chart and a summary of the replica sync state
	summarize()
	stop()
}
