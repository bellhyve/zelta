# Zelta Replication Suite

**Zelta** is a suite of tools offering a streamlined approach to managing ZFS snapshot replication across systems. It's built with the intention of simplifying complex ZFS functions into safe and user-friendly commands while also being the foundation for large-scale backup and failover environments. It's easy and accessible while working with most UNIX and UNIX-like base systems without additional packages. It's optimized for environments with strict permission separation, and integrates well into many types of existing ZFS workflows.

Zelta can be used to safely perform workstation backups with a single command, but it was designed for large environments with significant regulatory compliance concerns. Zelta is currently being used in production to replicate millions of snapshots across hundreds of systems automatically and in tandem with alerting and analytics systems.

The suite comprises three main components:

- `zelta match`: Compares two ZFS dataset trees, reporting matching snapshots or discrepancies. It's a helpful tool for replication assistance, rollback assistance, and source-backup validation.
- `zelta replicate`: A robust ZFS dataset tree replication tool with safe defaults.
- `zelta policy`: A policy-based backup tool for managing extensive replication jobs.

There are additional functions and shortcuts:
- `zelta backup`: A synonym for `zelta replicate` that adds a snapshot before replication if new source data was written, performs additional safety checks, and gives recommendations if a conflict occurs.
- `zelta sync`: A synonym for `zelta replicate` that only replicates the latest snapshots, e.g., for faster migration.
- `zelta clone`: Creates a read-write view of dataset tree for inspection and recovery.
- `zelta snapshot`: A simple but customizable (local or remote) snapshot tool.

Additional features are being tested and are coming soon:
- `zelta clone` enhancements: Replicate divergent rollback trees to ensure you never lose a single byte.
- `zelta prune`: A tool to identify snapshots to prune based on snapshot size and creation dates.
- ZFS list caching: Speed up continuous sync operations with snapshot name prediction.
- Non-ZFS backend storage: Back up and restore streams from arbitrary local and cloud storage systems.

By "safe", we mean:
- Zelta can snapshot conditionally before replication if to ensure a backup is as up-to-date as possible.
- Zelta replicates read-only by default and resets ("inherits") mountpoints below the parent dataset to avoid dangerous overlapping mounts.
- Zelta does not have a force overwrite option, but provides assistance with `zfs rollback` and related operations. A cloning feature is in active development to eliminate the common ZFS admin habit of destroying divergent datasets.

Zelta is designed with Unix philosophy in mind. It is modular, extensible, and almost anything (including our safe defaults) can be changed with a tiny bit of elbow grease. Since Zelta commands and switches are designed with the similar flags and phrases as the upstream ZFS tools, it's an excellent teaching tool for new ZFS administrators.


## Quick-Start
To install, go to the top of the cloned repo and run: `./install.sh`
Given `pool1` and `pool2` on a local system, you can back up one to the other with: `zelta backup pool1 pool2/pool1-backup`


## Detailed Instructions
You do **not** need to be root to perform ZFS replication, but additional setups steps are required to create users and set up `zfs allow`. Additionally, working with remote systems requires setting up your infrastructure for efficient use of `ssh`. Documentation and examples can be found on our [wiki](https://github.com/bellhyve/zelta/wiki/Home-&-FAQ). We are actively adding use case examples and updating the manpage drafts to reflect Zelta's active feature development.

Point-of-use documentation is also provided in the installed examples:
- [zelta.conf](https://github.com/bellhyve/zelta/blob/main/zelta.conf) for policy-based backups
- [zelta.env](https://github.com/bellhyve/zelta/blob/main/zelta.env) for location and behavior overrides
- `zelta help` (From the command line.)


## Early-Release Software Notice, and a Commitment to Safety and Community Collaboration

Zelta, although a recent addition to GitHub, has been rigorously used in production for over five years. It has successfully managed the replication of millions of datasets, with a primary emphasis on safety. We're currently refining features, finalizing command names, and enhancing documentation.

We invite individuals of all technical backgrounds who want to protect both personal and organizational mission-critical data to collaborate with us. Your input is crucial in making Zelta, and ZFS at large, more accessible and user-friendly. By engaging with us, you'll not only contribute to the development of Zelta but also gain the opportunity to receive direct support and insights from our team at [Bell Tower](https://belltower.it/).


## Goals and Methodology

ZFS's versatility is unparalleled in the open source world, but users of all experience levels wrestle with its complex command structures with non-intuitive and often destructive defaults. Zelta addresses this by providing streamlined commands and safer defaults for common backup and migration tasks.

The act of simply backing up a boot drive with the basic ZFS commands (`zfs send -R zroot@latest | zfs receive backup/zroot`) is difficult to construct and will likely result in errors, overlapping mounts, and sometimes lost data. Zelta simplifies this process to:
- `zelta backup zroot backup/zroot`: Backs up the latest `zroot` snapshots to `backup/zroot`
- `zelta match zroot backup/zroot`: Confirms that the latest snapshots on the backup are identical.

Zelta is both safer and easier to use, and simplifies complex backup and migration tasks for experts. We find it to be ideal for both routine maintenance and complex tasks like fleet backup management and asynchronous clustering. Zelta **never** destroys target data, but provides tools to help delicately untangle mismatched replicas.

Zelta works with any snapshot management system or system scheduler. It's currently used to back up thousands of datasets in conjunction with [zfsnap](https://github.com/zfsnap/zfsnap), however, basic snapshot and pruning features are being added to Zelta that will be sufficient for many users. See the `zelta.env` example to change Zelta's naming schemes.

## Installation Notes

- The scripts were written on FreeBSD's built-in (Kernighan) awk.
- All updates to the main branch are additionally tested on Illumos, MacOS, and Debian GNU/Linux with the packages nawk, mawk, and gawk.
- PLEASE open an issue if Zelta is not working as expected on your system; see the FAQ for know problems and workarounds.
- Make sure ssh auth and "zfs allow" is correctly configured for all involved systems.


## Future

See Zelta's issues for active development notes. An older version of Zelta contained a configuration editor and socat/netcat support, but in practice they weren't as useful as expected. Priorities include basic snapshot and pruning tools, as well as providing assistance to untangling mountpoint/canmount/readonly dataset trees to protect from the need to clobber backups and overlapping mountpoints.


## History

Zelta evolved from a series of Bourne scripts deployed on October 7, 2019, later renamed to `zdelta`. The first production awk version of Zelta was deployed on September 1, 2021.
