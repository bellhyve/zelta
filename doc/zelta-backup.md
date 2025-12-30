% zelta-backup(8) | System Manager's Manual

# NAME

**zelta backup** - replicate ZFS dataset trees

# SYNOPSIS

**zelta backup** [_OPTIONS_] _source_ _target_

# DESCRIPTION

**zelta backup** recursively replicates snapshots from a _source_ ZFS dataset to a _target_ dataset. Both _source_ and _target_ may be local or remote via **ssh(1)**.

As with other Zelta commands, **zelta backup** works recursively on dataset trees. The _target_ dataset must be a replica of the _source_ or must not exist.

Prior to replication, **zelta backup** analyzes both source and target to automatically select optimal `zfs send` and `zfs recv` options. This process includes property inspection, parent dataset creation if needed, snapshot GUID comparison via **zelta match**, and one or more send/recv operations to update the target.

## Replication Process

**zelta backup** performs these operations:

1. **Property Analysis**: Source and target properties are checked using `zfs get` to detect encryption, written state, and other features.
2. **Parent Creation**: If the target dataset's parent does not exist, it will be created with `zfs create`.
3. **Snapshot Comparison**: Using **zelta match**, a snapshot GUID comparison is performed with `zfs list` to identify matching snapshots and determine the optimal replication strategy.
4. **Snapshot Creation**: If the source has uncommitted changes and no recent snapshot exists, a new snapshot is created (unless `--no-snapshot` is specified).
5. **Incremental Sync**: One or more `zfs send/zfs recv` operations are performed to update the target, using incremental sends when possible.

## Send Options

The following `zfs send` options are applied based on dataset properties:

- **Default**: `--large-block`, `--compressed`, `--embed`
- **Encrypted Datasets**: `--large-block`, `--raw`
- **New/Full Syncs**: Also includes `--props`
- **Replicate Mode** (`-R`): `--replicate`, `--large-block`, `--raw`, `--skip-missing`

## Target Safety Features

To ensure safe and repeatable replication, the following measures are applied to the target:

- The property `readonly=on` is set on the topmost dataset requested
- Synced filesystems are not mounted during replication
- On newly backed up filesystems, property `canmount=noauto` is set
- On newly backed up filesystems, mountpoints are inherited to prevent overlapping mounts

## Source and Target Endpoints

Remote dataset endpoints follow **scp(1)** conventions and require standard ZFS utilities and SSH access. Note that Zelta does **not** need to be installed on remote ZFS servers.

Examples:

    Local:  pool/dataset
    Local:  pool/dataset@snapshot
    Remote: user@example.com:pool/dataset
    Remote: user@example.com:pool/dataset@snapshot

# OPTIONS

## Endpoint Arguments (Required)

If both endpoints are remote, the default behavior is **pull replication** (`--pull`). This requires that the _target_ user have ssh access to the _source_, typically provided by ssh keys or agent forwarding. For advanced ssh configuration, see _https://zelta.space_.

_source_
: The dataset to replicate. If a snapshot is specified, replication will sync up to that snapshot.

_target_
: The dataset which will be updated.

**Output Options**

**-v, \--verbose**
: Increase verbosity. Specify once for operational detail, twice (`-vv`) for debug output.

**-q, \--quiet**
: Quiet output. Specify once to suppress warnings, twice (`-qq`) to suppress errors.

**-j, \--json**
: Output results in JSON format. See **zelta-options(8)** for details.

**-n, \--dryrun, \--dry-run**
: Display `zfs` commands without executing them.

## Connection Options

**\--push, \--pull, \--sync-direction** _DIRECTION_
: When both endpoints are remote, use `PULL` (default) or `PUSH` sync direction.

**\--recv-pipe** _COMMAND_
: Pipe `zfs receive` output through the indicated command, such as `dd status=progress`.

## Dataset Options

**-d, \--depth** _LEVELS_
: Limit recursion depth. For example, a depth of 1 includes only the specified dataset.

**\--exclude, -X** _PATTERN_
: Exclude /dataset/suffix, @snapshot, or #bookmark beginning with the indicated symbol. Wildcards `?` and `*` are permitted. See **zelta-match(8)**.

## Snapshot Options

**\--no-snapshot**
: Do not create snapshots. If a snapshot is needed for replication, the operation will fail.

**\--snapshot, \--snapshot-always**
: Force snapshot creation even if the source has no uncommitted changes.

**\--snap-name** _NAME_
: Specify snapshot name. Use `$(command)` for dynamic generation. Default: `$(date -u +zelta_%Y-%m-%d_%H.%M.%S)`.

**\--snap-mode** _MODE_
: Specify when to snapshot: `NEVER` (or `0`), `IF_NEEDED` (default, only if source has new data or no recent snapshot), or `ALWAYS`.

## Sync Options

**-R, \--replicate**
: Use `zfs send --replicate` instead of Zelta's per-snapshot analysis. This sends all snapshots, bookmarks, and properties in a single process but provides less granular control over send options.

**-I**
: Sync all intermediate source snapshots using `zfs send -I` for updates. This is the default behavior. See **-i**.

**-i, \--incremental**
: Sync only the latest snapshot, skipping any intermediate snapshots. For full backups only the latest snapshot will be sent. For incremental backups, `zfs send -i` will be used.

**\--resume, \--no-resume**
: Enable (default) or disable automatic resume of interrupted syncs.

## Advanced Override Options

You may need to override default `zfs send` or `zfs recv` options. For precise and repeatable configuration, use `ZELTA_SEND_*` and `ZELTA_RECV_*` environment variables instead. See **zelta-options(8)**. Note only unambiguous `zfs send-recv` options are permitted on the Zelta command line.
: **Examples:**
  * **-Lw**: Always send in raw mode.
  * **-L**: Use only **-L**. Since Zelta's defaults include **-c** for nonencrpyted datasets, overriding this allows data to be recompressed at the target endpoint. **Warning:** Encrypted datasets will be sent with an unencrypted stream.

**-b, \--backup, -c, \--compressed, -D, \--dedup, \--embed, \--holds, -L, \--largeblock, -p, \--parsable, \--proctitle, \--props, \--raw, \--skipmissing, -V, -w**
: Override default `zfs send` options. Use with caution.

**-M, -u**
: Override default `zfs receive` options. Use with caution. Note: `-e` and `-h` are ambiguous and cannot be used for receive overrides.

# EXAMPLES

The same command works for both new and existing target datasets.

Local replication with automatic snapshot creation:

    zelta backup sink/source/dataset tank/target/dataset

Remote to local synchronization:

    zelta backup remote_host:sink/source/dataset tank/target/dataset

Dry run to preview commands:

    zelta backup -n sink/source/dataset tank/target/dataset

Replicate with custom snapshot naming:

    zelta backup --snap-name "backup_$(date +%Y%m%d)" \
        sink/source/dataset tank/backups/source/dataset

Incremental sync, skipping intermediate snapshots:

    zelta backup -i sink/source tank/target

Limit recursion depth:

    zelta backup -d 2 sink/source tank/target

# EXIT STATUS

Returns 0 on success, non-zero on error.

# NOTES

See **zelta-options(8)** for environment variables, `zelta.env` configuration, and `zelta policy` integration.

The `zelta sync` command is a convenience alias for `zelta backup -i` and may be extended in future versions with additional optimizations for continuous replication workflows.

# SEE ALSO

zelta(8), zelta-options(7), zelta-match(8), zelta-policy(8), zelta-clone(8), zelta-revert(8), zelta-rotate(8), ssh(1), zfs(8), zfs-send(8), zfs-receive(8)

# AUTHORS

Daniel J. Bell <_bellhyve@zelta.space_>

# WWW

https://zelta.space
