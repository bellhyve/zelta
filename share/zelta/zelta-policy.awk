#!/usr/bin/awk -f
#
# zelta policy, zp - iterates through "zelta" commands
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

function report(level, message) {
	if (level <= LOG_WARNING) {
		print "error: " message > STDERR
		if (level <= LOG_ERROR) exit 1
	} else if ((level <= LOG_DEFAULT ) && (MODE == "ACTIVE")) { printf message }
	else if ((level <= LOG_DEFAULT) || (MODE == "VERBOSE")) {
		if (message == "") {
			printf buffer_delay
			buffer_delay = ""
		} else { buffer_delay = buffer_delay message }
	}
}

function usage(message) {
	usage_command = "zelta usage policy"
	while (usage_command |getline) print
	report(LOG_ERROR, message)
}

function env(env_name, var_default) {
	return ( (env_name in ENVIRON) ? ENVIRON[env_name] : var_default )
}

function get_hostname() {
	hostname = ENVIRON["HOST"] ? ENVIRON["HOST"] : ENVIRON["HOSTNAME"]
	if (!hostname) {
		"hostname" | getline hostname; close("hostname")
	}
	if (hostname) LOCALHOST[hostname]++
	LOCALHOST["localhost"]++
}

function resolve_target(src, tgt) {
	if (tgt) { return tgt }
	tgt = host_conf["backup_root"]
	if (host_conf["host_prefix"] && host) {
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

function create_backup_command() {
	flags = "-" MODE_FLAGS
	#flags = flags (host_conf["dry_run"] ? "n" : "")
	flags = flags ((host_conf["intermediate"]=="0") ? "i" : "I")
	flags = flags (host_conf["replicate"] ? "R" : "")
	snap_flags = host_conf["snapshot"]
	if ((snap_flags == "0") || (snap_flags=="OFF")) { }
	else if (snap_flags=="ALL") flags = flags "S"
	else if (snap_flags=="SKIP") flags = flags "ss"
	else flags = flags "s"
	flags = flags (host_conf["depth"] ? " -d" host_conf["depth"] : "")
	cmd_src = q((host in LOCALHOST) ? source : (host":"source))
	cmd_tgt = q(datasets[host, source])
	backup_command[site,host,source] = host_conf["backup_command"] " " flags " " cmd_src " " cmd_tgt
}

function var_name(var) {
	gsub(/-/,"_",var)
	return tolower(var)
}

function long_option() {
	if ($0 in OPTIONS_BOOLEAN) cli_options[var_name($0)]++
	else {
		split($0, opt_pair, "=")
		opt_name = var_name(opt_pair[1])
		opt_val = opt_pair[2]
		if (opt_name in OPTIONS) {
			if (!(opt_val ~ /./)) opt_val = ARGV[++i]
			cli_options[opt_name] = opt_val
			PASS_FLAGS = PASS_FLAGS "=" opt_val
		} else usage("unknown option: " opt_name)
	}
	$0 = ""
}

function get_options() {
	# Possible Options
	OPTIONS["archive_root"]++
	OPTIONS["backup_root"]++
	OPTIONS["host_prefix"]++
	OPTIONS["initiator"]++
	OPTIONS["intermediate"]++
	OPTIONS["output_mode"]++
	OPTIONS["prefix"]++
	OPTIONS["push_to"]++
	OPTIONS["replicate"]++
	OPTIONS["retry"]++
	OPTIONS["snapshot"]++
	OPTIONS["threads"]++
	OPTIONS_BOOLEAN["list"]++
	OPTIONS_BOOLEAN["dry-run"]++
	OPTIONS_BOOLEAN["json"]++
	OPTIONS_BOOLEAN["quiet"]++
	OPTIONS_BOOLEAN["verbose"]++

	AUTO = 1
	for (i=1;i<ARGC;i++) {
		$0 = ARGV[i]
		if (gsub(/^-/,"")) {
			PASS_FLAGS = PASS_FLAGS (PASS_FLAGS ? " " ARGV[i] : ARGV[i])
			while (/./) {
				if (sub(/^-/,"")) long_option()
				# Deprecate after adding long options to zelta replicate
				else if (sub(/^j/,"")) cli_options["output_mode"] = "JSON"
				else if (sub(/^q/,"")) cli_options["output_mode"] = "QUIET"
				else if (sub(/^n/,"")) cli_options["output_mode"] = "DRY_RUN"
				else if (sub(/^v/,"")) cli_options["output_mode"] = "VERBOSE"
				else if (sub(/^z/,"")) cli_options["output_mode"] = "DEFAULT"
				else usage("unknown option: " $0)
			}
		} else {
			AUTO = 0
			LIMIT_PATTERN[$0]++
		}
	}
}

function set_mode() {
	if (cli_options["output_mode"]) MODE = toupper(cli_options["output_mode"])
	else if (cli_options["list"]) MODE = "LIST"
	else if (cli_options["json"]) MODE = "JSON"
	else if (cli_options["quiet"]) MODE = "QUIET"
	else if (cli_options["dry_run"]) MODE = "DRY_RUN"
	else if (cli_options["verbose"]) MODE = "VERBOSE"
	else if (AUTO) MODE = "ACTIVE"
	else MODE = "DEFAULT"
	if (MODE == "JSON") MODE_FLAGS = "j"
	else if (MODE == "VERBOSE") MODE_FLAGS = "v"
	else if (MODE == "QUIET") MODE_FLAGS = "q"
	else MODE_FLAGS = "z"
}

function copy_array(src, tgt) {
	delete tgt
	for (key in src) tgt[key] = src[key]
	for (key in cli_options) tgt[key] = cli_options[key]
}

function set_var(option_list, var, val) {
	gsub(/-/,"_",var)
	gsub(/^ +/,"",var)
	var = tolower(var)
	if (!(var in OPTIONS)) usage("unknown policy option: "var)
	option_list[var] = val
}

function load_config() {
	FS = "(:?[ \t]+)|(:$)"
	OFS=","
	CONF_ERR = "configuration parse error at line: "
	POLICY_COMMAND = "zelta policy"
	BACKUP_COMMAND = "zelta replicate"

	get_options()
	set_mode()
	conf_context = "global"
	global_conf["backup_command"] = BACKUP_COMMAND

	while ((getline < ZELTA_CONFIG)>0) {
		CONF_LINE++

		# Clean up comments:
		if (split($0, arr, "#")) {
			$0 = arr[1]
		}
		gsub(/[ \t]+$/, "", $0)
		if (! $0) { continue }

		# Global options
		if (/^[^ ]+: +[^ ]/) {
			if (!conf_context == "global") usage(CONF_ERR CONF_LINE)
			set_var(global_conf, $1, $2)

		# Sites:
		} else if (/^[^ ]+:$/) {
			conf_context = "site"
			site = $1
			sites[site]++
			copy_array(global_conf, site_conf)
		} else if (/^  [^ ]+: +[^ ]/) {
			set_var(site_conf, $2, $3)

		# Hosts:
		} else if (/^  [^ ]+:$/) {
			if (conf_context == "global") usage(CONF_ERR CONF_LINE)
			conf_context = "host"
			host = $2
			hosts[host] = 1
			hosts_by_site[site,host] = 1
			copy_array(site_conf, host_conf)
		} else if ($2 == "options") {
			conf_context = "options"
		} else if ($2 == "datasets") {
			conf_context = "datasets"
		} else if (/^      [^ ]+: +[^ ]/) {
			if (conf_context != "options") usage(CONF_ERR CONF_LINE)
			set_var(host_conf, $2, $3)
		} else if ((/^  - [^ ]/) || (/^    - [^ ]/)) {
			if (!(conf_context ~ /^(datasets|host)$/)) usage(CONF_ERR CONF_LINE)
			source = $3
			target = resolve_target(source, $4)
			if (!target) {
				report(LOG_WARNING,"no target defined for " source)
			} else target = resolve_target(source, target)
			if (!should_replicate()) continue
			total_datasets++
			datasets[host, source] = target
			dataset_count[source]++
			backup_command[host, source] = create_backup_command()
		} else usage(CONF_ERR CONF_LINE)
	}
	close(ZELTA_CONFIG)
	if (!total_datasets) usage("no datasets defined in " ZELTA_CONFIG)
	for (key in cli_options) global_conf[key] = cli_options[key]
	FS = "[ \t]+";
	LOG_ERROR = -2
	LOG_WARNING = -1
	LOG_DEFAULT = 0
	LOG_VERBOSE = 1
}

function sub_keys(key_pair, key1, key2_list, key2_subset) {
	delete key2_subset
	for (key2 in key2_list) {
		#if (key_pair[key1, key2]) {
		if ((key1,key2) in key_pair) {
			key2_subset[key2]++
		}
	}
}

function should_replicate() {
	if (AUTO) return 1
	target_stub = target
	sub(/.*\//,"",target_stub)
	if (site in LIMIT_PATTERN || host in LIMIT_PATTERN || source in LIMIT_PATTERN ||target in LIMIT_PATTERN || host":"source in LIMIT_PATTERN || target_stub in LIMIT_PATTERN) {
		return 1
	} else { return 0 }
}

function q(s) { return "'" s "'" }

function h_num(num) {
	suffix = "B"
	divisors = "KMGTPE"
	for (i = 1; i <= length(divisors) && num >= 1024; i++) {
		num /= 1024
		suffix = substr(divisors, i, 1)
	}
	return int(num) suffix
}

function zelta_sync() {
	sync_cmd = backup_command[site,host,source]
	sync_status = 1
	if (MODE == "LIST") {
		print host":"source
		return 1
	} else if (MODE == "DRY_RUN") {
		print "+ " sync_cmd
		return 1
	} else if (MODE == "ACTIVE") report(LOG_DEFAULT, source": ")
	else if ((MODE == "DEFAULT") || (MODE == "VERBOSE")) report(LOG_DEFAULT, host":"source": ")
	while (sync_cmd|getline) {
		# Provide a one-line sync summary
		# received_streams, total_bytes, time, error
		if (/[0-9]+ [0-9]+ [0-9]+\.*[0-9]* -?[0-9]+/) {
			if ($2) report(LOG_DEFAULT, h_num($2) ": ")
			if ($4) {
				report(LOG_DEFAULT, "failed: ")
				sync_status = 0
				if ($4 == 1) report(LOG_DEFAULT, "error matching snapshots")
				else if ($4 == 2) report(LOG_DEFAULT, "replication error")
				else if ($4 == 3) report(LOG_DEFAULT, "target is ahead of source")
				else if ($4 == 4) report(LOG_DEFAULT, "error creating parent dataset")
				else if ($4 == 5) report(LOG_DEFAULT, "match error")
				else if ($4 < 0) report(LOG_DEFAULT, (0-$4) " missing streams")
				else report(LOG_DEFAULT, "error: " $0)
			} else if ($1) { report(LOG_DEFAULT, "replicated in " $3 "s") }
			else report(LOG_DEFAULT, "up-to-date")
		} else {
			report(LOG_DEFAULT, $0)
			if (/replicationErrorCode/ && !/0,/) sync_status = 0
		}
		report(LOG_DEFAULT, "\n")
	}
	report(LOG_DEFAULT, "")
	close(sync_cmd)
	return sync_status
}

function xargs() {
	for (site in sites) site_list = site_list " "site
	xargs_command = "echo" site_list " | xargs -n1 -P" global_conf["threads"] " " POLICY_COMMAND " " PASS_FLAGS
	while (xargs_command | getline) { print }
	close(xargs_command)
	exit 0
}

BEGIN {
	ZELTA_CONFIG = env("ZELTA_CONFIG", "/usr/local/etc/zelta/zelta.conf")
	STDERR = "/dev/stderr"
	get_hostname()
	load_config()
	if (AUTO && (global_conf["threads"] > 1)) xargs()
	for (site in sites) {
		if (MODE == "ACTIVE") report(LOG_DEFAULT, site "\n")
		sub_keys(hosts_by_site, site, hosts, site_hosts)
		for (host in site_hosts) {
			if (MODE == "ACTIVE") report(LOG_DEFAULT, "  " host "\n")
			sub_keys(datasets, host, dataset_count, host_datasets)
			for (source in host_datasets) {
				target = datasets[host,source]
				if (!AUTO && !should_replicate()) continue
				if (MODE == "ACTIVE") report(LOG_DEFAULT,"    ")
				if (! zelta_sync()) {
					failed_num++
					failed_list[site"\t"host"\t"source"\t"target]++
				}
			}
		}
	}
	while ((global_conf["retry"]-- > 0) && failed_num) {
		for (failed_sync in failed_list) {
			$0 = failed_sync
			site = $1; host = $2; source = $3; target = $4
			if (MODE != "JSON") report(LOG_DEFAULT, "retrying: " $host ":" $source ": ")
			if (zelta_sync()) {
				delete failed_list[failed_sync]
			}
		}
	}
}
