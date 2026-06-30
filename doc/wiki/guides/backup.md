# Simple Backups

Compare first, back up second, then verify with the same comparison command.

```sh
zelta match tank/data backup@storage.example.com:tank/Backups/data
zelta backup tank/data backup@storage.example.com:tank/Backups/data
zelta match tank/data backup@storage.example.com:tank/Backups/data
```

`zelta backup` creates snapshots when needed, detects the best incremental stream, and creates read-only backup datasets by default. Run the same command again later to update incrementally.

Use `--include` and `--exclude` to narrow dataset or snapshot selection. Snapshot patterns begin with `@`.

```sh
zelta backup --exclude '@hourly_*' tank/data backup:tank/Backups/data
zelta backup --include '/critical,@daily_*' tank/data backup:tank/Backups/data
```

For recurring backups, either schedule direct commands with cron or move the jobs into `zelta policy`.
