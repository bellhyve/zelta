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
function zelta_init(	_o, _prefix_re) {
	_prefix_re = ENV_PREFIX
	for (_o in ENVIRON) {
		if (sub(_prefix_re, "", _o)) {
			_val = ENVIRON[ENV_PREFIX _o]
			if (tolower(_val) in False) _val = "0"
			Opt[_o] = _val
		}
	}
}

# OUTPUT FUNCTIONS

# Logging
function report(mode, message) {
	print mode "\t" message | LOG_COMMAND
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
function load_summary_data(	_sum_data, _sum_arr, _sum_num, _s) {
	_summary_data="# MAP_KEY	VAR_SOURCE	VAR_KEY	MAP_KEY	NULL_MODE\n\
# MAP_KEY: The name of the summary field\n\
# VAR_SOURCE: The source of the key\n\
# VAR_KEY: The key\n\
# NULL_MODE: null, 0, or empty to suppress the field if not found\n\
\n\
sourceUser	Opt	SRC_USER	\n\
sourceHost	Opt	SRC_HOST	\n\
sourceDataset	Opt	SRC_DS	\n\
sourceSnapshot	Opt	SRC_SNAP	\n\
sourceEndpoint	Opt	SRC_ID	\n\
targetUser	Opt	TGT_USER	\n\
targetHost	Opt	TGT_HOST	\n\
targetDataset	Opt	TGT_DS	\n\
targetSnapshot	Opt	TGT_SNAP	\n\
targetEndpoint	Opt	TGT_ID\n\
"
	_sum_num = split(_summary_data, _sum_arr, "\n")
	for (_s = 1; _s <= _sum_num; _s++) {
		$0 = _sum_arr[_s]
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
}

function load_summary_vars() {
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

# Constructs a remote command string
function remote_str(endpoint, type,     _cmd) {
        type = type ? type : "DEFAULT"
        _cmd = Opt["REMOTE_" type]" "Opt[endpoint "_" "REMOTE"]
        return _cmd
}

## Command builder
##################

# Loads zelta-cmds.tsv which format external 'zelta' and 'zfs' commmands
function load_build_commands(           _action) {
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
function build_command(action, vars,            _remote_prefix, _cmd, _num_vars, _var_list, _val) {
	if (!LOAD_BUILD_COMMANDS) load_build_commands()
        if (CommandRemote[action] && vars["endpoint"]) {
                _remote_prefix = remote_str(vars["endpoint"], CommandRemote[action])
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

	# load user options into Opt[]
	zelta_init()

	# Derived globals
	LOG_COMMAND	= Opt["LOG_COMMAND"] ? Opt["LOG_COMMAND"] : "zelta ipc-log"
}
