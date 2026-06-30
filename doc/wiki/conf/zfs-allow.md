# ZFS Allow Delegation for Zelta

Zelta is designed to run without root. With ZFS delegation (`zfs allow`) and SSH, you can give each operational user only the permissions required for its job.

This is not just convenience. It is the security model: production, backup, twin failover, snapshot scheduling, retention, and emergency recovery can be different roles with different keys, different cron jobs, and different ZFS permissions.

## The Role Model

The safest Zelta deployments separate duties by user account. Small sites may combine roles, but the model is still useful because it shows which permissions are dangerous.

| Role | Job | Typical ZFS permissions |
|------|-----|-------------------------|
| Production Admin | Operate services and perform non-destructive recovery | `snapshot,clone,rename` where needed |
| Snapshot Admin | Create production snapshots and enforce local snapshot policy | `snapshot,destroy` on production snapshots |
| Backup Admin | Replicate production data to backup systems | source: `send:raw,snapshot,hold,bookmark`; target: `receive:append,create,mount,readonly` plus safe properties |
| Twin Admin | Maintain Zelta Twin failover partners | `send:raw,receive:append,snapshot,hold,bookmark,create,mount,readonly,clone,rename` on both twin roots |
| Retention Admin | Prune or redact snapshots on backup systems | `destroy` on backup snapshots; sometimes broader `receive` for deliberate rewrites |
| Rescue Admin | Perform emergency recovery and invasive maintenance | case-specific elevated grants such as `clone,rename,promote,destroy` |

Routine backup and twin users should not need root. They also usually should not need plain `receive` if their platform supports `receive:append`.

## Modern Delegation Features

Modern OpenZFS adds two delegation forms that are especially important for Zelta.

### `receive:append`

`receive:append` allows a user to receive new snapshots without granting destructive receive behavior. In practice, this means the user can append backup history but cannot use receive rollback behavior such as `zfs receive -F` to rewrite the target.

Use `receive:append` for routine Zelta backup and Zelta Twin users whenever it is available.

Plain `receive` is still useful for specific high-trust roles:

- Retention or remediation users that intentionally resync or rewrite backup history.
- Emergency recovery users during controlled repair.
- Legacy platforms that do not support `receive:append`.

Do not grant plain `receive` just because a user also needs `clone` and `rename`. Clone and rename make Zelta recovery flexible; `receive:append` keeps replication itself append-only.

### `send:raw`

`send:raw` allows encrypted datasets to be sent in raw encrypted form without granting permission to send decrypted streams. This matters even when the source dataset is mounted and readable by local services.

For encrypted datasets, prefer `send:raw` over plain `send` for backup and twin users. Plain `send` can permit decrypted streams when encryption keys are loaded.

Zelta uses raw send options by default when appropriate. The delegation still matters because ZFS enforces whether the user is allowed to send a raw or decrypted stream.

## Quick Recipes

Replace the user names and dataset roots with your own. Grant permissions on the smallest dataset tree that covers the job.

### Backup Source

Use this on a production dataset tree that a backup user reads from:

```sh
zfs allow -u backup hold,send:raw,bookmark,snapshot tank/production
```

If the source is never encrypted and your OpenZFS version lacks `send:raw`, use plain `send`:

```sh
zfs allow -u backup hold,send,bookmark,snapshot tank/production
```

### Backup Target

Use this on a backup root that receives replicas:

```sh
zfs allow -u backup receive:append,create,mount,readonly,clone,rename,volmode,compression,recordsize tank/backups
```

The important boundary is `receive:append`: the backup user can add new received snapshots but cannot perform destructive receive rewrites.

### Zelta Twin Pair

A Zelta Twin user needs to send and receive on both sides because either side may become active.

On each twin root:

```sh
zfs allow -u twin send:raw,receive:append,snapshot,hold,bookmark,create,mount,readonly,clone,rename,volmode,compression,recordsize tank/services
```

This supports an asynchronous cluster pattern: the active side creates snapshots and sends; the standby side receives read-only replicas; after failover the direction reverses.

### Retention User

Keep pruning separate from backup replication when possible:

```sh
zfs allow -u retention destroy tank/backups
```

If a retention or remediation role must intentionally rewrite a backup target, grant plain `receive` only to that role, not to the routine backup user.

```sh
zfs allow -u retention receive,destroy tank/backups
```

### Rescue User

Recovery users are intentionally broader, but should still be separate from cron-driven backup users:

```sh
zfs allow -u rescue send:raw,receive:append,snapshot,hold,clone,rename,promote,mount,create tank/services
```

Add `destroy` only when the rescue workflow really needs it.

## Permission Details

`send:raw`
: Send raw encrypted streams. Prefer for encrypted datasets.

`send`
: Send normal streams. Use for legacy systems or unencrypted-only trees.

`receive:append`
: Receive new snapshots without destructive receive rewrites. Prefer for routine backup and twin users.

`receive`
: Full receive permission. Reserve for trusted repair, retention, or legacy systems.

`snapshot`
: Create snapshots before replication. Zelta can snapshot only when needed.

`hold`
: Place holds that prevent accidental snapshot destruction during replication workflows.

`bookmark`
: Create bookmarks for safer and more flexible incremental replication.

`create`
: Create child datasets during recursive replication.

`mount`
: Set or use mount-related behavior. Zelta normally receives backup filesystems unmounted.

`readonly`
: Set backup targets read-only.

`clone`
: Create clones for recovery, inspection, and rotation workflows.

`rename`
: Rename datasets during rotate, revert, and failover workflows.

`volmode`
: Preserve zvol behavior when replicating volumes.

`compression`, `recordsize`
: Preserve or set important performance properties on received datasets.

`destroy`
: Destroy snapshots or datasets. Keep this out of routine backup users.

## Platform Notes

FreeBSD 14 and newer OpenZFS builds generally support modern delegation features such as `receive:append`, `send:raw`, and `volmode`. Check the installed OpenZFS version and test the actual delegation on your host.

Older systems may lack `receive:append` or `send:raw`. In that case, use plain `receive` or `send` only for the smallest necessary dataset tree and compensate operationally with separate users, careful SSH keys, and explicit review.

Linux delegation has limitations around mount namespace operations. Zelta still normally works well because backups are received unmounted and with safe properties, but mount-related grants may not behave identically across platforms.

## Testing Delegation

Check current grants:

```sh
zfs allow tank/backups
```

Test read access and matching first:

```sh
zelta match backup@source:tank/production backup@target:tank/backups/production
```

Then test replication with dry-run and verbose output:

```sh
zelta backup -nv backup@source:tank/production backup@target:tank/backups/production
```

Finally run one real backup and verify it:

```sh
zelta backup backup@source:tank/production backup@target:tank/backups/production
zelta match backup@source:tank/production backup@target:tank/backups/production
```

## Troubleshooting

### `cannot receive: permission denied`

Common causes:

- Missing `receive:append` or legacy `receive` on the target.
- Missing `create` for child datasets.
- Missing property grants such as `readonly`, `compression`, `recordsize`, or `volmode`.
- Grant was applied to the wrong dataset root.

### `cannot send: permission denied`

Common causes:

- Missing `send:raw` or legacy `send` on the source.
- Encrypted dataset requires raw send permission.
- Missing `snapshot` when Zelta needs to create a snapshot.

### zvol replication fails

The receiver probably lacks `volmode`, or the platform does not support delegating it. Grant `volmode` when available.

### Target properties are not preserved

Grant the relevant property permissions on the receiving root:

```sh
zfs allow -u backup readonly,compression,recordsize,volmode tank/backups
```

### Backup user can destroy too much

Split the role. Keep `destroy` with a retention user, and keep routine replication on `receive:append`.

## See Also

- [SSH Configuration](/conf/ssh)
- [Zelta Twin](/guides/twin)
- [Policy-Based Automatic Backups](/guides/policy)
- [Simple Backups](/guides/backup)
