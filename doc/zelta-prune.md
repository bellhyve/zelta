% zelta-prune(8) | System Manager's Manual

# NAME

**zelta prune** - report snapshot prune candidates

# SYNOPSIS

**zelta prune** [_OPTIONS_] _source_ [_target_]

# DESCRIPTION

**zelta prune** reports snapshots on a source dataset tree that are candidates for pruning. It is nondestructive. To destroy snapshots, use **zprune(8)** with identical prune options.

Pruning is built from filters which describe the retention shape or narrow the dataset tree, snapshot names, target-safety requirement, or size recovery target.

By default, **zelta prune** applies this failsafe filter:

- keep the newest 30 snapshots;
- keep snapshots newer than 30 days;
- warn if target match safety cannot be confirmed.

Defining any explicit retention shape replaces the 30/30 default. Filters can be combined; a snapshot is reported only when all selected filters allow it.

As with other Zelta commands, **zelta prune** works recursively on dataset trees. Source and target endpoints may be local or remote using **scp(1)**-style syntax.

# RETENTION SHAPES

The examples below show time moving left to right. `o` means kept. `x` means selected as a prune candidate.

## Keep Window

Keep windows count from the latest snapshots. They protect recent history and prune older history.

```text
oldest                                      latest
x x x x x x x x x x x x x x x x x x o o o o
                                      keep 4
```

Common options:

- **--keep-snap-num** _N_: keep the newest _N_ snapshots.
- **--keep-snap-time** _TIME_: keep snapshots newer than _TIME_.

## GFS Grid

The grid keeps sparse historical points and prunes snapshots between them. Grid mode always protects the oldest and newest snapshots in each dataset.

```text
oldest                                      latest
o x x x o x x x o x o x o x o o o o o o o o
weekly      daily      hourly       recent
```

Grid terms use _COUNT_`x`_INTERVAL_. A term without `x` keeps one snapshot per interval forever from that point onward. Separate terms with commas or vertical bars. Whitespace is allowed around `x` and between interval numbers and units.

```sh
zelta prune --prune-grid='30x1 day, 52x1 week, 1 year' source target
```

Grid intervals use the same duration syntax as **--keep-snap-time**.

Snapshots older than a bounded grid span are prune candidates unless protected by another filter. An unbounded term such as `1 year` keeps one snapshot per year for all older history. Zelta recommends putting unbounded terms last, but does not enforce it.

## Duration Syntax

Bare numbers are seconds. Use unambiguous units for anything else:

```text
seconds   s, sec, second, seconds
minutes   mi, min, minute, minutes
hours     h, hour, hours
days      d, day, days
weeks     w, week, weeks
months    mo, mon, month, months
years     y, year, years
```

The units `m` and `M` are invalid because they are ambiguous between minutes and months. Months are treated as 30 days and years as 365 days.

# OPTIONS

## Endpoint Arguments

_source_
: Dataset tree containing snapshots to evaluate.

_target_
: Optional dataset tree used for target-safety checks. If the target is omitted with **--prune-synced=match** or **--prune-synced=always**, **zelta prune** emits a warning.

## Retention Filters

**--keep-snap-num** _N_
: Keep the newest _N_ snapshots.

**--keep-snap-time** _TIME_
: Keep snapshots newer than _TIME_. Bare numbers are seconds.

**--prune-grid** _GRID_
: Apply GFS-style grid retention. Example: `30x1 day, 52x1 week, 1 year`.

## Safety And Selection Filters

**--prune-synced** `match`|`always`|`never`
: Select target matching behavior. The default is `match`.

`match`
: Require a common source/target snapshot match when a target is supplied. Snapshots older than the match point may be reported even if each individual snapshot is not present on the target.

`always`
: Require each candidate to exist on the target with the same GUID and snapshot name.

`never`
: Do not use target matching. This is local-only retention.

**--no-prune-synced**
: Equivalent to **--prune-synced=never**.

**--prune-size** _SIZE_
: Select oldest eligible snapshots until their cumulative snapshot `used` values reach at least _SIZE_. This planner target is off by default. _SIZE_ accepts ZFS-style byte counts and suffixes such as `K`, `KB`, `M`, `GB`, and `T`.

**-d**, **--depth** _LEVELS_
: Limit dataset-tree recursion depth. A depth of `1` includes only the specified dataset.

**-X**, **--exclude** _PATTERN_
: Exclude datasets or snapshots matching _PATTERN_. Snapshot patterns begin with `@`. Dataset patterns may be exact dataset names or glob patterns containing `/`.

**--include** _PATTERN_
: Include only datasets or snapshots matching _PATTERN_. This uses the same pattern style as **--exclude**.

## Output Options

**--no-ranges**
: Disable range compression. By default, consecutive snapshots are emitted as ZFS snapshot ranges.

**-v**, **--verbose**
: Increase verbosity. Specify once for operational detail, twice for debug output.

**-q**, **--quiet**
: Decrease verbosity.

**-n**, **--dryrun**, **--dry-run**
: Display underlying listing commands without running them.

# OUTPUT FORMAT

By default, **zelta prune** outputs ZFS snapshot names or ranges, one per line:

```text
pool/dataset@oldest_snapshot%newest_snapshot
```

With **--no-ranges**, each candidate snapshot is emitted individually:

```text
pool/dataset@snapshot
```

The output is suitable for review and for **zprune(8)**. Manual piping to **zfs destroy** is discouraged; **zprune** previews candidates with **zfs destroy -nvp** and prompts before deletion.

# EXAMPLES

Report candidates using the default 30/30 failsafe:

```sh
zelta prune tank/data backup:tank/data
```

Preview and confirm destructive pruning with the wrapper:

```sh
zprune tank/data backup:tank/data
```

Require every candidate to exist on the target:

```sh
zelta prune --prune-synced=always tank/data backup:tank/data
```

Run local-only retention:

```sh
zelta prune --no-prune-synced tank/data
```

Keep a larger recent window:

```sh
zelta prune --keep-snap-num=200 --keep-snap-time=180days \
    tank/data backup:tank/data
```

Apply GFS-style retention:

```sh
zelta prune --prune-grid='30x1 day, 52x1 week, 1 year' \
    tank/data backup:tank/data
```

Exclude temporary datasets and include only daily snapshots:

```sh
zelta prune --exclude='*/tmp' --include='@daily-*' \
    tank/data backup:tank/data
```

Prune from the oldest eligible snapshots until at least 1 GiB is selected:

```sh
zelta prune --prune-size=1G tank/data backup:tank/data
```

# EXIT STATUS

Returns 0 on success and non-zero on error.

# NOTES

**zelta prune** is under active development for the BSDCan 2026 prune workflow. Review output carefully before destructive use.

This command is driven by the same comparison engine as **zelta match**. See **zelta-match(8)** for source/target matching behavior.

# SEE ALSO

**zelta(8)**, **zprune(8)**, **zelta-options(7)**, **zelta-match(8)**, **zelta-backup(8)**, **zfs(8)**, **zfs-destroy(8)**

# AUTHORS

Daniel J. Bell <_bellhyve@zelta.space_>

# WWW

https://zelta.space
