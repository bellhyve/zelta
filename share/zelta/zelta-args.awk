#!/usr/bin/awk -f
#
# zelta-args.awk: serialize common zelta arguments

# Create a set of variables from an scp-like host-dataset argument
# [[user@]host:]dataset[@snapshot]
function get_endpoint(ep_type) {
	ep_pre = ep_type "_"
	endpoint_id = $0
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
	NewOpt[ep_pre "ID"] = endpoint_id
	NewOpt[ep_pre "USER"] = user
	NewOpt[ep_pre "HOST"] = host
	NewOpt[ep_pre "DS"] = dataset
	NewOpt[ep_pre "SNAP"] = snapshot
	NewOpt[ep_pre "PREFIX"] = prefix
}

function add_arg(arg) {
	args = args (args ? "\t" : "") arg
}

function match_arg(arg, 	_flag) {
	for (_flag in OptListFlags) {
		_flags = OptListFlags[_flag]
		if (arg == _flag) return _flags
	} 
	report(LOG_ERROR, "invalid option '"arg"'")
	stop(1)
}

function set_arg(_flag, subopt) {
	if (OptListType[_flag] == "arglist")	NewOpt[OptListKey[_flag]] = str_add(NewOpt[OptListKey[_flag]])
	else if (OptListType[_flag] == "bool")	NewOpt[OptListKey[_flag]] = "yes"
	else if (OptListType[_flag] == "set")	NewOpt[OptListKey[_flag]] = subopt
	else if (OptListType[_flag] == "del")	NewOpt[OptListKey[_flag]] = ""
	else if (OptListType[_flag] == "incr")	NewOpt[OptListKey[_flag]]++
	else if (OptListType[_flag] == "decr")	NewOpt[OptListKey[_flag]]--
	if (OptListType[_flag] == "warn")	report(LOG_WARNING, OptListWarn[_flag])
}

function get_args() {
	for (i=1;i<ARGC;i++) {
		$0 = ARGV[i]
		if (/^--[^-]/) {
		       	_flag = match_arg($0)
			subopt = (OptListType[_flag] == "set") ? ARGV[++i] : ""
			set_arg(_flag, subopt)
		} else if (/^-[^-]/) {
			for (_m=2; _m <= length($0); _m++) {
				_arg = "-" substr($0, _m, 1)
				_flag = match_arg(_arg)
				if ((OptListType[_flag]) == "set") {
					subopt = substr($0, _m+1)
					if (!subopt) subopt = ARGV[++i]
					set_arg(_flag, subopt)
					break
				} else set_arg(_flag)
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
	_tsv = Opt["SHARE"]"/zelta-opts.tsv"
	while (getline<_tsv) {
		if (index($1, Opt["VERB"]) || ($1 == "all")) {
			_flags = $2
			split($2, _flag_arr, ",")
			# Make an dictionary for flag synonyms
			for (_idx in _flag_arr) OptListFlags[_flag_arr[_idx]] = _flags
			OptListKey[_flags]	= $3
			OptListType[_flags]	= $4
			OptListValue[_flags]	= $5
			OptListWarn[_flags]	= $6
		}
	}
}

BEGIN {
	FS="\t"
	ENV_PREFIX = "ZELTA_"

	# We need to know the LOG_LEVEL default for -v/-q
	NewOpt["LOG_LEVEL"] = Opt["LOG_LEVEL"]
	load_option_list()
	get_args()
	for (e in NewOpt) {
		# Make sure we're actually changing something
		if (NewOpt[e] != Opt[e]) {
			export = export " " (ENV_PREFIX e) "='" NewOpt[e] "'"
		}
	}
	if (export) print export
}
