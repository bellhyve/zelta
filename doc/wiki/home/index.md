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
- **[Manual: failover helpers](/man/zelta-failover):** `zelta lock`, `zelta unlock`, and `zelta propsync` are lower-level failover workflow commands.
- **[Guide: Zelta Twin](/guides/twin):** Compose asynchronous cluster pairs from reciprocal backup policy and guarded failover commands.



## Configuration Examples



- **[Configuration: ssh](/conf/ssh):** SSH best practices for efficient ZFS backup.
- **[Configuration: zfs allow](/conf/zfs-allow):** Set up ZFS permissions with minimal access.
- **[Configuration: zelta.conf](/conf/zelta-conf):** Policy configuration for complex backups.
- **[Configuration: zelta.env](/conf/zelta-env):** Override default behavior, snapshot names, and `zfs` options.
- **[Configuration: zfs](/conf/zfs):** Getting started with ZFS for new users.



### [Next Page: About](/home/about)
