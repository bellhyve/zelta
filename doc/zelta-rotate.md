% zelta-rotate(8) | System Manager's Manual

# NAME

**zelta rotate** - Rotate snapshots according to retention policy.

# SYNOPSIS

**zelta rotate** [**-d** _depth_] [_initiator_] _dataset_

# DESCRIPTION

**zelta rotate** applies snapshot retention policies to a dataset and all of its descendents. Snapshots are expired and destroyed based on policy rules defined in the Zelta configuration.

Rotation is typically used after replication to prune obsolete snapshots while preserving required recovery points.

# OPTIONS

A _dataset_ parameter is required.

**_dataset_**
:    A dataset whose snapshots will be evaluated and rotated.

**initiator**
:    A remote host, accessible via SSH, where the rotation commands will be executed.

**--policy _name_**
:    Apply a specific snapshot retention policy.

**-n, --dryrun**
:    Don't rotate, but show the snapshots that would be destroyed.

**-q**
:    Reduce verbosity.

**-v**
:    Increase verbosity.

**-d _depth_, --depth _depth_**
:    Limits the depth of all Zelta operations.

# EXAMPLES

**Rotate snapshots using the default policy:**

```sh
zelta rotate tank/data
