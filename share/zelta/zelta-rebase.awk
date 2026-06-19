#!/usr/bin/awk -f
#
# zelta-rebase.awk - rebase a dataset onto an upgraded upstream while preserving local files.

## Command execution
####################

function run_cmd(cmd,    _rc) {
	if (Opt["DRYRUN"])
		report(LOG_NOTICE, "+ " cmd)
	else
		report(LOG_INFO, "+ " cmd)
	if (Opt["DRYRUN"])
		return 0
	_rc = system(cmd)
	if (_rc)
		stop(1, "command failed: " cmd)
	return _rc
}

function endpoint_cmd(ep, cmd,    _remote) {
	_remote = get_remote_cmd(ep)
	if (_remote)
		return _remote " " dq(cmd)
	return cmd
}

function sh_q(str,    _out, _i, _char) {
	_out = "'"
	for (_i = 1; _i <= length(str); _i++) {
		_char = substr(str, _i, 1)
		if (_char == "'")
			_out = _out "'\\''"
		else
			_out = _out _char
	}
	return _out "'"
}

## Rebase validation
####################

function usage(message) {
	if (message)
		report(LOG_ERROR, message)
	print "usage: zelta rebase [OPTIONS] UPSTREAM TARGET" > STDERR
	print "" > STDERR
	print "Options:" > STDERR
	print "  --rebase-file FILE         override path to preserve file" > STDERR
	print "  -n, --dryrun               show commands but do not run them" > STDERR
	stop(1)
}

function validate_rebase(upstream_ep, target_ep) {
	if (Opt["USAGE"])
		usage()
	if (NumOperands != 2)
		usage("zelta rebase requires UPSTREAM and TARGET")
	load_endpoint(Operands[1], upstream_ep)
	load_endpoint(Operands[2], target_ep)
	if (upstream_ep["REMOTE"] != target_ep["REMOTE"])
		stop(1, "rebase requires UPSTREAM and TARGET on the same host")
}

## Dataset queries
##################

function get_latest_snapshot(ds,    _cmd, _snap) {
	if (Opt["DRYRUN"])
		return ds "@latest"
	_cmd = "zfs list -t snapshot -H -o name -S creation " sh_q(ds) " 2>/dev/null | head -1"
	report(LOG_DEBUG, "`" _cmd "`")
	_cmd = _cmd CAPTURE_OUTPUT
	if ((_cmd | getline _snap) > 0) {
		close(_cmd)
		if (_snap != "")
			return _snap
	}
	close(_cmd)
	stop(1, "no snapshots found on upstream: " ds)
}

function get_clone_origin(ds,    _cmd, _origin) {
	if (Opt["DRYRUN"])
		return ds "@dryrun"
	_cmd = "zfs get -H -o value origin " sh_q(ds)
	report(LOG_DEBUG, "`" _cmd "`")
	_cmd = _cmd CAPTURE_OUTPUT
	if ((_cmd | getline _origin) > 0) {
		close(_cmd)
		if (_origin != "" && _origin != "-")
			return _origin
	}
	close(_cmd)
	stop(1, "target has no clone origin; cannot rebase: " ds)
}

function get_mountpoint(ep,    _cmd, _mp) {
	if (Opt["DRYRUN"])
		return "/" ep["DS"]
	_cmd = endpoint_cmd(ep, "zfs get -H -o value mountpoint " sh_q(ep["DS"]))
	report(LOG_DEBUG, "`" _cmd "`")
	_cmd = _cmd CAPTURE_OUTPUT
	while ((_cmd | getline _mp) > 0)
		break
	close(_cmd)
	if (_mp == "" || _mp == "-" || _mp == "none" || _mp == "legacy")
		stop(1, "cannot use mountpoint for preserve copy: " ep["ID"] " has mountpoint " (_mp ? _mp : "<empty>"))
	return _mp
}

function get_zfs_property(ep, prop,    _cmd, _val) {
	if (Opt["DRYRUN"])
		return ""
	_cmd = endpoint_cmd(ep, "zfs get -H -o value " sh_q(prop) " " sh_q(ep["DS"]))
	report(LOG_DEBUG, "`" _cmd "`")
	_cmd = _cmd CAPTURE_OUTPUT
	while ((_cmd | getline _val) > 0)
		break
	close(_cmd)
	return _val
}

## Path utilities
#################

function path_dir(path,    _dir) {
	_dir = path
	if (_dir !~ /\//)
		return "."
	sub(/\/[^\/]*$/, "", _dir)
	if (_dir == "")
		return "/"
	return _dir
}

function path_join(root, rel) {
	if (rel == "")
		return root
	if (root == "/")
		return root rel
	return root "/" rel
}

## Auto-rename
##############

function compute_backup_name(target_ds,    _origin) {
	_origin = get_clone_origin(target_ds)
	# Extract snapshot name from origin (e.g., "pool/ds@snap" -> "snap")
	sub(/^.*@/, "", _origin)
	return target_ds "_" _origin
}

## Preserve file handling
#########################

function clean_preserve_path(path) {
	sub(/^[ 	]+/, "", path)
	sub(/[ 	]+$/, "", path)
	if (path == "" || path ~ /^#/)
		return ""
	if (path ~ /^[+M-][ 	]+/)
		sub(/^[+M-][ 	]+/, "", path)
	sub(/^\/+/, "", path)
	if (path == "" || path ~ /(^|\/)\.\.($|\/)/)
		stop(1, "invalid preserve path: " path)
	return path
}

function load_rebase_file(file,    _line, _path, _rc) {
	while ((_rc = (getline _line < file)) > 0) {
		_path = clean_preserve_path(_line)
		if (!_path)
			continue
		PreservePath[++NumPreservePath] = _path
	}
	close(file)
	if (_rc < 0)
		stop(1, "cannot read rebase file: " file)
	if (!NumPreservePath)
		report(LOG_WARNING, "rebase file contains no preserve paths: " file)
}

function find_preserve_file(upstream_ep,    _upstream_mp, _file, _rc) {
	if (Opt["REBASE_FILE"])
		return Opt["REBASE_FILE"]
	if (Opt["DRYRUN"])
		return ""
	_upstream_mp = get_mountpoint(upstream_ep)
	_file = _upstream_mp "/.zelta-rebase.preserve"
	if ((_rc = getline < _file) >= 0) {
		close(_file)
		return _file
	}
	return ""
}

function prepare_preserve_target(target_ep) {
	run_cmd(endpoint_cmd(target_ep, "zfs set readonly=off " sh_q(target_ep["DS"])))
	run_cmd(endpoint_cmd(target_ep, "zfs set canmount=on " sh_q(target_ep["DS"])))
	run_cmd(endpoint_cmd(target_ep, "zfs mount -R " sh_q(target_ep["DS"])))
}

function restore_target_state(target_ep, old_readonly, old_canmount) {
	if (old_readonly != "")
		run_cmd(endpoint_cmd(target_ep, "zfs set readonly=" sh_q(old_readonly) " " sh_q(target_ep["DS"])))
	if (old_canmount != "")
		run_cmd(endpoint_cmd(target_ep, "zfs set canmount=" sh_q(old_canmount) " " sh_q(target_ep["DS"])))
}

function preserve_copy(backup_ep, target_ep,    _old_root, _new_root, _i, _rel, _old_path, _new_path, _cmd) {
	if (Opt["DRYRUN"]) {
		_old_root = "/" backup_ep["DS"]
		_new_root = "/" target_ep["DS"]
	} else {
		_old_root = get_mountpoint(backup_ep)
		_new_root = get_mountpoint(target_ep)
	}
	for (_i = 1; _i <= NumPreservePath; _i++) {
		_rel = PreservePath[_i]
		_old_path = path_join(_old_root, _rel)
		_new_path = path_join(_new_root, _rel)
		_cmd = "mkdir -p " sh_q(path_dir(_new_path)) " && cp -p " sh_q(_old_path) " " sh_q(_new_path)
		if (Opt["DRYRUN"])
			report(LOG_NOTICE, "+ " endpoint_cmd(backup_ep, _cmd))
		else
			run_cmd(endpoint_cmd(backup_ep, _cmd))
	}
}

## Rebase primitive
###################

function run_rebase_backup(upstream_snap, backup_name, target_ep,    _cmd) {
	report(LOG_NOTICE, "rebasing " target_ep["ID"] " from " upstream_snap)
	_cmd = "zelta ipc-run backup --target-origin " sh_q(backup_name) \
	    " --log-mode=text --log-level=2 " sh_q(upstream_snap) " " sh_q(target_ep["ID"])
	run_cmd(_cmd)
}

## Main
#######

function run_rebase(    _upstream, _target, _upstream_snap, _backup_name, _preserve_file, _old_readonly, _old_canmount) {
	validate_rebase(_upstream, _target)

	# 1. Determine upstream snapshot
	if (_upstream["SNAP"])
		_upstream_snap = _upstream["ID"]
	else
		_upstream_snap = get_latest_snapshot(_upstream["DS"])

	# 2. Compute backup name from target's clone origin
	_backup_name = compute_backup_name(_target["DS"])

	# 3. Check for naming collision
	if (!Opt["DRYRUN"]) {
		if (system("zfs list -H -o name " sh_q(_backup_name) " >/dev/null 2>&1") == 0)
			stop(1, "backup name already exists: " _backup_name)
	}

	# 4. Rename old target out of the way
	run_cmd(endpoint_cmd(_target, "zfs rename " sh_q(_target["DS"]) " " sh_q(_backup_name)))

	# 5. Rebase using zelta backup --target-origin
	run_rebase_backup(_upstream_snap, _backup_name, _target)

	# 6. Find preserve file and copy if present
	_preserve_file = find_preserve_file(_upstream)
	if (_preserve_file) {
		load_rebase_file(_preserve_file)
		if (NumPreservePath) {
			# Save old properties for restore
			_old_readonly = get_zfs_property(_target, "readonly")
			_old_canmount = get_zfs_property(_target, "canmount")

			# 7. Prepare target for file copy
			prepare_preserve_target(_target)

			# 8. Copy preserve files from backup to new target
			# Load backup endpoint for mountpoint queries
			load_endpoint(_backup_name, _backup)
			preserve_copy(_backup, _target)

			# 9. Restore target state
			restore_target_state(_target, _old_readonly, _old_canmount)
		}
	}

	# 10. Report
	report(LOG_NOTICE, "rebased " _target["ID"] " from " _upstream_snap)
	report(LOG_NOTICE, "old prod preserved as " _backup_name)
}

BEGIN {
	FS = "\t"
	run_rebase()
	stop()
}
