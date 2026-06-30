% zelta-propsync(8) | System Manager's Manual

# NAME
**zelta propsync** - sync local ZFS properties between dataset trees

# SYNOPSIS
**zelta propsync** [_OPTIONS_] _source_ _target_

# DESCRIPTION
**zelta propsync** replays local ZFS properties from one dataset tree to another while preserving target-only local overrides. It is used by **zelta failover** so a promoted target receives the operational properties needed to take over service.

Most users should start with **zelta-failover(8)**.

# EXAMPLES

Sync local properties before unlocking a standby tree:

    zelta propsync primary.example.com:tank/service standby.example.com:tank/service

# EXIT STATUS
Returns 0 on success, non-zero on error.

# SEE ALSO
zelta(8), zelta-failover(8), zelta-lock(8), zelta-unlock(8), zelta-backup(8), zfs(8)

# AUTHORS
Daniel J. Bell <_bellhyve@zelta.space_>

# WWW
https://zelta.space
