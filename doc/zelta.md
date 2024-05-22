% zelta(8) | System Manager's Manual

# NAME
**zelta** - Perform remote and recursive ZFS operations

# SYNOPSIS
        zelta SUBCOMMAND

# DESCRIPTION
**zelta** simplifies **zfs** tasks involving a datasets and their children ("dataset trees") on local or remote systems. Most **zelta** subcommands accept a _source_ and _target_ dataset or remote dataset endpoint accessible via **ssh(1)**.

See the **zfs(8)** manual for more information about dataset names. A _source_ dataset may be pool name (a single element).

Remote dataset endpoints are defined similar to the **scp(1)** command in the form [user@]host:[dataset].

A local dataset:

    apool
    apool/filesystem
    apool/filesystem@snapshot
    apool/filesystem/volume
    apool/filesystem/volume#bookmark

A remote dataset endpoint:

    twin@example.com:apool
    twin@example.com:apool/volume@snapshot
    example.com:bpool/filesystem


# SUBCOMMANDS
Zelta's parameters attempt to follow ZFS conventions whenever possible.

**zelta help**

**zelta -?**
:    Displays a help message.

**zelta -V, --version**

**zelta version**
:    Displays the Zelta suite version


## Comparison
See **zelta-match(8)** for more details.

**zelta match**
:    Describe the difference between dataset trees.

## Replication & Cloning
Note that **zelta** is designed to be a safe and efficient backup tool that overides ZFS's destructive and obtrsive operations by default. For detail see **zelta-backup(8)** or the [Zelta Wiki](https://zelta.space/home).

**zelta backup**
:    Replicate a dataset tree. By default run extra commands to detect optimal zfs send options, snapshot if necessary, and replicate as many intermediate datasets as possible.

**zelta sync**
:    Replicate a dataset tree. By default, assume an up-to-date versions of ZFS and replicate only the most recent snapshot.

**zelta clone**
:    Clone and mount a dataset tree.

## Policy-based Replication

**zelta policy**
:    Use **zelta.conf** to replicate dataset trees using a configuration file.

## Other Zelta Functions
The following are additional Zelta utilities that are used internally and/or haven't been designed for public use.

**zelta enpoint**
:    Validate and split an endpoint definiton.

**zelta report**
:    An example API reporter.

**zelta sendopts**
:    Determine compatible **zfs send** options between two hosts.

**zelta snapshot**
:    Create a recursive snapshot.

**zelta time**
:    If **time(1)** is unavailable, Zelta will use bash's POSIX time function to time for precision reporting.

# SEE ALSO
cron(8), ssh(1), zfs(8)

# AUTHORS
Daniel J. Bell _<bellta@belltower.it>_

# WWW
https://zelta.space
