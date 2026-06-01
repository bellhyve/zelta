# Zelta Backup and Recovery Suite

## Documentation Index



Zelta provides bulletproof backups that meet strict compliance requirements while remaining straightforward to deploy and operate. It transforms
complex backup and recovery operations into safe, auditable commands—protecting your data without requiring specialized expertise.



Zelta orchestrates backup operations across any modern Unix system. It has been battle-tested in production for over six years, managing tens of
millions of snapshots across thousands of systems—with zero package dependencies.



> **Zelta requires ZFS.** If ZFS isn't yet part of your workflow, see [Getting Started with ZFS](/conf/zfs) to begin.



## Getting Started



Learn about Zelta and quickly get your backups running.



- **[About Zelta](/home/about):**

Learn about the Zelta project and its design philosophy: compliance-ready, safe defaults, zero footprint, and portable.



- **[Definitions & Features](/home/overview):**

Understand core Zelta concepts including endpoints, dataset trees, and backup operations.



- **[Quick Start](/home/start):**

Create a backup with `zelta backup` and verify it with `zelta match`.



- **[Installation & Configuration](/home/install):**

Deploy, configure, and customize Zelta for your server or fleet, including an overview of `zelta policy`.



- **[FAQ](/home/faq):**

Answers to common questions.



## Core Tools



All Zelta commands operate recursively on backup sets and work locally or remotely via SSH.



- **[Manual: zelta](/man/zelta)**

Overview of the Zelta suite and common options.



- **[Manual: zelta backup](/man/zelta-backup)**

Robust backup with safe defaults, intelligent incremental detection, and optional pre-backup snapshots.



- **[Manual: zelta match](/man/zelta-match)**

Compare dataset trees and report matching snapshots or discrepancies.



- **[Manual: zelta policy](/man/zelta-policy)**

Automate large-scale concurrent backup operations using policy-based configuration.



- **[Manual: zelta clone](/man/zelta-clone)**

Create temporary read-write clones for testing, recovery, or inspection without disturbing the original.



- **[Manual: zelta revert](/man/zelta-revert)**

Rewind a dataset in place by renaming and cloning, preserving current state.



- **[Manual: zelta rotate](/man/zelta-rotate)**

Keep backups rolling after divergence by preserving all versions without destructive receives.



- **[Manual: zelta snapshot](/man/zelta-snapshot)**

Create recursive snapshots on local or remote endpoints.



- **[Manual: zelta prune](/man/zelta-prune)** *(Experimental)*

Identify snapshots eligible for deletion based on backup state and retention windows.



## Configuration Examples



- **[Configuration: ssh](/conf/ssh)**

SSH best practices for efficient ZFS replication.



- **[Configuration: zfs allow](/conf/zfs-allow)**

Set up ZFS permissions to replicate data with minimal access.



- **[Configuration: zelta.conf](/conf/zelta-conf)**

Policy configuration for complex backups.



- **[Configuration: zelta.env](/conf/zelta-env)**

Override Zelta's default behavior, including auto-snapshot names and `zfs` options.



- **[Configuration: zfs](/conf/zfs)**

Getting started with ZFS for new users.



### [Next Page: About](/home/about)
