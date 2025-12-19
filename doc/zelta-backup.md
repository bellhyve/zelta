% zelta-backup(8) | System Manager's Manual

# NAME

**zelta backup**, **zelta sync**, **zelta clone** - Perform a recursive replication operation.


# SYNOPSIS

**zelta backup** [**-bcdDeeFhhLMpuVw**] [**-iIjnpqRtTv**] [_initiator_] _source-endpoint_ _target-endpoint_

# DESCRIPTION
**zelta backup** and **zelta sync** attempt to intelligently replicate snapshots from a _source_ ZFS dataset endpoint to a _target_. **zelta backup** optimizes for complete backups of all snapshots by default using a careful LBYL strategy, appropriate for typical backup jobs. **zelta sync** optimizes for efficiency using an EAFP strategy, appropriate for time-sensitive operations or controlled environemnts. Endpoints may be remotely accessible via SSH. As with **zfs receive**, the _target_ dataset endpoint must not exist or be an replica of the _source_.

Zelta is designed for simplicity and safety and is suitable for a backup server replicating datasets from many systems. To ensure safe operation, the following default options are set for new replication _targets_:
1. The property _readonly=on_ will be set.
2. Filesystems will not be mounted.
3. On filesystems, the property _canmount=noauto_ will be set. 
4. On filesystems, mountpoints will be inherited (discarded) to prevent overlapping mounts.

These defaults, as well as snapshot naming scheme and many other assumptions, can be modified with arguments or via the environment (see `zelta.env.example` for more information).

# OPTIONS


**-v,--verbose**
:    Increase verbosity. Specify once for operational detail and twice (-vv) for debug output.

**-q,--quiet**
:    Quiet output. Specify once to suppress warnings and twice (-qq) to suppress errors.

**--log-level**
:    Specify a log level value 0-4: errors (0), warnings (1), notices (2, default), info (3, verbose), and debug (4).

**--log-mode**
:    Enable the specified log modes: 'text' and 'json' are currently supported.

**--text**
:    Force default output (notices) to print as plain text standard output.

**--help,-h,-?**
:    Show usage output for the current verb. Also consider 'zelta help <topic>' to view a manual.

**-n,--dryrun,--dry-run**
:    Display 'zfs' commands related to the action rather than running them.

**-d,--depth**
:    Limit the recursion depth of operations to the number of levels indicated. For example, a depth of 1 will only include the indicated dataset.

**--exclude,-X**
:    Exclude a /dataset/suffix, @snapshot, or #bookmark, beginning with the symbol indicated. Wild card matches with '?' and '*' are permitted. See 'zelta help match' for more details.

**-j,--json**
:    Print JSON output. Only 'zelta backup' is supported. See the 'zelta help backup' for details.

**-b,--backup,-c,--compressed,-D,--dedup,-e,--embed,-h,--holds,-L,--largeblock,-p,--parsable,--proctitle,--props,--raw,--skipmissing,-V,-w**
:    Override all 'zfs send' options with those indicated. For precise and flexible configuration, use the ZELTA_SEND_* environment variables instead.

**--send-check**
:    Attempt to drop unsupported 'zfs send' options using a no-op test prior to replication. This feature is not fully implemented.

**-e,-h,-M,-u**
:    Override all 'zfs receive' options with those indicated. For precise and flexible configuration, use the ZELTA_RECV* environment variables instead.

**--rotate**
:    Rename the target dataset and attempt to sync a clone via a delta provided by the source or source origin clone.

**-R,--replicate**
:    Use 'zfs send --replicate' in a backup operation.

**-I**
:    Sync all possible source snapshots, using 'zfs send -I' for updates. When disabled, only the newest snapshots will be synced.

**--resume**
:    Enable (the default) or disable automatic resume of interrupted syncs.

**--snap-name**
:    Specify a snapshot name. Use the form '$(my_snapshot_program)' to use a dynamically generated snapshot. The default is '$(date -u +zelta_%Y-%m-%d_%H.%M.%S)'.

**--snap-mode**
:    Specify when to snapshot during a 'zelta backup' operation. Specify '0' for never, 'IF_NEEDED', or 'ALWAYS'. 'IF_NEEDED', the default, does not snapshot if the source has no new data.

**--sync-direction**
:    If both endpoints are remote, use 'PULL' (the default) or 'PUSH' sync. See 'zelta help backup' for more details.

**--recv-pipe**
:    Pipe output through the indicated command, such as 'dd status=progress'

# EXAMPLES

Note that the same command can be used for new and existing _target_ datasets.

**Local synchronization:** Synchronize a dataset and all of its snapshots from a local source dataset to a local target dataset, creating a snapshot only if necessary to get the latest data.

```sh
zelta backup tank/source/dataset tank/target/dataset
```

**Migrate remote data to localhost:** Create a snapshot and replicate it from a remote source to a local target, only if the source has new written data.

```sh
zelta sync -ss remote_host:tank/source/dataset tank/target/dataset
```

**Dry Run:** Display the `zfs send` and `zfs receive` commands without executing them.

```sh
zelta backup -n tank/source/dataset tank/target/dataset
```

# SEE ALSO
ssh(1), zelta(8), zelta-match(8), zelta-policy(8), zfs(8)

# AUTHORS
Daniel J. Bell _<bellta@belltower.it>_

# WWW
https://zelta.space
