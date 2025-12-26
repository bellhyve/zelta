% zelta-backup(8) | System Manager's Manual

# NAME
**zelta backup**, - replicate ZFS dataset trees

# SYNOPSIS
**zelta backup** [_OPTIONS_] _source_ _target_

# DESCRIPTION
**zelta backup** recursively syncs snapshots from a _source_ ZFS dataset to a _target_ dataset. Both _source_ and _target_ may be local or remote via **ssh(1)**.

Backups are optimized for complete, safe replication including syncing all snapshots for new backups and intermediate snapshots when updating existing replicas. As with `zfs recv`, the _target_ dataset must be a replica of the _source or must not exist.

Prior to sync, `zelta backup` performs the following operations to ensure optimal `zfs send/zfs recv` options are automatically selected.

    • The properties of the _source_ and _target_ are checked using `zfs get`.
    • If the _target_ dataset's parent does not exist, it will be created with `zfs create`.
    • Using `zelta match`, a snapshot GUID comparison is performed with `zfs list`.
    • One or more `zfs send/zfs recv` operations will be performed to update the _target_.

The following `zfs send` options will be automatically applied to the _source_:

    • Default: --large-block, --compressed, --embed
    • Encrypted Datasets: --large-block, --raw
    • Replicate Mode: --replicate, --large-block, --raw, --skip-missing
    • New/full syncs also use --props

To ensure safe and repeatable syncs, the following options are applied to the _target_:

    • The property `readonly=on` is set on the topmost dataset requestsed
    • Synced filesystems are not mounted
    • On newly backed up filesystems, property `canmount=noauto` is set
    • On newly backed up filesystems, mountpoints are inherited to prevent overlapping mounts

Remote dataset endpoints follow **scp(1)** conventions: [user@]host:[dataset], and require standard ZFS utilities and SSH access. Note that Zelta does **not** need to be installed on remote ZFS servers.

Examples:

    Local:  zpool/dataset@snapshot
    Remote: user@example.com:zpool/dataset@snapshots


# OPTIONS

**Endpoint Options (Required)**
If both endpoints are remote, the default behavior will be a **pull replication** (`\--pull`). This requires that the _target_ user must have ssh access to the _source_, typically provided by using an `ssh` key or agent forwarding. For help with advanced `ssh` configuration, see the _https://zelta.space_ wiki.

_source_
: The dataset to replicate. If a snapshot is specified, replication will sync up to that snapshot.

_target_
:    The dataset which will be updated.

**Output Options**

**-v, \--verbose**
:    Increase verbosity. Specify once for operational detail, twice (`-vv`) for debug output.

**-q, \--quiet**
:    Quiet output. Specify once to suppress warnings, twice (`-qq`) to suppress errors.

**-n, \--dryrun, \--dry-run**
:    Display `zfs` commands without executing them.

**-d, \--depth** _LEVELS_
:    Limit recursion depth. For example, a depth of 1 includes only the specified dataset.

**\--exclude, -X** _PATTERN_
:    Exclude /dataset/suffix, @snapshot, or #bookmark beginning with the indicated symbol. Wildcards `?` and `*` are permitted. See **zelta-match(8)**.

**-j, \--json**
:    Print JSON output. See **zelta-options(8)** for details.

**Connection Options**

**\--push,\--pull,\--sync-direction** _DIRECTION_
:    When both endpoints are remote, use `PULL` (default) or `PUSH` sync direction.

**\--recv-pipe** _COMMAND_
:    Pipe `zfs receive` output through the indicated command, such as `dd status=progress`.

**Snapshot Options**

**\--no-snapshot**
:    Do not snapshot.

**\--snapshot-always**
:    Snapshot even if the _source_ has no written data in need of one.

**\--snap-name** _NAME_
:    Specify snapshot name. Use `$(command)` for dynamic generation. Default: `$(date -u +zelta_%Y-%m-%d_%H.%M.%S)`.

**\--snap-mode** _MODE_
:    Specify when to snapshot: `0` (never), `IF_NEEDED` (default, only if source has new data), or `ALWAYS`.

**Sync Options**

**\--send-check**
:    Attempt to drop unsupported `zfs send` options using a no-op test prior to replication. Not fully implemented.

**\--rotate**
:    Rename the target dataset and sync a clone via delta from the source or source origin clone. See **zelta help rotate**.

**-R,\--replicate**
:    Use **zfs send \--replicate** instead of Zelta's per-snapshot analysis.

**-I**
:    Sync all possible source snapshots using `zfs send -I` for updates. This is the default behavior. See **-i** to disable this behavior.

**\--resume,\--no-resume**

**-i**
:    Sync only the latest snapshot, skipping any intermediate snapshots. For full backups only the latest snapshot will be sent. For incremental backups, `zfs send -i` will be used. This behavior is the default if the **zelta sync** verb is used.

**\--resume,\--no-resume**
:    Enable (default) or disable automatic resume of interrupted syncs.

**Override Options**
As a convenience feature, all options for `zfs send` and/or `zfs recv` may be overridden. In most circumstances, these defaults should be overridden in `zelta.env`. See `zelta help options` for more details.

**-b,\--backup,-c,\--compressed,-D,\--dedup,-e,\--embed,-h,\--holds,-L,\--largeblock,-p,\--parsable,\--proctitle,\--props,\--raw,\--skipmissing,-V,-w**
:    Override default `zfs send` options. For precise configuration, use `ZELTA_SEND_*` environment variables instead. See **zelta-options(8)**.

**-e,-h,-M,-u**
:    Override default `zfs receive` options. For precise configuration, use `ZELTA_RECV_*` environment variables instead. See **zelta-options(8)**.


# NOTES
See **zelta-options(8)** for more information about options that can be configured via the environment, `zelta.env`, and `zelta policy`.

The `zelta sync` command is a convenience alias for `zelta backup -i` and may be extended in future versions with additional optimizations for continuous replication workflows.

# EXAMPLES
The same command works for both new and existing target datasets.

Local replication with automatic snapshot creation:

    zelta backup tank/source/dataset tank/target/dataset

Remote to local synchronization:

    zelta backup remote_host:tank/source/dataset tank/target/dataset

Dry run to preview commands:

    zelta backup -n tank/source/dataset tank/target/dataset

Replicate with custom snapshot naming:

    zelta backup \--snap-name "backup_$(date +%Y%m%d)" \
        tank/source tank/backups/source

Limit recursion depth:

    zelta backup -d 2 tank/source tank/target

# EXIT STATUS
Returns 0 on success, non-zero on error.

# SEE ALSO
zelta(8), zelta-options(7), zelta-match(8), zelta-policy(8), zelta-clone(8),  zelta-revert(8), zelta-rotate(8), ssh(1), zfs(8)

# AUTHORS
Daniel J. Bell <_bellhyve@zelta.space_>

# WWW
https://zelta.space
