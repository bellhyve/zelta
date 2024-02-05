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
      If an initiator host is given, run all commands there instead of locally.
    source-endpoint  [user@][host:]pool/dataset[@snapshot]
    target-endpoint  [user@][host:]pool/dataset

LOG OPTIONS
      -j  Produce JSON output only.
      -q  Limit output to errors only.
      -v  Produce more verbose output. Use "-vv" if using custom pipes.

MISC OPTIONS
      -c  Clone instead of replicate; default for "zelta clone".
      -n  Dry-run; display replication commands instead of running them.
      -p  Pipe the "zfs send" output through "dd status=progress" or "pv" if installed.
      -R  Use "zfs send -R"; useful with "-d1".
      -S  Snapshot before performing the replication/clone task.
      -s  Snapshot only if written; "-ss" to quit if no snapshot is needed.
      -T  Run all commands from the source host.
      -t  Run all commands from the target host.
      -S  Snapshot before performing the replication/clone task; default for "zelta backup".
      -I  Replicate as many snapshots as possible; default for "zelta backup".
      -i  Replicate only the latest snapshot; default for "zelta sync".
      -M  No default "zfs receive" flags; replicate read-write with mountpoints.
      -u  Do not mount after replication.
      -d#  Limit depth to #.
      -L#  Pass -L to a "pv" pipe (pv must be installed). 
EOF
}

usage_match() {
	cat << EOF
DESCRIPTION
    zelta match [-Hpnw] [-d#] [-o fields] source-endpoint target-endpoint
      Report the latest matching snapshot between two datasets. If only one argument is
      given, report the amount of data unwritten since the last snapshot.

    By default, the user will receive a table output including the fields:
      [stub,]status,match,srclast
    Where "stub" describes the snapshot name relative to both the source and target. Stub
    will be suppressed if there are no child snapshots.

ENDPOINT SYNTAX
      source-endpoint [user@][host:]pool/dataset
      target-endpoint [user@][host:]pool/dataset

OPTIONS
      -H  Suppress the header row.
      -p  For piping/scripting, split the columns by a single tab.
      -n  Show the "zfs list" command lines that would be run and exit.
      -w  Add the "sizediff" column; note that this results in slower output.
      -d# Limit "zfs list" depth to #.
      -o  A comma-delimited list of fields with one or more of:
            stub      The name of the dataset relative to the source or target
            status    The target's sync status relative to the source, one of:
                        NOTARGET, NOSOURCE, SYNCED, BEHIND, AHEAD, MISMATCH
            sizediff  The amount of data missing on the target since the last snapshot match
            numdiff   The number of snapshots missing on the target since the last snapshot match
            match     The most recent common snapshot
            srcfirst  The first snapshot on the source
            tgtfirst  The first snapshot on the target
            srclast   The last snapshot on the source
            tgtlast   The last snapshot on the target
            srcnum    Total number of snapshot on the source
            tgtnum    Total number snapshot on the target
        
EOF
}

usage_policy() {
	cat << EOF
DESCRIPTION
    zelta policy [-jv] [site|host|dataset] ...
      Perform backups based on the zelta policy file.

OPTIONS
      -j  Produce JSON output.
      -v  Produce more verbose output.

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
