# ZFS Allow Configuration for Zelta

One of Zelta's core design principles is operating safely with minimal privileges. Using ZFS delegation (`zfs allow`), you can grant non-root users exactly the permissions they need for replication—and nothing more.

This document covers ZFS permission delegation for Zelta operations, from basic replication to advanced features like rotation and encrypted dataset handling.

## Why Delegation Matters

Running replication as root is convenient but unnecessary. With proper delegation:

- **Reduced attack surface**: Backup users cannot destroy data or modify critical properties
- **Audit trail**: ZFS tracks which users perform which operations
- **Compliance**: Separation of duties for regulatory requirements
- **Bastion security**: Combined with SSH agent forwarding, you can build a replication infrastructure where no system stores root credentials

Modern OpenZFS includes groundbreaking security features that make delegation even more powerful:

- **`receive:append`** prevents destructive receives (`zfs recv -F`), eliminating a major class of data loss scenarios
- **`send:raw`** prevents senders from transmitting unencrypted data from encrypted datasets—even if the dataset is mounted and accessible

## Quick Reference

### Modern OpenZFS (2.2+)

For OpenZFS 2.2+ (FreeBSD 14+, latest Illumos, cutting-edge Linux):

**Sender (source system):**
```sh
zfs allow -u backupuser hold,send,bookmark,snapshot sink
```

**Receiver (target system):**
```sh
zfs allow -u backupuser receive:append,create,mount,readonly,clone,rename,volmode,compression,recordsize tank/Backups
```

### Legacy OpenZFS

For older OpenZFS versions (most Linux distributions as of 2025, FreeBSD 13):

**Sender:**
```sh
zfs allow -u backupuser hold,send,snapshot sink
```

**Receiver:**
```sh
zfs allow -u backupuser receive,create,mount,readonly,clone,rename,compression,recordsize tank/Backups
```

**Note:** Legacy versions lack `receive:append`, `send:raw`, and `volmode` delegation. Without `receive:append`, users can perform destructive receives. Without `volmode`, you may encounter errors when replicating volumes (zvols).

## Detailed Permission Breakdown

### Sender Permissions

**Minimum for basic replication:**
```sh
zfs allow -u backupuser send,snapshot sink
```

- **`send`**: Required to transmit dataset snapshots
- **`snapshot`**: Allows Zelta to create snapshots before replication

**Recommended additions:**
```sh
zfs allow -u backupuser hold,send,bookmark,snapshot sink
```

- **`hold`**: Prevents snapshots from being destroyed during replication (safety feature)
- **`bookmark`**: Enables bookmark creation for more flexible incremental replication

**For encrypted datasets (OpenZFS 2.2+):**
```sh
zfs allow -u backupuser hold,send:raw,bookmark,snapshot sink
```

- **`send:raw`**: This is a game-changing security feature. It allows sending encrypted datasets in their encrypted form, but **prevents the sender from transmitting unencrypted data**. Even if an encrypted dataset is mounted and the sender has read access to the plaintext files, `send:raw` blocks them from sending an unencrypted stream. This provides unprecedented protection for encrypted datasets in multi-tenant or untrusted environments.

**Important:** `send` without `:raw` allows users to send decrypted data if the encrypted dataset is mounted. For encrypted datasets, always use `send:raw` instead of `send`.

### Receiver Permissions

**Minimum for basic replication (modern):**
```sh
zfs allow -u backupuser receive:append,create,mount,readonly tank/Backups
```

- **`receive:append`**: Allows receiving new snapshots but **prevents destructive receives** (`zfs recv -F`). This is a critical safety feature—one of Zelta's core design goals is never requiring destructive operations
- **`create`**: Required to create new datasets during recursive replication
- **`mount`**: Allows setting the `mountpoint` property (even though backups shouldn't be mounted)
- **`readonly`**: Allows setting replicas to read-only (strongly recommended)

**Recommended for production:**
```sh
zfs allow -u backupuser receive:append,create,mount,readonly,clone,rename,volmode,compression,recordsize tank/Backups
```

- **`clone`**: Required for `zelta clone`, `zelta revert`, and `zelta rotate`
- **`rename`**: Required for `zelta revert` and `zelta rotate` (these operations rename datasets as part of their workflow)
- **`volmode`**: Required for replicating volumes (zvols). On legacy systems without this delegation, you may see the error: `operation not applicable to datasets of this type`
- **`compression`**: Allows preserving compression settings from source. Without this, receivers cannot set compression properties, which can cause issues during failover or if you want to recompress backups with different settings
- **`recordsize`**: Allows preserving recordsize settings. Critical for maintaining performance characteristics during failover

**Legacy systems (without `receive:append`):**
```sh
zfs allow -u backupuser receive,create,mount,readonly,clone,rename,compression,recordsize tank/Backups
```

**Note:** Without `receive:append`, the user can perform destructive receives. This is less than ideal but may be necessary on older systems.

### Permissive Configurations

For environments where you want to grant broader permissions (testing, single-tenant systems, or when you trust the backup user completely):

**Permissive sender:**
```sh
zfs allow -u backupuser hold,send,send:raw,bookmark,snapshot,destroy sink
```

**Permissive receiver:**
```sh
zfs allow -u backupuser receive,receive:append,create,mount,mountpoint,canmount,readonly,clone,rename,volmode,compression,recordsize,setuid,exec,atime,destroy tank/Backups
```

These grant additional property permissions and `destroy` for snapshot management. Use with caution.

## Feature-Specific Requirements

### Basic Replication (`zelta backup`, `zelta sync`)

**Sender:** `send,snapshot` (minimum) or `hold,send,bookmark,snapshot` (recommended)

**Receiver:** `receive:append,create,mount,readonly` (minimum) or add `compression,recordsize` (recommended)

### Cloning (`zelta clone`)

**On the pool containing the dataset to clone:**
```sh
zfs allow -u backupuser clone tank/Backups
```

Creates a writable clone for recovery or testing without modifying the original backup.

### Reverting (`zelta revert`)

**On the dataset being reverted:**
```sh
zfs allow -u backupuser clone,rename sink/dataset
```

Rewinds a dataset to a previous snapshot by renaming and cloning in place.

### Rotation (`zelta rotate`)

**On both source and target:**
```sh
zfs allow -u backupuser clone,rename sink/dataset
zfs allow -u backupuser clone,rename,receive:append tank/Backups/dataset
```

Performs multi-way rename and clone operations to preserve divergent histories. This is Zelta's most sophisticated operation and requires both clone and rename permissions.

## Platform-Specific Notes

### Linux Delegation Limitations

From the `zfs-allow` man page:

> Delegations are supported under Linux with the exception of mount, unmount, mountpoint, canmount, rename, and share. These permissions cannot be delegated because the Linux mount(8) command restricts modifications of the global namespace to the root user.

**However**, in practice, Zelta works correctly on Linux despite this limitation. The *behavior* of these operations may not be delegated, but the *properties* are still set correctly. Zelta's testing confirms:

- `mountpoint` is reset to inherit
- Backup datasets are not mounted
- `canmount` is set to `noauto`
- `readonly` is set correctly

So while Linux won't allow the backup user to actually mount/unmount datasets, the properties are delegated and Zelta operates safely.

### FreeBSD

FreeBSD 14+ includes OpenZFS 2.3.4 with full support for modern delegation features including `receive:append`, `send:raw`, and `volmode`.

FreeBSD 13 uses an older OpenZFS version and requires legacy permission syntax.

### Illumos

Modern Illumos distributions include current OpenZFS with full delegation support.

## Troubleshooting

### "cannot receive: permission denied"

The receiver lacks necessary permissions. Common causes:

- Missing `receive` or `receive:append` permission
- Missing `create` permission for recursive replication
- Missing property permissions (e.g., `compression`, `recordsize`)

Check current delegations:
```sh
zfs allow tank/Backups
```

### "operation not applicable to datasets of this type"

You're likely replicating a volume (zvol) and the receiver lacks `volmode` permission. This delegation is only available on OpenZFS 2.2+.

**Workaround for legacy systems:** Grant broader `receive` permissions or use root for volume replication.

### "cannot send: permission denied"

The sender lacks necessary permissions. Common causes:

- Missing `send` permission
- Missing `snapshot` permission (if Zelta needs to create a snapshot)
- Trying to send encrypted data without `send:raw` permission

### Properties Not Preserved

If properties like `compression` or `recordsize` aren't being preserved on the target:

```sh
zfs allow -u backupuser compression,recordsize tank/Backups
```

Zelta will warn you if the receiver lacks permissions for properties it's trying to set.

## Security Considerations

### The Principle of Least Privilege

Grant only the permissions required for your use case. Start with minimum permissions and add more as needed.

### Encrypted Datasets

For encrypted datasets, **always use `send:raw` instead of `send`**. This prevents the sender from transmitting unencrypted data, even if they have filesystem-level access to the mounted dataset.

### Destructive Operations

Modern OpenZFS's `receive:append` prevents destructive receives, eliminating an entire class of data loss scenarios. If you're on a legacy system without this feature, consider:

- Using root access for critical replications (with appropriate safeguards)
- Upgrading to a modern OpenZFS version
- Implementing additional safety checks in your replication workflow

### Root Access: When It's Reasonable

While delegation is preferred, there are scenarios where root access is reasonable:

- **Evacuation from legacy systems**: Migrating data from old systems without modern delegation
- **Emergency recovery**: When time is critical and you need maximum flexibility
- **Single-tenant systems**: Where the security boundary is at the network level, not the user level

Root access for replication is not inherently dangerous—Zelta's safe defaults prevent data destruction regardless of privilege level. The risk is operational: root can accidentally destroy data through other means.

## Testing Your Configuration

After setting up delegations, test with `zelta match`:

```sh
zelta match backupuser@source:sink/dataset backupuser@target:tank/Backups/dataset
```

If this succeeds, your permissions are correctly configured for replication.

Test a full replication:

```sh
zelta backup backupuser@source:sink/dataset backupuser@target:tank/Backups/dataset
```

Zelta will report any missing permissions it encounters.

## Getting Help

If you encounter permission issues:

1. **Check current delegations**: `zfs allow <dataset>`
2. **Review Zelta's output**: Error messages indicate which permissions are missing
3. **Verify your OpenZFS version**: `zfs version` or `zpool upgrade -v`
4. **Test incrementally**: Start with minimum permissions and add more as needed

For more assistance:

- [Zelta Documentation](https://zelta.space/en/home)
- [GitHub Issues](https://github.com/bellhyve/zelta/issues)
- [Bell Tower Contact Form](https://belltower.it/contact/)

For ZFS-specific delegation questions:

- `man zfs-allow` - ZFS delegation documentation
- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)
