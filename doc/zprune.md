% zprune(8) | System Manager's Manual

# NAME

**zprune** - destroy snapshot prune candidates selected by zelta prune

# SYNOPSIS

**zprune** [_OPTIONS_] _source_ [_target_]

# DESCRIPTION

**zprune** is the destructive companion to **zelta prune**. It runs **zelta prune** with the supplied options, previews reported candidates with **zfs destroy -nvp**, asks for confirmation, and then destroys the same candidates with **zfs destroy**.

Candidate selection belongs to **zelta prune**. Destruction belongs to **zprune**. This keeps the safety boundary explicit: **zelta prune** reports, **zprune** destroys.

The _source_ and optional _target_ operands have the same meaning as in **zelta-prune(8)**. Remote source destruction is run through **ZELTA_REMOTE_COMMAND**, which defaults to **ssh(1)**.

# OPTIONS

## zprune Options

**-f**, **--force**
: Destroy previewed candidates without asking for confirmation. Candidates are still selected by **zelta prune** and previewed with **zfs destroy -nvp** before destruction.

**-q**, **--quiet**
: Do not display the snapshot candidate list or destroy preview. If **--force** is also used, **zprune** suppresses the prompt and proceeds after validation.

**-n**, **--dryrun**, **--dry-run**
: Display compact **zfs destroy** commands for selected candidates, print the summary, and exit without prompting or destroying snapshots. With **--verbose**, expand snapshot ranges in the command preview. With **--quiet**, print only the summary and exit.

**-h**, **--help**
: Show command usage.

**-V**, **--version**
: Show **zprune** version information.

## ZELTA PRUNE OPTIONS

Most options are passed directly to **zelta prune**. See **zelta-prune(8)** for complete behavior and safety details.

Common prune options:

**--prune-num** _N_
: Keep the newest _N_ snapshots after the guard point.

**--prune-time** _TIME_
: Keep snapshots newer than _TIME_.

**--prune-grid** _GRID_
: Apply GFS-style grid retention, such as `30x1 day, 52x1 week, 1 year`.

**--prune-size** _SIZE_
: Select oldest eligible snapshots until _SIZE_ bytes are reached.

**--prune-guard** `latest`|`unsynced`|`none`
: Select target safety behavior.

**--no-prune-guard**
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
- candidates are grouped per dataset and previewed with **zfs destroy -nvp**;
- destruction uses the same grouped candidate form as the preview;
- the prompt summarizes snapshot count and estimated reclaimed space;
- **--dryrun** shows compact destroy commands and summary, then exits before prompting;
- the operator must answer `y` or `yes` unless **--force** is used;
- **zfs destroy -R** is never used.

Unless **--no-prune-guard** is used, a target operand is required so **zelta prune** can confirm target safety before **zprune** destroys source snapshots.

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

Preview destroy commands and summary without prompting:

```sh
zprune --dryrun tank/data backup:tank/data
```

Print only the dry-run summary:

```sh
zprune -qn tank/data backup:tank/data
```

Use an explicit keep window:

```sh
zprune --prune-num=60 --prune-time='14 days' \
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

Other **ZELTA_** variables used by **zelta prune** are honored. **zprune** bootstraps through **zelta**, so **ZELTA_ENV** settings such as **PRUNE_GUARD** are loaded before prune candidates are selected. See **zelta-options(7)** and **zelta-prune(8)**.

# EXIT STATUS

Returns 0 on success and non-zero on error, aborted confirmation, failed candidate preview, or failed destruction.

# NOTES

For non-destructive candidate reporting, use **zelta prune** directly. To preview the exact destroy operations that **zprune** would run, use **zprune --dryrun**.

Manual piping from **zelta prune** to **zfs destroy** is discouraged. **zprune** preserves the review, preview, summary, and confirmation workflow.

# SEE ALSO

**zelta-prune(8)**, **zelta(8)**, **zelta-options(7)**, **zfs(8)**, **zfs-destroy(8)**, **ssh(1)**

# AUTHORS

Daniel J. Bell <_bellhyve@zelta.space_>

# WWW

https://zelta.space
