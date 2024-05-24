% zelta-backup(8) | System Manager's Manual

# NAME

**zelta backup**, **zelta sync**, **zelta clone** - Perform a recursive replication operation.


# SYNOPSIS

**zelta backup** [**-bcdDeeFhhLMpuVw**] [**-iIjnpqRtTv**] [_initiator_] _source-endpoint_ _target-endpoint_

**zelta sync** [**-bcdDeeFhhLMpuVw**] [**-iIjnpqRtTv**] [_initiator_] _source-endpoint_ _target-endpoint_

**zelta clone** [**-d** _depth_] _source-dataset_ _target-dataset_
  

# DESCRIPTION
**zelta backup** and **zelta sync** attempt to intelligently replicate snapshots from a _source_ ZFS dataset endpoint to a _target_. **zelta backup** optimizes for complete backups of all snapshots by default using a careful LBYL strategy, appropriate for typical backup jobs. **zelta sync** optimizes for efficiency using an EAFP strategy, appropriate for time-sensitive operations or controlled environemnts. Endpoints may be remotely accessible via SSH. As with **zfs receive**, the _target_ dataset endpoint must not exist or be an replica of the _source_.

Zelta is designed for simplicity and safety and is suitable for a backup server replicating datasets from many systems. To ensure safe operation, the following default options are set for new replication _targets_:
1. The property _readonly=on_ will be set.
2. Filesystems will not be mounted.
3. On filesystems, the property _canmount=noauto_ will be set. 
4. On filesystems, mountpoints will be inherited (discarded) to prevent overlapping mounts.

These defaults, as well as snapshot naming scheme and many other assumptions, can be modified with arguments or via the environment (see `zelta.env.example` for more information).

# OPTIONS
See the manuals for **zfs-send(8)** and **zfs-receive(8)** for detail on pass-through options listed below.

**[-bcdDeeFhhLMpuVw] [_--zfs-send-option_]**
:    Pass any unambiguous dashed or double-dashed option to all **zfs send** and **zfs receive** operations. Note that some options, such as `-s`, are ambiguous and must be set using the environment instead. Some options, such as `-I`, work differently in **zelta <backup|sync>**, and are described in detail below.

**-I** This is the default mode for `zelta backup`. Replicate intermediate incremental streams from the _source_ and _target's_ matching dataset to the newest. If the _target_ is new, all avaialble _source_ snapshots will be replicated.

**-i:** This is the default mode for `zelta sync`. Only replicate the latest stream from the source to the target. If the _target_ is new, only the latest _source_ snapshot will be replicated.

**-n, --dryrun**
:    Run with dry run mode. Don't replicate, but show `zfs <clone|create|get|receive|send>` commands that would be run. Note that **zelta match**, **zfs list**, and **zfs send -n** which are used to determine the anticipated replication operation will not be displayed.

**-j,--json**
:    Produce JSON output for the replication job, suppressing all other output. Stream names and error messages will be included in lists inside the JSON block. Incremental streams will be listed in the format: *@earliest-snapshot::dataset@latest-snapshot*

**-p, --progress**
:    Attempt to use a progress viewer. `pv` will be used by default, otherwise `dd status=progress` will be used.

**-q**  Reduce verbosity.

**-V**  Increase verbosity.

**-R**  Not recommended. Sets `--depth=1` and passes `-R` to the `zfs send`. See `zfs-send(8)` for details.

**-d _depth_, --depth _depth_**
:    Limits the depth of all Zelta operations.

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
