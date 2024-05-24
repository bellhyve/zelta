% zelta-clone(8) | System Manager's Manual

# NAME

**zelta clone** - Perform a recursive clone operation.


# SYNOPSIS

**zelta clone** [**-d** _depth_] [_initiator_] _source/dataset_ _target/dataset_
  

# DESCRIPTION
**zelta clone** performs a recursive **zfs clone** operation on a local or indicated host. By default, it wil clone the most recent dataset and all of its descendents. The _target_ dataset must not exist. By default, the topmost dataset property `readonly=off` will be set. Note that ZFS cloning will reset (inherit) mountpoints. Clones must be created on the same pool as the source dataset.

When cloning, the _source_ can be **readonly** and not mounted, making cloning excellent for backup inspection as well as recovery of a dataset from a specific snapshot. If using **zelta clone** for recovery, consider using **zelta backup --rotate** to replicate the cloned dataset state to its backup replicas.


# OPTIONS
A _source_ and _target_ dataset parameter are required.

**_source/dataset_**
:    A dataset, in the form **pool[/component][@snapshot]**, which will be cloned along with all of its descendents. If a snapshot is not given, the most recent snapshot will be used as the clone origin.

**_target/dataset_**
:    A dataset, which must be on the same pool as the **source/dataset**, where the clones will be created. This dataset must not exist.

**initiator**
:    A remote host, accessible via SSH, where the clone commands will be executed.

**--snapshot**  Snapshot before cloning. See `zelta.env.example` to adjust the naming scheme.

**-n, --dryrun**
:    Don't clone, but show the `zfs clone` commands that would be executed.

**-q**  Reduce verbosity.

**-v**  Increase verbosity.

**-d _depth_, --depth _depth_**
:    Limits the depth of all Zelta operations.

# EXAMPLES


The _target_ clones can be destroyed without affecting their source. After cloning a dataset with a remote replica, **zelta backup --rotate**

**Clone a dataset tree for inspection:**

```sh
zelta clone tank/vm/myos tank/temp/myos-202404 
```

**Recover a dataset tree, in place, to a previous snapshot's state:**

```sh
zfs rename tank/vm/myos tank/Archives/myos-202404
zelta clone tank/Archives/myos-202404@goodsnapshot tank/vm/myos
```

**Dry Run:** Display the `zfs clone` commands without executing them.

```sh
zelta clone -n tank/source/dataset tank/target/dataset
```

# SEE ALSO
ssh(1), zelta(8), zelta-backup(8), zelta-match(8), zelta-policy(8), zfs(8), zfs-clone(8), zfs-promote(8)

# AUTHORS
Daniel J. Bell _<bellta@belltower.it>_

# WWW
https://zelta.space
