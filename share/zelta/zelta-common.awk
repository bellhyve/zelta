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
#
# Common functions:
# report(log_level, message)
# str_add(a, b, sep): Join by " " or sep
# str_must_join(a, b, sep): Join by "" or sep but return "" either are missing

# Load ZELTA_ environment variables as Opt[VAR] shorthand without the prefix
function zelta_init(	_o, _prefix_re, _val) {
	_prefix_re = ENV_PREFIX
	for (_o in ENVIRON) {
		if (sub(_prefix_re, "", _o)) {
			_val = ENVIRON[ENV_PREFIX _o]
			if (tolower(_val) in False) _val = 0
			Opt[_o] = _val
		}
	}
	NumOperands	= split(Opt["OPERANDS"], Operands, SUBSEP)
}

function load_endpoint(ep, ep_arr,	_str_parts, _id, _remote ,_user, _host, _ds, _snap, _depth, _pool, _leaf) {
	if (!ep) return
	_id	= ep				# ID is the user's endpoint string
	# Find the connection info for ssh, '[user@]host'
	if (ep ~ /^[^ :\/]+:/) {
		_remote	= ep
		sub(/:.*/, "", _remote)		# REMOTE is '[user@]host'
		sub(/^[^ :\/]+:/,"", ep)	# Don't split(), ep may have ':'
		if (split(_remote, _str_parts, "@")==2) {
			_user = _str_parts[1]	# USER from 'user@host'
			_host = _str_parts[2]	# HOST
		} else _host = _str_parts[1]	# HOST only
		# Special case: If the DS or SNAP contains a ':' and our target is local, we
		# have a work around: 'localhost:' _remote (with no user) gets cleared (so no ssh).
		if (!_user && (_host == "localhost")) _remote = ""
	}
	# Try get a suitable hostname for logging
	if (!_host || (_host == "localhost"))
		_host = Opt["HOSTNAME"]
	# TO-DO: Review snapshot-only endpoint policy:
	# ZFS supports bookmarks for incremental source, but not Zelta only needs a target snapshot
	if (split(ep, _str_parts, "@") == 2) {
		_snap = "@" _str_parts[2]
	}
	_ds = _str_parts[1]
	_depth = split(_ds, _str_parts, "/")
	_pool = _str_parts[1]
	_leaf = _str_parts[_depth]
	if (!_user) { _user = ENVIRON["USER"] }	# USER may be useful for logging

	# Validate and define the endpoint
	#if (! _ds) stop(1, "invalid endpoint '"_id"'")
	ep_arr["ID"]		= _id
	ep_arr["REMOTE"]	= _remote
	ep_arr["USER"]		= _user
	ep_arr["HOST"]		= _host
	ep_arr["DS"]		= _ds
	ep_arr["SNAP"]		= _snap
	ep_arr["POOL"]		= _pool
	ep_arr["LEAF"]		= _leaf
	ep_arr["DEPTH"]		= _depth
}

# OUTPUT FUNCTIONS

# Logging
function report(mode, message,		_mode_message) {
	_mode_message = mode SUBSEP message
	print _mode_message | Opt["LOG_COMMAND"]
	log_output_count++
}

function json_write(_j, _depth, _fs, _rs, _val, _next_val) {
	_fs = "  "
	_rs = "\n"
	_depth = 0
	if (LoadSummaryVars) json_close_object()
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

# Return a json value of null, num, or string
function json_val(val) {
	if (val == "") val = "null"
	else if (val !~ /^-?[0-9\.]+$/) val = dq(val)
	return val
}

# Basic json contructors
function json_new_object(name) { JsonOutput[++JsonNum] = (name ? dq(name) ": " : "") "{" }
function json_close_object() { JsonOutput[++JsonNum] = "}" }
function json_new_array(name) { JsonOutput[++JsonNum] = (name ? dq(name) ": " : "") "[" }
function json_close_array() { JsonOutput[++JsonNum] = "]" }
function json_member(name, val) { JsonOutput[++JsonNum] = dq(name) ": " json_val(val) }
function json_element(val) { JsonOutput[++JsonNum] = json_val(val) }

# Lod global Summary for special output modes
function load_summary_data(	_tsv, _key, _val) {
        _tsv = Opt["SHARE"]"/zelta-json.tsv"
        FS="\t"
        while (getline < _tsv) {
		_key = $1
		if ($2 == "Opt") _val = Opt[$3]
		else continue
		if (!_val) {
			if (!$4) continue
			else if ($4 == "0") _val = "0"
			else if ($4 == "null") _val = ""
			else _val = ""
		}
		Summary[_key] = _val
	}
	close(_tsv)
}

function load_summary_vars(	_j) {
        if (Opt["LOG_MODE"] == "json") {
                json_new_object()
                json_new_object("output_version")
                json_member("command", "zelta "Opt["VERB"])
                json_member("vers_major", GlobalState["vers_major"])
                json_member("vers_minor", GlobalState["vers_minor"])
                json_close_object()
                for (_j in Summary) json_member(_j, Summary[_j])
		LoadSummaryVars++
	}
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
function qq(_s) {
	gsub(/ /, "\\ ", _s)
	return "'"_s"'"
}

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

# For remote-conditional quoting; if _r is present, escape spaces
function rq(_r, _s) {
	_s = _r ? qq(_s) : q(_s)
	return _s
}

# DELETE ME
function str_join(arr, sep) {
	report(LOG_WARNING, "deprecated common function 'str_join()'")
	return arr_join(arr, sep)
}

# Joins non-blank elements of an array
function arr_join(arr, sep,    _str, _idx, _i) {
	if (!sep) sep = " "
	for (_idx in arr)
		if (arr[++_i])
			_str = _str ? _str sep arr[_i] : arr[_i]
	return _str
}

function arr_copy(src_arr, tgt_arr,		_key) {
        delete tgt_arr
        for (_key in src_arr) tgt_arr[_key] = src_arr[_key]
}

function arr_len(arr, _lcv, _i) {
	for (_lcv in arr)
		++_i
	return _i
}

# Sort an array
function arr_sort(arr, num_elements,	_i, _j, _val) {
	if (!num_elements)
		num_elements = arr_len(arr);
	for (_i = 2; _i <= num_elements; _i++) {
		# Store the current value and its key
		_val = arr[_i];
		_j = _i - 1;
		while (_j >= 1 && arr[_j] > _val) {
			arr[_j + 1] = arr[_j];
			_j--;
		}
		arr[_j + 1] = _val;
	}
}

# Create an associative array from a list
function create_assoc(list, assoc, sep,		_i, _arr) {
	sep = sep ? sep : " "
	split(list, _arr, sep)
	for (_i in _arr)
		assoc[_arr[_i]] = 1
}

# I think this is just for 'zelta match' and could be retired
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

# Constructs a remote command string
function remote_str(endpoint, type,     _cmd) {
	if (!Opt[endpoint "_REMOTE"]) return ""
        type = type ? type : "DEFAULT"
        _cmd = Opt["REMOTE_" type]" "Opt[endpoint "_" "REMOTE"]
        return _cmd
}

# Gets remote command from endpoint array
function get_remote_cmd(ep, type,	_cmd) {
	if (!ep["REMOTE"]) return
	type = type ? type : "DEFAULT"
	_cmd = Opt["REMOTE_" type]" "ep["REMOTE"]
	return _cmd
}

## Command builder
##################

# Loads zelta-cmds.tsv which format external 'zelta' and 'zfs' commmands
function load_build_commands(           _tsv, _action) {
	LOAD_BUILD_COMMANDS++
        _tsv = Opt["SHARE"]"/zelta-cmds.tsv"
        FS="\t"
        while (getline < _tsv) {
                if (/^$|^#/) continue
                _action= $1
                CommandRemote[_action]      = $2
                CommandLine[_action]     = str_add($3, $4)
                CommandVars[_action]    = $5
                CommandSuffix[_action]    = $6
        }
        close(_tsv)
}

# Constructs a command using an action and the passed array
# Special variables:
#   "endpoint": Expands a remote prefix if given
#   "command_prefix": Inserts before command name for an additional pipe or environment variable
function build_command(action, vars, 		_remote_prefix, _cmd, _num_vars, _var_list, _val) {
	if (!LOAD_BUILD_COMMANDS) load_build_commands()
        if (CommandRemote[action]) {
		if (vars["endpoint"])
	                _remote_prefix = remote_str(vars["endpoint"], CommandRemote[action])
		else if (vars["remote"])
			_remote_prefix = vars["remote"]
	}
        _cmd = CommandLine[action]
        _num_vars = split(CommandVars[action], _var_list, " ")
        for (_v = 1; _v <= _num_vars; _v++) {
                _val = vars[_var_list[_v]]
                _cmd = str_add(_cmd, _val)
        }
        _cmd = str_add(_cmd, CommandSuffix[action])
        if (_remote_prefix && vars["dq"]) _cmd = dq(_cmd)
        _cmd = str_add(_remote_prefix, _cmd)
        if (vars["command_prefix"]) _cmd = str_add(vars["command_prefix"], _cmd)
        return _cmd
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

	create_assoc("no false 0", False)
	create_assoc("yes true 1", True)

	# load user options into Opt[] and create global lists
	zelta_init()
}
