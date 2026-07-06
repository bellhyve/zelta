% zelta-unlock(8) | System Manager's Manual

# NAME
**zelta unlock** - unlock a dataset tree for Zelta promotion workflows

# SYNOPSIS
**zelta unlock** [_OPTIONS_] _endpoint_

# DESCRIPTION
**zelta unlock** reverses the lock state used by Zelta promotion workflows so a promoted dataset tree can become active. It is a lower-level companion to **zelta failover** for operators who need to script each step explicitly.

Most users should start with **zelta-failover(8)**.

# EXAMPLES

Unlock a promoted standby tree:

    zelta unlock standby.example.com:tank/service

# EXIT STATUS
Returns 0 on success, 1 if mount operations fail after unlock continues, and 255 if Zelta cannot safely clear readonly state.

# SEE ALSO
zelta(8), zelta-failover(8), zelta-lock(8), zelta-propsync(8), zelta-backup(8), zfs(8)

# AUTHORS
Daniel J. Bell <_bellhyve@zelta.space_>

# WWW
https://zelta.space
