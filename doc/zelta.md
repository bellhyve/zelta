% zelta(8) | System Manager's Manual

# NAME
**zelta** - perform safe, recursive ZFS operations locally and remotely

# SYNOPSIS
        zelta -V | --version
        zelta SUBCOMMAND [OPTIONS] [ARGUMENTS]

# DESCRIPTION
**zelta** provides tools for ZFS replication, backup verification, dataset recovery, and policy-based automation. All operations work recursively on dataset trees and support both local and remote execution via **ssh(1)**.

Remote dataset endpoints follow **scp(1)** conventions: [user@]host:[dataset]. Operations can be performed without installing **zelta** on remote systems—only standard ZFS utilities and SSH access are required.

Examples:

    Local:  zpool/dataset@snapshot
    Remote: user@example.com:zpool/dataset@snapshot

See **zfs(8)** for dataset naming conventions.

# SUBCOMMANDS
For detailed usage of each subcommand, see the respective manual page.

**zelta help <subcommand>**

**zelta -?**
:    Display help message.

**zelta -V, --version**

**zelta version**
:    Display version information.

## Comparison

**zelta match** _source_ _target_
:    Compare two dataset trees and report matching snapshots or discrepancies. See **zelta-match(8)**.

## Replication

**zelta backup** _source_ _target_
:    Replicate a dataset tree. Creates snapshots if needed, detects optimal send options, and replicates intermediate datasets. See **zelta-backup(8)**.

**zelta sync** _source_ _target_
:    Replicate only the most recent snapshot between dataset trees. See **zelta-sync(8)**.

## Recovery and Iterative Infrastructure

**zelta clone** _dataset_ _target_
:    Create a writable clone of a dataset tree. See **zelta-clone(8)**.

**zelta revert** _dataset_
:    Rewind a dataset to a previous snapshot by renaming and cloning. Preserves current state. See **zelta-revert(8)**.

**zelta rotate** _source_ _target_
:    Preserve divergent dataset versions through rename and clone operations. See **zelta-rotate(8)**.

## Automation

**zelta policy** [_options_]
:    Execute replication operations based on configuration file definitions. See **zelta-policy(8)**.

# OPTIONS AND ENVIRONMENT
Configuration follows a hierarchy from lowest to highest precedence:

    1. Built-in defaults
    2. `/usr/local/etc/zelta/zelta.env`
    3. Policy configuration (`zelta.conf`)
    4. Environment variables
    5. Command-line arguments

See **zelta-options(8)** for details.

# FILES
**/usr/local/etc/zelta/zelta.conf**
:    Default policy configuration file.

**/usr/local/etc/zelta/zelta.env**
:    Global default setting overrides.

# EXAMPLES
Replicate a dataset to a remote host:

    zelta backup sink/data/project user@backup.example.com:tank/backups/project

Compare local and remote dataset trees:

    zelta match sink/data remote:tank/backups

Revert a dataset to its previous snapshot:

    zelta revert sink/data/project

Update a target that has diverged:

    zelta rotate sink/data/project user@backup.example.com:tank/backups/project

Back up everything defined in policy settings.

    zelta policy

# EXIT STATUS
Returns 0 on success, non-zero on error.

# SEE ALSO
**zelta-backup(8)**, **zelta-clone(8)**, **zelta-match(8)**, **zelta-options(8)**, **zelta-policy(8)**, **zelta-revert(8)**, **zelta-rotate(8)**, **zelta-sync(8)**, **cron(8)**, **ssh(1)**, **zfs(8)**

# AUTHORS
Daniel J. Bell _<bellhyve@zelta.space>_

# WWW
https://zelta.space
