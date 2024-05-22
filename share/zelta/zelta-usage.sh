#!/bin/sh

usage_top() {
cat << EOF
usage: zelta command args ...
where 'command' is one of the following:

	version

	match [-Hp] [-d max] [-o field[,...]] source-endpoint target-endpoint

	<backup|sync> [zfs send/receive options] [-iIjnpqRtTv]
	              [initiator] source-endpoint target-endpoint

	sync [zfs send/receive options] [-iIjnpqRtTv] [initiator]
	     source-endpoint target-endpoint

	clone [-d max] source-endpoint target-endpoint

	policy [backup-override-options] [site|host|dataset] ...

Each dataset is of the form: pool/[dataset/]*dataset[@name]

Each endpoint is of the form: [user@][host:]dataset

For further help on a command or topic, run: zelta help [<topic>]
EOF
}

usage_sync () {
	cat << EOF
DESCRIPTION
    zelta replicate [-jqvcnpRSsTtIiMu] [-d#] [-L#] [initiator.host] source-endpoint target-endpoint
      Recursively replicate as many snapshots as possible from the source to the target.
    zelta backup [-jqvcnpRSsTtIiMu] [-d#] [-L#] [initiator.host] source-endpoint target-endpoint
      Equivalent to "zelta replicate -S": Snapshot then recursively replicate as many snapshots as
      possible from the source to the target.
    zelta sync [-jqvcnpRSsTtIiMu] [-d#] [-L#] [initiator.host] source-endpoint target-endpoint
      Equivalent to "zelta replicate -i": Recursively replicate the latest snapshots only.
    zelta clone [-jqvcnpRSsTtIiMu] [-d#] [-L#] [initiator.host] dataset[@snapshot] dataset
      Equivalent to "zelta replicate -c": Recursively clone a dataset to a target on the local pool.

ENDPOINT SYNTAX
    initiator.host  [user@]hostname
      If an initiator host is given, run all commands there instead of locally (zelta required.
    source-endpoint  [user@][host:]pool/dataset[@snapshot]
    target-endpoint  [user@][host:]pool/dataset

OUTPUT OPTIONS
      -j  Produce JSON output only.
      -n  Dry-run; print the zfs commands instead of running replication commands.
      -q  Limit output to errors only.
      -v  Produce more verbose output. Use "-vv" to prevent all buffering.
      -z  Abbreviate output for single line "zelta policy" logging.

MISC OPTIONS
      -c  Clone instead of replicate; default for "zelta clone".
      -L#  Pass -L to a "pv" pipe (pv must be installed). 
      -p  Pipe the "zfs send" output through "dd status=progress" or "pv" if installed.
      -S  Snapshot before performing the replication/clone task; default for "zelta backup".
      -s  Snapshot only if written; "-ss" to quit if no snapshot is needed.
      -T  Run all commands from the source host.
      -t  Run all commands from the target host.
      -M  No default "zfs receive" flags (replicate read-write with mountpoints).

ZFS SEND FLAGS
      -R  Use "zfs send -R"; useful with "-d1".
      -I  Replicate as many snapshots as possible; default for "zelta backup".
      -i  Replicate only the latest snapshot; default for "zelta sync".
      -d#  Limit depth to #.
EOF
}

usage_policy() {
	cat << EOF
DESCRIPTION
    zelta policy [-jvnq] [--POLICY_OVERRIDE=VAL] [site|host|dataset] ...
      Perform backups based on the zelta policy file.

OPTIONS
      -j  Produce JSON output.
      -n  Print a list of zelta replicate commands and exit.
      -q  Suppress all output besides errors.
      -v  Produce more verbose output.

LONG OPTIONS
    All policy file options can also be passed as overrides in the command line.

      --list  Print a list of the requested source endpoints and exit.

POLICY OPTIONS
    See the example policy configuration for details.

    BACKUP_ROOT: dataset
      Default backup path for each replication job.
    SNAPSHOT: WRITTEN|ALL|SKIP|OFF
      Snapshot when new data has been written, always, skip if not written, or never snapshot. 
    RETRY: #
      Attempt to retry failed replication jobs this many times. Recommended.
    INTERMEDIATE: 0|1
      Set to 0 to replicate newest snapshots only. Otherwise, replicate as many snapshots as possible.
    REPLICATE: 0|1
      Set to 1 to use "zfs send -R" behavior. Sometimes useful with "DEPTH: 1".
    DEPTH: #
      Limit depth to this number of levels.
    PREFIX: #
      If set, pad with this number of parent prefixes up to the pool name.
    HOST_PREFIX: 0|1
      If set to 1, pad the target with the hostname.
    PUSH_TO: hostname
      If set, replicate all sources to the target host.

EXAMPLE SITE, HOST, AND SNAPSHOT CONFIGURATION

My_LAN:
  localhost:
  - zroot: my.twin.host:twinpool/Backups/my_host_zroot
  my.twin.host:
  - twinpool/stuff: zroot/Backups/twin_stuff

EXAMPLE OVERRIDE
  Show a list of all dataset endpoints from hosts in site1, all dataset endpoints from host2, and the
  dataset endpoint for dataset3:

    zelta policy --list site1 host2 dataset3
EOF
}

# Add "man" if available.
case $1 in
	usage|help) usage_top ;;
	backup|sync|clone|replicate) usage_sync "$1" ;;
	match) zelta match -? ;;
	policy) usage_policy ;;
	*)	[ -n "$1" ] && echo unrecognized command \'$1\' >>/dev/null ;
		usage_top ;;
esac
