#!/usr/bin/awk -f
#
# zelta-endpoint.awk - resolve and validate a local or remote volume string

function invalid() {
	print "invalid endpoint: "$0 > "/dev/stderr"
	error_code = 1
}

function clear_vars() {
	endpoint_id = ""
	prefix = ""
	user = ""
	host = ""
	volume = ""
	delete vol_snap
	delete user_host
}

BEGIN { FS = "[:]" }

(NR > 1) { clear_vars() }

($3 || !$1) { invalid(); next }

$2 {
	if (split($1, user_host, "@")==2) {
		user = user_host[1]
		host = user_host[2]
	} else host = $1
	prefix = $1
	$1 = $2
}

{
	if (split($1, vol_snap, "@")) {
		volume = vol_snap[1]
		snapshot = vol_snap[2]
	} else volume = vol_snap[1]
}

!user { user = ENVIRON["USER"] }

!host {
	host = ENVIRON["HOST"] ? ENVIRON["HOST"] : ENVIRON["HOSTNAME"]
	if (!host) {
		"hostname" | getline host
		close("hostname")
        } else host = "localhost"
}

{ 
	endpoint_id = user"_"host"_"volume"_"snapshot
	gsub(/[^A-Za-z0-9_]/,"-", endpoint_id)
	OFS = "\t"
	print endpoint_id,prefix,user,host,volume,snapshot
}

END { exit error_code }
