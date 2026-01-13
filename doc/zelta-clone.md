% zelta-clone(8) | System Manager's Manual

# NAME

**zelta clone** - Perform a recursive clone operation.


# SYNOPSIS

**zelta clone** [**-d** _depth_] _source/dataset[@snap]_ _target/dataset_


# DESCRIPTION
`zelta clone` performs a recursive **zfs clone** operation on a dataset. This is useful for recursive duplication of dataset trees and backup inspection and recovery of a files replicated with `zelta backup`. The clones will reference the latest or indicated snapshot, and consume practically no additional space. Clones can be modified and destroyed without affecting their origin datasets.

The _source_ and _target_ must be on the same host and pool. The mountpoint will be inherited below the target parent (as provided by `zfs clone`). The _target_ dataset must not exist. To create a clone on a remote host ensure the _source_ and _target_ are identical including the username and hostname used:

Example remote operation:

    zelta clone backup@host1.com:tank/zones/data host1.com:tank/clones/data

# OPTIONS

**Required Options**

_source_
:    A dataset, in the form **pool[/dataset][@snapshot]**, which will be cloned along with all of its descendents. If a snapshot is not given, the most recent snapshot will be used.

_target_
:    A dataset on the same pool as the **source/dataset**, where the clones will be created. This dataset must not exist.

**Logging Options**

**-n, \--dryrun**
:    Don't clone, but show the `zfs clone` commands that would be executed.

**-q**
:    Reduce verbosity.

**-v**
:    Increase verbosity.

**Dataset and Snapshot Options**

**\--snapshot-always**
:    Ensure a snapshot before cloning.

**\--snapshot-name**
:    Specify a snapshot name. See `zelta.env.example` to adjust the default naming scheme.

**-d _depth_, \--depth _depth_**
:    Limits the depth of all Zelta operations.

# EXAMPLES

**Clone a dataset tree:**

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
zelta(8), zelta-backup(8), zelta-match(8), zelta-options(7), zelta-policy(8), zelta-revert(8), zelta-rotate(8), cron(8), ssh(1), zfs(8), zfs-clone(8), zfs-promote(8)

# AUTHORS
Daniel J. Bell <_bellhyve@zelta.space_>

# WWW
https://zelta.space
