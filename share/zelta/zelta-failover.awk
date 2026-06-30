#!/usr/bin/awk -f
#
# zelta-failover.awk - lock, unlock, fail over, and sync properties for ZFS dataset trees.

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

function endpoint_build_cmd(ep, action, vars,    _cmd) {
	_cmd = build_command(action, vars)
	return endpoint_cmd(ep, _cmd)
}

## Lock and unlock
##################

function lock_dataset(ep,    _cmd, _cmd_arr, _list_cmd, _mount_cmd, _list_local, _mount_local, _ds, _mounted) {
	_cmd_arr["ds"] = q(ep["DS"])
	_list_local = build_command("FAILOVER_LIST_LOCK_NAMES", _cmd_arr)
	_mount_local = build_command("FAILOVER_LIST_LOCK_MOUNTED", _cmd_arr)
	_list_cmd = endpoint_cmd(ep, _list_local)
	_mount_cmd = endpoint_cmd(ep, _mount_local)
	if (Opt["DRYRUN"]) {
		report(LOG_NOTICE, "+ " endpoint_build_cmd(ep, "FAILOVER_SET_READONLY", _cmd_arr))
		report(LOG_NOTICE, "+ " endpoint_cmd(ep, _list_local " | xargs -n1 zfs set canmount=noauto"))
		report(LOG_NOTICE, "+ " endpoint_cmd(ep, _mount_local " | while read ds mounted; do [ \\\"$mounted\\\" = yes ] && zfs unmount \\\"$ds\\\"; done"))
		return
	}
	run_cmd(endpoint_build_cmd(ep, "FAILOVER_SET_READONLY", _cmd_arr))
	_cmd = _list_cmd
	while ((_cmd | getline) > 0) {
		_cmd_arr["ds"] = q($1)
		run_cmd(endpoint_build_cmd(ep, "FAILOVER_SET_CANMOUNT_NOAUTO", _cmd_arr))
	}
	close(_cmd)
	_cmd = _mount_cmd
	while ((_cmd | getline) > 0) {
		_ds = $1
		_mounted = $2
		if (_mounted == "yes") {
			_cmd_arr["ds"] = q(_ds)
			run_cmd(endpoint_build_cmd(ep, "FAILOVER_UNMOUNT", _cmd_arr))
		}
	}
	close(_cmd)
}

function unlock_dataset(ep,    _cmd, _cmd_arr, _list_cmd, _mount_cmd, _list_local, _mount_local, _ds, _canmount, _mounted) {
	_cmd_arr["ds"] = q(ep["DS"])
	_list_local = build_command("FAILOVER_LIST_UNLOCK_NAMES", _cmd_arr)
	_mount_local = build_command("FAILOVER_LIST_UNLOCK_MOUNTED", _cmd_arr)
	_list_cmd = endpoint_cmd(ep, _list_local)
	_mount_cmd = endpoint_cmd(ep, _mount_local)
	run_cmd(endpoint_build_cmd(ep, "FAILOVER_INHERIT_READONLY", _cmd_arr))
	if (Opt["DRYRUN"])
		report(LOG_NOTICE, "+ " endpoint_cmd(ep, _list_local " | xargs -n1 zfs set canmount=on"))
	else {
		_cmd = _list_cmd
		while ((_cmd | getline) > 0) {
			_cmd_arr["ds"] = q($1)
			run_cmd(endpoint_build_cmd(ep, "FAILOVER_SET_CANMOUNT_ON", _cmd_arr))
		}
		close(_cmd)
	}
	_cmd_arr["ds"] = q(ep["DS"])
	run_cmd(endpoint_build_cmd(ep, "FAILOVER_MOUNT_RECURSIVE", _cmd_arr))
	if (Opt["DRYRUN"]) {
		report(LOG_NOTICE, "+ " endpoint_cmd(ep, _mount_local " | while read ds canmount mounted; do [ \\\"$canmount\\\" != off ] && [ \\\"$mounted\\\" != yes ] && zfs mount \\\"$ds\\\"; done"))
		return
	}
	_cmd = _mount_cmd
	while ((_cmd | getline) > 0) {
		_ds = $1
		_canmount = $2
		_mounted = $3
		if (_canmount != "off" && _mounted != "yes") {
			_cmd_arr["ds"] = q(_ds)
			run_cmd(endpoint_build_cmd(ep, "FAILOVER_MOUNT", _cmd_arr))
		}
	}
	close(_cmd)
}

function skip_ordered_option(arg, idx) {
	if (arg == "-n" || arg == "--dryrun" || arg == "--dry-run")
		return 1
	if (arg ~ /^-[vq]+$/ || arg == "--verbose" || arg == "--quiet")
		return 1
	if (arg ~ /^-d[^[:space:]]+/)
		return 1
	if (arg ~ /^--(depth|exclude|include|log-level|log-mode)=/)
		return 1
	if (arg == "-d" || arg == "--depth" || arg == "--exclude" || arg == "--include" || arg == "--log-level" || arg == "--log-mode")
		return 2
	return 0
}

function run_ordered_lock_args(    _i, _arg, _action, _num, _ep, _skip) {
	_action = Opt["VERB"] == "unlock" ? "unlock" : "lock"
	for (_i = 1; _i < ARGC; _i++) {
		_arg = ARGV[_i]
		if (_arg == "--lock") {
			_action = "lock"
			continue
		}
		if (_arg == "--unlock") {
			_action = "unlock"
			continue
		}
		_skip = skip_ordered_option(_arg, _i)
		if (_skip == 2) {
			_i++
			continue
		}
		if (_skip)
			continue
		if (_arg ~ /^-/)
			stop(1, "unsupported lock option in ordered mode: " _arg)
		load_endpoint(_arg, _ep)
		if (_action == "unlock")
			unlock_dataset(_ep)
		else
			lock_dataset(_ep)
		delete _ep
		_num++
	}
	if (!_num)
		stop(1, "zelta " Opt["VERB"] " requires at least one dataset")
}

## Property playback
####################

function rel_suffix(root, ds) {
	if (ds == root)
		return ""
	if (substr(ds, 1, length(root) + 1) != root "/")
		stop(1, "dataset is outside expected root: " ds)
	return substr(ds, length(root) + 1)
}

function load_local_props(ep, props, seen_ds,    _cmd, _cmd_arr, _ds, _prop, _val, _suffix) {
	_cmd_arr["ds"] = q(ep["DS"])
	_cmd = endpoint_build_cmd(ep, "FAILOVER_PROPS", _cmd_arr)
	while ((_cmd | getline) > 0) {
		_ds = $1
		_prop = $2
		_val = $3
		if (_prop == "volsize")
			continue
		if (_prop == "canmount")
			continue
		_suffix = rel_suffix(ep["DS"], _ds)
		if (_prop == "readonly" && _suffix == "")
			continue
		seen_ds[_suffix] = 1
		props[_suffix, _prop] = _val
	}
	close(_cmd)
}

function playback_source_props(tgt_ep,    _key, _parts, _suffix, _prop, _ds, _cmd_arr) {
	for (_key in SourceProp) {
		split(_key, _parts, SUBSEP)
		_suffix = _parts[1]
		_prop = _parts[2]
		_ds = tgt_ep["DS"] _suffix
		_cmd_arr["prop"] = _prop "=" q(SourceProp[_key])
		_cmd_arr["ds"] = q(_ds)
		run_cmd(endpoint_build_cmd(tgt_ep, "FAILOVER_PROP_SET", _cmd_arr))
	}
}

function inherit_target_only_props(tgt_ep,    _key, _parts, _suffix, _prop, _ds, _cmd_arr) {
	for (_key in TargetProp) {
		if (_key in SourceProp)
			continue
		split(_key, _parts, SUBSEP)
		_suffix = _parts[1]
		_prop = _parts[2]
		_ds = tgt_ep["DS"] _suffix
		_cmd_arr["prop"] = _prop
		_cmd_arr["ds"] = q(_ds)
		run_cmd(endpoint_build_cmd(tgt_ep, "FAILOVER_PROP_INHERIT", _cmd_arr))
	}
}

function sync_locked_source(src_ep, tgt_ep,    _cmd_arr, _cmd) {
	_cmd_arr["flags"] = "--snapshot --log-mode=text --log-level=" Opt["LOG_LEVEL"]
	_cmd_arr["source"] = q(src_ep["ID"])
	_cmd_arr["target"] = q(tgt_ep["ID"])
	_cmd = build_command("FAILOVER_BACKUP", _cmd_arr)
	run_cmd(_cmd)
}

function load_prop_endpoints(src_ep, tgt_ep) {
	if (NumOperands != 2)
		stop(1, "zelta " Opt["VERB"] " requires SOURCE and TARGET")

	load_endpoint(Operands[1], src_ep)
	load_endpoint(Operands[2], tgt_ep)
	load_local_props(src_ep, SourceProp, SourceDS)
	load_local_props(tgt_ep, TargetProp, TargetDS)
}

function sync_props(tgt_ep) {
	playback_source_props(tgt_ep)
	inherit_target_only_props(tgt_ep)
}

## Failover
###########

function run_failover(    _src, _tgt) {
	if (NumOperands != 2)
		stop(1, "zelta failover requires SOURCE and TARGET")

	load_endpoint(Operands[1], _src)
	load_endpoint(Operands[2], _tgt)

	if (!Opt["DRYRUN"]) {
		load_local_props(_src, SourceProp, SourceDS)
		load_local_props(_tgt, TargetProp, TargetDS)
	}

	lock_dataset(_src)
	sync_locked_source(_src, _tgt)
	sync_props(_tgt)
	unlock_dataset(_tgt)
}

function run_propsync(    _src, _tgt) {
	load_prop_endpoints(_src, _tgt)
	sync_props(_tgt)
}

## Main
#######

BEGIN {
	FS = "\t"
	if (Opt["VERB"] == "unlock" || Opt["VERB"] == "lock")
		run_ordered_lock_args()
	else if (Opt["VERB"] == "failover")
		run_failover()
	else if (Opt["VERB"] == "propsync")
		run_propsync()
	else
		stop(1, "unsupported failover verb: " Opt["VERB"])
	stop()
}
