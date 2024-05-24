#!/usr/bin/awk -f

#
# zelta-endpoint.awk
#
# Resolve and validate local or remote dataset endpoint strings, splitting them
# into a tabbed list of elements. Called with "zelta endpoint".

function clear_vars() {
	endpoint_id = ""
	prefix = ""
	user = ""
	host = ""
	dataset = ""
}

function print_endpoint(endpoint) {
	if (!(endpoint ~ /^[a-zA-Z0-9_.@:\/ -]+$/)) {
		print "invalid endpoint: '"$0"'" > "/dev/stderr"
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
	print endpoint_id,prefix,user,host,dataset,snapshot
}

BEGIN {
	FS = "[\t]"
	OFS = "\t"
}

{
	for(i=1;i<=NF;i++) {
		print_endpoint($i)
		clear_vars()
	}
}

END { exit error_code }
