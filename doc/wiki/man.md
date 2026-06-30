# Zelta Manual Pages

## Command Reference

### [zelta(8)](zelta)
Main Zelta command interface and controller

### [zelta-options(7)](zelta-options)
Common options and configuration for Zelta commands

### [zelta-match(8)](zelta-match)
Compare datasets and report matching snapshots or discrepancies

### [zelta-backup(8)](zelta-backup)
Create and update ZFS backups with robust replication

### [zelta-policy(8)](zelta-policy)
Run configured backup jobs using policy-based automation

### [zelta-clone(8)](zelta-clone)
Clone ZFS datasets for testing or recovery

### [zelta-revert(8)](zelta-revert)
Rename and clone a dataset in-place to rewind state

### [zelta-rotate(8)](zelta-rotate)
Recover sync continuity after divergence

### [zelta-prune(8)](zelta-prune)
Plan snapshot pruning without destroying data

### [zprune(8)](zprune)
Validate and destroy snapshots selected by `zelta prune`

### [zelta-failover(8)](zelta-failover)
Promote a backup target through a guarded failover workflow

### [zelta-rebase(8)](zelta-rebase)
Build a new dataset tree from an upgraded upstream while preserving backup continuity

### [zelta-lock(8)](zelta-lock), [zelta-unlock(8)](zelta-unlock), [zelta-propsync(8)](zelta-propsync)
Lower-level commands used by the failover workflow
