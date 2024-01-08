#!/usr/bin/awk -f
#
# zmatch - compares a source and target datasets for dataset simiddlarity
#
# usage: zmatch [user@][host:]source/dataset [user@][host:]target/dataset
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
# replication depth in zpull.

function usage(message) {
	if (message) error(message)
	if (! ZELTA_PIPE) print "usage: zelta pull [-jz] [-d#] [user@][host:]source/dataset [user@][host:]target/dataset"
	exit 1
}

function env(env_name, var_default) {
	return ( (env_name in ENVIRON) ? ENVIRON[env_name] : var_default )
}

function sub_opt() {
	if (!$0) {
		i++
		$0 = ARGV[i]
	}
	opt = $0
	$0 = ""
	return opt
}

function get_options() {
        for (i=1;i<ARGC;i++) {
                $0 = ARGV[i]
                if (gsub(/^-/,"")) {
                        #if (gsub(/j/,"")) JSON++
                        if (gsub(/z/,"")) ZELTA_PIPE++
                        if (gsub(/d/,"")) ZELTA_DEPTH = sub_opt()
                        if (/./) {
                                usage("unkown options: " $0)
                        }
                } else if (target) {
                        usage("too many options: " $0)
                } else if (source) target = $0
                else source = $0
        }
}

function get_endpoint_info(arg) {
	if (!split(arg, snap, ":")) exit
	if (snap[2]) {
		cmdpre = "sh -c \"ssh -n " snap[1] " "
		cmdpre = "ssh -n " snap[1] " "
		snapvol = snap[2];
	} else {
		cmdpre = ""
		cmdpost = ""
		snapvol = snap[1]
	}
	vol_name_length[arg] = length(snapvol) + 1	# Get dataset length for trimming so we can compare stub names
	dataset[arg] = snapvol 				# Translate endpoint name to volume name
	zfs_list_command[arg] = cmdpre "zfs list " ZFS_LIST_FLAGS " '" snapvol "' " cmdpost " 2>&1"
	return snapvol
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

function error(string) {
	print "error: "string | "cat 1>&2"
}

function get_snapshot_data(trim) {
		if (/dataset does not exist/) return 0
		else if (! /@/) {
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

function load_target_snapshots(dataset_info) {
	while  (zfs_list_command[target] | getline) {
		if (!get_snapshot_data(vol_name_length[target])) { continue }
		target_guid[snapshot_stub] = snapshot_guid
		target_written[snapshot_stub] = snapshot_written
		if (!(target_vol_count[dataset_stub]++)) {
			target_latest[dataset_stub] = snapshot_stub
			target_order[++target_num] = dataset_stub
		}
		target_list[dataset_stub target_vol_count[dataset_stub]] = snapshot_stub
	}
	close(zfs_list_command[target])
}

function verbose(message) { if (VERBOSE) print message }


function check_parent(parent) {
	ZFS_LIST_FLAGS = "-Hponame"
	if (!gsub(/\/[^\/]+$/, "", parent)) {
		error("invalid target pool: " dataset[target])
		exit 1
	}
	get_endpoint_info(parent)
	zfs_list_command[parent] | getline parent_check
	if (parent_check ~ /dataset does not exist/) {
		create_parent=dataset[parent]
		verbose("parent volume does not exist: " create_parent)
	}
}

function reconcile_snapshots() {
	while (getline) {
		if (!get_snapshot_data(vol_name_length[source])) { continue }
		source_guid[snapshot_stub] = snapshot_guid
		source_written[snapshot_stub] = snapshot_written
		if (!(source_vol_count[dataset_stub]++)) {
			source_latest[dataset_stub] = snapshot_stub
			source_order[++source_num] = dataset_stub
		}
		if (dataset_stub in matches) { continue}
		else if (!target_latest[dataset_stub] && !(dataset_stub in missing_target_volume)) {
			if (!dataset_stub) check_parent(target)
			# We need to keep the volume creation order:
			new_volume_count++
			new_volume_source[new_volume_count] = dataset_name
		        new_volume_target[new_volume_count] = dataset[target] dataset_stub
			missing_target_volume[dataset_stub] = dataset_name
			verbose("snapshots for volume only on source: " dataset_name)
		} else if (target_guid[snapshot_stub]) {
			if (target_guid[snapshot_stub] == source_guid[snapshot_stub]) {
				matches[dataset_stub]++
				if (snapshot_stub == source_latest[dataset_stub]) {
					verbose("target has latest source snapshot: " snapshot_stub)
				} else if (guid_error[dataset_stub]) {
					error("latest guid match on target snapshot: " dataset_name)
				} else {
					delta_count++
					delta_match[delta_count] = snapshot_name
					delta_source[delta_count] = dataset[source] source_latest[dataset_stub]
					delta_target[delta_count] = dataset[target] dataset_stub
					verbose("match: " snapshot_stub "\tlatest: " source_latest[dataset_stub])
				}
			} else {
				error("guid mismatch on: " snapshot_stub)
				guid_error[dataset_stub]++
			}
		} else { total_transfer_size += snapshot_written }
	}
	if (length(source_latest) == 0) error("no source snapshots")
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

function pipe_output() {
	OFS="\t"
	if (create_parent) print create_parent
	for (n=1;n<=new_volume_count;n++) print new_volume_source[n], new_volume_target[n]
	for (d=1;d<=delta_count;d++) print delta_match[d], delta_source[d], delta_target[d]
}

BEGIN {
	FS="\t"
	exit_code = 0
	ZELTA_PIPE = env("ZELTA_PIPE", 0)
	ZELTA_DEPTH = env("ZELTA_DEPTH", 0)
	ZMATCH_STREAM = env("ZMATCH_STREAM", 0)
	
	get_options()
	ZMATCH_PREFIX = "ZMATCH_STREAM=1 "
	ZMATCH_PREFIX = ZMATCH_PREFIX (ZELTA_DEPTH ? "ZELTA_DEPTH="ZELTA_DEPTH" " : "")
	ZMATCH_PREFIX = ZMATCH_PREFIX (ZELTA_PIPE ? "ZELTA_PIPE="ZELTA_PIPE" " : "")
	ZMATCH_COMMAND = ZMATCH_PREFIX "zelta match"
	ZELTA_DEPTH = ZELTA_DEPTH ? " -d"ZELTA_DEPTH : ""

	ZFS_LIST_FLAGS = "-Hproname,guid,written -Htsnap -Screation" ZELTA_DEPTH

	if (!ZELTA_PIPE) { VERBOSE = 1 }

	if (target) {
		print source "\n" target | ZMATCH_COMMAND
		get_endpoint_info(source)
		while (zfs_list_command[source] | getline) {
			print | ZMATCH_COMMAND
		}
	}
	else if (ZMATCH_STREAM) {
		getline source; getline target
		get_endpoint_info(source)
		get_endpoint_info(target)
		load_target_snapshots(target)
		reconcile_snapshots()
		if (VERBOSE) output_summary()
		if (ZELTA_PIPE) pipe_output()
	} else {
		usage()
	}
}
