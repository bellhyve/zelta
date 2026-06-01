# Environment & Policy Files

As you move from running manual backups to managing automated fleets, you shouldn't have to keep typing the same command-line arguments.

This guide explains how to graduate from `zelta backup` CLI arguments to a set-and-forget orchestration system using `zelta.env` and `zelta.conf` to back up the world.

---

## Configuration Hierarchy

Zelta options follow a "specific beats general" hierarchy. This allows you to set sensible global defaults while overriding specific options for particular jobs.

1. **Built-in defaults** (Hardcoded safe defaults)
2. **`zelta.env`** (User/System-wide general preferences)
3. **`zelta.conf`** (Per-job policy configuration)
4. **Environment variables** (Shell exports or cron overrides)
5. **Command-line arguments** (Always win)

---

## Global Defaults: `zelta.env`

The `zelta.env` file is read by the `zelta` controller script before any operation. This is the place for settings that should apply to **every** command you run, such as SSH behaviors, logging preferences, or a standardized snapshot naming convention.

- **Default Location:** `/usr/local/etc/zelta/zelta.env`
- **User Location:** `~/.config/zelta/zelta.env` (if installed as non-root)

### Variable Naming
Inside this file, valid shell syntax is required. You may omit the `ZELTA_` prefix here.

```sh
# /usr/local/etc/zelta/zelta.env example

# 1. Snapshot Naming
# Use a dynamic date command so every run generates a unique name.
# Note the single quotes to prevent expansion until runtime.
SNAP_NAME='$(date -u +auto-%Y-%m-%d_%H-%M)'

# 2. SSH Tuning
# Use Agent Forwarding (-A) to hop through bastions without keys on endpoints.
REMOTE_SEND="ssh -An"   # For "pull" orchestration
REMOTE_RECV="ssh -A"    # For "push" orchestration

# 4. ZFS Tuning
# Remove default compression (-c); useful if you'd like your target host to recompress your backups.
# Add -L (large blocks) and -e (embed data).
SEND_DEFAULT="-Le"
```

---

## Automation Policy: `zelta.conf`

The `zelta.conf` file allows you to record replication logic in a clean, maintainable format. This file is used exclusively by the `zelta policy` command. It can be used as a shorthand to repeat common replication jobs with your pre-set options, such as running `zelta policy HOSTNAME` to run all backup jobs associated with a particular host. Running `zelta policy` without operands will orchestrate all jobs you've defined.

- **Default Location:** `/usr/local/etc/zelta/zelta.conf`

### The Structure
The hierarchy within the file is **Site** → **Host** → **Dataset**.

*   **Global Options:** Apply to everything.
*   **Site:** A logical grouping (e.g., "New York", "Critical", "Failover"). This is the unit of concurrency for the `JOBS` setting.
*   **Host:** The source hostname (as resolvable by SSH).
*   **Dataset:** The specific replication mapping.

### A Production Example

This configuration demonstrates how to handle standard backups, high-frequency retention, and divergent targets in a single file.

```yaml
# /usr/local/etc/zelta/zelta.conf

# --- Global Defaults ---
# Default target for all jobs (SCP-style syntax)
BACKUP_ROOT: backup-user@archive.tyrell.corp:tank/Backups
# Retry failed sends 2 times before giving up
RETRY: 2
# Run 2 Sites concurrently
JOBS: 2

# --- Site 1: Standard Production ---
TYRELL-HQ:
  # Host: nexus-6
  nexus-6:
    - sys/proxmox/vm-100
    - sys/proxmox/vm-101
    # You can map to a specific target path if it differs from the default
    - data/research/biotech: tank/SecureVault/biotech

  # Host: esper-photo
  esper-photo:
    options:
      # Override global defaults for this specific host
      SNAP_NAME: "$(date -u +daily-%Y-%m-%d)"
    datasets:
    - tank/images/raw
    - tank/images/processed

# --- Site 2: High Frequency / Low Latency ---
WINTERMUTE:
  # This site has limited bandwidth, so we tune for speed.
  options:
    SEND_INTR: 0       # Incremental only (skip intermediate snaps)
    SEND_DEFAULT: "-c" # Ensure stream compression

  # Host: straylight
  straylight:
    - deck/matrices/cyberspace
    - deck/matrices/net 

# --- Site 3: Specialized Workflows ---
NOSTROMO:
  lp-one:
    # Just backup everything under 'opt'
    - opt
  
  mother:
    options:
      # Assume snapshots are managed by an external tool (like zfs-auto-snapshot)
      # Zelta will just replicate what it finds.
      SNAP_MODE: SKIP
    datasets:
     - tank/flight-recorder
     - tank/crew-logs
```

---

## Common Options Reference

While there are many granular options (see `zelta help options`), these are the ones you will use most often.

### Replication Control
| Option | Description |
| :--- | :--- |
| `BACKUP_ROOT` | The default destination. Can be local (`tank/bk`) or remote (`user@host:pool/bk`). |
| `SNAP_NAME` | The name of the snapshot to create. Supports shell command substitution. |
| `SNAP_MODE` | `IF_NEEDED` (default): Snap only if source has written data.<br>`ALWAYS`: Snap every run.<br>`SKIP`: Never snap (replication only). |
| `SEND_INTR` | `1` (default): Send stream as distinct snapshots (`-I`).<br>`0`: Collapse into a single incremental stream (`-i`). Faster, but loses history between runs. |

### Performance & Reliability
| Option | Description |
| :--- | :--- |
| `JOBS` | Number of **Sites** to process in parallel. |
| `RETRY` | Number of times to retry a failed dataset replication. |
| `EXCLUDE` | Filter out datasets. E.g., `EXCLUDE: "/swap,@twin_*"`. |

### Advanced Metadata
| Option | Description |
| :--- | :--- |
| `SEND_DEFAULT` | `zfs send` flags (default: `-Lce`). |
| `SEND_RAW` | `zfs send` flags for encrypted datasets (default: `-Lw`). |
| `RECV_TOP` | Flags for the top-level target dataset creation (default: `-o readonly=on`). |

---

## Dynamic Snapshot Names

Rather than reinventing every imaginable wheel, Zelta leans on the power of Unix philosophy to take advantage of dynamic snapshot naming using **command substitution**. This allows you to decouple Zelta from strict naming policies and adapt to whatever schema you prefer.

```yaml
# "zelta_2024-05-20_14.00.00" (Default Zelta style)
SNAP_NAME: "$(date -u +zelta_%Y-%m-%d_%H.%M.%S)"

# "auto-2024-05-20_1400" (Sanoid/ZFS-auto-snapshot style)
SNAP_NAME: "autosnap_$(date -u +%Y-%m-%d_%H:%M:%S)_hourly"

# Or call a script
SNAP_NAME: "$(/home/space/bin/my-naming-logic.sh)"
```

---

## Testing & Validation

Before you unleash a new policy on your production data, validate it.

**1. Syntax Check**
Parse the configuration and print the job list without connecting to any hosts.
```sh
zelta policy -n
```

**2. Dry Run**
Connect to hosts, check snapshots, and calculate what *would* happen, without sending data.
```sh
zelta policy -v -n
```

**3. Site Specific**
Run only the "WINTERMUTE" site definitions to test a specific subset.
```sh
zelta policy WINTERMUTE
```

--- 

## Next Steps

- **[Quick Start Guide](/home/start)** - Basic replication examples
- **[SSH Configuration](/conf/ssh)** - Secure remote replication setup
- **[ZFS Allow Delegation](/conf/zfs-allow)** - Non-root permission management
- **Man Pages** - Run `zelta help` for detailed command documentation

For questions or issues, see [GitHub Issues](https://github.com/bellhyve/zelta/issues) or the [Zelta Wiki](https://zelta.space). 

