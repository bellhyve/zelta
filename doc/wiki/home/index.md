# Zelta Backup and Recovery Suite

## Documentation Index

Zelta provides safe ZFS backup and recovery operations that remain straightforward to deploy and operate.

Zelta orchestrates backup operations across modern Unix systems. It has zero package dependencies and can run from an orchestrator without being installed on the ZFS endpoints.

> **Zelta requires ZFS.** If ZFS isn't yet part of your workflow, see [Getting Started with ZFS](/conf/zfs) to begin.



## Getting Started



Learn about Zelta and get your first backups running.

- **[About Zelta](/home/about):** Project overview and design philosophy.
- **[Definitions & Features](/home/overview):** Endpoints, dataset trees, and backup operations.
- **[First Backup](/home/start):** Create a backup with `zelta backup` and verify it with `zelta match`.
- **[Installation & Configuration](/home/install):** Deploy, configure, and customize Zelta for your server or fleet.
- **[FAQ](/home/faq):** Answers to common questions.



## Core Tools



All Zelta commands operate recursively on dataset trees and work locally or remotely via SSH.

See the complete [Manual Pages](/man) index for command references.

- **[Manual: zelta](/man/zelta):** Overview of the Zelta suite and common options.
- **[Manual: zelta backup](/man/zelta-backup):** Backup with safe defaults, incremental detection, and optional pre-backup snapshots.
- **[Manual: zelta match](/man/zelta-match):** Compare dataset trees and report matching snapshots or discrepancies.
- **[Manual: zelta policy](/man/zelta-policy):** Automate concurrent backup operations using policy-based configuration.
- **[Manual: zelta clone](/man/zelta-clone):** Create temporary read-write clones for testing, recovery, or inspection.
- **[Manual: zelta revert](/man/zelta-revert):** Rewind a dataset in place by renaming and cloning, preserving current state.
- **[Manual: zelta rotate](/man/zelta-rotate):** Keep backups rolling after divergence by preserving all versions.
- **[Manual: zelta snapshot](/man/zelta-snapshot):** Create recursive snapshots on local or remote endpoints.
- **[Manual: zelta prune](/man/zelta-prune):** Plan snapshot pruning without destroying data.
- **[Manual: zprune](/man/zprune):** Validate and destroy snapshots selected by `zelta prune`.
- **[Manual: zelta failover](/man/zelta-failover):** Promote a backup target through a guarded failover workflow.
- **[Manual: zelta rebase](/man/zelta-rebase):** Rebase a dataset onto an upgraded upstream while preserving local files and backup continuity.
- **[Guide: Zelta Twin](/guides/twin):** Compose asynchronous cluster pairs from reciprocal backup policy and guarded failover commands.



## Guides

See the complete [Guides](/guides) index.


- **[Simple Backups](/guides/backup):** Create and verify direct backups.
- **[Policy-Based Automatic Backups](/guides/policy):** Run multiple backup jobs from configuration.
- **[Zelta Twin](/guides/twin):** Asynchronous cluster pairs and guarded failover.
- **[Failover Workflows](/guides/sync):** Backup, lock/unlock, propsync, and failover.
- **[Rollback & Recovery](/guides/recovery):** Snapshots, clones, revert, and rotate.
- **[Retention Strategies](/guides/retention):** Plan snapshot retention and safe destruction.
- **[JSON Output](/guides/json):** Machine-readable output for monitoring.



## Configuration Examples

See the complete [Configuration](/conf) index.


- **[Environment & Policy Files](/conf/env):** Which file to edit, syntax, and precedence.
- **[Configuration: ssh](/conf/ssh):** SSH best practices for efficient ZFS backup.
- **[Configuration: zfs allow](/conf/zfs-allow):** Set up ZFS permissions with minimal access.
- **[Configuration: zelta.conf](/conf/zelta-conf):** Policy configuration for complex backups.
- **[Configuration: zelta.env](/conf/zelta-env):** Override default behavior, snapshot names, and `zfs` options.
- **[Configuration: zfs](/conf/zfs):** Getting started with ZFS for new users.



### [Next Page: About](/home/about)
