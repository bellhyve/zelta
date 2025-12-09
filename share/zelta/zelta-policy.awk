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

# TO-DO: Move this to zelta-common.awk
function log_buffer(level, message) {
	if ((level <= LOG_NOTICE) || (MODE == "VERBOSE")) {
		if (message == "") {
			printf buffer_delay
			buffer_delay = ""
		} else { buffer_delay = buffer_delay message }
	} else {
		report(level, message)
	}
}

function resolve_target(src, tgt) {
	if (tgt) { return tgt }
	tgt = host_conf["BACKUP_ROOT"]
	if (host_conf["HOST_PREFIX"] && host) {
		tgt = tgt "/" host
	}
	n = split(src, segments, "/")
	for (i = n - host_conf["host_prefix"]; i <= n; i++) {
		if (segments[i]) {
			tgt = tgt "/" segments[i]
		}
	}
	return (host_conf["push_to"] ? host_conf["push_to"] ":" : "") tgt
}

function create_backup_command(		_cmd_arr, _i, _src, _tgt) {
	for (_key in host_conf) {
		print _key, host_conf[_key]
		if (host_conf[_key])
			_cmd_arr[++_i] = ENV_PREFIX _key "=" q(host_conf[_key])
	}
	# Construct the endpoint strings
	_src = q((host in LOCALHOST) ? source : (host":"source))
	_tgt = q(datasets[host, source])
	_cmd_arr[++_i] = host_conf["backup_command"]
	_cmd_arr[++_i] = _src
	_cmd_arr[++_i] = _tgt
	# Do we ever pass flags directly? Probably not with zelta-args.awk
	#backup_command[site,host,source] = host_conf["backup_command"] " " flags " " cmd_src " " cmd_tgt
	backup_command[site,host,source] = arr_join(_cmd_arr)
	print backup_command[site,host,source]
}

# Removed because of zelta-args.awk
#function var_name(var) {
#	gsub(/-/,"_",var)
#	return tolower(var)
#}
#
#function long_option() {
#	if ($0 in OPTIONS_BOOLEAN) cli_options[var_name($0)]++
#	else {
#		split($0, opt_pair, "=")
#		opt_name = var_name(opt_pair[1])
#		opt_val = opt_pair[2]
#		if (opt_name in OPTIONS) {
#			if (!(opt_val ~ /./)) opt_val = ARGV[++i]
#			cli_options[opt_name] = opt_val
#			PASS_FLAGS = PASS_FLAGS "=" opt_val
#		} else usage("unknown option: " opt_name)
#	}
#	$0 = ""
#}

#function get_options() {
#	# Policy Options
#	OPTIONS["archive_root"]++
#	OPTIONS["backup_root"]++
#	OPTIONS["depth"]++
#	OPTIONS["host_prefix"]++
#	OPTIONS["initiator"]++
#	OPTIONS["intermediate"]++
#	OPTIONS["output_mode"]++
#	OPTIONS["prefix"]++
#	OPTIONS["push_to"]++
#	OPTIONS["replicate"]++
#	OPTIONS["retry"]++
#	OPTIONS["snapshot"]++
#	OPTIONS["threads"]++
#	OPTIONS_BOOLEAN["list"]++
#	OPTIONS_BOOLEAN["dry-run"]++
#	OPTIONS_BOOLEAN["json"]++
#	OPTIONS_BOOLEAN["quiet"]++
#	OPTIONS_BOOLEAN["verbose"]++
#
#	AUTO = 1
#	for (i=1;i<ARGC;i++) {
#		$0 = ARGV[i]
#		if (gsub(/^-/,"")) {
#			PASS_FLAGS = PASS_FLAGS (PASS_FLAGS ? " " ARGV[i] : ARGV[i])
#			while (/./) {
#				if (sub(/^-/,"")) long_option()
#				# Deprecate after adding long options to zelta replicate
#				else if (sub(/^[h?]/,"")) usage()
#				else if (sub(/^j/,"")) cli_options["output_mode"] = "JSON"
#				else if (sub(/^q/,"")) cli_options["output_mode"] = "QUIET"
#				else if (sub(/^n/,"")) cli_options["output_mode"] = "DRY_RUN"
#				else if (sub(/^v/,"")) cli_options["output_mode"] = "VERBOSE"
#				else if (sub(/^z/,"")) cli_options["output_mode"] = "DEFAULT"
#				else usage("unknown option: " $0)
#			}
#		} else {
#			AUTO = 0
#			LIMIT_PATTERN[$0]++
#		}
#	}
#}

# Removed because of centralized logging
#function set_mode() {
#	if (cli_options["output_mode"]) MODE = toupper(cli_options["output_mode"])
#	else if (cli_options["list"]) MODE = "LIST"
#	else if (cli_options["json"]) MODE = "JSON"
#	else if (cli_options["quiet"]) MODE = "QUIET"
#	else if (cli_options["dry_run"]) MODE = "DRY_RUN"
#	else if (cli_options["verbose"]) MODE = "VERBOSE"
#	else if (AUTO) MODE = "ACTIVE"
#	else MODE = "DEFAULT"
#	if (MODE == "JSON") MODE_FLAGS = "j"
#	else if (MODE == "VERBOSE") MODE_FLAGS = "v"
#	else if (MODE == "QUIET") MODE_FLAGS = "q"
#	#else MODE_FLAGS = "z"
#	else MODE_FLAGS = "v"
#}

function copy_array(src, tgt) {
	delete tgt
	for (key in src) tgt[key] = src[key]
	for (key in cli_options) tgt[key] = cli_options[key]
}

function set_var(option_list, var, val) {
	gsub(/-/,"_",var)
	gsub(/^ +/,"",var)
	var = toupper(var)
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

# Use the same option list as args, but just load the keys and legacy synonyms
function load_option_list(	_tsv, _idx, _flags, _flag_arr) {
	_tsv = Opt["SHARE"]"/zelta-opts.tsv"
	# TO-DO: Complain if TSV doesn't load
	FS="\t"
	while ((getline<_tsv)>0) {
		if (index($1, "policy") || ($1 == "all")) {
			if (!$3) continue
			_key = $3
			PolicyOpt[_key]		= 1
			PolicyOptType[_key]	= $4
			split($7, _legacy_arr, ",")
			for (_idx in _legacy_arr) PolicyLegacy[_flag_arr[_idx]] = _flags
		}
	}
	close(_tsv)
}

function load_config(		_context) {
	FS = "(:?[ \t]+)|(:$)"
	OFS=","
	CONF_ERR = "configuration parse error at line: "
	POLICY_COMMAND = "zelta policy"
	BACKUP_COMMAND = "zelta backup"

	#get_options()
	#set_mode()
	_context = "global"
	ConfGlobal["backup_command"] = BACKUP_COMMAND

	while ((getline < Opt["CONFIG"])>0) {
		CONF_LINE++

		# Clean up comments:
		if (split($0, arr, "#")) {
			$0 = arr[1]
		}
		gsub(/[ \t]+$/, "", $0)
		if (! $0) { continue }

		# Global options
		if (/^[^ ]+: +[^ ]/) {
			if (!_context == "global") usage(CONF_ERR CONF_LINE)
			set_var(ConfGlobal, $1, $2)

		# Sites:
		} else if (/^[^ ]+:$/) {
			_context = "site"
			site = $1
			sites[site]++
			copy_array(ConfGlobal, site_conf)
		} else if (/^  [^ ]+: +[^ ]/) {
			set_var(site_conf, $2, $3)

		# Hosts:
		} else if (/^  [^ ]+:$/) {
			if (_context == "global") usage(CONF_ERR CONF_LINE)
			_context = "host"
			host = $2
			hosts[host] = 1
			hosts_by_site[site,host] = 1
			copy_array(site_conf, host_conf)
		} else if ($2 == "options") {
			_context = "options"
		} else if ($2 == "datasets") {
			_context = "datasets"
		} else if (/^      [^ ]+: +[^ ]/) {
			if (_context != "options") usage(CONF_ERR CONF_LINE)
			set_var(host_conf, $2, $3)
		} else if ((/^  - [^ ]/) || (/^    - [^ ]/)) {
			if (!(_context ~ /^(datasets|host)$/)) usage(CONF_ERR CONF_LINE)
			source = $3
			target = resolve_target(source, $4)
			if (!target) {
				log_buffer(LOG_WARNING,"no target defined for " source)
			} else target = resolve_target(source, target)
			if (!should_backup()) continue
			total_datasets++
			datasets[host, source] = target
			dataset_count[source]++
			backup_command[host, source] = create_backup_command()
		} else usage(CONF_ERR CONF_LINE)
	}
	close(Opt["CONFIG"])
	if (!total_datasets) usage("no datasets defined in " Opt["CONFIG"])
	for (key in cli_options) ConfGlobal[key] = cli_options[key]
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

# Provided endpoint arguments will filter the backup job to a specific matched keyword 
function get_backup_selection_pattern() {
	# zelta-args.awk needs to be updated to create arg lists for limiting here
	delete LIMIT_PATTERN
	LIMIT_PATTERN[Opt["SRC_ID"]]++
	LIMIT_PATTERN[Opt["TGT_ID"]]++
}

function should_backup() {
	# AUTO means backup everything (I think); we'll check for a parameter instead
	#if (AUTO) return 1
	
	# If no endpoint arguments were given, accept any backup job
	# See get_backup_selection_pattern() above, this should be broader
	if (!Opt["SRC_ID"]) return 1
	
	target_stub = target
	sub(/.*\//,"",target_stub)
	if (site in LIMIT_PATTERN || host in LIMIT_PATTERN || source in LIMIT_PATTERN ||target in LIMIT_PATTERN || host":"source in LIMIT_PATTERN || target_stub in LIMIT_PATTERN) {
		return 1
	} else { return 0 }
}

function zelta_backup() {
	sync_cmd = backup_command[site,host,source]
	sync_status = 1
	if (MODE == "LIST") {
		print host":"source
		return 1
	} else if (MODE == "DRY_RUN") {
		print "+ " sync_cmd
		return 1
	} else if (MODE == "ACTIVE") log_buffer(LOG_NOTICE, source": ")
	else if ((MODE == "DEFAULT") || (MODE == "VERBOSE")) log_buffer(LOG_NOTICE, host":"source": ")
	while (sync_cmd|getline) {
		# Provide a one-line sync summary
		# received_streams, total_bytes, time, error
		if (/[0-9]+ [0-9]+ [0-9]+\.*[0-9]* -?[0-9]+/) {
			if ($2) log_buffer(LOG_NOTICE, h_num($2) ": ")
			if ($4) {
				#log_buffer(LOG_NOTICE, "failed: ")
				sync_status = 0
				if ($4 == 1) log_buffer(LOG_NOTICE, "error matching snapshots")
				else if ($4 == 2) log_buffer(LOG_NOTICE, "replication error")
				else if ($4 == 3) log_buffer(LOG_NOTICE, "target is ahead of source")
				else if ($4 == 4) log_buffer(LOG_NOTICE, "error creating parent dataset")
				else if ($4 == 5) log_buffer(LOG_NOTICE, "match error")
				else if ($4 < 0) log_buffer(LOG_NOTICE, (0-$4) " missing streams")
				else log_buffer(LOG_NOTICE, "error: " $0)
			} else if ($1) { log_buffer(LOG_NOTICE, "replicated in " $3 "s") }
			else log_buffer(LOG_NOTICE, "up-to-date")
		} else {
			log_buffer(LOG_NOTICE, $0)
			if (/replicationErrorCode/ && !/0,/) sync_status = 0
		}
		log_buffer(LOG_NOTICE, "\n")
	}
	log_buffer(LOG_NOTICE, "")
	close(sync_cmd)
	return sync_status
}

function xargs() {
	for (site in sites) site_list = site_list " "site
	xargs_command = "echo" site_list " | xargs -n1 -P" ConfGlobal["threads"] " " POLICY_COMMAND " " PASS_FLAGS
	while (xargs_command | getline) { print }
	close(xargs_command)
	exit 0
}

BEGIN {
	STDERR = "/dev/stderr"
	load_option_list()
	load_config()
	if (AUTO && (ConfGlobal["threads"] > 1)) xargs()
	for (site in sites) {
		if (MODE == "ACTIVE") log_buffer(LOG_NOTICE, site "\n")
		sub_keys(hosts_by_site, site, hosts, site_hosts)
		for (host in site_hosts) {
			if (MODE == "ACTIVE") log_buffer(LOG_NOTICE, "  " host "\n")
			sub_keys(datasets, host, dataset_count, host_datasets)
			for (source in host_datasets) {
				target = datasets[host,source]
				# The backup job should already be excluded before this point
				if (!AUTO && !should_backup()) continue
				if (MODE == "ACTIVE") log_buffer(LOG_NOTICE,"    ")
				if (! zelta_backup()) {
					failed_num++
					failed_list[site"\t"host"\t"source"\t"target]++
				}
			}
		}
	}
	while ((ConfGlobal["retry"]-- > 0) && failed_num) {
		for (failed_sync in failed_list) {
			$0 = failed_sync
			site = $1; host = $2; source = $3; target = $4
			if (MODE != "JSON") log_buffer(LOG_NOTICE, "retry: " )
			if (zelta_backup()) {
				delete failed_list[failed_sync]
			}
		}
	}
}
