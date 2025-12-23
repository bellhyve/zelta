% zelta-sync(8) | System Manager's Manual
# NAME

**zelta sync** - Synchronize dataset state between peers.

# SYNOPSIS

**zelta sync** [**-d** _depth_] [_initiator_] _source/dataset_ _target/dataset_

# DESCRIPTION

**zelta sync** ensures that the _target_ dataset mirrors the snapshot state of the _source_ dataset. Unlike replication, synchronization may include the removal of snapshots that no longer exist on the source, resulting in an exact snapshot set match.

This operation is commonly used to enforce strict consistency between primary and secondary systems.

# OPTIONS

A _source_ and _target_ dataset parameter are required.

**_source/dataset_**
:    The authoritative dataset whose snapshot state will be mirrored.

**_target/dataset_**
:    The dataset to be synchronized to match the source snapshot state.

**initiator**
:    A remote host, accessible via SSH, where the sync commands will be executed.

**--prune**
:    Remove snapshots on the target that do not exist on the source.

**-n, --dryrun**
:    Don't sync, but show the commands and snapshot changes that would occur.

**-q**
:    Reduce verbosity.

**-v**
:    Increase verbosity.

**-d _depth_, --depth _depth_**
:    Limits the depth of all Zelta operations.

# EXAMPLES

**Synchronize a backup dataset with its source:**

```sh
zelta sync tank/data backup/data