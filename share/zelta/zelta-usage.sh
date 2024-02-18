#!/bin/sh

usage_top() {
cat << EOF
usage: zelta command args ...
where 'command' is one of the following:

	version

	usage [command]

	match [-flags] source-endpoint target-endpoint

	backup [-flags] [initiator.host] source-endpoint target-endpoint
	sync [-flags] [initiator.host] source-endpoint target-endpoint
	clone [-flags] [initiator.host] source-endpoint target-endpoint

	policy [site|host|dataset] ...

internal utilities: endpoint, snapshot, time, reconcile

source-endpoint syntax: [user@][host:]pool/dataset[@snapshot]
target-endpoint syntax: [user@][host:]pool/dataset
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

usage_match() {
	cat << EOF
DESCRIPTION
    zelta match [-Hpnw] [-d#] [-o fields] source-endpoint target-endpoint
      Report the latest matching snapshot between two datasets. If only one argument is
      given, report the amount of data unwritten since the last snapshot.

    By default, the user will receive a table output including the fields:
      [stub,]status,match,srclast,summary
    Where "stub" describes the snapshot name relative to both the source and target. Stub
    will be suppressed if there are no child snapshots.

ENDPOINT SYNTAX
      source-endpoint [user@][host:]pool/dataset
      target-endpoint [user@][host:]pool/dataset

OPTIONS
      -H  Suppress the header row.
      -p  For piping/scripting, split the columns by a single tab.
      -n  Show the "zfs list" command lines that would be run and exit.
      -w  Add the "xfersize" column; note that this results in slower output.
      -d# Limit "zfs list" depth to #.
      -o  A comma-delimited list of fields with one or more of:
            stub      The name of the dataset relative to the source or target
            status    The target's sync status relative to the source, one of:
                        NOTARGET, NOSOURCE, SYNCED, BEHIND, AHEAD, MISMATCH
            xfersize  The amount of data missing on the target since the last snapshot match
            xfernum   The number of snapshots missing on the target since the last snapshot match
            match     The most recent common snapshot
            srcfirst  The first snapshot on the source
            tgtfirst  The first snapshot on the target
            srclast   The last snapshot on the source
            tgtlast   The last snapshot on the target
            srcnum    Total number of snapshot on the source
            tgtnum    Total number snapshot on the target
            summary   Human-readable description of the target state
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

case $1 in
	usage|help) usage_top ;;
	backup|sync|clone|replicate) usage_sync "$1" ;;
	match) usage_match ;;
	policy) usage_policy ;;
	*)	[ -n "$1" ] && echo unrecognized command \'$1\' >>/dev/null ;
		usage_top ;;
esac
