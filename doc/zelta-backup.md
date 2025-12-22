% zelta-backup(8) | System Manager's Manual

# NAME
**zelta backup**, - replicate ZFS dataset trees

# SYNOPSIS
**zelta backup** [_OPTIONS_] _source_ _target_

# DESCRIPTION
**zelta backup** syncs snapshots from a _source_ ZFS dataset to a _target_ dataset, working recursively on a dataset tree. Both _source_ and _target_ may be local or remote via **ssh(1)**. Remote endpoints follow **scp(1)** conventions: [user@]host:dataset.

**zelta backup** optimizes for complete, safe replication including intermediate snapshots. The synonym **zelta sync** performs incremental syncs excluding intermediate snapshots, and the synonym **zelta replicate** uses the **zfs send \--replicate** option instead of Zelta's per-snapshot analysis. 

As with **zfs receive**, the _target_ dataset must not exist or must be a replica of the _source_.

To ensure safe operation, the following defaults are set for a new sync _target_ dataset:

    1. The property `readonly=on` is set on the top (indicated) filesystem
    2. Filesystems are not mounted
    3. On filesystems, property `canmount=noauto` is set
    4. On filesystems, mountpoints are inherited to prevent overlapping mounts

See **zelta-options(8)** for more information.

# OPTIONS
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

**-b,\--backup,-c,\--compressed,-D,\--dedup,-e,\--embed,-h,\--holds,-L,\--largeblock,-p,\--parsable,\--proctitle,\--props,\--raw,\--skipmissing,-V,-w**
:    Override default `zfs send` options. For precise configuration, use `ZELTA_SEND_*` environment variables instead. See **zelta-options(8)**.

**\--send-check**
:    Attempt to drop unsupported `zfs send` options using a no-op test prior to replication. Not fully implemented.

**-e,-h,-M,-u**
:    Override default `zfs receive` options. For precise configuration, use `ZELTA_RECV_*` environment variables instead. See **zelta-options(8)**.

**\--rotate**
:    Rename the target dataset and sync a clone via delta from the source or source origin clone. See **zelta help rotate**.

**-R, \--replicate**
:    Use **zfs send \--replicate** instead of Zelta's per-snapshot analysis.

**-I**
:    Sync all possible source snapshots using `zfs send -I` for updates. When disabled, only the newest snapshots are synced. This is the default behavior for **zelta backup**.

**\--resume,\--no-resume**
:    Enable (default) or disable automatic resume of interrupted syncs.

**\--no-snapshot**
:    Do not snapshot.

**\--snapshot-always**
:    Snapshot even if the _source_ has no written data in need of one.

**\--snap-name** _NAME_
:    Specify snapshot name. Use `$(command)` for dynamic generation. Default: `$(date -u +zelta_%Y-%m-%d_%H.%M.%S)`.

**\--snap-mode** _MODE_
:    Specify when to snapshot: `0` (never), `IF_NEEDED` (default, only if source has new data), or `ALWAYS`.

**\--push,\--pull,\--sync-direction** _DIRECTION_
:    When both endpoints are remote, use `PULL` (default) or `PUSH` sync direction.

**\--recv-pipe** _COMMAND_
:    Pipe `zfs receive` output through the indicated command, such as `dd status=progress`.

# EXAMPLES
The same command works for both new and existing target datasets.

Local replication with automatic snapshot creation:

    zelta backup tank/source/dataset tank/target/dataset

Remote to local synchronization:

    zelta sync remote_host:tank/source/dataset tank/target/dataset

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
**zelta(8)**, **zelta-clone(8)**, **zelta-match(8)**, **zelta-options(8)**, **zelta-policy(8)**, **zelta-rotate(8)**, **zelta-sync(8)**, **ssh(1)**, **zfs(8)**

# AUTHORS
Daniel J. Bell _<bellta@belltower.it>_

# WWW
https://zelta.space

https://github.com/bellhyve/zelta
