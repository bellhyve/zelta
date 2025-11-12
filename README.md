![Zelta Logo](https://zelta.space/index/zelta-banner.svg)

# The Zelta Replication Suite

[zelta.space](https://zelta.space) | [Documentation](https://zelta.space/en/home) | [GitHub](https://github.com/bellhyve/zelta)

**Zelta** is a safe and powerful suite of tools for managing ZFS replication. It simplifies complex ZFS functions into user-friendly commands, providing a robust foundation for large-scale backup and failover environments. Designed for portability, it runs on most UNIX and UNIX-like systems (including FreeBSD, Linux, and MacOS) and has no package dependencies.

Zelta has been battle-tested in production for over six years, replicating tens of millions of snapshots across thousands of systems. It is optimized for environments with strict permission separation and significant regulatory compliance concerns, but it's simple enough to safely perform a full workstation backup with a single command.

---

## Installation

### FreeBSD
Zelta is available in the FreeBSD Ports Collection.
```sh
pkg install zelta
```

### From Source (Linux, Illumos, or others)
For other systems, you can install it directly from the source repository.
```sh
git clone https://github.com/bellhyve/zelta.git
cd zelta
./install.sh
# Follow the instructions to set up the environment
```

---

## Quickstart: Laptop Backup

Zelta makes common ZFS tasks, which can be tricky or dangerous with the wrong flags, ridiculously simple. Here’s how to back up your ZFS-based laptop to a remote server and then access your backed-up files.

### 1. Perform a Backup

This command will snapshot `zroot/home` on your local machine and replicate it to `backups/my-laptop` on a server named `storage-box`. It handles creating snapshots, calculating the difference, and sending the data over SSH.

```sh
# zelta backup <source_dataset> <user@destination_host>:<destination_dataset>
zelta backup zroot backup-user@storage-box.example.com:backups/my-laptop
```

### 2. Access Your Backup Data

Need to recover a file? On the storage server, `zelta clone` creates a live, read-write copy of your backup without disturbing the original replica.

```sh
# zelta clone <readonly_backup_dataset> <new_clone_path>
zelta clone backups/my-laptop backups/my-laptop-recovery
```
Your recovered files are now available in the filesystem at the mountpoint for `backups/my-laptop-recovery`.

---

## Core Features

All Zelta tools operate recursively on a dataset and its children ("dataset trees") and work locally or remotely via SSH. The commands use flags and conventions similar to upstream ZFS tools, making Zelta an excellent teaching aid for new administrators.

*   `zelta match`: Compares two ZFS dataset trees, reporting matching snapshots or discrepancies. Ideal for validating replication, planning rollbacks, and auditing backups.
*   `zelta backup`: A robust replication tool with safe defaults, designed for creating consistent and reliable read-only replicas.
*   `zelta sync`: Performs a "fast" replication by sending only the latest common snapshot, minimizing checks for maximum speed.
*   `zelta policy`: A policy-based engine for automating complex, large-scale replication jobs across many systems with hierarchical options.
*   `zelta clone`: Creates a temporary, read-write clone of a dataset tree for data recovery, testing, or inspection.

---

## Safety by Design

Zelta prioritizes data integrity and operational safety above all else.

*   **Safe Defaults**: Replicas are created as `readonly=on` by default. Mountpoints on child datasets are reset to `inherit` to prevent dangerous overlapping mounts.
*   **Remote and Recursive**: All Zelta operations work remotely and recursively by default. It will replicate as much as possible and report clearly about discrepancies between replicas.
*   **No Forced Overwrites**: Zelta never suggests or requires a forced receive (`zfs recv -F`). Instead, the `--rotate` option preserves divergent datasets by cloning the old replica before receiving the new history.
*   **Environment Agnostic**: Zelta makes replication decisions based on metadata and available features rather than arbitrary naming patterns. Along with its portability, this makes Zelta an outstanding recovery tool for complex, mixed environments.
*   **Up-to-Date Backups**: The backup sources are checked for changes and Zelta creates snapshots before replication to ensure the backup is as current as possible.

Zelta is built on the Unix philosophy. It is modular, extensible, and nearly all behavior—including its safe defaults—can be customized with minimal effort.

---

## Roadmap

Zelta is under active development. Our current major effort is a refactor to improve POSIX compliance, enhance portability across all UNIX-like systems, and streamline the code to make future enhancements easier.

See Zelta's [GitHub Issues](https://github.com/bellhyve/zelta/issues) for active development notes. Key features currently in testing include:

*   **`zelta lock/unlock`**: Simplifies failover processes by confirming a replica is readonly before "promoting" it to be the read-write primary.
*   **Property Checking/Syncing**: Like `zelta match`, describe property and feature differences between replicas and update them.
*   **Zelta Bastion**: For maximum safety and portability, Zelta won't be required on either the source or target machine. Instead, backups can be initiated from a separate hardened instance.
*   **`zelta prune`**: A tool to identify snapshots based on flexible, metadata-driven policies rather than just by name.
*   **ZFS List Caching**: Accelerate continuous sync operations with snapshot name prediction, enabling faster resumes and more efficient replication streams.
*   **Non-ZFS Backends**: Support for backing up ZFS streams to, and restoring from, any local or cloud-based storage system.

---

## Community & Support

We welcome contributors of all backgrounds who are passionate about protecting mission-critical data. By contributing to Zelta, you help make ZFS more accessible and robust for everyone.

For commercial support, custom feature development, and consulting services related to secure and high-efficiency cloud infrastructure, please contact us at [Bell Tower](https://belltower.it/).

---

## History

Zelta evolved from a series of Bourne scripts first deployed on October 7, 2019. The first production AWK version, which forms the basis of the current tool, was deployed on September 1, 2021.
