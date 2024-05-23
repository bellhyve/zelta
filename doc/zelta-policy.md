% zelta-policy(8) | System Manager's Manual

# NAME
**zelta policy** - Execute a list of **zelta backup** operations from a configuration file. 

# SYNOPSIS
**zelta policy** [_backup-override-options_] [_site_|_host_|_dataset_] _..._

# DESCRIPTION
**zelta policy** reads from a simple YAML-style configuration file containing parameters for **zelta backup**. Running **zelta policy** without parameters will iterate through the entire configuration file. Override options for either **zelta policy** or **zelta backup** can be provided on the command line, for example, adding `--json` will cause that parameter to be passed to all **zelta backup** calls. Subsequent undashed parameters will be matched against a user-defined _site_ name, _host_ name, or _dataset_, and the backup processes will be limited to that group or item.

## Options
In the **zelta policy** configuration file, you may override **zelta backup**'s default parameters as defined in **zelta-backup(8)**. The following parameters are specific **zelta policy**:

**--backup-root=_dataset_**
:    The default _target_ dataset for replication jobs. For example, if given **backup_root** of `pool/Backups` and a _source_ dataset endpoint of`host01:tank01/vm/myOS`, the _target_ dataset will be `pool/Backups/myOS`.

**--prefix=_num-elements_**
:    Construct a target name using **backup_root** plus the indicated number of _source_ elements. If given a **prefix** of `1` in the previous example, the _target_ will be `pool/Backups/vm/myOS`.

**--host_prefix**
:    Construct a target name using **backup_root** plus the _source_ hostname. If enabled with the above example, the _target_ will be `pool/Backups/host01/vm/myOS`.

**--push_to:_hostname_**
:    Change the default _target_ endpoint from **localhost** to the indicated _hostname_.

**--retry=_num-retries_**
:    If replication fails, retry the indicated number of times. Note that the retry attempts are deferred until after all replciation jobs are attempted.

**--threads=_num-threads_**
:    Run the indicated number of concurrent backup jobs for each _site_.

## Backup Job Parameters
Without additional parameters, **zelta policy** will run a **zelta backup** job for each dataset in the configuration file. Providing one of the following will limit the backup job.

**_site_**  Run a backup job only for the _site_ listed. A _site_ is a user defined top-level parameter in the configuration file representing a list of one or more hosts. 

**_host_**  Run a backup job only for the _host_ listed. Hosts must be accessible via SSH private-key authentication or **localhost**.

**_dataset_**  Run a backup job only for the _dataset_ listed. Note this parameter can match the _source_ **or** _target_ dataset, e.g., requesting `zroot` would run the replication for any matching dataset on any host.

**_host:dataset_**  Specify a _source_ or _backup_ dataset endpoint, equivalent to the paramemters of **zelta backup**.


# FILES
For detailed documentation of the **zelta policy** configuraiton see `zelta.conf.example`.

**/usr/local/etc/zelta/zelta.conf**
:    The default configuration file locaiton.

**/usr/local/etc/zelta/zelta.env**
:    The default environment override file location.


# ENVIRONMENT
For detailed documentation of the **zelta** environment variables see `zelta.env.example`.

**ZELTA_ETC**
:    The directory where **zelta.conf** and **zelta.env** will be loaded from.


# SEE ALSO
cron(8), ssh(1), zelta(8), zelta-backup(8), zfs(8)


# AUTHORS
Daniel J. Bell _<bellta@belltower.it>_

# WWW
https://zelta.space
