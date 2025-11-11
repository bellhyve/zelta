#!/usr/bin/awk -f
#
# zelta-args.awk: serialize common zelta arguments

function env(env_name, var_default) {
	env_prefix = "ZELTA_"
	return ENVIRON[env_prefix env_name]
}

function error(error_message) {
	STDERR = "/dev/stderr"
	print "argument parsing error: " error_message > STDERR
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
	if (!user) { user = ENVIRON["USER"] }
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
		if (env("VERB") in repl_verb) {
			if (ep_type == "SRC") { zfs = env("REMOTE_SEND") }
			else if (ep_type == "TGT") { zfs = env("REMOTE_RECEIVE") }
			else { zfs = env("REMOTE_DEFAULT") }
		} else { zfs = env("REMOTE_DEFAULT") }
		zfs = zfs " " prefix " zfs"
	} else { zfs = "zfs" }
	newenv[ep_pre "ID"] = endpoint_id
	newenv[ep_pre "USER"] = user
	newenv[ep_pre "HOST"] = host
	newenv[ep_pre "DS"] = dataset
	newenv[ep_pre "SNAP"] = snapshot
	newenv[ep_pre "PREFIX"] = prefix
	newenv[ep_pre "ZFS"] = zfs
}

function add_arg(opt) {
	args = args (args ? "\t" : "") opt
}

function get_args() {
	repl_verb["backup"]
	repl_verb["replicate"]
	repl_verb["sync"]
	repl_verb["zpull"]
	repl_verb["zpush"]
	zfs_short_opts["X"]++
	zfs_short_opts["d"]++
	zfs_short_opts["o"]++
	zfs_short_opts["x"]++
        for (i=1;i<ARGC;i++) {
                $0 = ARGV[i]
		if (sub(/^-/,"")) {
			if (sub(/^-/,"") || (length($0)==1)) {
				add_arg($0)
			} else {
				for (m=1;m<=length($0);m++) {
					o = substr($0, m, 1)
					if (o in zfs_short_opts) {
						subopt = substr($0, m+1)
						if (!subopt) {
							i += 1
							subopt = ARGV[i]
						}
						add_arg(o " " subopt)
						break
					} else { add_arg(o) }
				}
			}
		} else if (!source_set) {
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
	if (args) { newenv["ZELTA_ARGS"] = args }
}

BEGIN {
	get_args()
	if (length(newenv) == 0) { exit(1) }
	for (e in newenv) {
		export = export " " e "='" newenv[e] "'"
	}
	print export
}
