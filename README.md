![Zelta Logo](https://zelta.space/index/zelta-banner.svg)

# The Zelta Backup and Recovery Suite
*Version 1.1.0-beta.1, 2025-12-22

---

> **⚠️ BETA NOTICE**  
> This is a beta release with significant improvements over the stable 1.0 branch. Documentation and QA are ongoing, but the codebase is solid and is actively being used in production for thousands of replication workflows.
> 
> - **Stable Release:** For the most tried-and-true version of Zelta see the [March 2024 release (v1.0)](https://github.com/bellhyve/zelta/tree/release/1.0)
> - **What's New:** Check [CHANGELOG.md](CHANGELOG.md) for the latest changes
> - **Found a Bug?** Please [open an issue](https://github.com/bellhyve/zelta/issues)
> 
> We're excited for the new changes and encourage you to try it out. Your feedback helps make Zelta better.

---

[zelta.space](https://zelta.space) | [Documentation](https://zelta.space/en/home) | [GitHub](https://github.com/bellhyve/zelta)

**Zelta** is a suite of safe, portable, and powerful tools for backup, recovery, migration, and advanced ZFS management. It simplifies complex operations into user-friendly commands while providing a robust foundation for large-scale environments with strict regulatory compliance requirements.

Zelta has been battle-tested in production for over six years, replicating tens of millions of snapshots across thousands of systems. It runs on most UNIX and UNIX-like systems (FreeBSD, Illumos, Linux, macOS) with zero package dependencies—just Bourne shell and AWK.

**Zelta does not need to be installed on backup sources or targets.** Using SSH keys and agent forwarding, you can manage replication from a secure bastion host, keeping your infrastructure clean and your attack surface minimal.

Zelta has no destructive features, is namespace agnostic, has no package dependencies, and is permissively licensed. Zelta can improve your existing ZFS workflow or product without risk or lock-in.

---

## Installation

### From Source (Recommended for v1.1)
```sh
git clone https://github.com/bellhyve/zelta.git
cd zelta
sudo ./install.sh
# The installer will guide you through setup.
# For non-root installation, see install.sh output for user-mode variables.
```

### FreeBSD Ports
Zelta 1.0 (March 2024) is available in the FreeBSD Ports Collection. For the latest features, install from GitHub.
```sh
pkg install zelta
```

---

## Quickstart: Developer Workflow

Zelta makes operations that are tricky or dangerous with raw ZFS commands ridiculously simple. Here's a real-world developer scenario showing backup, recovery, and time travel—all without destroying data.

### 1. Back Up Your Development Machine

Snapshot and replicate your entire laptop to a backup server. Zelta handles snapshot creation, incremental detection, and safe replication.

```sh
# Syntax: zelta backup <user@host:source> <user@host:target>
zelta backup rpool backup-user@storage.example.com:tank/Backups/my-laptop
```

### 2. Back Up a Container as Non-Root

Grant a regular user minimal permissions to replicate a specific dataset. This works beautifully for containerized workloads, databases, or any delegated environment.

```sh
# As root, delegate send permissions on source
zfs allow -u developer send,snapshot,hold opt

# Delegate receive permissions on backup target
zfs allow -u developer receive:append,create,mount,canmount,volmode,readonly,clone,rename tank/Backups

# As developer user, replicate
zelta backup opt/datasource/big-database-thing tank/Backups/big-database-thing
```

Run the same command again later to update incrementally. No configuration files, no daemon, no bull.

### 3. Time Travel: Revert to Previous State

You need to roll back your development dataset to investigate a bug, but you don't want to lose your current environment.

```sh
# Rewind the working dataset in place, renaming it to preserve current state
zelta revert opt/datasource/big-database-thing
```

Your dataset is now at its previous snapshot. Your current work is **still there**, just renamed to `big-database-thing_<last-snap-name>`.

### 4. Keep the Backup Rolling After Divergence

Now your source has diverged from your backup. Normally this requires manual ZFS gymnastics or destructive receives. Not with Zelta.

```sh
# Rotate the backup: preserve the old version, receive the new history
zelta rotate opt/datasource/big-database-thing tank/Backups/big-database-thing
```

Done. You now have **both versions** preserved in your backup. No force flags, no data loss, no bull. And it even works between remote datasets!

**Your cloud cannot do this.**

*These commands use modern ZFS delegation features including `receive:append` (which rejects dangerous `zfs receive -F` operations) and `volmode` for safety and consistency.*

---

## Core Tools

All Zelta commands operate recursively on dataset trees and work locally or remotely via SSH. The interface mirrors upstream ZFS conventions, making Zelta an excellent teaching tool for administrators learning ZFS.

### `zelta match`
Compares two dataset trees and reports matching snapshots or discrepancies. Essential for validating replication, planning rollbacks, auditing backups, or comparing any two dataset trees—production to backup, backup to backup, clone to origin, you name it.

### `zelta backup`
Robust replication with safe defaults. Creates consistent, read-only replicas with intelligent incremental detection and optional pre-replication snapshots to ensure backups are current.

### `zelta policy`
Automates large-scale concurrent replication operations across many systems using a policy-based engine. Supports hierarchical configuration with YAML-style policies.

### `zelta clone`
Creates a temporary read-write clone of a dataset tree (on the same pool) for recovery, testing, or inspection without disturbing the original. With the convenience of `zelta clone`, there is never a reason to make your backup datasets writable.

### `zelta revert`
Carefully rewinds a dataset in place by renaming and cloning. Ideal for forensic analysis, testing, or recovering from mistakes without losing current state.

### `zelta rotate`
Performs a multi-way rename and clone operation to keep backups rolling even after source or target has diverged. Preserves all versions without destructive receives. Your team is already telling your regulators you do this, but Zelta makes the process practical—and easy.

## Misc Tools and Synonyms

Zelta can be used with a few synonyms and shortcuts.
- `zelta snapshot`: Runs `zfs snapshot -r` on a local or remote endpoint.
- `zelta report`: A simple example Slack API reporting script that provides a 1-line report of backup status.
- `zelta sync`: Runs `zelta backup -i` which skips intermediate snapshots.
- `zelta replicate`: Runs `zelta backup -R`, which uses the recursive `zfs send -R`  option rather than Zelta's per-snapshot analysis.
- `zpull`, `zmatch`, `zp`: If symlinked or aliased to `zelta`, these legacy shortcuts can be used for `zelta backup`, `zelta match`, and `zelta policy` respectively.

---

## Safety by Design

Zelta prioritizes data integrity above all else. It has managed production environments for over six years with millions of datasets, and safety is baked into every design decision.

### Safe Defaults
- Replicas are created as `readonly=on` by default
- Child dataset mountpoints are reset to `inherit` to prevent dangerous overlapping mounts
- Snapshots are created before replication when needed to ensure up-to-date backups

### No Forced Overwrites
Zelta **never** suggests or requires destructive actions of any kind. The `zelta rotate` feature preserves divergent datasets by cloning before receiving new history.

### Remote and Recursive
All operations work remotely and recursively by default. Zelta replicates as much as possible and reports clearly about any discrepancies.

### Environment Agnostic
Replication decisions are based on metadata and available features, not naming conventions. Combined with portability, this makes Zelta an outstanding recovery tool for complex, mixed environments.

### No Installation Required on Endpoints
Zelta can run entirely from a bastion host using SSH keys or agent forwarding. Your backup sources and targets don't need Zelta installed—just standard ZFS tools and SSH. This provides outstanding security in disaster recovery design using `zfs allow`. The Zelta team at Bell Tower runs its core `zelta policy` loop from a locked-down OpenBSD system with configurations ensuring that **no** backup user has access to any unencrypted dataset throughout the entire backup workflow.

Zelta follows the Unix philosophy: modular, extensible, and customizable. Defaults can be hierarchically overridden or adjusted with minimal effort.

---

## Community & Support

The Zelta Backup and Recovery tools in this repository are open source under the BSD 2-Clause License and will always remain permissively licensed.

We welcome contributors who are passionate about data protection and recovery. By contributing to Zelta, you help make advanced backup and recovery accessible to everyone.

### Contact

We welcome questions, bug reports, and feature requests at [GitHub Issues](https://github.com/bellhyve/zelta/issues).

For other inquiries including business questions, you can reach the Zelta team at Bell Tower via our [contact form](https://belltower.it/contact/).

### Conference Talks

**BSDCan 2024: Zelta: A Safe and Powerful Approach to ZFS Replication**  
By Daniel J. Bell
[Watch on YouTube](https://www.youtube.com/watch?v=_nmgQTs8wgE&pp=ygUMemVsdGEgYmFja3Vw)

**OpenZFS Summit 2025: Responsible Replication with Zelta**  
[Watch on YouTube](https://www.youtube.com/watch?v=G3weooQqcXw)

### Bell Tower Services
For commercial support, custom feature development, and consulting on secure, high-efficiency infrastructure, contact us at [Bell Tower](https://belltower.it/). We provide consulting services for advanced policy management, cost control, compliance, and business continuity.

---

## Roadmap

Zelta 1.1 represents a major refactor improving POSIX compliance, portability, and code maintainability. The following features are already used internally or by Bell Tower clients and will be upstreamed by Q2 2026.

### Features In Development
- **zelta lock/unlock**: Simplify failover by confirming the correct twin is read-only before promoting a read-write primary.
- **zelta rebase**: Update base images across filesystems while preserving customizations, sidestepping container problems that Docker was invented to work around.
- **zelta prune**: Identify snapshots for deletion based on flexible, metadata-driven policies such as creation dates, snapshot density, and actual usage patterns.
- **Metadata-Aware Sync Protection**: Ensure backup continuity using automatic holds and bookmarks based on replica relationships, and track property changes with ZFS user properties.
- **Flexible API**: Although `zelta backup` has a JSON output mode useful for telemetry, we intend to match ZFS's new native JSON output styles for more integration options. To support larger fleets, `zelta policy` configurations are being updated to support JSON, SQLite, and other database formats.

---

## History

Zelta evolved from a series of Bourne scripts first deployed on October 7, 2019. The first production AWK version, which forms the basis of the current tool, was deployed on September 1, 2021.
