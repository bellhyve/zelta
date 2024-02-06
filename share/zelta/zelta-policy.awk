#!/usr/bin/awk -f
#
# zelta policy, zp - iterates through "zelta" commands
#
# usage: zelta policy [site, host, dataset, or source host:dataset] ...
#
# requires: zelta-sync.awk, zelta-match.awk
#
# zelta reads a YAML-style configuration file. The minimal
# conifguration is:
#
# 	BACKUP_ROOT: backup/parent
# 	site:
#   	  host:
#   	  - data/set:
#
# See the example confiuguration for details.
#
# Arguments can be any site, host, dataset, or a host:dataset pair, separated by
# spaces.
#
# By default, "zelta policy" attempts to replicate from every site, host, and dataset.
# This behavior can be overridden by adding one or more unique item names from the
# configuration file to the argument list. For example, entering a site name will
# replicate all datasets from all hosts of a site. Keep this in mind when reusing
# host or dataset names.

function report(mode, message) {
	if (LOG_WARNING == mode) { print "error: " message | STDOUT }
	else if (LOG_ACTIVE == LOG_MODE) { printf message }
	else if ((LOG_DELAY == mode) && ((LOG_MODE == LOG_DELAY))) {
		if (message == "") {
			printf buffer_delay
			buffer_delay = ""
		} else { buffer_delay = buffer_delay message }
	}
}

function usage(message) {
	usage_command = "zelta usage policy"
	while (usage_command |getline) print
	close(usage_command)
	report(LOG_WARNING, message)
	exit 1
}

function env(env_name, var_default) {
	return ( (env_name in ENVIRON) ? ENVIRON[env_name] : var_default )
}

function resolve_target(source, target) {
	if (target) { return target}
	target = c["BACKUP_ROOT"]
	if (c["HOST_PREFIX"] && current_host) {
		target = target "/" current_host
	}
	n = split(source, segments, "/")
	for (i = n - c["PREFIX"]; i <= n; i++) {
		if (segments[i]) {
			target = target "/" segments[i]
		}
	}
	return (c["PUSH_TO"] ? c["PUSH_TO"] ":" : "") target
}

function load_config() {
	FS = "(:?[ \t]+)|(:$)"
	OFS=","
	while ((getline < ZELTA_CONFIG)>0) {
		if (split($0, arr, "#")) {
			$0 = arr[1]
		}
		gsub(/[ \t]+$/, "", $0)
		if (! $0) { continue }
		if (/^[^ ]+: +[^ ]/) {
			c[$1] = $2
		} else if (/^[^ ]+:$/) {
			current_site = $1
			sites[current_site]++
		} else if (/^  [^ ]+:$/) {
			current_host = $2
			hosts[current_host] = 1
			hosts_by_site[current_site,current_host] = 1
		} else if (/^  - [^ ]/) {
			source_dataset = $3
			target_dataset = resolve_target(source_dataset, $4)
			if (!target_dataset) {
				report(LOG_WARNING,"no target defined for " source_dataset)
			}
			datasets[current_host, source_dataset] = resolve_target(source_dataset, target_dataset)
			dataset_count[source_dataset]++
		} else {
			print "can't parse: " $0
			continue
		}
	}
	if (length(datasets)==0) usage("no datasets defined in " ZELTA_CONFIG)
	FS = "[ \t]+";
	# Fix: Handle LOG_JSON
	LOG_ACTIVE = 1; LOG_DELAY = 2; LOG_WARNING = 3
	LOG_MODE = LOG_DELAY
	ZELTA_COMMAND = "zelta policy"
	SYNC_LOG_MODE = c["JSON"] ? "j" : "z"
	for (i = 1; i < ARGC; i++) {
		if (gsub(/^-/,"",ARGV[i])) {
			SYNC_LOG_MODE = ARGV[i]
			ZELTA_COMMAND = ZELTA_COMMAND " -"SYNC_LOG_MODE
		} else ARGS[ARGV[i]]++
	}
	if (length(ARGS) == 0) {
		AUTO++
		if (SYNC_LOG_MODE == "z") LOG_MODE = LOG_ACTIVE
	}
	if (SYNC_LOG_MODE == "j") c["JSON"] = 1

	SNAPSHOT = c["SNAPSHOT"]
	if ((SNAPSHOT == "0") || (SNAPSHOT=="OFF")) SNAPSHOT = ""
	else if (SNAPSHOT=="ALL") SNAPSHOT = "S"
	else if (SNAPSHOT=="SKIP") SNAPSHOT = "ss"
	else SNAPSHOT = "s"

	REPLICATE = c["REPLICATE"] ? "R" : ""
	INTERMEDIATE = c["INTERMEDIATE"] ? "I" : ""
	DRY_RUN = c["DRY_RUN"] ? "n" : ""
	DEPTH = c["DEPTH"]? " -d"c["DEPTH"] : ""
	SYNC_FLAGS = " -" SYNC_LOG_MODE SNAPSHOT REPLICATE INTERMEDIATE DRY_RUN DEPTH " "
	ZELTA_SYNC = "zelta replicate" SYNC_FLAGS
}

function sub_keys(key_pair, key1, key2_list, key2_subset) {
	delete key2_subset
	for (key2 in key2_list) {
		if (key_pair[key1, key2]) {
			key2_subset[key2]++
		}
	}
}

function should_replicate() {
	if (site in ARGS || host in ARGS || source in ARGS || target in ARGS || host":"source in ARGS) {
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

function zelta_sync(host, source, target) {
	cmd_src = q((host in LOCALHOST) ? source : (host":"source))
	cmd_tgt = q(target)
	sync_cmd = ZELTA_SYNC cmd_src " " cmd_tgt
	sync_status = 1
	# Only print host:source explicitly in non-interactive interactive
	if ((LOG_MODE == LOG_DELAY) && !c["JSON"]) report(LOG_DELAY, host":"source": ")
	report(LOG_ACTIVE, source": ")
	while (sync_cmd|getline) {
		# received_streams, total_bytes, time, error
		if (/[0-9]+ [0-9]+ [0-9]+\.*[0-9]* -?[0-9]+/) {
			if ($2) report(LOG_DELAY, h_num($2) ": ")
			if ($4) {
				report(LOG_DELAY, "failed: ")
				sync_status = 0
				if ($4 == 1) report(LOG_DELAY, "error matching snapshots")
				else if ($4 == 2) report(LOG_DELAY, "replication error")
				else if ($4 == 3) report(LOG_DELAY, "target is ahead of source")
				else if ($4 == 4) report(LOG_DELAY, "error creating parent volume")
				else if ($4 < 0) report(LOG_DELAY, (0-$4) " missing streams")
				else report(LOG_DELAY, "error: " $0)
			} else if ($1) { report(LOG_DELAY, "replicated in " $3 "s") }
			else report(LOG_DELAY, "nothing to replicate")
		} else {
			report(LOG_DELAY, $0)
			if (/replicationErrorCode/ && !/0,/) sync_status = 0
		}
		report(LOG_DELAY, "\n")
	}
	report(LOG_DELAY, "")
	close(sync_cmd)
	return sync_status
}

function xargs() {
	for (site in sites) site_list = site_list " "site
	xargs_command = "echo" site_list " | xargs -n1 -P" c["THREADS"] " " ZELTA_COMMAND
	while (xargs_command | getline) { print; }
	exit 0
}

BEGIN {
	ZELTA_CONFIG = env("ZELTA_CONFIG", "/usr/local/etc/zelta/zelta.conf")
	LOCALHOST["localhost"]++  # Consider addding other local hostnames
	STDOUT = "cat 1>&2"
	c["INTERMEDIATE"] = 1
	c["SNAPSHOT"] = 1
	load_config()
	if (AUTO && (c["THREADS"] > 1)) xargs()
	for (site in sites) {
		report(LOG_ACTIVE, site "\n")
		sub_keys(hosts_by_site, site, hosts, site_hosts)
		for (host in site_hosts) {
			report(LOG_ACTIVE, "  " host "\n")
			sub_keys(datasets, host, dataset_count, host_datasets)
			for (source in host_datasets) {
				target = datasets[host,source]
				if (!AUTO && !should_replicate()) continue
				report(LOG_ACTIVE,"    ")
				if (! zelta_sync(host, source, target)) {
					failed_list[host"\t"source"\t"target]++
				}
			}
		}
	}
	while (c["RETRY"]-- > 0) {
		for (failed_sync in failed_list) {
			$0 = failed_sync
			if (!c["JSON"]) report(LOG_DELAY, "retrying: " $1 ":")
			if (zelta_sync($1, $2, $3)) {
				delete failed_list[failed_sync]
			}
		}
	}
}
