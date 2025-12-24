% zelta-revert(8) | System Manager's Manual
# NAME

**zelta revert** - Revert datasets to a previous snapshot state.

# SYNOPSIS

**zelta revert** [**-d** _depth_] [_initiator_] _dataset[@snapshot]_

# DESCRIPTION

**zelta revert** rolls back a dataset and all of its descendents to a specified snapshot. If no snapshot is provided, the most recent snapshot will be used.

Rollback operations are destructive and will permanently discard all changes made after the snapshot. Datasets must not be in active use. Zelta does not automatically destroy dependent clones.

# OPTIONS

A _dataset_ parameter is required.

**_dataset[@snapshot]_**
:    A dataset, optionally including a snapshot name, to which the dataset tree will be reverted.

**initiator**
:    A remote host, accessible via SSH, where the revert commands will be executed.

**--force**
:    Force rollback even if newer snapshots exist.

**-n, --dryrun**
:    Don't revert, but show the `zfs rollback` commands that would be executed.

**-q**
:    Reduce verbosity.

**-v**
:    Increase verbosity.

**-d _depth_, --depth _depth_**
:    Limits the depth of all Zelta operations.

# EXAMPLES

**Revert a dataset tree to a known-good snapshot:**

```sh
zelta revert tank/vm/myos@goodsnapshot