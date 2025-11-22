#!/usr/bin/awk -f
#
# zelta-args.awk: serialize common zelta arguments

function init(		o) {
	for (o in ENVIRON) {
		if (sub(/^ZELTA_/,"",o)) {
			opt[o] = ENVIRON["ZELTA_" o]
		}
	}
}

function report(mode, message) {
	print mode "\t" message | opt["LOG_COMMAND"]
	LOG_LINES++
}

function stop(exit_code) {
	if (LOG_LINES) close(LOGGER)
	exit exit_code
}

function get_endpoint(ep_type) {
	ep_pre = ep_type "_"
	endpoint = $0
	if (!(endpoint ~ /^[a-zA-Z0-9_.@:\/ -]+$/)) {
		report(LOG_ERROR, "invalid endpoint: '"$0"'")
		return
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
	# Change the ID  back to just the actual endpoint string, I think.
	newenv[ep_pre "ID"] = endpoint_id
	newenv[ep_pre "USER"] = user
	newenv[ep_pre "HOST"] = host
	newenv[ep_pre "DS"] = dataset
	newenv[ep_pre "SNAP"] = snapshot
	newenv[ep_pre "PREFIX"] = prefix
}

function add_arg(arg) {
	args = args (args ? "\t" : "") arg
}

function get_args() {
	repl_verb["backup"]++
	repl_verb["replicate"]++
	repl_verb["sync"]++
	repl_verb["zpull"]++
	repl_verb["zpush"]++
	zfs_short_opts["X"]++
	zfs_short_opts["d"]++
	zfs_short_opts["o"]++
	zfs_short_opts["x"]++
	for (i=1;i<ARGC;i++) {
		$0 = ARGV[i]
		if (sub(/^-/,"")) {
			if (sub(/^-/,"")) {
				# Double-dash sub options must be --opt=val
				if (sub(/^log-level=/,"")) newenv["LOG_LEVEL"] = $0
				else add_arg($0)
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
					}
					else if (o == "v") newenv["LOG_LEVEL"]++
					else if (o == "q") newenv["LOG_LEVEL"]--
					else add_arg(o)
				}
			}
		} else if (!source_set) {
			get_endpoint("SRC")
			source_set++
		} else if (!target_set) {
			get_endpoint("TGT")
			target_set++
		} else {
			report(LOG_ERROR, "too many options: '"$0"'")
			exit
		}
	}
	if (args) { newenv["ARGS"] = args }
}

BEGIN {
	init()
	LOG_ERROR = 0
	LOG_WARNING = 1
	LOG_NOTICE = 2
	LOG_INFO = 3
	LOG_DEBUG = 4
	
	ENV_PREFIX = "ZELTA_"

	# We need to know the LOG_LEVEL default for -v/-q
	newenv["LOG_LEVEL"] = opt["LOG_LEVEL"]
	get_args()
	for (e in newenv) {
		# Make sure we're actually changing something
		if (newenv[e] != opt[e]) {
			export = export " " (ENV_PREFIX e) "='" newenv[e] "'"
		}
	}
	if (export) print export
}
