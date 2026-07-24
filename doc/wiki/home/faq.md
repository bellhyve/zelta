# FAQ

Short answers to common operator questions. How-to workflows live under [Guides](/guides); flags live in the [manual pages](/man).

### If my pool has a colon `:` in its name, how can I replicate it with Zelta?

The first colon (before a `/` or space) is treated as the host separator. Prefix with **localhost:**, for example `localhost:my:pool:name`, and Zelta will do the right thing.

### Can I use Zelta without installing it globally?

Yes. For most user-local installs, use the web installer as the target user:

```sh
curl -fsSL https://zelta.space/web-install.sh | sh
```

You can also run the source installer from a checkout:

```sh
./install.sh
```

The installer shows proposed directories before installing. Override locations with environment variables and rerun `./install.sh`. For development from a checkout:

```sh
export PATH="$(pwd)/bin:$PATH"
export ZELTA_SHARE="$(pwd)/share/zelta"
```

### Do I need Zelta installed on the source and target?

No. Zelta only needs standard ZFS tools and SSH on the endpoints. You can orchestrate from a bastion that has no ZFS at all. See [SSH Configuration](/conf/ssh).

### Do I need root?

No. Use `zfs allow` and SSH keys so backup and twin users run with least privilege. Recipes: [ZFS Allow Delegation](/conf/zfs-allow).

### Will Zelta work with Sanoid, TrueNAS, or other snapshot names?

Yes. Zelta does not require a naming convention. Match and backup use ZFS metadata (GUIDs), not name patterns. You can still filter with `--include` / `--exclude` if you only want certain names on a given job.

### Full history or only latest snapshots?

By default, `zelta backup` preserves intermediate snapshots so the target keeps a usable history. That is safer for recovery and costs more transfer and space. To limit what is sent, use snapshot filters (for example `--include='@daily*'`) or intermediate-skip options documented in [zelta-options(7)](/man/zelta-options). See also [Simple Backups](/guides/backup).

### How do encrypted datasets work?

Zelta prefers raw send when appropriate so encrypted datasets stay encrypted in transit and on the backup. Grant `send:raw` (not only plain `send`) for backup users on encrypted trees. Details: [ZFS Allow Delegation](/conf/zfs-allow) and [zelta-backup(8)](/man/zelta-backup).

### What is the difference between `zelta` and `zprune`?

Commands that start with **zelta** are nondestructive. **zprune** is deliberately separate because it destroys snapshots after `zelta prune` plans them. If something goes wrong, you should never have to say “Zelta deleted my data.” See [Rollback & Recovery](/guides/recovery).

### When do I use clone, revert, rotate, or failover?

| Goal | Command | Guide |
|------|---------|-------|
| Writable inspection copy | `zelta clone` | [Recovery](/guides/recovery) |
| Rewind live dataset, keep broken state | `zelta revert` | [Recovery](/guides/recovery) |
| Diverged source/target, keep both histories | `zelta rotate` | [Recovery](/guides/recovery) |
| Promote a read-only twin | `zelta failover` | [Failover](/guides/sync), [Twin](/guides/twin) |

### What is a Zelta Twin?

Two dataset trees that back each other up so either side can become active. It is an asynchronous cluster pattern built from ordinary backup and failover commands, not a separate product. See [Zelta Twin](/guides/twin).

### Why is my backup target read-only / unmounted?

Safe defaults: replicas are `readonly=on`, new filesystems get `canmount=noauto`, and child mountpoints inherit so backups do not overlay production paths. That is intentional. Promote or clone when you need a writable tree.

### Where do I put configuration?

- `zelta.env` — defaults for all commands (shell `KEY=value`)
- `zelta.conf` — policy jobs for `zelta policy` (YAML-like, `import:` fragments)

See [Environment & Policy Files](/conf/env).
