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

internal untilities: endpoint, snapshot, time, reconcile

source-endpoint syntax: [user@][host:]pool/dataset[@snapshot]
target-endpoint syntax: [user@][host:]pool/dataset
EOF
}

usage_sync () {
	cat << EOF
DESCRIPTION
    zelta sync [-jqvcnpRSsTtIiMu] [-d#] [-L#] [initiator.host] source-endpoint target-endpoint
      Recursively replicate the latest snapshots.
    zelta backup [-jqvcnpRSsTtIiMu] [-d#] [-L#] [initiator.host] source-endpoint target-endpoint
      Recursively snapshot and then replicate as many snapshots as possible
      from the source to the target.
    zelta clone [-jqvcnpRSsTtIiMu] [-d#] [-L#] [initiator.host] dataset[@snapshot] dataset
      Recursively clone a dataset to a local pool.

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
      -S  Snapshot before performing the replication/clone task; defualt for "zelta backup".
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
    zelta match [-nvw] [-d#] source-endpoint target-endpoint
      Report the latest matching snapshot between two datasets. If only one argument is
      given, report the amount of data unwritten since the last snapshot.

ENDPOINT SYNTAX
      source-endpoint  [user@][host:]pool/dataset
      target-endpoint  [user@][host:]pool/dataset

OPTIONS
      -n  Show the "zfs list" command lines that would be run and exit.
      -w  Calculate missing written data for "zelta backup" or "zelta sync -I".
      -d#  Limit "zfs list" depth to #.
EOF
}

case $1 in
	usage) usage_top ;;
	backup|sync|clone) usage_sync "$1" ;;
	match) usage_match ;;
	*)	[ -n "$1" ] && echo unrecognized command \'$1\' >>/dev/null ;
		usage_top ;;
esac
