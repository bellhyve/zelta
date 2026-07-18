# Guides

These guides cover common Zelta workflows. Start with direct `zelta backup` and `zelta match` commands, then move repeated work into `zelta policy`.

Flags and precise behavior live in the [manual pages](/man) (also published on this site). Guides answer *when* and *how* to compose commands.

| Guide | Use when |
|-------|----------|
| [Simple Backups](/guides/backup) | Match → backup → verify; filters; bookmarks |
| [Policy-Based Automatic Backups](/guides/policy) | Many hosts/jobs, `import:` fragments, bastions |
| [Zelta Twin](/guides/twin) | Reciprocal pair, day-2 twin operations |
| [Failover Workflows](/guides/sync) | Promote standby; lock / propsync / unlock |
| [Rollback & Recovery](/guides/recovery) | Clone, revert, rotate, prune decision tree |
| [JSON Output](/guides/json) | Logs and monitoring |

Not sure which command? See [Which Command?](/home/overview#which-command) in Core Concepts.

For installation and delegation, see [Installation & Configuration](/home/install), [SSH Configuration](/conf/ssh), and [ZFS Allow Delegation](/conf/zfs-allow).
