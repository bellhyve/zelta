# Zelta Replication Suite

**Zelta** is a suite of tools offering a streamlined approach to managing ZFS snapshot replication across various systems. It's built with the intention of simplifying complex ZFS functions into safe and user-friendly commands while also being the foundation for large and complex backup and failover environments. It's easy and accessible while working with most UNIX and UNIX-like base systems without additional packages, is optimized for environments with strict permission separation, and integrates well into many types of existing ZFS workflows.

The suite comprises three main components:

- `zelta match`: Compares two ZFS volume trees, reporting matching snapshots or discrepancies. It's a helpful tool for replication assistance, rollback assistance, and source-backup validation.
- `zelta sync`: A robust ZFS volume tree replication tool with very safe defaults.
- `zelta policy`: A policy-driven backup tool for managing extensive replication jobs.

There are additional functions in development or soon to be released:
- `zelta snapshot`: A simple but customizable (local or remote) snapshot tool.
- `zelta backup`: A synonym for `zelta sync` with excellent defaults for complete backups for beginners.
- `zelta review`: Creates a temporary view of volume tree for inspection and recovery.


# Alpha Software Notice, and a Commitment to Safety and Community Collaboration

Zelta, although a recent addition to GitHub, has been rigorously used in production for over five years. It has successfully managed the replication of millions of datasets, with a primary emphasis on safety. We're currently refining features, finalizing command names, and enhancing documentation.

We invite individuals of all technical backgrounds who want to protect both personal and organizational mission-critical data to collaborate with us. Your input is crucial in making Zelta, and ZFS at large, more accessible and user-friendly. By engaging with us, you'll not only contribute to the development of Zelta but also gain the opportunity to receive direct support and insights from our team at (Bell Tower)[https://belltower.it/].


## Goals and Methodology

ZFS's versatility is unparalleled in the open source world, but users of all experience levels wrestle with its complex command structures with non-intuitive and often destructive defaults. Zelta addresses this by providing streamlined commands and safer defaults for common backup and migration tasks.


The act of simply backing up a boot drive (`zfs send -R zroot@latest | zfs receive backup/zroot`) is difficult to construct and will likely result in errors and overlapping mounts. Zelta simplifies this process to:
- `zelta sync zroot backup/zroot`: Backs up the latest `zroot` snapshots to `backup/zroot`
- `zelta match zroot backup/zroot`: Confirms that the latest snapshots on the backup are identical.

Zelta is both safer and easier to use, and simplifies complex backup and migration tasks for experts. We find it to be ideal for both routine maintenance and complex tasks like fleet backup management and asynchronous clustering. Zelta **never** destroys target data, but provides tools to help delicately untangle mismatched replicas.

Zelta works with any snapshot management system (or none) and is used to back up thousands of volumes in conjunction with (zfsnap)[https://github.com/zfsnap/zfsnap].


### Latest Examples

The most complete documentation and examples can be found on our (GitHub wiki)[https://github.com/bellhyve/zelta/wiki/Home-&-FAQ]. We are actively adding use case examples and updating the manpage drafts to reflect Zelta's active feature development.


## Quick Start: Setup

`install.sh` will copy the awk scripts to `/usr/local/share/zelta/` and the `zelta` shell wrapper to `/usr/local/bin/`, and some symlinks for zelta synonyms, `zmatch` and `zpull`. See the (FAQ)[https://github.com/bellhyve/zelta/wiki/Home-&-FAQ] for more information. 

```sh
git clone https://github.com/bellhyve/zelta.git
cd zelta
sudo sh ./install.sh
```

In addition to the (FAQ)[https://github.com/bellhyve/zelta/wiki/Home-&-FAQ], man page drafts are also available on the (wiki)[https://github.com/bellhyve/zelta/wiki/Home-&-FAQ]. Point-of-use documentation is also provided in the installed examples:
- zelta.conf[https://github.com/bellhyve/zelta/blob/main/zelta.conf] for policy-driven backups
- zelta.env[https://github.com/bellhyve/zelta/blob/main/zelta.env] for location and behavior overrides


## Quick Start: Back up your computer

In this example, we have an OS installed with a ZFS pool called `zroot`. After attaching a new blank drive to the system, we detect a new drive as `da2`. We can create a blank pool called `backups` with a command such as `zpool create backups da2`.

Zelta does not (yet) have a snapshot function, so let's make a snapshot for our boot pool using `zfs snapshot`.

```sh
zfs snapshot -r zroot@$(date +%Y-%m-%d_%H.%M.%S)
```

Let's perform a quick "sanity check" to make sure `zelta` is working by comparing our pool's latest snapshots to themselves, and then repeat the command targeting our new drive.

```sh
zelta match zroot zroot
zelta match zroot backups/my_zroot_backup
```

For the first command, you should see a list of `target has latest source snapshot` for all volumes under zroot. In the second command, we "match" against an empty target, and will see a similar list with `snapshots only on source`. To back up, use `zelta sync` instead of `match`.

```sh
zelta sync zroot backups/my_zroot_backup
3G sent, 21/21 streams received in 10.34 seconds
```

Simply repeat the snapshot and final `zelta sync` process to update your backup. To learn more, see the `zelta sync` section of this document and this (manpage draft)[https://github.com/bellhyve/zelta/wiki/zelta-sync-(man-page-draft)].


## Quick Start: Back up the universe using a policy

`zelta match` and `zelta sync` are useful for migrations and backup scripts that deal with a small number of replication jobs interactively. To deal with large numbers of backup volumes, you can use `zelta policy` perform many backups and receive a human-readable backup report or JSON detail.

Next, we'll use a policy configuration file to perform the same task as we did in the first example: backing up a local `zroot` source to `backups/my_zroot_backup`. Set up and edit **zelta.conf**.

```sh
vi /usr/local/etc/zelta/zelta.conf
```

First, let's make a configuration to test local backups. The first line below is a unique Site name of choice, representing a location or backup set. Note the two spaces before host and dataset names:

```yaml
MyLocalBackups:
  localhost:
  - zroot: backups/my_zroot_backup
```

Run `zelta`. It will perform the backup operation and report some details if it succeeds, or an "⊜" symbol if it finds nothing to replication. Now we extend our policy with options and more volumes.

On your backup servers, create a backup user and give it access to replicate to your backup target (`zfs allow -u backup receive,mount,create backups`). Note that the backup user will not be able to receive any property it doesn't have permission to. Missing some permissions doesn't prevent a successful backup of data, but if you'd like to back up a default FreeBSD system with all properties, set these additional permissions: `canmount,mountpoint,setuid,exec,atime,compression`.

On your source servers (the servers with volumes you would like to back up) also create a backup user, and grant it access to send snapshots from your source volumes (or a parent volume above your backup source volume), e.g., `zfs allow -u backup send,snapshot,hold pool/stuff`.

Use SSH (key-based authentication)[https://docs.freebsd.org/en/books/handbook/security/#security-ssh-keygen] between your backup server and source servers. Make sure you can ssh from the machine you're running Zelta on to the others.

```yaml
BACKUP_ROOT: backups
HOST_PREFIX: 1

MySites:
  localhost:
  - zroot: backups/my_zroot_backup
  host1:
  - tank/vm/one
  - tank/vm/two
  host2:
  - tank/jail/three
  - tank/jail/four
```

And so on. Save again, and as before, run the replication process:

```sh
zelta
```

If we want to back up a subset of the policy, name a site, hostname, and/or volume you'd like to back up. For example, the following will back up all hosts under "MySites", all volumes in host1, and only tank/jail/four for host2:

```sh
zelta MySites host1 tank/jail/four
```

 If all went well, a `zfs list` command will show that you have a backup of the five volumes listed in the configuration: `backups/my_zroot_backup`, `backups/host1/one`, `backups/host1/two`, `backups/host2/three`, and `backups/host2/four`.

See the [configuration example](https://github.com/bellhyve/zelta/blob/main/zelta.conf) for more details and useful options.


## zelta match

`zelta match` (or `zmatch`) is a tool used for comparing ZFS datasets. It identifies the most recent matching snapshot between two given volumes. This tool is particularly useful for determining if datasets are in sync and identifying the latest common snapshot.

```sh
zelta match [options] source_volume target_volume
```

## zelta sync

`zelta sync` (previously `zpull`) handles the actual replication of ZFS snapshots between a source and a target volume. It uses the output of `zelta match` to determine which snapshots need to be sent and then performs the replication. Without options, `zelta sync` will only replicate the latest snapshots of the indicated volume and its descendants.

```sh
zelta sync [options] source_volume target_volume
```


## zelta backup

For a more complete backup including snapshot history, you can use `zelta backup`, which will first snapshot the source and replicate as much as possible to the target. If the target doesn't exist, it will function like an improved `zfs send -R` in that will replicate snapshot histories for children even if they differ from their parent.

```sh
zelta backup source_volume target_volume
```


## zelta policy

`zelta policy` (or just `zelta`) orchestrates the replication process. The configuration file `zelta.conf` allows you to specify various parameters, including backup roots, sites, hosts, and datasets.

```yaml
BACKUP_ROOT: pool/Backups

DAL1:
  fw1.dal1:
  - fw1-boot/jail/webproxy_bti
  host00.bts:
  - ssd00/jail/app1.asi
  ...
```

In `zelta.conf`, you can organize your hosts into different Sites which can be used for multi-threaded replication. Several targeting options are provided for any backup naming hierarchy. See the [configuration example](https://github.com/bellhyve/zelta/blob/main/zelta.conf).

Usage:sh
```sh
zelta [optional_site_host_or_dataset] [...]
```

If one or more arguments are provided, ```zelta``` will limit the replication process to the specified sites, hosts, or datasets. If no argument is provided, it will process according to the settings in the configuration file.


## Installation Notes

- The scripts were written on FreeBSD's built-in (Kernighan) awk.
- All updates to the main branch are additionally tested on MacOS and Debian GNU/Linux with the packages nawk, mawk, and gawk.
- PLEASE open an issue if Zelta is not working as expected on your system; see the FAQ for know problems and workarounds.
- Make sure ssh auth and "zfs allow" is correctly configured for all involved systems.


## Future

See Zelta's issues for active development notes. An older version of Zelta contained a configuration editor and socat/netcat support, but in practice they weren't as useful as expected. Configuration via JSON pipe (using JSON.awk) and/or database will likely be added for very large fleets.


## Contributing

Testing and contributions to enhance these tools are welcome. Please feel free to submit pull requests or open issues for any bugs or feature requests.


## History

The original version of Zelta, `zdelta`, was deployed internally at Bell Tower Integration on May 2020. The first production of Zelta was deployed in September 1, 2021.
