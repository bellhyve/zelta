# zelta-common.awk
#
# Function common to all Zelta scripts
#


# Load ZELTA_ environment variables as Opt[VAR] shorthand without the prefix
function zelta_init(_o) {
	for (_o in ENVIRON) {
		if (sub(/^ZELTA_/, "", _o)) {
			Opt[_o] = ENVIRON["ZELTA_" _o]
		}
	}
}

function report(mode, message) {
	print mode "\t" message | Opt["LOG_COMMAND"]
	log_output_count++
}

# Flush buffers and quit
function stop(_error_code) {
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
