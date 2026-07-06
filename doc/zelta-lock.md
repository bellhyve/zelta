% zelta-lock(8) | System Manager's Manual

# NAME
**zelta lock** - lock a dataset tree for Zelta promotion workflows

# SYNOPSIS
**zelta lock** [_OPTIONS_] _endpoint_

# DESCRIPTION
**zelta lock** applies the ordered readonly, canmount, unmount, and remount operations used by Zelta promotion workflows. It is a lower-level companion to **zelta failover** for operators who need to script each step explicitly.

Most users should start with **zelta-failover(8)**.

# OPTIONS

**-f**, **\--force**
: Force unmounts during lock.

**\--no-unmount**
: Set readonly and canmount state but leave mounted filesystems mounted.

# EXAMPLES

Lock an active service tree before final backup:

    zelta lock primary.example.com:tank/service

# EXIT STATUS
Returns 0 on success, 1 if unmounts fail after lock continues, and 255 if Zelta cannot safely set readonly state.

# SEE ALSO
zelta(8), zelta-failover(8), zelta-unlock(8), zelta-propsync(8), zelta-backup(8), zfs(8)

# AUTHORS
Daniel J. Bell <_bellhyve@zelta.space_>

# WWW
https://zelta.space
