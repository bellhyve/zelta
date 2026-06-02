% zelta-rebase(8) | System Manager's Manual

# NAME
**zelta rebase** - build a new dataset tree from an upgraded upstream while preserving backup continuity

# SYNOPSIS
**zelta rebase** [_OPTIONS_] _origin_ _target_ _upstream_ [_new_]

# DESCRIPTION
**zelta rebase** composes a replication workflow for replacing a production tree with a new tree based on an upgraded upstream while preserving incremental backup continuity through an existing origin backup.

This is useful for image, template, appliance, and development workflows where local changes must move forward onto a newer upstream base without forcing a full backup history restart.

The workflow uses existing ZFS lineage information and Zelta backup state. It is not a destructive overwrite workflow; divergent datasets are preserved according to Zelta's normal safety model.

# OPTIONS

_origin_
: Existing origin backup or lineage member used as the continuity basis.

_target_
: Current production or working dataset tree to be rebased.

_upstream_
: Upgraded upstream dataset tree.

_new_
: Optional destination for the newly composed dataset tree.

**-n**, **\--dryrun**, **\--dry-run**
: Display underlying commands without executing them.

**-v**, **\--verbose**
: Increase verbosity. Specify once for operational detail, twice for debug output.

**-q**, **\--quiet**
: Decrease log output.

# EXAMPLES

Compose a rebased tree from an upgraded upstream:

    zelta rebase backup:tank/origin tank/app upstream:tank/app-v2 tank/app-v2

# EXIT STATUS
Returns 0 on success, non-zero on error.

# NOTES

Use **zelta match** before and after rebasing to confirm lineage and backup state.

# SEE ALSO
zelta(8), zelta-backup(8), zelta-match(8), zelta-clone(8), zelta-rotate(8), zelta-options(7), ssh(1), zfs(8)

# AUTHORS
Daniel J. Bell <_bellhyve@zelta.space_>

# WWW
https://zelta.space
