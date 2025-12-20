zelta-options(7) -- environment and policy options to modify Zelta behavior
============================================================================

## SYNOPSIS

Environment variables and policy configuration options for controlling Zelta's behavior across all commands.

## DESCRIPTION

Zelta's behavior can be modified through environment variables, command-line arguments, and policy configuration files. This manual documents all available options and their effects.

Options set in the user environment must be prefixed with the string `ZELTA_`. For example, to override the default `zelta.env`, export the variable `ZELTA_ENV="/path/to/env"`. In other contexts, the `ZELTA_` prefix can be omitted.

Options follow a hierarchy:
    1. Defaults
    2. `zelta.env`
    3. `zelta.conf` (`zelta policy` only)
    4. Environment variables (must prefix names with `ZELTA_`)
    5. Command-line arguments

## SETUP OPTIONS
The following options are often modified for user-specific installations and testing purposes. Note that if ENV and/or ETC need to be overridden this must typically be done in the user environment using `ZELTA_ENV` and `ZELTA_ETC` respectively. 

* `AWK`:
  The **awk* executable. The default is the awk in the path. Example: `AWK='mawk -Wi'`.

* `SHARE`:
  The location of Zelta assets including the AWK scripts and data files. The default is `/usr/local/share/zelta`

* `ETC`:
  The location of `zelta.env` and `zelta.conf`. The default is `/usr/local/etc/zelta`.

* `ENV`:
  The exact path of `zelta.env`.

* `DOC`:
  The location of Zelta's manpages. Default is unset, using the system-wide manual.
  

## LOGGING OPTIONS

* `LOG_FILE`:
  Divert all output into the indicated file.

* `LOG_LEVEL`:
  Specify a log level value 0-4: errors (0), warnings (1), notices (2, default), info (3, verbose), and debug (4).

* `LOG_MODE`:
  Enable the specified log modes. Currently supported: 'text' (default) and 'json' (`zelta backup` related verbs only).

## SSH OPTIONS

* `REMOTE_COMMAND`:
  The remote shell command. Defaults to `ssh`.

* `REMOTE_DEFAULT`:
  The default remote shell command used for misc operations which should prevent reading from stdin. Defaults to `REMOTE_COMMAND -n` (`ssh -n`).

* `REMOTE_SEND`:
  The remote shell command used for `zfs send`. Defaults to `REMOTE_COMMAND` (`ssh`).

* `REMOTE_RECV`:
  The remote shell command used for `zfs recv`. Defaults to `REMOTE_DEFAULT` (`ssh -n`).

## GENERAL OPTIONS

* `DEPTH`:
  Limit the recursion depth of operations to the number of levels indicated. For example, a depth of 1 will only include the indicated _source_ dataset.

* `EXCLUDE`:
  Exclude a comma-delimited list of dataset suffixes anchored with a `/`, like `/dataset/suffix`, or snapshots anchored with a `@`, like `@snapshot`. Wild card matches with `?` and `*` are permitted. Given a _source_ endpoint `sink` and the setting: `EXCLUDE='/*/swap,#*,@*_hourly,/temp'`:

    `@*_hourly`:
    All snapshots ending with `_hourly` would be excluded as sync candidates.

    `/*/swap`:
    All datasets ending with `/swap` will be ignored.

    `/temp`:
    The `sink/temp` dataset will be ignored; however a `sink/ds/temp` would still be synced.

## ZELTA MATCH OPTIONS

* `SCRIPTING_MODE`:
  Suppress column headers and separate columns with a single tab. Useful for parsing output in scripts.

* `PARSABLE`:
  Output sizes in exact numbers instead of human-readable values like `1M`.

* `PROPLIST`:
  Specify a list of `zelta match` columns. See `zelta match -h` or `zelta help match` for more detail.

* `LIST_WRITTEN`:
  Calculate data sizes for datasets and snapshots in the summary. Enabled by default.

* `CHECK_TIME`:
  Calculate the time of each `zfs list` operation.

## ZFS SEND/RECEIVE OPTIONS

* `SEND_OVERRIDE`:
  Override all `zfs send` options with those indicated. For precise and flexible configuration for different circumstances, use the `SEND_*` variables below instead.

* `SEND_DEFAULT`:
  Options used for unencrpyted filesystems and volumes. Defaults to `-Lce`.

* `SEND_RAW`:
  Options used for encrypted datasets. Defaults to `-Lw`.

* `SEND_NEW`:
  Additional option used for new datasets. Defaults to `-p`.

* `SEND_INTR`:
  Toggle option to transmit intermediate snapshots (`1`, the default) or incremental (`0`).

* `SEND_REPLICATE`:
  Options to use in `zelta replicate` mode. Defaults to `-LsRw1`.

* `SEND_CHECK`:
  Attempt to drop unsupported `zfs send` options using a no-op test prior to replication. This feature is not fully implemented.

* `RECV_OVERRIDE`:
  Override all `zfs receive` options with those indicated. For precise and flexible configuration, use the `RECV_*` variables instead.

* `RECV_DEFAULT`:
  Default `zfs recv` options. Defaults to none.

* `RECV_TOP`:
  Additional options for the top dataset. Defaults to `-o readonly=on`.

* `RECV_FS`:
  Additional options for filesystems. Defaults to `-u -x mountpoint -o canmount=noauto`.

* `RECV_VOL`:
  Additional options for volumes. Defaults to none.

* `RECV_PARTIAL`:
  Additional options if RESUME is enabled. Defaults to `-s`.

* `RECV_PREFIX`:
  Pipe output through the indicated command, such as `dd status=progress`.

* `RESUME`:
  Enable (`1`, the default) or disable automatic resume of interrupted syncs.

## REPLICATION OPTIONS

* `SNAP_NAME`:
  Specify a snapshot name. Use the form `$(my_snapshot_program)` to use a dynamically generated snapshot. The default is `$(date -u +zelta_%Y-%m-%d_%H.%M.%S)`.

* `SNAP_MODE`:
  Specify when to snapshot during a `zelta backup` operation. Options: `0` (never), `IF_NEEDED` (default, only if source has new data), or `ALWAYS`.

* `SYNC_DIRECTION`:
  If both endpoints are remote, use `PULL` (the default) or `PUSH` sync. If set to `0`, traffic will stream through the local host. Note that this feature PUSH and PULL features require appropriate ssh configurations with keys properly installed and/or ssh agent forwarding enabled.

## CLONE OPTIONS
* `CLONE_DEFAULT`:
  Options for recursive cloning. Defaults to `-po readonly=off`.

## POLICY OPTIONS

* `RETRY`:
  Retry failed syncs the indicated number of times.

* `JOBS`:
  Run the indicated number of policy jobs concurrently, one for each Site in the configuration.

* `BACKUP_ROOT`:
  The relative target path for backup jobs. For example, `bkhost:tank/Backups` would place backups below that dataset (if not overridden by policy).

* `ARCHIVE_ROOT`:
  NOT YET IMPLEMENTED. The relative target path used for rotated clones.

* `HOST_PREFIX`:
  Include the source hostname as a parent of the synced target, for example, `tank/Backups/source.host/backup-dataset`.

* `DS_PREFIX`:
  Similar to `zfs recv -d` and `-e`, include the indicated number of parent labels for the target's synced name. See `zelta help backup` for more detail.

## SEE ALSO

**zelta(8)**, **zelta-backup**, **zelta-clone(8)**, **zelta-match(8)**, **zelta-policy(8)**, **zelta-rotate(8)**, **zelta-sync(8)**, **cron(1)**, **ssh(1)**, **zfs(8)**

## AUTHORS
Daniel J. Bell <bellhyve@zelta.space>

## WWW

https://zelta.space

https://github.com/bellhyve/zelta
