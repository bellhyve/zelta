# JSON Output

Use JSON output when feeding Zelta into monitoring, logs, or reporting tools.

```sh
zelta backup --json tank/data backup:tank/Backups/data
zelta match --json tank/data backup:tank/Backups/data
zelta policy --json
```

For cron jobs, redirect JSON output to a log and import it with your normal telemetry pipeline.

```cron
0 */6 * * * zelta policy --json >> /var/log/zelta-policy.json
```

Known issue: JSON field names currently use mixed conventions. This is planned to align with OpenZFS `zfs list -j` standards in a future release.

When using `mawk`, JSON timestamps require `ZELTA_SYSTIME='date +%s'`. `gawk` and original-awk work without this setting.
