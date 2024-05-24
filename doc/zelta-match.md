% zelta-match(8) | System Manager's Manual

# NAME

**zelta match** - Describes the relationship between a dataset tree and its replica.


# SYNOPSIS

**zelta match** [**-Hp**] [**-d** _depth_] [**-o** _field_[,...]] _source-endpoint_ _target-endpoint_


# DESCRIPTION

`zelta match` recursively displays a dataset and its children, similar to the `zfs list -r` command, except it compares common dataset between the _source_ dataset tree and its _target_ replica. Instead of ZFS Properties, `zelta match` displays fields describing differences and similarities between the two dataset trees. This is especially useful for assisting with replication operations and confirming backups.

**-d _depth_, --depth _depth_**
:    Limit recursion to dataset depth, e.g., **-d1** will report on the topmost dataset only.

**-H**  Used for scripting mode.  Do not print headers and separate fields by a single tab instead of arbitrary white space.

**-p**  Display numbers in exact, machine-readable values, instead of units such as B, K, M, or G.

**-n, --dryrun**
:    Show the `zfs list` commands instead of executing them.

**-o _field_[...]**
:    A comma-separated list of properties to display. See the **Field Options** or `zelta match -?` for details.

**-q**  Decrease verbosity.

**-v**  Increase verbosity.

**--W, --no-written**
:    Don't estimate sizes by retrieving the "written" property; this significantly speeds up operation, but may incorrectly report replicability, .e.g., if the _target_ has been modified.
 
 
# FIELD OPTIONS

| FIELD        | VALUES                                                      |
|--------------|--------------------------------------------------------------|
| rel_name     | '' for top or relative ds name                             |
| sync_code    | octal bits describing ds sync state                       |
| match        | matching snapshot (or source bookmark)                    |
| xfer_size    | sum of unreplicated source snapshots                     |
| xfer_num     | count of unreplicated source snapshots                   |
| src_name     | full source ds name                                       |
| src_first    | first available source snapshot                          |
| src_next     | source snapshot following 'match'                        |
| src_last     | most recent source snapshot                              |
| src_written  | data written after last source snapshot                 |
| src_snaps    | total source snapshots and bookmarks                    |
| tgt_name     | full target ds name                                      |
| tgt_first    | first available target snapshot                         |
| tgt_next     | target snapshot following 'match'                       |
| tgt_last     | most recent target snapshot                             |
| tgt_written  | data written after last target snapshot                |
| tgt_snaps    | total target snapshots and bookmarks                   |
| info         | description of the ds sync state                        |

# EXAMPLES

**Basic Comparison:** Compare snapshots between local source and target datasets.

```sh
zelta match tank/source/dataset tank/target/dataset
```

**Remote Comparison:** Compare snapshots and show the size in bytes of missing snapshots on the second system.

```sh
zelta match -v user@remote.host1:tank/source/dataset user2@remote.host2:tank/target/dataset
```

**Quick backup integrity check:**  Compare the top two levels of similar backup repositories to see which backups might be missing or out of between each host.

```sh
zelta match -d1 backuphost:rust101/Backups rust000/Backups
```

**Dry Run:** Display the `zfs list` commands without executing them.

```sh
zelta match -n tank/source/dataset tank/target/dataset
```

# SEE ALSO
ssh(1), zelta(8), zfs(8)

# AUTHORS
Daniel J. Bell _<bellta@belltower.it>_

# WWW
https://zelta.space
