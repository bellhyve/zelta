![Zelta Logo](https://zelta.space/index/zelta-banner.svg)

# About the Zelta Replication Suite

[Zelta Wiki](https://zelta.space)

**Zelta** is a suite of tools offering a streamlined approach to managing ZFS replication across systems. It's built with the intention of simplifying complex ZFS functions into safe and user-friendly commands while also being the foundation for large-scale backup and failover environments. It's easy and accessible while working with most UNIX and UNIX-like base systems without additional packages. It's optimized for environments with strict permission separation and integrates well into many types of existing ZFS workflows.

Zelta can be used to safely perform workstation backups with a single command, but it was designed for large environments with significant regulatory compliance concerns. Zelta is currently being used in production to replicate millions of snapshots across hundreds of systems automatically and in tandem with alerting and analytics systems.

All Zelta tools operate recursively on a dataset and its children ("dataset trees") and all commands work locally or between systems remotely accessible via SSH.

The suite comprises three main components:

- `zelta match`: Compares two ZFS dataset trees, reporting matching snapshots or discrepancies. It's a helpful tool for replication assistance, rollback assistance, and source-backup validation.
- `zelta backup`: A robust ZFS dataset tree replication tool with safe defaults.
- `zelta policy`: A policy-based backup tool for managing extensive replication jobs.

There are additional functions and shortcuts:
- `zelta sync`: Replicate as quickly as possible by performing minimal checks and transferring the latest data only.
- `zelta clone`: Creates a read-write view of a dataset tree for inspection and recovery.

By "safe", we mean:
- Zelta can snapshot conditionally before replication to ensure a backup is as up-to-date as possible.
- Zelta creates read-only replicas by default and resets ("inherits") mountpoints below the parent dataset to avoid dangerous overlapping mounts.
- Zelta never suggests or requires using forced deletion overwrite option, but instead provides a **--rotate** feature that performs a cloning operation to preserve divergent datasets, e.g., after a rollback or cloned sorce event.

Zelta is designed with the Unix philosophy in mind. It is modular, extensible, and almost anything (including our safe defaults) can be changed with a tiny bit of elbow grease. Since Zelta commands and switches are designed with similar flags and phrases as the upstream ZFS tools, it's an excellent teaching tool for new ZFS administrators.


## Early-Release Software Notice, and a Commitment to Safety and Community Collaboration

Although Zelta is a relatively recent addition to the open source world, it has been rigorously used in production for over five years. It has successfully managed the replication of millions of datasets, with a primary emphasis on safety. We're currently refining features and enhancing documentation.

We invite individuals of all technical backgrounds who want to protect both personal and organizational mission-critical data to collaborate with us. Your input is crucial in making Zelta, and ZFS at large, more accessible and user-friendly. By engaging with us, you'll not only contribute to the development of Zelta but also gain the opportunity to receive direct support and insights from our team at [Bell Tower](https://belltower.it/).


## Future

See Zelta's [issues](https://github.com/bellhyve/zelta/issues) for active development notes. Additional features being tested and coming soon:
- `zelta prune`: A tool to identify snapshots to prune based on metadata (rather than by name).
- ZFS list caching: Speed up continuous sync operations with snapshot name prediction, allowing for resumes and more continuous replication.
- Non-ZFS backend storage: Back up and restore streams from any local or cloud storage.


## History

Zelta evolved from a series of Bourne scripts deployed on October 7, 2019, later renamed to `zdelta`. The first production AWK version of Zelta was deployed on September 1, 2021.


## Getting Started

Continue to the [Zelta Overview](https://zelta.space/en/home/overview) to learn more.
