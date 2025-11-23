# zelta-common.awk
#

# Load ZELTA_ environment variables as opt[VAR] shorthand without the prefix
function zelta_init(_o) {
	for (_o in ENVIRON) {
		if (sub(/^ZELTA_/, "", _o)) {
			opt[_o] = ENVIRON["ZELTA_" _o]
		}
	}
}

function report(mode, message) {
	print mode "\t" message | opt["LOG_COMMAND"]
	log_output_count++
}

function close_all() {
	if (log_output_count) { close(opt["LOG_COMMAND"]) }
}

# Simple String Functions
function q(s) { return "'" s "'" }
function dq(s) { return "\"" s "\"" }

function str_add(s, n, sep) {
	if (!sep) sep = " "
	return s ? s sep n : n
}

function str_join(arr, sep,    _str, _idx, _i) {
	if (!sep) sep = " "
	for (_idx in arr) {
		_str = str_add(_str, arr[++_i], sep)
	}
	return _str
}

# systime() doesn't work on a lot of systems despite being in the POSIX spec.
# This workaround isn't entirely portable either and should be replaced.
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
	zelta_init()

	# Constants
	LOG_ERROR = 0
	LOG_WARNING = 1
	LOG_NOTICE = 2
	LOG_INFO = 3
	LOG_DEBUG = 4

	STDERR = "/dev/stderr"
}
