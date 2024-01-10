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
function verbose(message) { if (VERBOSE) print message }
function error(string) {
	print "error: "string | "cat 1>&2"
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
			error($0)
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
		error("invalid target pool: " parent)
		exit 1
	}
	parent_list_command = snapshot_list_command
	sub(/zfs list.*'/, "zfs list '"parent"'", parent_list_command)
	parent_list_command | getline parent_check
	if (parent_check ~ /dataset does not exist/) {
		create_parent=parent
		verbose("parent volume does not exist: " create_parent)
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

function output_summary() {
	# Verbose output for humans
	for (dataset_stub in target_latest) {
		if (!source_latest[dataset_stub]) {
			verbose("target volume not on source: " target_latest[dataset_stub])
		}
	}
	if (total_transfer_size) verbose("new snapshot transfer size: " h_num(total_transfer_size))
}

function output_pipe() {
	# Line 1 = time & status, 1 param = create, 2 param = new, 3 param = incremental
	print source_zfs_list_time,":",target_zfs_list_time
	if (create_parent) print create_parent

	for (i=1;i<=length(source_order);i++) {
		stub = source_order[i]
		if (new_volume[stub]) print new_volume[stub]
		if (delta[stub]) print delta[stub]
	}
	#for (d=1;d<=delta_count;d++) print delta_match[d], delta_source[d], delta_target[d]
}

BEGIN {
	FS="\t"
	OFS="\t"
	exit_code = 0
	ZELTA_PIPE = env("ZELTA_PIPE", 0)
	ZELTA_JSON = env("ZELTA_PIPE", 0)
	if (!ZELTA_PIPE) { VERBOSE = 1 }
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
		verbose("snapshots for volume only on source: " dataset_name)
	} else if (target_guid[snapshot_stub]) {
		if (target_guid[snapshot_stub] == source_guid[snapshot_stub]) {
			matches[dataset_stub]++
			if (snapshot_stub == source_latest[dataset_stub]) {
				verbose("target has latest source snapshot: " snapshot_stub)
			} else if (guid_error[dataset_stub]) {
				error("latest guid match on target snapshot: " dataset_name)
			} else {
				delta_update = volume[source] source_latest[dataset_stub]
				delta_target = volume[target] dataset_stub
				delta[dataset_stub] = snapshot_name OFS delta_update OFS delta_target
				verbose("match: " snapshot_stub "\tlatest: " source_latest[dataset_stub])
			}
		} else {
			error("guid mismatch on: " snapshot_stub)
			guid_error[dataset_stub]++
		}
	} else { total_transfer_size += snapshot_written }
}

END {
	if (length(source_latest) == 0) error("no source snapshots found")
	arr_sort(source_order)
	source_zfs_list_time = zfs_list_time
        if (VERBOSE) output_summary()
        if (ZELTA_PIPE) output_pipe()
}
