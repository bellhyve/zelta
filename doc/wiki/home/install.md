# Installation & Configuration

This guide covers installing Zelta and configuring it for your environment. Whether you're setting up a single-user backup system or managing enterprise-scale replication across multiple teams, Zelta's flexible installation model adapts to your needs.

## Table Of Contents

[System Requirements](#system-requirements)
[Installation Methods](#installation-methods)
[Installation Types](#installation-types)
[Post-Installation Setup](#post-installation-setup)
[Multiple User Configurations](#multiple-user-configurations)
[Environment Variables](#environment-variables)
[Updating Zelta](#updating-zelta)
[Uninstalling Zelta](#uninstalling-zelta)
[Environment Variables](#environment-variables)
[Convenience Aliases](#convenience-aliases)
[Next Steps](#next-steps)

---

## System Requirements

Zelta runs on any UNIX or UNIX-like system with:
- Bourne shell (`/bin/sh`)
- AWK (any POSIX-compliant implementation)
- SSH (for remote replication)

**Tested platforms:**
- FreeBSD
- Illumos (OmniOS)
- Linux (Ubuntu, Debian, RHEL)
- macOS

No package dependencies. No daemons. No configuration databases.

**Note:** ZFS is **not** required on a remote Zelta bastion (also known as an orchestrator or initiator). You can manage replication between ZFS systems from any UNIX-like host with SSH access.

---

## Installation Methods

### From Repository (Recommended)

Installing from GitHub gives you the latest features and bug fixes:

```sh
git clone https://github.com/bellhyve/zelta.git
cd zelta
sudo ./install.sh
```

The installer detects whether you're running as root and adjusts paths accordingly.

### FreeBSD Ports

Zelta 1.0 (March 2024) is available in the FreeBSD Ports Collection:

```sh
pkg install zelta
```

For the latest v1.1 features, install from source.

---

## Installation Types

The installer supports two installation modes: system-wide (root) and user-specific (non-root). Both are fully functional—the choice depends on your environment and security requirements.

### System-Wide Installation (Root)

Run the installer as root for a traditional system-wide installation:

```sh
sudo ./install.sh
```

**Default paths:**
- Binaries: `/usr/local/bin/zelta`
- AWK scripts: `/usr/local/share/zelta/`
- Configuration: `/usr/local/etc/zelta/`
- Man pages: `/usr/local/share/man/man8/` (or `/usr/share/man/man8/`)

**Files created:**
- `/usr/local/etc/zelta/zelta.env` - Environment variable defaults
- `/usr/local/etc/zelta/zelta.env.example` - Reference copy
- `/usr/local/etc/zelta/zelta.conf` - Policy configuration
- `/usr/local/etc/zelta/zelta.conf.example` - Reference copy

### User-Specific Installation (Non-Root)

Run the installer as a regular user for a personal installation:

```sh
./install.sh
```

**Default paths:**
- Binaries: `$HOME/bin/zelta`
- AWK scripts: `$HOME/.local/share/zelta/`
- Configuration: `$HOME/.config/zelta/`
- Documentation: `$HOME/.local/share/zelta/doc/`

The installer will prompt you to add these environment variables to your shell's startup script (`.bashrc`, `.zshrc`, etc.):

```sh
export ZELTA_BIN="$HOME/bin"
export ZELTA_SHARE="$HOME/.local/share/zelta"
export ZELTA_ETC="$HOME/.config/zelta"
export ZELTA_DOC="$ZELTA_SHARE/doc"
```

**Important:** Ensure `$HOME/bin`, or whichever bin directory you choose, is in your `PATH`. Zelta must be able to call its own subcommands for most operations. Be sure to `source` your shell's startup script or restart your shell and verify your environment before running `./install.sh`.

---

## Post-Installation Setup

### Verify Installation

Check that Zelta is installed and accessible:

```sh
zelta usage
```

You should see Zelta's command reference.

### Configure SSH Access

For remote replication, set up SSH keys for passwordless authentication. See [SSH Configuration](/conf/ssh) for detailed instructions.

**Quick setup:**
```sh
# Generate SSH key (if you don't have one)
ssh-keygen -t ed25519

# Copy key to remote systems
ssh-copy-id backupuser@remote-host
```

### Configure ZFS Permissions

Grant non-root users the minimum permissions needed for replication. See [ZFS Allow Delegation](/conf/zfs-allow) for comprehensive examples.

**Quick setup:**
```sh
# On source systems (as root)
zfs allow -u backupuser send,snapshot,hold tank/data

# On target systems (as root)
zfs allow -u backupuser create,mount,canmount,readonly,receive tank/backups
```

---

## Multiple User Configurations

Since Zelta is extremely portable and flexible, you can take advantage of its ability to run multiple independent configurations on the same system using different user accounts. This is **amazing** for separating concerns, implementing defense-in-depth, and managing different types of replication workflows—from conventional backups to asynchronous clustering to complex development workflows.

### Why Multiple Users?

Different replication workflows have different requirements:

- **Production Admin:** Service management, non-destructive recovery
- **Failover Admin:** Standby server replication & recovery
- **Snapshot Admin:** Snapshot scheduling & retention policies
- **Backup Admin:** Automated backup management, manual recovery
- **Retention Admin:** Pruning and redaction on backup systems

By using separate user accounts, you get:
- **Isolation:** Each user has independent configuration, logs, and SSH keys
- **Security:** Limit blast radius by granting minimal permissions per user
- **Flexibility:** Different schedules, different targets, different policies
- **Auditability:** Clear separation of duties for compliance

### Example: Three-User Setup

Here are three examples inspired by real-world Zelta accounts at Bell Tower:

#### User: `space` (Primary Backup)

**Purpose:** System-to-system backups, comprehensive and reliable

**Configuration:**
```sh
# In space's ~/.bashrc or ~/.zshrc
export ZELTA_SHARE="$HOME/.local/share/zelta"
export ZELTA_ETC="$HOME/.config/zelta"
# 'space' uses the system-wide PATH
```

**Policy file (`~/.config/zelta/zelta.conf`):**
```yaml
SNAP_MODE: 0  # We're managing snapshots elsewhere
BACKUP_ROOT: backupserver:tank/Backups
JOBS: 2

Production:
  app-server-01:
    - sink01/www
    - sink01/database
  app-server-02:
    - sink02/www
    - sink02/cache
```

**Cron schedule:**
```cron
# Every 6 hours
0 */6 * * * /usr/local/bin/zelta policy
```

#### User: `twin` (Failover Replication)

**Purpose:** Fast bidirectional replication for high-availability failover

This setup creates an active-passive HA configuration where whichever dataset is read-write will generate "written" data, which Zelta automatically snapshots and replicates to the read-only side. Both replication directions are defined in a single policy file, and Zelta intelligently determines which direction needs syncing on each run.

**The magic:** You can failover and fail back simply by toggling the `readonly` property. Set the primary read-only, verify sync, then set the secondary read-write. That's it. No Ceph, no blood magic, just ransomware-proof async failover that cannot die by garlic nor silver nor kryptonite.

**Configuration:**
```sh
# In twin's ~/.bashrc or ~/.zshrc
export ZELTA_BIN="$HOME/bin"
export ZELTA_SHARE="$HOME/.local/share/zelta"
export ZELTA_ETC="$HOME/.config/zelta"
export PATH="$ZELTA_BIN:$PATH"
```

**Policy file (`~/.config/zelta/zelta.conf`):**
```yaml
SNAP_NAME: "$(date -u +twin-%Y-%m-%d_%H-%M)"
SNAP_MODE: IF_NEEDED  # Only snapshot if source has written data (default)
SEND_INTR: 0  # Skip intermediate snapshots for faster replication
JOBS: 4

# Primary to Secondary replication
Failover:
  primary-db:
    - tank/postgres: secondary-db:sink/postgres
  primary-web:
    - tank/www: secondary-web:sink/www

# Secondary to Primary replication (for failback)
Failback:
  secondary-db:
    - sink/postgres: primary-db:tank/postgres
  secondary-web:
    - sink/www: primary-web:tank/www
```

**How it works:**

1. **Normal operation (primary active):**
   - Primary datasets are read-write, generating new data
   - `SNAP_MODE: IF_NEEDED` snapshots the primary automatically
   - `Failover` site replicates primary → secondary
   - `Failback` site does nothing (secondary is read-only, no written data)

2. **Failover procedure:**
   ```sh
   # On primary system
   zfs set readonly=on tank/postgres
   zfs set readonly=on tank/www
   
   # Verify sync (run as twin user)
   zelta match primary-db:tank/postgres secondary-db:sink/postgres
   zelta match primary-web:tank/www secondary-web:sink/www
   
   # On secondary system (promote to primary)
   zfs set readonly=off sink/postgres
   zfs set readonly=off sink/www
   ```

3. **Failback operation:**
   - Secondary (now active) generates new data
   - `SNAP_MODE: IF_NEEDED` snapshots the secondary automatically
   - `Failback` site replicates secondary → primary
   - `Failover` site does nothing (primary is read-only)

4. **Return to normal:**
   - Reverse the readonly settings to restore original primary

**Caveats:**
- Don't set both sides read-write simultaneously (split-brain)
- Always verify sync before promoting a secondary
- Don't boot both VMs/systems at the same time

**Future enhancement:** In Zelta 1.2, this will be simplified to `zelta failover source target`, which will automatically swap sync direction, promote the source to primary, and lock the target read-only.

**Cron schedule:**
```cron
# Every 15 minutes
*/15 * * * * /home/twin/bin/zelta policy
```

#### User: `rescue` (Recovery Operations)

**Purpose:** Elevated permissions for emergency recovery and reverts

Note that in addition to disaster recovery, `zelta revert` and `zelta rotate` can also be used for powerful development workflows—rolling back to previous states, testing different configurations, or managing complex dataset histories.

**Configuration:**
```sh
# In rescue's ~/.bashrc or ~/.zshrc
export ZELTA_BIN="$HOME/bin"
export ZELTA_SHARE="$HOME/.local/share/zelta"
export ZELTA_ETC="$HOME/.config/zelta"
export PATH="$ZELTA_BIN:$PATH"
```

**ZFS permissions (broader than backup users):**
```sh
# On production systems (as root)
zfs allow -u rescue send,snapshot,hold,destroy,mount,create,clone,promote tank/production
```

**Usage:**
```sh
# Rescue user performs emergency revert
zelta revert tank/production/database

# Or recover from a backup
zelta clone backup:tank/Backups/database tank/production/database-recovery
```

**No cron schedule** - This user operates on-demand only.

### Setting Up Multiple Users

1. **Create user accounts:**
   ```sh
   # As root (FreeBSD syntax shown)
   pw useradd space -m -s /bin/sh -c "Backup User"
   pw useradd twin -m -s /bin/sh -c "Failover User"
   pw useradd rescue -m -s /bin/sh -c "Recovery User"
   ```

2. **Configure Zelta for each user:**
   ```sh
   # Install as root
   git clone https://github.com/bellhyve/zelta.git
   cd zelta
   sudo ./install.sh
   # Set ZELTA_ENV for each user
   sudo su - twin
   mkdir -p "$HOME/.config/zelta"
   # Add ZELTA_ENV="$HOME/.config/zelta" to crontab and user RC
   exit
   ```

3. **Configure SSH keys:**
   ```sh
   # As each user
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
   ssh-copy-id remote-host
   ```

4. **Set ZFS permissions:**
   ```sh
   # As root, grant appropriate permissions to each user
   zfs allow -u space send,snapshot,hold sink/data
   zfs allow -u space receive:append,create,mount,canmount,volmode,readonly,clone,rename,userprop,recordsize tank/backups
   zfs allow -u twin receive:append,send:raw,create,mount,canmount,volmode,readonly,recordsize,compression,hold,bookmark,create tank/data
   zfs allow -u rescue send,snapshot,hold,destroy,mount,create,clone tank/data
   ```

5. **Create independent policy files:**
   Each user maintains their own `~/.config/zelta/zelta.conf` with different targets, schedules, and options.

---

## Environment Variables

Zelta's behavior can be customized using environment variables. Variables can be set in three places:

1. **Shell environment** - Set in your `.bashrc`, `.zshrc`, or session
2. **`zelta.env` file** - System-wide or user-specific defaults
3. **Command-line arguments** - Override everything else

### Variable Naming Rules

**Outside of `zelta.env`:** All environment variables **must** use the `ZELTA_` prefix:
```sh
export ZELTA_SNAP_NAME='$(date -u +auto-%Y-%m-%d_%H-%M)'
export ZELTA_JOBS=4
```

**Inside `zelta.env`:** The `ZELTA_` prefix is **optional** (but allowed):
```sh
# Both forms work in zelta.env
SNAP_NAME='$(date -u +auto-%Y-%m-%d_%H-%M)'
JOBS=4
```

### Special Variables

Some variables **must** be set in your shell environment because they're needed before `zelta.env` is loaded:

- `ZELTA_AWK` - Path to AWK interpreter (default: `awk`)
- `ZELTA_ENV` - Path to environment file (default: `/usr/local/etc/zelta/zelta.env`)

**Example:**
```sh
# In your ~/.bashrc
export ZELTA_AWK="/usr/bin/gawk"
export ZELTA_ENV="$HOME/.config/zelta/zelta.env"
```

### Common Environment Variables

See [Environment & Policy Files](/conf/env-policy) for a comprehensive reference. Here are the most commonly used:

- `SNAP_NAME` - Snapshot naming pattern (supports command substitution)
- `BACKUP_ROOT` - Default target root for policy-based replication
- `JOBS` - Number of concurrent replication jobs (formerly `THREADS`, backward compatible)
- `RETRY` - Number of retry attempts for failed replications
- `SEND_INTR` - Skip intermediate snapshots (0 or 1)

---

## Updating Zelta

### From Source

Pull the latest changes and reinstall:

```sh
cd zelta
git pull
sudo ./install.sh
```

The installer preserves your existing `zelta.env` and `zelta.conf` files.

### FreeBSD Ports

```sh
pkg upgrade zelta
```

---

## Uninstalling Zelta

Zelta doesn't install system services or modify system files outside its installation directories. To uninstall:

### System-Wide Installation

```sh
# As root
rm -f /usr/local/bin/zelta
rm -rf /usr/local/share/zelta
rm -rf /usr/local/etc/zelta
rm -f /usr/local/share/man/man8/zelta*.8
```

### User-Specific Installation

```sh
# As the user
rm -f ~/bin/zelta
rm -rf ~/.local/share/zelta
rm -rf ~/.config/zelta
```

Remove the environment variable exports from your shell's startup script.

## Convenience Aliases
Zelta pre-1.0 included convenience aliases for several zelta subcommands. 

Zelta supports adding these as aliases (global):

```sh
    for cmd in zeport zpush zpull zp zmatch; do
        ln -s /usr/local/bin/zelta /usr/local/bin/$cmd
    done
```
Or as shell aliases (user-specific):
```sh
    for cmd in zeport zpush zpull zp zmatch; do
        echo "alias $cmd=zelta" >> ~/.zshrc  # or ~/.bashrc
    done
```

---

## Next Steps

Now that Zelta is installed, you're ready to start replicating:

- **[Quick Start Guide](/home/start)** - Basic replication examples
- **[Environment & Policy Files](/conf/env-policy)** - Detailed configuration reference
- **[SSH Configuration](/conf/ssh)** - Secure remote replication setup
- **[ZFS Allow Delegation](/conf/zfs-allow)** - Non-root permission management

For questions or issues, see [GitHub Issues](https://github.com/bellhyve/zelta/issues) or the [Zelta Wiki](https://zelta.space).
