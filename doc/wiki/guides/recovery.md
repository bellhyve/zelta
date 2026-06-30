# Rollback & Recovery

Prefer nondestructive recovery paths first.

Use `.zfs/snapshot` for file-level recovery when the source dataset is still available. Use `zelta clone` when you need a writable recovery environment from a backup:

```sh
zelta clone backup:tank/Backups/data tank/recovery/data-test
```

Use `zelta revert` to rewind a dataset in place while preserving the current state by rename and clone:

```sh
zelta revert tank/data
```

Use `zelta rotate` when a source and target have diverged and you want backups to continue without destroying either history:

```sh
zelta rotate tank/data backup:tank/Backups/data
```

For snapshot cleanup, keep planning and destruction separate:

```sh
zelta prune --prune-time 30d tank/data backup:tank/Backups/data
zprune --prune-time 30d tank/data backup:tank/Backups/data
```
