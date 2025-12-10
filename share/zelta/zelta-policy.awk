#!/usr/bin/awk -f
#
# zelta policy, zp - iterates through replication commands indicated in a policy file
#
# usage: zelta policy [-flags] [site, host, dataset, dataset_last_element, or source host:dataset] ...
#
# requires: zelta-sync.awk, zelta-match.awk, or a compatible pipe
#
# zelta reads a YAML-style configuration file. The minimal conifguration is:
#
# 	site:
#   	  host:
#   	  - data/set: pool/target
#
# See the example confiuguration for details.
#
# Arguments can be any site, host, dataset, last dataset element, or a host:dataset pair, separated by
# whitespace.
#
# By default, "zelta policy" attempts to replicate from every site, host, and dataset.
# This behavior can be overridden by adding one or more unique item names from the
# configuration file to the argument list. For example, entering a site name will
# replicate all datasets from all hosts of a site. Keep this in mind when reusing
# host or dataset names. For example, "zelta policy zroot" will back up every dataset
# ending in "zroot".
#
# It can also be used to loop through the site/host/dataset objects to run
# other commmands such as other replication tools, logging, replications setup
# functions, or any arbitrary command.

function usage(message) {
	if (message) print message							> STDERR
	print "usage:"									> STDERR
	print "	policy [backup-override-options] [site|host|dataset] ...\n"		> STDERR
	print "See zelta.conf(5) for configuration details.\n"				> STDERR
	print "For further help on a command or topic, run: zelta help [<topic>]"	> STDERR
	exit(1)
}

function resolve_target(src, tgt, host,		_n, _i, _segments) {
	if (tgt) { return tgt }
	tgt = Host["BACKUP_ROOT"]
	if (Host["HOST_PREFIX"] && host) {
		tgt = tgt "/" host
	}
	_n = split(src, _segments, "/")
	for (_i = _n - Host["host_prefix"]; _i <= _n; _i++) {
		if (_segments[_i]) {
			tgt = tgt "/" _segments[_i]
		}
	}
	return tgt
}

function create_backup_command(		_cmd_arr, _i, _src, _tgt) {
	for (_key in Host) {
		# Don't forward 'zelta policy' options
		if (PolicyOptScope[_key]) continue
		else if (Host[_key])
			_cmd_arr[++_i] = ENV_PREFIX _key "=" q(Host[_key])
	}
	# Construct the endpoint strings
	# Switch to use the command_builder
	_src = q((host in LOCALHOST) ? source : (host":"source))
	_tgt = q(datasets[host, source])
	_cmd_arr[++_i] = Host["BACKUP_COMMAND"]
	_cmd_arr[++_i] = _src
	_cmd_arr[++_i] = _tgt
	backup_command[site,host,source] = arr_join(_cmd_arr)
}

function set_var(option_list, var, val) {
	gsub(/-/,"_",var)
	gsub(/^ +/,"",var)
	var = toupper(var)
	if (var in PolicyLegacy) {
		# TO-DO: Legacy warning
		report(LOG_DEBUG, "reassigning option '"var"' to '"PolicyLegacy[var]"'")
		var = PolicyLegacy[var]
	}
	if (!(var in PolicyOpt)) usage("unknown option: "var)
	if (var in Opt) {
		# Var is overriden by envorinment
		report(LOG_DEBUG, "skipping " var "; already in args/user env")
		return
	}
	# TO-DO: Validate type for boolean or number (incr/decr)
	# PolicyOptType
	if ((PolicyOptType[var] == "true") || (PolicyOptType[var] == "false")) {
		if (val in True)
			val = "1"
		else if (val in False)
			val = "0"
	} else if ((PolicyOptType[var] == "incr") || (PolicyOptType[var] == "decr")) {
		if (val !~ /^[0-9]$/) 
			report(LOG_WARNING, "option '" var "' is an integer; '"var"' invalid")
		return
	}
	option_list[var] = val
}

# Use the option list keys to create hierarchical config for the backup policy
function load_option_list(	_tsv, _idx, _flags, _flag_arr) {
	_tsv = Opt["SHARE"]"/zelta-opts.tsv"
	# TO-DO: Complain if TSV doesn't load
	FS="\t"
	while ((getline<_tsv)>0) {
		if (index($1, "policy") || ($1 == "all")) {
			if (!$3) continue
			_key = $3
			PolicyOptScope[_key]	= ($1 == "policy")
			PolicyOpt[_key]		= 1
			PolicyOptType[_key]	= $4
			split($7, _legacy_arr, ",")
			for (_idx in _legacy_arr) PolicyLegacy[_legacy_arr[_idx]] = _key
		}
	}
	close(_tsv)
}

# Differentiate between backup and policy options
function get_global_overrides(		_key) {
	for (_key in Opt)
		if (PolicyOptScope[_key])
			Global[_key]	= Opt[_key]
	# The following are set because they're required for bootstrap,
	# so these are restored after the script starts.
	if (Opt["POLICY_LOG_MODE"])
		Opt["LOG_MODE"]		= Opt["POLICY_LOG_MODE"]
	if (Opt["POLICY_LOG_LEVEL"] != "")
		Opt["LOG_LEVEL"]	= Opt["POLICY_LOG_LEVEL"]
	if (Opt["POLICY_LOG_COMMAND"])
		Opt["LOG_COMMAND"]	= Opt["POLICY_LOG_COMMAND"]
}

function load_config(		_context) {
	FS = "(:?[ \t]+)|(:$)"
	OFS=","
	_conf_error = "configuration parse error at line: "
	BACKUP_COMMAND = "zelta backup"

	#get_options()
	#set_mode()
	_context = "global"
	Global["BACKUP_COMMAND"] = BACKUP_COMMAND

	while ((getline < Opt["CONFIG"])>0) {
		_line_num++

		# Clean up comments:
		if (split($0, arr, "#")) {
			$0 = arr[1]
		}
		gsub(/[ \t]+$/, "", $0)
		if (! $0) { continue }

		# Global options
		if (/^[^ ]+: +[^ ]/) {
			if (!_context == "global") usage(_conf_error _line_num)
			set_var(Global, $1, $2)

		# Sites:
		} else if (/^[^ ]+:$/) {
			_context = "site"
			site = $1
			Sites[site]++
			NumSites++
			arr_copy(Global, site_conf)
		} else if (/^  [^ ]+: +[^ ]/) {
			set_var(site_conf, $2, $3)

		# Hosts:
		} else if (/^  [^ ]+:$/) {
			if (_context == "global") usage(_conf_error _line_num)
			_context = "host"
			host = $2
			Hosts[host] = 1
			HostsBySite[site,host] = 1
			arr_copy(site_conf, Host)
		} else if ($2 == "options") {
			_context = "options"
		} else if ($2 == "datasets") {
			_context = "datasets"
		} else if (/^      [^ ]+: +[^ ]/) {
			if (_context != "options") usage(_conf_error _line_num)
			set_var(Host, $2, $3)
		} else if ((/^  - [^ ]/) || (/^    - [^ ]/)) {
			if (!(_context ~ /^(datasets|host)$/)) usage(_conf_error _line_num)
			source = $3
			target = resolve_target(source, $4, host)
			if (!target) {
				report(LOG_WARNING,"no target defined for " source)
			} else target = resolve_target(source, target, host)

			if (!should_backup(site, host, source, target)) continue
			total_datasets++
			datasets[host, source] = target
			dataset_count[source]++
			Host["LOG_PREFIX"] = host":"source": "
			backup_command[host, source] = create_backup_command()
		} else usage(_conf_error _line_num)
	}
	close(Opt["CONFIG"])
	if (!total_datasets) usage("no datasets defined in " Opt["CONFIG"])
	#for (key in cli_options) Global[key] = cli_options[key]
	FS = "[ \t]+";
}

function sub_keys(key_pair, key1, key2_list, key2_subset) {
	delete key2_subset
	for (key2 in key2_list) {
		if ((key1,key2) in key_pair) {
			key2_subset[key2]++
		}
	}
}

function should_xargs() {
	print NumOperands, Opt["OPERANDS"]
	return ((Global["JOBS"] > 1) && (NumOperands > 1) && (NumSites > 1))
}

# Provided endpoint arguments will filter the backup job to a specific matched keyword 
function get_backup_selection_pattern() {
	# zelta-args.awk needs to be updated to create arg lists for limiting here
	delete LIMIT_PATTERN
	LIMIT_PATTERN[Opt["SRC_ID"]]++
}

# If a parameter is given
function should_backup(site, host, source, target,	_host_source, _target_stub) {
	if (!Opt["SRC_ID"]) return 1
	_host_source = host":"source
	_target_stub = target
	sub(/.*\//,"",_target_stub)
	if (site in LIMIT_PATTERN || host in LIMIT_PATTERN || source in LIMIT_PATTERN)
		return 1
	if (target in LIMIT_PATTERN || host":"source in LIMIT_PATTERN || _target_stub in LIMIT_PATTERN)
		return 1
	return 0
}

function zelta_backup(endpoint_key,		_cmd, _return_code) {
	# Removed explicit output modes: LIST, ACTIVE, DEFAULT, VERBOSE
	# LIST is undocumented
	# ACTIVE creates a simplified indented print style
	#_cmd = backup_command[site,host,source]
	_cmd = backup_command[endpoint_key]
	if (Opt["DRYRUN"]) {
		report(LOG_NOTICE, "+ " _cmd)
		return
	}
	_return_code = system(_cmd)
	close(_cmd)
	# TO-DO: Use error codes to deduce if it seems to be retryable or not.
	return !!_return_code
}

function xargs(		_xargs_cmd, _site, _echo_sites, _return_code) {
	_policy_cmd = "zelta policy"
	_echo_sites = "echo"
	for (_site in Sites) _echo_sites = str_add(_echo_sites, q(_site))
	report(LOG_DEBUG, "launching " Global["JOBS"] " 'zelta policy' jobs")
	_xargs_cmd = _echo_sites " | xargs -n1 -P" Global["JOBS"] " " _policy_cmd
	system(_xargs_cmd)
	return _return_code
}

function backup_loop(		_site, _host, _hosts_arr, _job_status, _endpoint_key, _site_hosts, _num_failed, _failed_arr) {
	for (_site in Sites) {
		sub_keys(HostsBySite, _site, Hosts, _site_hosts)
		for (_host in _site_hosts) {
			sub_keys(datasets, _host, dataset_count, host_datasets)
			for (source in host_datasets) {
				target = datasets[_host,source]
				_endpoint_key = _site SUBSEP _host SUBSEP source
				# The backup job should already be excluded before this point
				if (!should_backup()) continue
				if (zelta_backup(_endpoint_key)) {
					_num_failed++
					_failed_arr[_endpoint_key] = _host ":" source
				}
			}
		}
	}
	while ((Global["RETRY"]-- > 0) && _num_failed) {
		for (_endpoint_key in _failed_arr) {
			report(LOG_WARNING, "retrying: " _failed_arr[_endpoint_key])
			if (zelta_backup(_endpoint_key))
				delete _failed_arr[_endpoint_key]
		}
	}
}

BEGIN {
	STDERR = "/dev/stderr"
	load_option_list()
	get_global_overrides()
	get_backup_selection_pattern()
	load_config()
	if (should_xargs()) xargs()
	else backup_loop()
	stop(0)
}
