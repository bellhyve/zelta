#!/usr/bin/awk -f
#
# zelta reconcile - compares a snapshot list via pipe and command
#
# usage: internal to "zelta match", but could be leveraged for other comparison
# operation
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
# ENVIRONMENT VARIABLES
#
# ZELTA_PIPE: When set to 1, we provide full snapshot names and simplify the output as
# follows:
#   - No output is provided for an up-to-date match.
#   - A single snapshot indicates the volume is missing on the target.
#   - A tab separated pair of snapshots indicates the out-of-date match and the latest.
#
# ZELTA_DEPTH: Adds "-d $ZELTA_DEPTH" to zfs list commands. Useful for limiting
# replication depth in "zelta pull".

function env(env_name, var_default) {
	return ( (env_name in ENVIRON) ? ENVIRON[env_name] : var_default )
}

# CHANGE TO REPORT FUNCTION
function report(mode, message) {
	if (!message) return 0
	if (LOG_ERROR == mode) print "error: " message | STDOUT
	else if ((LOG_PIPE == mode) && ZELTA_PIPE) print message
	else if ((LOG_BASIC == mode) && ((LOG_MODE == LOG_BASIC) || LOG_MODE == LOG_VERBOSE)) { print message }
	else if ((LOG_VERBOSE == mode) && (LOG_MODE == LOG_VERBOSE)) print message
}

function h_num(num) {
	suffix = "B"
	divisors = "KMGTPE"
	for (i = 1; i <= length(divisors) && num >= 1024; i++) {
		num /= 1024
		suffix = substr(divisors, i, 1)
	}
	return int(num) suffix
}

function get_snapshot_data(trim) {
		if (/dataset does not exist/) return 0
		else if (/ real /) {
			split($0, time_arr, /[ \t]+/)
			zfs_list_time = time_arr[2]
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
		return 1
}

function load_target_snapshots() {
	while  (snapshot_list_command | getline) {
		if (!get_snapshot_data(vol_name_length[target])) { continue }
		target_guid[snapshot_stub] = snapshot_guid
		target_written[snapshot_stub] = snapshot_written
		if (!(target_vol_count[dataset_stub]++)) {
			target_latest[dataset_stub] = snapshot_stub
			target_order[++target_num] = dataset_stub
		}
		target_list[dataset_stub target_vol_count[dataset_stub]] = snapshot_stub
	}
	close(snapshot_list_command)
}

function check_parent() {
	if (!(snapshot_list_command ~ /zfs list/)) return 0
	parent = volume[target]
	if (!gsub(/\/[^\/]+$/, "", parent)) {
		report(LOG_ERROR,"invalid target pool name: " parent)
		exit 1
	}
	parent_list_command = snapshot_list_command
	sub(/zfs list.*'/, "zfs list '"parent"'", parent_list_command)
	parent_list_command | getline parent_check
	if (parent_check ~ /dataset does not exist/) {
		create_parent=parent
		report(LOG_BASIC, "parent volume does not exist: " create_parent)
	}
}

function arr_sort(arr) {
	for (x in arr) {
		y = arr[x]
		z = x - 1
		while (z && arr[z] > y) {
			arr[z + 1] = arr[z]
			z--
		}
		arr[z + 1] = y
	}
}



BEGIN {
	FS="\t"
	OFS="\t"
	STDOUT = "cat 1>&2"
	LOG_ERROR=-1
	LOG_PIPE=0
	LOG_BASIC=1
	LOG_VERBOSE=2
	exit_code = 0
	ZELTA_PIPE = env("ZELTA_PIPE", 0)
	LOG_MODE = ZELTA_PIPE ? 0 : 1
}

function get_endpoint_info() {
	endpoint = $1
	volume[endpoint] = $2
	vol_name_length[endpoint] = length(volume[endpoint]) + 1
	return endpoint
}


NR == 1 { source = get_endpoint_info() }

NR == 2 { target = get_endpoint_info() }

NR == 3 {
	snapshot_list_command = $0;
	load_target_snapshots()
	target_zfs_list_time = zfs_list_time
	zfs_list_time = 0
}

NR > 3 {
	if (!get_snapshot_data(vol_name_length[source])) { next }
	source_guid[snapshot_stub] = snapshot_guid
	source_written[snapshot_stub] = snapshot_written
	if (!(source_vol_count[dataset_stub]++)) {
		source_latest[dataset_stub] = snapshot_stub
		source_order[++source_num] = dataset_stub
	}
	if (dataset_stub in matches) { next }
	else if (!target_latest[dataset_stub] && !(dataset_stub in new_volume)) {
		if (!dataset_stub) check_parent()
		new_volume[dataset_stub] = dataset_name OFS volume[target] dataset_stub
		basic_log[dataset_stub] = "snapshots only on source: " dataset_name
	} else if (target_guid[snapshot_stub]) {
		if (target_guid[snapshot_stub] == source_guid[snapshot_stub]) {
			matches[dataset_stub]++
			if (snapshot_stub == source_latest[dataset_stub]) {
				basic_log[dataset_stub] = "target has latest source snapshot: " snapshot_stub
			} else if (guid_error[dataset_stub]) {
				report(LOG_ERROR,"latest guid match on target snapshot: " dataset_name)
			} else {
				delta_update = volume[source] source_latest[dataset_stub]
				delta_target = volume[target] dataset_stub
				delta[dataset_stub] = snapshot_name OFS delta_update OFS delta_target
				basic_log[dataset_stub] = "match: " snapshot_stub OFS "latest: " source_latest[dataset_stub]
			}
		} else {
			report(LOG_ERROR,"guid mismatch on: " snapshot_stub)
			guid_error[dataset_stub]++
		}
	} else { total_transfer_size += snapshot_written }
}

END {
	if (length(source_latest) == 0) report(LOG_ERROR,"no source snapshots found")
	source_zfs_list_time = zfs_list_time
	report(LOG_PIPE, source_zfs_list_time OFS ":" OFS target_zfs_list_time)
	report(LOG_PIPE, create_parent)
	for (stub in target_latest) {
		if (!source_latest[stub]) report(LOG_BASIC, "target volume not on source: " target_latest[dataset_stub])
	}
	arr_sort(source_order)
	for (i=1;i<=length(source_order);i++) {
		stub = source_order[i]
		report(LOG_PIPE,new_volume[stub])
		report(LOG_PIPE,delta[stub])
		report(LOG_BASIC,basic_log[stub])
	}
	if (total_transfer_size) report(LOG_BASIC, "new snapshot transfer size: " h_num(total_transfer_size))
}
