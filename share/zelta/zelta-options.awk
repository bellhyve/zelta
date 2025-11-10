#!/usr/bin/awk -f
#
# zelta-options.awk: serialize common zelta arguments

function env(env_name, var_default) {
	env_prefix = "ZELTA_"
	return ENVIRON[env_prefix env_name]
}

function error(error_message) {
	STDERR = "/dev/stderr"
	print "invalid argument: " error_message > STDERR
}


function get_endpoint(ep_type) {
	ep_pre = "ZELTA_"ep_type"_"
	endpoint = $0
	if (!(endpoint ~ /^[a-zA-Z0-9_.@:\/ -]+$/)) {
		error("invalid endpoint: '"$0"'")
		error_code = 1
		return 0
	}
	if (endpoint ~ /^[^ :\/]+:/) {
		split(endpoint, connect_string, ":")
		prefix = connect_string[1]
		if (match(prefix, /@[^@]*$/)) {
			user = substr(prefix, 1, RSTART - 1)
			host = substr(prefix, RSTART + 1)
		} else host = prefix
		if (split(prefix, user_host, "@")==2) {
			user = user_host[1]
			host = user_host[2]
		} else host = user_host[1]
		if (host == "localhost") prefix = ""
		sub(/^[^:]+:/,"",endpoint)
	}
	if (split(endpoint, ds_snap, "@")) {
		dataset = ds_snap[1]
		snapshot = ds_snap[2]
	} else dataset = ds_snap[1]
	if (!user) user = ENVIRON["USER"]
	if (!host) {
		host = ENVIRON["HOST"] ? ENVIRON["HOST"] : ENVIRON["HOSTNAME"]
		if (!host) {
			"hostname" | getline host; close("hostname")
		}
		if (!host) host = "localhost"
	}
	endpoint_id = user"_"host"_"dataset
	gsub(/[^A-Za-z0-9_]/,"-", endpoint_id)
	if (prefix) {
		if (verb in repl_verbs) {
			zfs = (ep_type == "TGT") ? env("REMOTE_SEND") : env("REMOTE_RECEIVE")
		} else { zfs = env("REMOTE_DEFAULT") }
		zfs = zfs " " prefix " zfs"
	} else { zfs = "zfs" }
	args[ep_pre "ID"] = endpoint_id
	args[ep_pre "USER"] = user
	args[ep_pre "HOST"] = host
	args[ep_pre "DS"] = dataset
	args[ep_pre "SNAP"] = snapshot
	args[ep_pre "PREFIX"] = prefix
	args[ep_pre "ZFS"] = zfs
}

function get_options() {
        for (i=1;i<ARGC;i++) {
                $0 = ARGV[i]
		if (!/^-/) {
			if (!source_set) {
	       			get_endpoint("SRC")
				source_set++
			} else if (!target_set) {
				get_endpoint("TGT")
				target_set++
			} else {
				error("too many options: '"$0"'")
				exit
			}
		}
        }
}

BEGIN {
	get_options()
	for (a in args) {
		print "export " a "='" args[a] "'"
	}
}
