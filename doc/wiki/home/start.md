# Quick Start Guide

Welcome to Zelta! This guide will get you syncing ZFS datasets in minutes. We'll cover installation, basic operations, and setting up automated policy-based replication.

Zelta has been battle-tested in production for over six years, managing tens of millions of snapshots. It runs on most UNIX and UNIX-like systems with zero package dependencies—just Bourne shell and AWK.

---

## Installation

### From Source (Recommended)

```sh
git clone https://github.com/bellhyve/zelta.git
cd zelta
sudo ./install.sh
```

The installer chooses system-wide defaults when run as root and user-local defaults otherwise. For custom install paths, see [Installation & Configuration](/home/install).

### FreeBSD Ports

Zelta 1.0 (March 2024) is available in FreeBSD ports. For the latest features in v1.1, install from GitHub.

```sh
pkg install zelta
```

For detailed installation instructions and configuration options, see [Installation & Configuration](/home/install).

---

## Before You Begin

### Understanding Endpoints

Zelta uses an SCP-like syntax to specify datasets and snapshots:

**Format:** `[username@][hostname:]pool[/dataset][@snapshot]`

**Examples:**
- Local dataset: `tank/data`
- Remote dataset: `server10.biz:tank/files`
- Remote with user: `backup@server11.biz:pool/stuff`
- Remote snapshot: `twin@server12.biz:sink/log@today`

### Key Defaults

- **Recursive by default:** All operations work on entire dataset trees
- **Safe by default:** Replicas are created as `readonly=on`
- **Remote-first:** Every command works the same locally or remotely
- **No root required:** Use `zfs allow` for delegation

---

## Non-Root Operation

**Zelta does not need to be installed on backup sources or targets.** Using SSH keys and agent forwarding, you can manage all replication from a secure bastion host.

**Plus, there's no need to run Zelta as root.** Using ZFS delegation and SSH keys, you can safely replicate datasets with limited access to keep your backup servers and orchestrators as hardened as possible.

### Quick Setup

On source systems, delegate send permissions:
```sh
# As root, grant minimal permissions to backup user
zfs allow -u backupuser bookmark,hold,send,snapshot sink/data
```

On target systems, delegate receive permissions:
```sh
# As root, grant receive permissions
zfs allow -u backupuser canmount,clone,compression,create,mount,readonly,receive,recordsize,rename tank/backups
```

The above provides a useful set of compatible permissions for a wide array of backup and recovery scenarios. Your specific `zfs allow` options should be tuned to take advantage of your particular replication scenario and the latest ZFS features available. See our detailed guides:
- [SSH Configuration](/conf/ssh)
- [ZFS Allow Delegation](/conf/zfs-allow)

---

## Basic Operations

### 1. Compare Two Dataset Trees

Before replicating, let's see what we're working with:

```sh
zelta match tank/data tank/backups/data
```

This shows you the relationship between two dataset trees—matching snapshots, discrepancies, or if oen side is missing. It's essential for validating replication and planning your backup strategy.

### 2. Create Your First Backup

Replicate a dataset tree to a local backup:

```sh
zelta backup tank/data tank/backups/data
```

**What just happened:**
- Zelta detected that the target doesn't exist and created it
- A snapshot was created on the source (if needed)
- The entire `tank/data` tree was replicated recursively
- The target was set to `readonly=on`
- The target mountpoints were reset to `inherit`

Run the same command again later to update incrementally. Zelta automatically detects the optimal `zfs send` method.

### 3. Replicate to a Remote System

The syntax is identical for remote replication:

```sh
zelta backup tank/data backup@storage.example.com:pool/backups/data
```

Zelta uses SSH to stream the replication. Make sure you've set up SSH keys and `zfs allow` permissions on both systems.

### 4. Verify the Replication

Confirm everything matches:

```sh
zelta match tank/data backup@storage.example.com:pool/backups/data
```

You should see matching snapshots across the entire tree.

---

## Policy-Based Replication

For managing multiple replication jobs, `zelta policy` automates the process using a configuration file. This is ideal for production environments where you're backing up dozens or hundreds of datasets.

### Configuration File

The default policy file is located at `/usr/local/etc/zelta/zelta.conf`. Here's a simple example:

```yaml
# /usr/local/etc/zelta/zelta.conf

# Global settings (optional)
SNAP_NAME: "$(date -u +auto-%Y-%m-%d_%H-%M)"

# Site names like "Production" are used for organization
# and setting backup job concurrency.
Production:
  # Source hostname: app-server-01
  app-server-01:
    - tank/www: backups/app-server-01/www
    - tank/database: backups/app-server-01/database
  
  # Source hostname: app-server-02
  app-server-02:
    - tank/www: backups/app-server-02/www
    - tank/cache: backups/app-server-02/cache
```

**Breaking it down:**
- `Production` is the user-defined site name
- `app-server-01` and `app-server-02` are source hostnames
- `tank/www`, `tank/database`, etc. are source datasets
- `backups/app-server-01/www`, etc. are local target replicas

**About `SNAP_NAME`:** This creates timestamped snapshots using your system's `date` command. You can customize this to match your preferred naming convention, or leave it blank to use the default of `zelta_YYYY-MM-DD_H.M.S`.

### Running Policy-Based Replication

Execute all backup jobs defined in the policy:

```sh
zelta policy
```

Run a specific site:

```sh
zelta policy Production
```

Run only a specific host within a site:

```sh
zelta policy app-server-01
```

Run only a specific dataset:

```sh
zelta policy tank/www
```

### Scheduling Automated Backups

Use cron or your system's scheduler to run `zelta policy` automatically:

```sh
# Example crontab entry: run every 6 hours
PATH=/usr/local/bin:/usr/bin:/bin
0 */6 * * * zelta policy
```

For production environments, consider:
- Running from a dedicated backup bastion host
- Using SSH agent forwarding for key management
- Monitoring replication status with `zelta match`
- Testing recovery procedures regularly

---

## Next Steps

You now have the basics of Zelta replication. Here are some directions to explore:

### Learn More Commands
- `zelta revert`: Roll back a dataset in place without losing current state
- `zelta rotate`: Handle divergent histories without destructive receives
- `zelta clone`: Create temporary read-write copies for testing

Run `zelta usage` for quick command reference, or `zelta help` for the full manual.

### Advanced Topics
- [Installation & Configuration](/home/install): Detailed setup instructions
- [SSH Configuration](/conf/ssh): Secure remote replication setup
- [ZFS Allow Delegation](/conf/zfs-allow): Fine-grained permission management
- [Core Concepts](/home/concepts): Understanding Zelta's terminology and workflow

### Get Help

- **Documentation:** [zelta.space](https://zelta.space)
- **Issues & Features:** [GitHub Issues](https://github.com/bellhyve/zelta/issues)
- **General ZFS Support:** [PracticalZFS Community](https://discourse.practicalzfs.com)
- **Commercial Support:** [Bell Tower](https://belltower.it)

---

## Real-World Example: Complete Backup Workflow

Here's a practical example showing a complete backup workflow from initial setup to automated replication:

```sh
# 1. Set up delegation on source (as root)
ssh root@app-server-01 "zfs allow -u backupuser send,snapshot,hold tank/www"

# 2. Set up delegation on target (as root)
zfs allow -u backupuser create,mount,canmount,readonly,receive tank/backups

# 3. Initial replication (as backupuser)
zelta backup backupuser@app-server-01:tank/www tank/backups/app-server-01/www

# 4. Verify the backup
zelta match backupuser@app-server-01:tank/www tank/backups/app-server-01/www

# 5. Add to policy configuration
cat >> /usr/local/etc/zelta/zelta.conf << 'EOF'

Production:
  app-server-01:
    - tank/www: backups/app-server-01/www
EOF

# 6. Run policy-based replication
zelta policy

# 7. Schedule automated backups
echo "0 */6 * * * /usr/local/bin/zelta policy" | crontab -
```

That's it. You now have automated, incremental, cryptographically verified backups running every 6 hours. No daemons, no configuration drift, no bull.
