% zelta-replicate(8) | System Manager's Manual
# NAME

**zelta replicate** - Replicate ZFS datasets using incremental send/receive.

# SYNOPSIS

**zelta replicate** [**-d** _depth_] [_initiator_] _source/dataset_ _target/dataset_

# DESCRIPTION

**zelta replicate** performs a recursive ZFS snapshot replication from a _source_ dataset to a _target_ dataset, using incremental **zfs send | zfs receive** semantics. Replication may be performed locally or on a remote host via SSH.

The target dataset will be created if it does not exist. Snapshot naming and retention behavior are governed by the active Zelta policy and environment configuration.

Replication preserves dataset properties where supported by ZFS, and will resume incrementally when common snapshots exist between source and target.

# OPTIONS

A _source_ and _target_ dataset parameter are required.

**_source/dataset_**
:    A dataset, in the form **pool[/component]**, to be replicated along with all of its descendents.

**_target/dataset_**
:    The destination dataset where replicated datasets and snapshots will be received.

**initiator**
:    A remote host, accessible via SSH, where the replication commands will be executed.

**--snapshot**
:    Take a snapshot before replication. See `zelta.env.example` to adjust the naming scheme.

**--full**
:    Force a full replication, ignoring existing snapshots.

**-n, --dryrun**
:    Don't replicate, but show the `zfs send` and `zfs receive` commands that would be executed.

**-q**
:    Reduce verbosity.

**-v**
:    Increase verbosity.

**-d _depth_, --depth _depth_**
:    Limits the depth of all Zelta operations.

# EXAMPLES

**Replicate a dataset tree to a backup pool:**

```sh
zelta replicate tank/data backup/data