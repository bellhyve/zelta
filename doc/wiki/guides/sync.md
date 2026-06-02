# Failover Workflows

For active-passive systems, keep the standby dataset tree read-only and verify it before promotion.

When both directions are defined as recurring policy jobs, this pattern is a [Zelta Twin](/guides/twin): an asynchronous cluster pair where either side can become the active dataset tree.

The high-level workflow in Zelta 1.2 is `zelta failover`:

```sh
zelta failover primary.example.com:tank/service standby.example.com:tank/service
```

`zelta failover` composes the safety steps: lock the active source, perform a final backup, sync local ZFS properties, and unlock the promoted target.

Use lower-level commands when you need to script each step yourself:

```sh
zelta lock primary.example.com:tank/service
zelta backup primary.example.com:tank/service standby.example.com:tank/service
zelta propsync primary.example.com:tank/service standby.example.com:tank/service
zelta unlock standby.example.com:tank/service
```

Do not run both sides read-write at the same time. Always verify state with `zelta match` before and after promotion.
