#!/usr/bin/awk -f
#
# zelta-rebase.awk - rebase a dataset tree onto an upgraded source.

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
	print "usage: zelta rebase [OPTIONS] OLD_PROD NEW_UPSTREAM NEW_PROD" > STDERR
	print "" > STDERR
	print "Options:" > STDERR
	print "  --rebase-file FILE         list of paths to preserve from OLD_PROD" > STDERR
	print "  --rebase-preserve MODE     preserve mode: plan or copy" > STDERR
	print "  -n, --dryrun               show commands but do not run them" > STDERR
	stop(1)
}

function validate_rebase(old_ep, upstream_ep, new_ep) {
	if (Opt["USAGE"])
		usage()
	if (NumOperands != 3)
		usage("zelta rebase requires OLD_PROD, NEW_UPSTREAM, and NEW_PROD")
	load_endpoint(Operands[1], old_ep)
	load_endpoint(Operands[2], upstream_ep)
	load_endpoint(Operands[3], new_ep)
	if (Opt["REBASE_PRESERVE"] && !(Opt["REBASE_PRESERVE"] in PreserveMode))
		stop(1, "invalid --rebase-preserve mode: " Opt["REBASE_PRESERVE"])
}

function require_same_host(old_ep, new_ep) {
	if (old_ep["REMOTE"] != new_ep["REMOTE"])
		stop(1, "preserve copy requires OLD_PROD and NEW_PROD on the same host")
}

## Dataset mountpoints
######################

function get_mountpoint(ep,    _cmd, _mp) {
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

function prepare_preserve_target(new_ep) {
	run_cmd(endpoint_cmd(new_ep, "zfs set readonly=off " sh_q(new_ep["DS"])))
	run_cmd(endpoint_cmd(new_ep, "zfs set canmount=on " sh_q(new_ep["DS"])))
	run_cmd(endpoint_cmd(new_ep, "zfs mount -R " sh_q(new_ep["DS"])))
}

## Rebase primitive
###################

function run_rebase_backup(old_ep, upstream_ep, new_ep,    _cmd) {
	report(LOG_NOTICE, "rebasing " new_ep["ID"] " from " upstream_ep["ID"])
	_cmd = "zelta ipc-run backup --target-origin " sh_q(old_ep["ID"]) \
	    " --log-mode=text --log-level=2 " sh_q(upstream_ep["ID"]) " " sh_q(new_ep["ID"])
	run_cmd(_cmd)
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

function preserve_copy(old_ep, new_ep,    _old_root, _new_root, _i, _rel, _old_path, _new_path, _cmd) {
	if (!Opt["REBASE_FILE"])
		return
	require_same_host(old_ep, new_ep)
	load_rebase_file(Opt["REBASE_FILE"])
	if (!NumPreservePath)
		return
	if (Opt["REBASE_PRESERVE"] == "copy")
		prepare_preserve_target(new_ep)
	else {
		report(LOG_NOTICE, "+ " endpoint_cmd(new_ep, "zfs set readonly=off " sh_q(new_ep["DS"])))
		report(LOG_NOTICE, "+ " endpoint_cmd(new_ep, "zfs set canmount=on " sh_q(new_ep["DS"])))
		report(LOG_NOTICE, "+ " endpoint_cmd(new_ep, "zfs mount -R " sh_q(new_ep["DS"])))
	}
	if (Opt["DRYRUN"]) {
		report(LOG_NOTICE, "+ " endpoint_cmd(old_ep, "zfs get -H -o value mountpoint " sh_q(old_ep["DS"])))
		report(LOG_NOTICE, "+ " endpoint_cmd(new_ep, "zfs get -H -o value mountpoint " sh_q(new_ep["DS"])))
		_old_root = "/" old_ep["DS"]
		_new_root = "/" new_ep["DS"]
	} else {
		_old_root = get_mountpoint(old_ep)
		_new_root = get_mountpoint(new_ep)
	}
	for (_i = 1; _i <= NumPreservePath; _i++) {
		_rel = PreservePath[_i]
		_old_path = path_join(_old_root, _rel)
		_new_path = path_join(_new_root, _rel)
		_cmd = "mkdir -p " sh_q(path_dir(_new_path)) " && cp -p " sh_q(_old_path) " " sh_q(_new_path)
		if (Opt["REBASE_PRESERVE"] == "copy")
			run_cmd(endpoint_cmd(old_ep, _cmd))
		else
			report(LOG_NOTICE, "+ " endpoint_cmd(old_ep, _cmd))
	}
}

## Main
#######

function run_rebase(    _old, _upstream, _new) {
	validate_rebase(_old, _upstream, _new)
	run_rebase_backup(_old, _upstream, _new)
	preserve_copy(_old, _new)
}

BEGIN {
	FS = "\t"
	PreserveMode["plan"] = 1
	PreserveMode["copy"] = 1
	if (!Opt["REBASE_PRESERVE"])
		Opt["REBASE_PRESERVE"] = "plan"
	run_rebase()
	stop()
}
