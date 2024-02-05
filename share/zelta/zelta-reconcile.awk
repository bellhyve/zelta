#!/usr/bin/awk -f
#
# zelta reconcile - compares a snapshot list via pipe and command
#
# usage: internal to "zelta match", but could be leveraged for other comparison
# operations.
#
# Reports the most recent matching snapshot and the latest snapshot of a volume and
# its children, which are useful for various zfs operations
#
# In interactive mode, child snapshot names are provided relative to the target
# dataset. For example, when zmatch is called with tank/dataset, tank/dataset/child's
# snapshots will be reported as"/child@snapshot-name".
#
# Specifically:
#   - The latest matching snapshot and child snapshots
#   - Missing child volumes on the destination
#   - Matching snapshot names with different GUIDs
#   - Newer target snapshots not on the source
#
# If only one argument is given, report the amount of data written since the last
# snapshot.
#
# ENVIRONMENT VARIABLES
#
# ZELTA_PIPE: When set to 1, we provide full snapshot names and simplify the output as
# follows:
#   - No output is provided for an up-to-date match.
#   - A single snapshot indicates the volume is missing on the target.
#   - A tab separated pair of snapshots indicates the out-of-date match and the latest.

function env(env_name, var_default) {
	return ( (env_name in ENVIRON) ? ENVIRON[env_name] : var_default )
}

function report(level, message) {
	if (!message) return 0
	if ((level <= LOG_LEVEL) && (level < 0)) print message > STDERR
	if (level <= LOG_LEVEL) print message
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

function get_snapshot_data(volume_name) {
		trim = vol_name_length[volume_name]
		if (/dataset does not exist/) return 0
		else if (/^real[ \t]+[0-9]/) {
			split($0, time_arr, /[ \t]+/)
			zfs_list_time = time_arr[2]
			return 0
		} else if (/(sys|user)[ \t]+[0-9]/) {
			return 0
		} else if (!($1 ~ /@/) && ($2 ~ /[0-9]/)) {
			# Toggle remote/target list to see what's missing
			stub = substr($1, trim)
			if (volume_check[stub]) delete volume_check[stub]
			else volume_check[stub] = $1
			if (!stub_list[stub]++) stub_order[++stub_num] = stub
			if (!status[stub]) status[stub] = "NOSNAP"
			if (!num_snaps[volume_name,stub]) num_snaps[volume_name,stub] = 0
			stub_written[volume_name,stub] += $3
			volume_written[volume_name] += $3
			return 0
		} else if (! /@/) {
			report(LOG_ERROR,$0)
			exit_code = 1
			return 0
		}
		dataset_name = $1			# full/volume@snapshot
		snapshot_stub = substr($1, trim)	# [child]@snapshot
		snapshot_guid = $2			# GUID property
		snapshot_written = $3			# written property
		split(snapshot_stub, split_stub, "@")
		dataset_stub = split_stub[1]		# [child] (blank for top volume name)
		snapshot_name = "@" split_stub[2]	# @snapshot
		num_snaps[volume_name,dataset_stub]++   # Total snapshots per dataset
		return 1
}

function load_target_snapshots() {
	while  (snapshot_list_command | getline) {
		if (!get_snapshot_data(target)) { continue }
		target_guid[snapshot_stub] = snapshot_guid
		target_written[snapshot_stub] = snapshot_written
		stub_written[target,stub] += snapshot_written
		if (!(target_vol_count[dataset_stub]++)) {
			target_latest[dataset_stub] = snapshot_stub
			tgtlast[dataset_stub] = snapshot_name
			target_order[++target_num] = dataset_stub
			status[dataset_stub] = "TGTONLY"
		}
		#target_list[dataset_stub target_vol_count[dataset_stub]] = snapshot_stub
		tgtfirst[dataset_stub] = snapshot_name
	}
	close(snapshot_list_command)
}

function check_parent() {
	if (!(snapshot_list_command ~ /zfs list/)) return 0
	parent = volume[target]
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
	PROPERTIES_ALL = "stub,status,sizediff,numdiff,match,srcfirst,srclast,tgtfirst,tgtlast,srcnum,tgtnum"
	PROPERTIES_DEFAULT = "stub,status,match,srclast"
	PROPERTIES = env("ZELTA_MATCH_PROPERTIES", PROPERTIES_DEFAULT)
	if (PROPERTIES == "all") PROPERTIES = PROPERTIES_ALL
	split(PROPERTIES, PROPLIST, ",")
	for (i in PROPLIST) COL[PROPLIST[i]]++
	
	MODE = "CHART"
	if (PASS_FLAGS ~ /p/) MODE = "PARSE"
	if (PASS_FLAGS ~ /H/) NOHEADER++
	if (PASS_FLAGS ~ /v/) LOG_LEVEL++

	exit_code = 0
	LOG_MODE = ZELTA_PIPE ? 0 : 1
	target_zfs_list_time = 0
}

function get_endpoint_info() {
	endpoint = $1
	endpoint_hash[endpoint] = $1
	volume[endpoint] = $2
	vol_name_length[endpoint] = length(volume[endpoint]) + 1
	return endpoint
}

NR == 1 { source = get_endpoint_info() }

NR == 2 { target = get_endpoint_info() }

NR == 3 {
	zfs_list_time = 0
	volume_written[source] = 0
	volume_written[target] = 0
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
	if (!(source_vol_count[dataset_stub]++)) {
		source_latest[dataset_stub] = snapshot_stub
		srclast[dataset_stub] = snapshot_name
		source_order[++source_num] = dataset_stub
	}
	# Catch oldest snapshot name to ensure replication completeness
	source_oldest[dataset_stub] = snapshot_name

	if (dataset_stub in matches) next
	else if (!target_latest[dataset_stub] && !(dataset_stub in new_volume)) {
		if (!dataset_stub) check_parent()
		new_volume[dataset_stub] = snapshot_name
		status[dataset_stub] = "SRCONLY"
	} else if (target_guid[snapshot_stub]) {
		if (target_guid[snapshot_stub] == source_guid[snapshot_stub]) {
			matches[dataset_stub] = snapshot_name
			if (snapshot_stub == source_latest[dataset_stub]) {
				basic_log[dataset_stub] = "target has latest source snapshot: " snapshot_stub
				status[dataset_stub] = (snapshot_stub==target_latest[dataset_stub]) ? "SYNCED" : "AHEAD"
			} else if (guid_error[dataset_stub]) {
				report(LOG_ERROR,"latest guid match on target snapshot: " dataset_name)
				status[dataset_stub] = "MIXED"
			} else {
				status[dataset_stub] = "BEHIND"
				basic_log[dataset_stub] = "match: " snapshot_stub OFS "latest: " source_latest[dataset_stub]
			}
		} else {
			report(LOG_ERROR,"guid mismatch on: " snapshot_stub)
			guid_error[dataset_stub]++
		}
	} else {
		total_transfer_size += snapshot_written
		size_diff[dataset_stub] += snapshot_written
		num_diff[dataset_stub]++
	}
}

# Add a check to see if it's safe to add a volume in zelta-replicate
#function new_volume_check() {

function print_row(col) {
	for(c=1;c<=length(col);c++) {
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

function chart_header() {
	c = 0
	delete columns
	if ((arrlen(stub_order) <= 1) && MODE=="CHART") {
		report(LOG_VERBOSE, "single dataset; hiding stub column")
		delete COL["stub"]
	}
	if ("stub" in COL) make_header_column("STUB", stub_order)
	if ("status" in COL) make_header_column("STATUS", status)
	if ("sizediff" in COL) make_header_column("SIZEDIFF", size_diff)
	if ("numdiff" in COL) make_header_column("NUMDIFF", num_diff)
	if ("match" in COL) make_header_column("MATCH", matches)
	if ("srcfirst" in COL) make_header_column("SRCFIRST", source_oldest)
	if ("srclast" in COL) make_header_column("SRCLAST", srclast)
	if ("tgtfirst" in COL) make_header_column("TGTFIRST", tgtfirst)
	if ("tgtlast" in COL) make_header_column("TGTLAST", tgtlast)
	if ("srcnum" in COL) make_header_column("SRCNUM", num_snaps[source,stub])
	if ("tgtnum" in COL) make_header_column("TGTNUM", num_snaps[target,stub])
	if (!NOHEADER) print_row(columns)
}

function chart_row(stub) {
	if (!ROW++) chart_header()
	c=0
	delete columns
	if ("stub" in COL) columns[++c] = stub
	if ("status" in COL) columns[++c] = status[stub]
	if ("sizediff" in COL) columns[++c] = h_num(size_diff[stub])
	if ("numdiff" in COL) columns[++c] = num_diff[stub]
	if ("match" in COL) columns[++c] = matches[stub]
	if ("srcfirst" in COL) columns[++c] = source_oldest[stub]
	if ("srclast" in COL) columns[++c] = srclast[stub]
	if ("tgtfirst" in COL) columns[++c] = tgtfirst[stub]
	if ("tgtlast" in COL) columns[++c] = tgtlast[stub]
	if ("srcnum" in COL) columns[++c] = num_snaps[source,stub]
	if ("tgtnum" in COL) columns[++c] = num_snaps[target,stub]
	print_row(columns)
}

END {
	arr_sort(stub_order)
	for (i=1;i<=arrlen(stub_order);i++) {
		stub = stub_order[i]
		if ((matches[stub] != srclast[stub]) && (matches[stub] != tgtlast[stub])) {
			status[stub] = "MIXED"
		}
		if (srclast[stub] == tgtlast[stub]) num_diff[stub] = 0
		chart_row(stub)
	}
	source_zfs_list_time = zfs_list_time
	if (MODE=="PARSE") print "SOURCE_LIST_TIME:", source_zfs_list_time, ":","TARGET_LIST_TIME", target_zfs_list_time
	if (arrlen(source_latest) == 0) report(LOG_DEFAULT,"no source snapshots found")
	if (volume_written[source]) report(LOG_DEFAULT, "source volume has changed: " h_num(volume_written[source]))
	if (volume_written[target]) report(LOG_DEFAULT, "target volume has changed: " h_num(volume_written[target]))
	for (stub in volume_check) if (!source_latest[stub]) missing_branch[stub]
	report(LOG_PIPE, create_parent)
	if (total_transfer_size) report(LOG_DEFAULT, "new snapshot transfer size: " h_num(total_transfer_size))
}
