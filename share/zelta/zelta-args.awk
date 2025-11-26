#!/usr/bin/awk -f
#
# zelta-args.awk: serialize common zelta arguments

# Create a set of variables from an scp-like host-dataset argument
# [[user@]host:]dataset[@snapshot]
function get_endpoint(ep_type) {
	ep_pre = ep_type "_"
	endpointd = $0
	if (!(/^[a-zA-Z0-9_.@:\/ -]+$/)) {
		report(LOG_ERROR, "invalid endpoint: '"$0"'")
		return
	}
	if (/^[^ :\/]+:/) {
		split($0, connect_string, ":")
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
		sub(/^[^:]+:/,"")
	}
	if (split($0, ds_snap, "@")) {
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
	NewOpt[ep_pre "ID"] = endpointd
	NewOpt[ep_pre "USER"] = user
	NewOpt[ep_pre "HOST"] = host
	NewOpt[ep_pre "DS"] = dataset
	NewOpt[ep_pre "SNAP"] = snapshot
	NewOpt[ep_pre "PREFIX"] = prefix
}

function match_arg(arg, 	_flag, _flags) {
	for (_flag in OptListFlags) {
		_flags = OptListFlags[_flag]
		if (arg == _flag) return _flags
	} 
	report(LOG_ERROR, "invalid option '"arg"'")
	stop(1)
}

function set_arg(flag, subopt) {
	if (OptListType[flag] == "arglist")	NewOpt[OptListKey[flag]] = str_add(NewOpt[OptListKey[flag]])
	else if (OptListType[flag] == "true")	NewOpt[OptListKey[flag]] = "1"
	else if (OptListType[flag] == "false")	NewOpt[OptListKey[flag]] = "0"
	else if (OptListType[flag] == "set")	NewOpt[OptListKey[flag]] = subopt
	else if (OptListType[flag] == "incr")	NewOpt[OptListKey[flag]]++
	else if (OptListType[flag] == "decr")	NewOpt[OptListKey[flag]]--
	else if (OptListType[flag] == "invalid") {
		report(LOG_ERROR, OptListWarn[flag])
		stop()
	}
	if (OptListType[flag] == "warn")		report(LOG_WARNING, OptListWarn[flag])
}

# Handle "set" action logic
function get_subopt(flag, m,	_subopt) {
	# If a key=value is given out of context, stop
	if ($2 && ((OptListType[flag] != "set") || OptListValue[flag])) {
		report(LOG_ERROR, "invalid option assignment '"$0"'")
		stop(1)
	}
	# Not a "set" action
	else if (OptListType[flag] != "set") return ""
	# --key=value
	else if ($2) return $2
	# Value is defined upstream
	else if (OptListValue[flag]) return OptListValue[flag]
	# Single dash option
	if (m) {
		_subopt = substr($0, m+1)
		# -k1
		if (_subopt) return _subopt
	}
	# '--key value' or '-k 1', increment the ARGV index
	_subopt = ARGV[++Idx]
	if (!_subopt) {
		report(LOG_ERROR, "option '"$1"' requires an argument")
		stop(1)
	} else return _subopt
}

function get_args(		_i, _flag, _m, _subopt) {
	FS = "="
	for (Idx = 1; Idx < ARGC; Idx++) {
		$0 = ARGV[Idx]
		if (/^--[^-]/) {
		       	_flag = match_arg($1)
			_subopt = get_subopt(_flag)

			set_arg(_flag, _subopt)
		} else if (/^-[^-]/) {
			# step through basic -opts
			for (_m=2; _m <= length($0); _m++) {
				_arg = "-" substr($0, _m, 1)
				_flag = match_arg(_arg)
				_subopt = get_subopt(_flag, _m)
				set_arg(_flag, _subopt)
				if (_subopt && !OptListValue[_flag]) break
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
}

# Load and index option file
function load_option_list(		_tsv, _flag, _flags, _idx, _flag_arr) {
	# We need to know the LOG_LEVEL default for -v/-q
	NewOpt["LOG_LEVEL"] = Opt["LOG_LEVEL"]
	_tsv = Opt["SHARE"]"/zelta-opts.tsv"
	FS="\t"
	while (getline<_tsv) {
		if (index($1, Opt["VERB"]) || ($1 == "all")) {
			_flags = $2
			if (!_flags) {
				report(LOG_WARNING, "malformed option file line: "$0)
				continue
			}
			split($2, _flag_arr, ",")
			# Make an dictionary for flag synonyms
			for (_idx in _flag_arr) OptListFlags[_flag_arr[_idx]] = _flags
			OptListKey[_flags]	= $3
			OptListType[_flags]	= $4
			OptListValue[_flags]	= $5
			OptListWarn[_flags]	= $6
		}
	}
	close(_tsv)
}

# Send an override back to 'zelta' when an arg has changed
function override_options(	_e) {
	for (_e in NewOpt) {
		if (NewOpt[_e] != Opt[_e]) {
			export = export " " (ENV_PREFIX _e) "='" NewOpt[_e] "'"
		}
	}
	# This must be an explicit 'print' for shell input (not 'zelta ipc-log')
	if (export) print export
}

BEGIN {
	load_option_list()
	get_args()
	override_options()
}
