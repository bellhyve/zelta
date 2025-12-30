% zelta-rotate(8) | System Manager's Manual

# NAME

**zelta rotate** - recover sync continuity by renaming, cloning, and incrementally syncing a ZFS replica

# DESCRIPTION
**zelta rotate** renames a replica and then performs a multi-way clone and sync operation. This can be used to restore sync continuity when a _source_ and/or _target_ replica have diverged. This technique is a non-destructive alternative to `zfs rollback` and `zfs recv -F`, and is useful for maintaining forensic evidence in recovery scenarios and advanced iterative infrastructure workflows.

As with `zelta backup`, `zelta rotate` works recursively, and both _source_ and _target_ may be local or remote via **ssh(1)**.

The rotate operation will attempt to sync a minimum amount of data to complete the task, targeting the next available snapshot for incremental sync. It is recommended to run `zelta backup` with your preferred settings after successful rotation.

If any child dataset is already in sync, Zelta will create a snapshot on the source, which is required for a successful rotation. If no common snapshots are found between the source and target for any children, a full backup will be performed instead. 

If the requested (topmost) target replica has no common snapshot with the source, `zelta rotate` will not continue. In this case, it is recommended to rename the diverged target so `zelta backup` can perform a full backup.

See `zelta help backup` for more information about Zelta's sync process, which `zelta rotate` also performs. Additionally, `zelta rotate` performs the following additional operations.

    • If the _target_ has no matching snapshots with the _source_, the _source origin_ is checked for matches.
    • The _target_ is renamed, appending the matching snapshot name. For example, `pool/ds` with the snapshot @yesterday may become `pool/ds_yesterday`.
    • For each child with a matching snapshot, an incremental sync will be performed by creating a clone.
    • For each child without a matching snapshot, a full backup will be performed.

Remote dataset endpoints for the _source_ and _target_ follow **scp(1)** conventions. Dataset names follow **zfs(8)** naming conventions. The _target_ must be a replica of the _source_.

Examples:

    Local:  pool/dataset
    Remote: user@example.com:pool/dataset

# OPTIONS

**Endpoint Options (Required)**
If both endpoints are remote, the default behavior will be a **pull replication** (`\--pull`). This requires that the _target_ user must have ssh access to the _source_, typically provided by using an `ssh` key or agent forwarding. For help with advanced `ssh` configuration, see the _https://zelta.space_ wiki.

_source_
: The dataset to replicate. The source origin, if needed, is automatically detected.

_target_
:    The dataset which will be rotated.

**Output Options**

**-v, \--verbose**
:    Increase verbosity. Specify once for operational detail, twice (`-vv`) for debug output.

**-q, \--quiet**
:    Quiet output. Specify once to suppress warnings, twice (`-qq`) to suppress errors.

**-n, \--dryrun, \--dry-run**
:    Display `zfs` commands without executing them.

**Connection Options**

**\--push,\--pull,\--sync-direction** _DIRECTION_
:    When both endpoints are remote, use `PULL` (default) or `PUSH` sync direction.

**Snapshot Options**

**\--no-snapshot**
:    Do not snapshot. If a snapshot is needed, rotation will not occur.

**\--snapshot**
:    Snapshot even if the _source_ is not in need of one.

**\--snap-name** _NAME_
:    Specify snapshot name. Use `$(command)` for dynamic generation. Default: `$(date -u +zelta_%Y-%m-%d_%H.%M.%S)`.

**Sync Options**

**\--send-check**
:    Attempt to drop unsupported `zfs send` options using a no-op test prior to replication. Not fully implemented.

**Override Options**
As a convenience feature, all options for `zfs send` and/or `zfs recv` may be overridden. In most circumstances, these defaults should be overridden in `zelta.env`. See `zelta help options` for more details.

**-b,\--backup,-c,\--compressed,-D,\--dedup,-e,\--embed,\--holds,-L,\--largeblock,-p,\--parsable,\--proctitle,\--props,\--raw,\--skipmissing,-V,-w**
:    Override default `zfs send` options. For precise configuration, use `ZELTA_SEND_*` environment variables instead. See **zelta-options(8)**.

**-M,-u**
:    Override default `zfs receive` options. For precise configuration, use `ZELTA_RECV_*` environment variables instead. See **zelta-options(8)**.

# NOTES
See **zelta-options(8)** for more information about options that can be configured via the environment, `zelta.env`, and `zelta policy`.

# EXAMPLES
Rewind a _source_ backup to its previous snapshot state with a rename and clone operation.

    zelta revert sink/source/dataset

Rename and update its replica with a 4-way incremental backup.

    zelta rotate sink/source/dataset backup-host.example:tank/target/dataset

Ensure the replicas are consistent.

    zelta backup sink/source/dataset backup-host.example:tank/target/dataset

# EXIT STATUS
Returns 0 on success, non-zero on error.

# SEE ALSO
zelta(8), zelta-options(7), zelta-match(8), zelta-backup(8), zelta-policy(8), zelta-clone(8),  zelta-revert(8), ssh(1), zfs(8)

# AUTHORS
Daniel J. Bell <_bellhyve@zelta.space_>

# WWW
https://zelta.space
