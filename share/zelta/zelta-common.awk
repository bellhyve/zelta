# zelta-common.awk
#
# Function common to all Zelta scripts
#
# Awk variable styles:
# - GLOBAL_CONSTANT
# - GlobalVariable
# - received_function_variable
# - _local_function_variables
# - ["ARRAY_KEY"] (when upstream or hard-coded)

# Load ZELTA_ environment variables as Opt[VAR] shorthand without the prefix
function zelta_init(	_o, _prefix_re) {
	_prefix_re = ENV_PREFIX
	for (_o in ENVIRON) {
		if (sub(_prefix_re, "", _o)) {
			_val = ENVIRON[ENV_PREFIX _o]
			if (tolower(_val) in Nope) _val = "0"
			Opt[_o] = _val
		}
	}
}

# OUTPUT FUNCTIONS

# Logging
function report(mode, message) {
	print mode "\t" message | Opt["LOG_COMMAND"]
	log_output_count++
}

function report_once(mode, message) {
	if (!SuppressedMessage[message]++)
		report(mode, message)
}

function json_write(_j, _depth, _fs, _rs, _val, _next_val) {
	_fs = "  "
	_rs = "\n"
	_depth = 0
	for (_j = 1; _j <= JsonNum; _j++) {
		_val = JsonOutput[_j]
		_next_val = JsonOutput[_j+1]
		if (_val ~ /^[\]\}]/) _depth--
		# Enable JSON_PRETTY or provide 'jq'-like output
		if (Opt["JSON_PRETTY"]) printf str_rep(_fs, _depth)
		printf(_val)
		if (_next_val && _val !~ /[{\[]$/ && _next_val !~ /^[\]\}]/) {
			printf(",")
		}
		if (Opt["JSON_PRETTY"]) printf _rs
		if (_val ~ /[\[\{]$/) {
			_depth++
		}
	}
}

function json_val(val) {
	if (val == "") val = "null"
	else if (val !~ /^-?[0-9\.]+$/) val = dq(val)
	return val
}

function json_new_object() { JsonOutput[++JsonNum] = "{" }
function json_close_object() { JsonOutput[++JsonNum] = "}" }
function json_new_array(name) { JsonOutput[++JsonNum] = (name ? dq(name) ": " : "") "[" }
function json_close_array() { JsonOutput[++JsonNum] = "]" }
function json_member(name, val) { JsonOutput[++JsonNum] = dq(name) ": " json_val(val) }
function json_element(val) { JsonOutput[++JsonNum] = json_val(val) }

function json_array(name, msg_list) {
	printf "  \""name"\": ["
	list_len = 0
	for (n in msg_list) list_len++
	if (list_len) {
		print ""
		for (n=1;n<=list_len;n++) {
			gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", msg_list[n])
			gsub(/\n/, "; ", msg_list[n])
			gsub(/"/, "'", msg_list[n])
			printf "    \""msg_list[n]"\""
			if (n<list_len) print ","
		}
		printf "\n  "
	}
	printf "]"
	return ",\n"
}

function output_json() {
	print "{"
	print jpair("startTime",time_start)
	print jpair("endTime",time_end)
	print jpair("sourceUser",user[source])
	print jpair("sourceHost",host[source])
	print jpair("sourceDataset",ds[source])
	print jpair("sourceListTime",source_zfs_list_time)
	print jpair("targetUser",user[target])
	print jpair("targetHost",host[target])
	print jpair("targetDataset",ds[target])
	print jpair("targetListTime",target_zfs_list_time)
	print jpair("replicationSize",total_bytes)
	print jpair("replicationStreamsSent",sent_streams)
	print jpair("replicationStreamsReceived",received_streams)
	print jpair("replicationErrorCode",error_code)
	print jpair("replicationTime",zfs_replication_time)
	printf jlist("sentStreams", source_stream)
	jlist("errorMessages", error_list)
	print "\n}"
}

# Flush buffers and quit
function stop(_error_code, _error_msg) {
	if (_error_msg) report(LOG_ERROR, _error_msg)
	if (log_output_count) close(Opt["LOG_COMMAND"])
	if (JsonNum) json_write()
	if (Opt["JSON_FILE"]) close(Opt["JSON_FILE"])
	exit _error_code
}

# Simple String Functions
function q(s) { return "'" s "'" }

function dq(s) { return "\"" s "\"" }

function str_add(s, v, sep) {
	if (!s || !v) return s v
	if (!sep) sep = " "
	return s ? s sep v : v
}

function str_rep(str, num,    _out, _i) {
	for (_i = 1; _i <= num; _i++) _out = _out str
	return _out
}

# DELETE ME
function str_join(arr, sep) {
	report(LOG_WARNING, "deprecated common function 'str_join()'")
	return arr_join(arr, sep)
}

function arr_join(arr, sep,    _str, _idx, _i) {
	if (!sep) sep = " "
	for (_idx in arr) {
		if (arr[++_i]) {
			_str = _str ? _str sep arr[_i] : arr[_i]
		}
	}
	return _str
}


# Create an associative array from a list
function create_assoc(list, assoc, sep,		_i, _arr) {
	sep = sep ? sep : " "
	split(list, _arr, sep)
	for (_i in _arr) assoc[_arr[_i]]++
}

function create_dict(dict, def, 		_i, _n, _arr, _pair) {
	# def format: user_key:key [space]
	_n = split(def, _arr, " ")
	for (_i = 1; _i <= _n; _i++) {
		if (split(_arr[_i], _pair, ":")) dict[_pair[1]] = _pair[2]
		else report(LOG_ERROR, "error creating dictionary: " _arr[_1])
	}
}

# systime() doesn't work on a lot of systems despite being in the POSIX spec.
# This workaround might not be entirely portable either; needs QA or replacement
function sys_time() {
	srand();
	return srand();
}

# Convert to a human-readable number
function h_num(num,	_suffix, _divisors, _h) {
	_suffix = "B"
	_divisors = "KMGTPE"
	for (_h = 1; _h <= length(_divisors) && num >= 1024; _h++) {
		num /= 1024
		_suffix = substr(_divisors, _h, 1)
	}
	return int(num) _suffix
}

BEGIN {
	# Constants
	ENV_PREFIX	= "ZELTA_"
	COMMAND_ERRORS	= "([Nn]o route to host|[Cc]ould not resolve|[Cc]ommand not found|[Cc]onnection refused|[Nn]etwork.*unreachable)"
	CAPTURE_OUTPUT	= " 2>&1"
	STDERR		= "/dev/stderr"
	LOG_ERROR	= 0
	LOG_WARNING	= 1
	LOG_NOTICE	= 2
	LOG_INFO	= 3
	LOG_DEBUG	= 4
	LOG_JSON	= LOG_NOTICE

	create_assoc("no false", Nope)

	# load user options into Opt[]
	zelta_init()
}
