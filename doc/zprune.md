% zprune(8) | System Manager's Manual

# NAME

**zprune** - destroy snapshot prune candidates selected by zelta prune

# SYNOPSIS

**zprune** [_OPTIONS_] _source_ [_target_]

# DESCRIPTION

**zprune** is the destructive companion to **zelta prune**. It runs **zelta prune** with the supplied options, previews each reported candidate with **zfs destroy -nv**, asks for confirmation, and then destroys the same candidates with **zfs destroy**.

Candidate selection belongs to **zelta prune**. Destruction belongs to **zprune**. This keeps the safety boundary explicit: **zelta prune** reports, **zprune** destroys.

The _source_ and optional _target_ operands have the same meaning as in **zelta-prune(8)**. Remote source destruction is run through **ZELTA_REMOTE_COMMAND**, which defaults to **ssh(1)**.

# OPTIONS

## zprune Options

**-f**, **--force**
: Destroy previewed candidates without asking for confirmation. Candidates are still selected by **zelta prune** and previewed with **zfs destroy -nv** before destruction.

**-h**, **--help**
: Show command usage.

**-V**, **--version**
: Show **zprune** version information.

## ZELTA PRUNE OPTIONS

Most options are passed directly to **zelta prune**. See **zelta-prune(8)** for complete behavior and safety details.

Common prune options:

**--keep-snap-num** _N_
: Keep the newest _N_ snapshots.

**--keep-snap-time** _TIME_
: Keep snapshots newer than _TIME_.

**--prune-grid** _GRID_
: Apply GFS-style grid retention, such as `30x1 day, 52x1 week, 1 year`.

**--prune-size** _SIZE_
: Select oldest eligible snapshots until _SIZE_ bytes are reached.

**--prune-synced** `match`|`always`|`never`
: Select target matching behavior.

**--no-prune-synced**
: Disable target matching checks.

**--include** _PATTERN_
: Include only datasets or snapshots matching _PATTERN_.

**-X**, **--exclude** _PATTERN_
: Exclude datasets or snapshots matching _PATTERN_.

**-d**, **--depth** _LEVELS_
: Limit dataset-tree recursion depth.

# SAFETY MODEL

**zprune** applies these checks before destruction:

- candidates are selected by **zelta prune**;
- candidates are validated before preview;
- each candidate is previewed with **zfs destroy -nv**;
- the operator must type `destroy` unless **--force** is used;
- **zfs destroy -R** is never used.

If the source is remote, destruction is executed on that source host through **ZELTA_REMOTE_COMMAND**. The default remote command is **ssh**.

# EXAMPLES

Preview default prune candidates and confirm before destroying:

```sh
zprune tank/data backup:tank/data
```

Destroy without the confirmation prompt:

```sh
zprune --force tank/data backup:tank/data
```

Use an explicit keep window:

```sh
zprune --keep-snap-num=60 --keep-snap-time='14 days' \
    tank/data backup:tank/data
```

Apply grid retention:

```sh
zprune --prune-grid='30x1 day, 52x1 week, 1 year' \
    tank/data backup:tank/data
```

Prune from the oldest eligible snapshots until at least 10 GiB is selected:

```sh
zprune --prune-size=10G tank/data backup:tank/data
```

# ENVIRONMENT

**ZELTA_REMOTE_COMMAND**
: Command used for remote source destruction. The default is `ssh`.

Other **ZELTA_** variables used by **zelta prune** are honored. See **zelta-options(7)** and **zelta-prune(8)**.

# EXIT STATUS

Returns 0 on success and non-zero on error, aborted confirmation, failed candidate preview, or failed destruction.

# NOTES

For non-destructive reporting, use **zelta prune** directly.

Manual piping from **zelta prune** to **zfs destroy** is discouraged. **zprune** preserves the review, preview, and confirmation workflow.

# SEE ALSO

**zelta-prune(8)**, **zelta(8)**, **zelta-options(7)**, **zfs(8)**, **zfs-destroy(8)**, **ssh(1)**

# AUTHORS

Daniel J. Bell <_bellhyve@zelta.space_>

# WWW

https://zelta.space
