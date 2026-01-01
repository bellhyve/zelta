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
- Synced filesystems are not mounted on the _target_ during replication
- On newly backed up filesystems, property `canmount=noauto` is set
- On newly backed up filesystems, mountpoints are inherited to prevent overlapping mounts

## Source and Target Endpoints

Remote dataset endpoint names follow **scp(1)** conventions and require standard ZFS utilities and SSH access. Note that Zelta does **not** need to be installed on remote ZFS servers.

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
Zelta automatically applies non-destructive and efficient `zfs send` and `zfs recv` options based on dataset type and context. These can be modified with three types of arguments.
- **Granular Override Options:** Define options to use in specific situations.
- **Dataset Tree Override Options:** Provide the entire string of `zfs send` or `zfs recv` options.
- **Pass-Through Override Options:** For convenience, provide unambiguous `zfs send` or `zfs recv` options.

Some options have special use or meaning and should usually be excluded from overrides.
- The following options are used internally by Zelta:
  - `zfs send \--parsable (-P)`
  - `zfs recv \-v)`
- These `zfs send` options have special behavior within Zelta (see the options above for details):
  - `-I` and `-i` change both full and incremental backup behavior
  - `--exclude, -X` is has additional Zelta functionality
  - `--dryrun, -n` shows `zfs send`/`zfs recv` commands that would be run
  - `-t` is used automatically to resume a partial backup
- `zfs send -S` is not supported
- `zfs recv -A` should be used manually when needed

These defaults can also be changed globally in `zelta.env` or via policy in `zelta.conf`.

### Granular Override Options
For precise control in dataset trees with mixed types, use these options to override specific contexts. These precise options are cumulative. For example, a filesystem receive will use options from **\--recv-default**, **\--recv-top** (if applicable), and **\--recv-fs**.

**\--send-default** *"OPTIONS"*
: `zfs send` options used when the dataset is **not** encrypted (default: **-Lce**)
* Example: `--send-default -Le` to allow the target to recompress the data.

**\--send-raw** *"OPTIONS"*
: `zfs send` options used when the dataset **is** encrypted (default: **-Lw**)

**\--send-new** *"OPTIONS"*
: Additional `zfs send` options used during a full (non-incremental) backup (default: **-p**)

**\--recv-default** *"OPTIONS"*
: `zfs recv` options used for all datasets (none by default)

**\--recv-top** *"OPTIONS"*
: Additional `zfs recv` options used for the topmost indicated dataset (default: **-o readonly=on**)

**\--recv-fs** *"OPTIONS"*
: Additional `zfs recv` options for filesystem datasets (default: **-u -o canmount=noauto -x mountpoint**)
* Example: `--recv-fs '-o mountpoint=none` may help avoid permission errors on some operating systems.

**\--recv-vol** *"OPTIONS"*
: Additional `zfs recv` options for volume datasets (default: **-o volmode=none**)
* Example: `--recv-vol '-o volmode=dev'`

### Dataset Tree Override Options
The following two options override `zfs send` and `zfs recv` for all datasets in the backup task regardless of context.

**\--send-override** *'OPTIONS'*
: Override default `zfs send` options.

**\--recv-override** *'OPTIONS'*
: Override default `zfs recv` options.

### Pass-Through Override Flags
For convenience for those especially fluent in ZFS, Zelta passes unambiguous `zfs send` and `zfs recv` options. If a single pass-through option is given, all other context-based options for that `zfs` command are overridden. For example, if `-L` is given, `zfs send` operations will only receive the `-L` flag

Several options may not work as expected or are unsupported:
- Ambiguous single-dash options are **unsupported**: [`-cdehs`]
- The following options have special handlers; see their definitions above for details:
  - `--exclude, -X`
  - `-I, -i`
  - `--replicate, -R`

**Use with caution.** When in doubt, modify options using the granular override options.

**-b, --backup, -c, --compressed, -D, --dedup, --embed, --holds, -L, --largeblock, -p, --parsable, --proctitle, --props, --raw, --skipmissing, -V, -w**
: Override default `zfs send` options.

**-F, -M, -u**
: Override default `zfs receive` options.

**Common Examples:**
- **-Lw**: Always send in raw encrypted mode
- **-L --recv-override '-o compression=zstd-5'**: Resets `zfs send` options and recompress the target with zstd level 5 compression. Since Zelta defaults include **-c** for unencrypted datasets, this allows data to be recompressed at the target. **Warning:** Encrypted datasets will be sent with an unencrypted stream.

# EXAMPLES

The same command works for both new and existing target datasets.

Local replication with automatic snapshot creation:

    zelta backup sink/source/dataset tank/target/dataset

Remote to local synchronization:

    zelta backup remote_host:sink/source/dataset tank/target/dataset

Dry run to preview commands:

    zelta backup -n sink/source/dataset tank/target/dataset

Replicate with custom snapshot naming:

    zelta backup \--snap-name "backup_$(date +%Y%m%d)" \
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
