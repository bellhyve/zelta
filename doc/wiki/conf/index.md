# Configuration

Zelta configuration is split between environment defaults, policy files, SSH access, and ZFS delegation.

- [Environment & Policy Files](/conf/env): Which file to edit, syntax differences, option precedence, and references.
- [SSH Configuration](/conf/ssh): Keys, bastions, agent forwarding, and connection tuning.
- [ZFS Allow Delegation](/conf/zfs-allow): Non-root ZFS permissions for backup, recovery, failover, and pruning.
- [Getting Started With ZFS](/conf/zfs): ZFS background for new users.

For reciprocal failover partners, see [Zelta Twin](/guides/twin).

Use user-local configuration under `~/.config/zelta` when present; otherwise Zelta uses `/usr/local/etc/zelta`.
