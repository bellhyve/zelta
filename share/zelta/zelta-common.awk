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

function report(mode, message) {
	print mode "\t" message | Opt["LOG_COMMAND"]
	log_output_count++
}

# Flush buffers and quit
function stop(_error_code, _error_msg) {
	if (_error_msg) report(LOG_ERROR, _error_msg)
	if (log_output_count) { close(Opt["LOG_COMMAND"]) }
	exit _error_code
}

# Simple String Functions
function q(s) { return "'" s "'" }

function dq(s) { return "\"" s "\"" }

function str_add(s, v, sep) {
	if (!sep) sep = " "
	#if (!v) v = $0
	return s ? s sep v : v
}

function str_join(arr, sep,    _str, _idx, _i) {
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
	ENV_PREFIX = "ZELTA_"
	STDERR = "/dev/stderr"
	LOG_ERROR = 0
	LOG_WARNING = 1
	LOG_NOTICE = 2
	LOG_INFO = 3
	LOG_DEBUG = 4

	create_assoc("no false", Nope)

	# load user options into Opt[]
	zelta_init()

}
