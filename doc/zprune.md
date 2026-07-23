% zprune(8) | System Manager's Manual

# NAME

**zprune** - destroy snapshot prune candidates selected by zelta prune

# SYNOPSIS

**zprune** [_OPTIONS_] **--match-endpoint=**_guard_ _endpoint_

**zprune** [_OPTIONS_] **--no-prune-guard** _endpoint_

# DESCRIPTION

**zprune** destroys snapshots selected by **zelta prune**. It previews grouped `zfs destroy` commands with **zfs destroy -nvp**, prints a summary of snapshot count and estimated reclaim, asks for confirmation, then destroys the same candidates.

Only _endpoint_ is destroyed. A match endpoint (_guard_) is used only for match validation and prune-guard protection.

Candidate selection, filters, prune guards, and retention options are identical to **zelta prune**. See **zelta-prune(8)** for strategy details. **zprune** requires `--match-endpoint` or `--no-prune-guard`.

# OPTIONS

## zprune Options

`--force`, `-f`
: Destroy candidates without asking for confirmation.

`--quiet`, `-q`
: Do not display the `zfs destroy` command list.

`--dryrun`, `-n`
: Preview compact destroy commands and the summary, then exit without prompting or destroying.

`--verbose`, `-v`
: Expand snapshot ranges in the command preview. With `--quiet`, print only the summary and exit.

`--help`, `-h`
: Show command usage.

`--version`, `-V`
: Show **zprune** version information and exit.

## Candidate Selection

All other options are forwarded to **zelta prune**. See **zelta-prune(8)** for complete behavior, including `--match-endpoint`, `--prune-num`, `--prune-time`, `--prune-grid`, `--prune-size`, `--prune-guard`, `--include`, `--exclude`, and `--depth`.

# SAFETY MODEL

**zprune** applies these checks before destruction:

- candidates are selected by **zelta prune**;
- candidates are validated before preview;
- candidates are grouped per dataset and previewed with **zfs destroy -nvp**;
- destruction uses the same grouped candidate form as the preview;
- the prompt summarizes snapshot count and estimated reclaimed space;
- `--dryrun` shows compact destroy commands and summary, then exits before prompting;
- the operator must answer `y` or `yes` unless `--force` is used;
- **zfs destroy -R** is never used;
- only _endpoint_ is destroyed; the match endpoint is never destroyed.

If _endpoint_ is remote, destruction runs on that host through **ZELTA_REMOTE_COMMAND** (default **ssh**).

# EXAMPLES

Preview default candidates and confirm before destroying:

```sh
zprune --match-endpoint=backup:tank/data tank/data
```

Destroy without the confirmation prompt:

```sh
zprune --force --match-endpoint=backup:tank/data tank/data
```

Preview destroy commands and summary without prompting:

```sh
zprune --dryrun --match-endpoint=backup:tank/data tank/data
```

Print only the dry-run summary:

```sh
zprune -qn --match-endpoint=backup:tank/data tank/data
```

Apply a retention strategy and destroy (same options as **zelta prune**):

```sh
zprune --prune-grid='30x1day, 52x1week, 1year' \
    --match-endpoint=backup:tank/data tank/data
```

Without a match endpoint, pass `--no-prune-guard` explicitly:

```sh
zprune --no-prune-guard --prune-size=10G tank/data
```

# ENVIRONMENT

**zprune** bootstraps through **zelta**, so **ZELTA_ENV** settings such as **PRUNE_GUARD** are loaded before candidates are selected. See **zelta-options(7)** and **zelta-prune(8)**.

# EXIT STATUS

Returns 0 on success and non-zero on error, aborted confirmation, failed candidate preview, or failed destruction.

# NOTES

For non-destructive candidate reporting, use **zelta prune**. To preview the exact destroy operations **zprune** would run, use `zprune --dryrun`.

# SEE ALSO

**zelta-prune(8)**, **zelta(8)**, **zelta-options(7)**, **zfs(8)**, **zfs-destroy(8)**, **ssh(1)**

# AUTHORS

Daniel J. Bell <_bellhyve@zelta.space_>

# WWW

https://zelta.space
