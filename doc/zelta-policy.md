% zelta-policy(8) | System Manager's Manual

# NAME
**zelta policy** - execute a list of **zelta backup** operations from a policy configuration

# SYNOPSIS
**zelta policy** [_backup-override-options_] [_site_|_host_|_dataset_] _..._

# DESCRIPTION
**zelta policy** reads from a simple YAML-style configuration file containing parameters for **zelta backup**. Running **zelta policy** without parameters will iterate through the entire configuration file. Override options for either **zelta policy** or **zelta backup** can be provided on the command line, for example, adding `--json` will cause that parameter to be passed to all **zelta backup** calls. Subsequent undashed parameters will be matched against a user-defined _site_ name, _host_ name, or _dataset_, and the backup processes will be limited to that group or item.

## Options
In the **zelta policy** configuration file, you may override **zelta backup**'s default parameters as defined in **zelta-backup(8)**. For the complete list of Zelta configuration options, see **zelta-options(7)**. The following parameters are specific **zelta policy**:

**\--retry**
:    Retry failed syncs the indicated number of times.

**\--jobs**
:    Run the indicated number of policy jobs concurrently, one for each Site in the configuration.

**-C**, **\--config** _FILE_
:    Read policy configuration from _FILE_ instead of the default location.

**\--backup-root**
:    The relative target path for the target job. For example 'bkhost:tank/Backups' would place backups below that dataset (if not overridden).

**\--archive-root**
:    Default archive target root for policy jobs that use archive-style destinations.

**\--backup-command** _COMMAND_
:    Command used by policy when executing backup jobs. This is primarily useful for wrappers and testing.

**\--host-prefix**
:    Include the source hostname as a parent of the synced target, for example, 'tank/Backups/source.host/backup-dataset'.

**\--ds-prefix**
:    Similar to 'zfs recv -d' and '-e', include the indicated number of parent labels for the target's backup name. See **zelta-options(7)** for more detail.

## Import Files

Policy files may use `import:` to insert another local policy fragment before parsing. Import paths are resolved relative to the file that contains the `import:` line, which allows a policy directory to be moved as a unit.

```yaml
SITE0:
  host1.example:
    options:
      import: targets/vault1.yaml
      import: rules/hostbackup.yaml
    datasets:
      import: sources/host1.example.yaml
```

Imported files are textual fragments, not independent policy files. The indentation of the `import:` line is prepended to each imported line, so fragments should usually contain only the lines needed inside the current context. For example, a dataset inventory fragment can contain only list items:

```yaml
- tank/vm/app1
- tank/vm/app2
```

Imports are expanded recursively up to a fixed depth limit, and recursive import loops are rejected. Later options override earlier options, but unspecified options remain in effect within the current policy context.

## Backup Job Parameters
Without additional parameters, **zelta policy** will run a **zelta backup** job for each dataset in the configuration file. Providing one of the following will limit the backup job.

**_site_**  Run a backup job only for the _site_ listed. A _site_ is a user defined top-level parameter in the configuration file representing a list of one or more hosts.

**_host_**  Run a backup job only for the _host_ listed. Hosts must be accessible via SSH private-key authentication or **localhost**.

**_dataset_**  Run a backup job only for the _dataset_ listed. Note this parameter can match the _source_ **or** _target_ dataset, e.g., requesting `zroot` would run the replication for any matching dataset on any host.

**_host:dataset_**  Specify a _source_ or _backup_ dataset endpoint name, equivalent to the parameters of **zelta backup**.

**_dataset_pattern_**  Specify the final source or target dataset label. For example, `vm` would run all backup jobs with datasets ending in `/vm`.

# FILES
For detailed documentation of the **zelta policy** configuration see `zelta.conf.example`.

**/usr/local/etc/zelta/zelta.conf**
:    The default configuration file location.

# ENVIRONMENT
For detailed documentation of the **zelta** environment variables see `zelta help options`.

# EXIT STATUS

Returns 0 on success, non-zero on error.

# NOTES

See **zelta-options(7)** for environment variables and `zelta.env` configuration.

# SEE ALSO
zelta(8), zelta-clone(8), zelta-backup(8), zelta-options(7), zelta-match(8), zelta-revert(8), zelta-rotate(8), zelta-snapshot(8), ssh(1), zfs(8), zfs-list(8)

# AUTHORS
Daniel J. Bell <_bellhyve@zelta.space_>

# WWW
https://zelta.space
