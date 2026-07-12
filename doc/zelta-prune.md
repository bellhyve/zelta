% zelta-prune(8) | System Manager's Manual

# NAME

**zelta prune** - report snapshot prune candidates

# SYNOPSIS

**zelta prune** [_OPTIONS_] _source_ [_target_]

# DESCRIPTION

**zelta prune** reports snapshots on a source dataset tree that are candidates for pruning. It is nondestructive. To destroy snapshots, use **zprune(8)** with identical prune options.

Pruning has two stages: first choose which snapshots are eligible, then apply a retention policy to that eligible set.

Scope and protection options decide eligibility. **--depth**, **--include**, and **--prune-name** narrow the dataset tree or snapshot names. **--exclude**, clone checks, and snapshots protected by **--prune-guard** remove snapshots from deletion. **--prune-guard=unsynced** requires every reported candidate to exist on the target.

Retention policy options decide which eligible snapshots to keep. Others are reported. By default, **zelta prune** applies this failsafe policy:

- protect snapshots newer than the latest common source/target match
- keep the newest 30 eligible snapshots after that guard point
- keep eligible snapshots newer than 30 days

Defining any explicit retention policy replaces the 30/30 default. Options can be combined; a snapshot is reported only when all selected rules allow it.

As with other Zelta commands, **zelta prune** works recursively on dataset trees. Source and target endpoints may be local or remote using **scp(1)**-style syntax.

# RETENTION POLICIES

The examples below show time moving left to right. `o` means kept. `x` means selected as a prune candidate.

## Keep Window

Keep windows count from the latest snapshots. They protect recent history and prune older history.

```text
oldest                                      latest
x x x x x x x x x x x x x x x x x x o o o o
                                      keep 4
```

Common options:

- **--prune-num** _N_: keep the newest _N_ snapshots after the guard point.
- **--prune-time** _TIME_: keep snapshots newer than _TIME_.

## GFS Grid

The grid keeps sparse historical points and prunes snapshots between them. Grid mode always protects the oldest snapshot and latest protected boundary in each dataset.

```text
oldest                                      latest
o x x x o x x x o x o x o x o o o o o o o o
weekly      daily      hourly       recent
```

Grid terms use _COUNT_`x`_INTERVAL_. A term without `x` keeps one snapshot per interval forever from that point onward. Separate terms with commas or vertical bars. Whitespace is allowed around `x` and between interval numbers and units.

```sh
zelta prune --prune-grid='30x1 day, 52x1 week, 1 year' source target
```

Grid intervals use the same duration syntax as **--prune-time**. Buckets are measured backward from the latest protected boundary, not from the wall-clock time when **zelta prune** runs. With the default prune guard, that boundary is the latest common source/target match. With **--prune-guard=none**, the boundary is the latest source snapshot. Zelta protects that boundary and the oldest snapshot in the dataset, then keeps the newest snapshot found in each older grid bucket.

Snapshots older than a bounded grid span are prune candidates unless protected by another rule. An unbounded term such as `1 year` keeps one snapshot per year for all older history. Zelta recommends putting unbounded terms last, but does not enforce it.

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

Note that `m` is ambiguous, but you can use `mi` for minutes and `mo` for months. Months are treated as 30 days and years as 365 days.

# OPTIONS

## Endpoint Arguments

_source_
: Dataset tree containing snapshots to evaluate.

_target_
: Dataset tree used for target-safety checks. If the target is omitted while **--prune-guard** is enabled, **zelta prune** returns an error. Use **--no-prune-guard** only for local-only retention.

## Retention Policy Options

**--prune-num** _N_
: Keep the newest _N_ snapshots after the guard point. With the default guard, this keeps snapshots newer than the latest common source/target match.

**--prune-time** _TIME_
: Keep snapshots newer than _TIME_. Bare numbers are seconds.

**--prune-grid** _GRID_
: Apply GFS-style grid retention. Example: `30x1 day, 52x1 week, 1 year`.

**--prune-size** _SIZE_
: Select oldest eligible snapshots until their estimated reclaim reaches at least _SIZE_. This planner target is off by default. _SIZE_ accepts ZFS-style byte counts and suffixes such as `K`, `KB`, `M`, `GB`, and `T`.

**--prune-size** is evaluated per dataset. On recursive dataset trees, each dataset may contribute up to the requested reclaim target, so the total candidate set can exceed _SIZE_. Use **--depth=1**, **--include**, or a non-recursive dataset selection when _SIZE_ should apply to one dataset only.

The estimate is based on sequential oldest-first pruning. If other rules create gaps, run pruning in multiple passes or use **zprune(8)** preview as the final authority.

**--prune-policy** _NAME_
: Apply a named pruning policy from configuration.

## Scope And Protection Options

**--prune-guard** `latest`|`unsynced`|`none`
: Select target safety behavior. The default is `latest`.

`latest`
: Require a common source/target snapshot match. Snapshots newer than the latest match are protected from pruning.

`unsynced`
: Require each candidate to exist on the target with the same GUID and snapshot name. Snapshots not confirmed on the target are protected from pruning.

`none`
: Do not use target matching. This is local-only retention.

**--no-prune-guard**
: Equivalent to **--prune-guard=none**.

Snapshots with clones are never reported as prune candidates. **zprune** also previews with **zfs destroy -nvp** before destruction, so clone checks remain effective if state changes after candidate selection.

**--prune-name** _PATTERN_
: Select snapshots by name before applying retention policies. Use this when multiple snapshot tools or naming policies share the same dataset tree.

**-d**, **--depth** _LEVELS_
: Limit dataset-tree recursion depth. A depth of `1` includes only the specified dataset.

**-X**, **--exclude** _PATTERN_
: Exclude datasets or snapshots matching _PATTERN_. Snapshot patterns begin with `@`. Dataset patterns may be exact dataset names or glob patterns containing `/`. See _INCLUDE AND EXCLUDE PATTERNS_ in **zelta-options(7)**.

**--include** _PATTERN_
: Include only datasets or snapshots matching _PATTERN_. This uses the same pattern style as **--exclude**. See _INCLUDE AND EXCLUDE PATTERNS_ in **zelta-options(7)**.

## Output Options

**-f**, **--force**
: Suppress the interactive prompt. With **zelta prune**, this only affects the prompt shown before the candidate list. With **zprune(8)**, this permits destruction after preview without asking for confirmation.

**-q**, **--quiet**
: Hide the snapshot candidate list. If **-f** is also given, **zelta prune** suppresses the prompt and snapshot list.

**--no-ranges**
: Disable range compression. By default, consecutive snapshots are emitted as ZFS snapshot ranges.

**-v**, **--verbose**
: Increase verbosity. Specify once for operational detail, twice for debug output.

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
zelta prune --prune-guard=unsynced tank/data backup:tank/data
```

Run local-only retention:

```sh
zelta prune --no-prune-guard tank/data
```

Keep a larger recent window:

```sh
zelta prune --prune-num=200 --prune-time=180days \
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

**zelta prune** is nondestructive: it only plans candidates. Use **zprune(8)** when you intend to destroy snapshots, and review the preview carefully.

This command is driven by the same comparison engine as **zelta match**. See **zelta-match(8)** for source/target matching behavior.

# SEE ALSO

**zelta(8)**, **zprune(8)**, **zelta-options(7)**, **zelta-match(8)**, **zelta-backup(8)**, **zfs(8)**, **zfs-destroy(8)**

# AUTHORS

Daniel J. Bell <_bellhyve@zelta.space_>

# WWW

https://zelta.space
