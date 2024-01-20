# Zelta Replication Suite

**Zelta** is a suite of tools offering a streamlined approach to managing ZFS snapshot replication across various systems. It's built with the intention of simplifying complex ZFS functionalities into user-friendly commands. With no package requirements on backup sources and no need for elevated permissions, Zelta is accessible and easy to integrate into existing workflows.

The suite comprises three main components:

- `zelta match`: Compares two ZFS volume trees, reporting matching snapshots or discrepancies. It's a helpful tool for replication assistance, rollback assistance, and source-backup validation.
- `zelta sync`: A robust ZFS volume tree replication tool with safe defaults.
- `zelta backup`: A policy-driven backup tool for managing extensive replication jobs.


## Goals and Methodology

ZFS's versatility is unparalleled in the open source world, but users of all experience levels wrestle with its complex command structures with non-intuitive defaults. Zelta addresses this by providing streamlined commands and safer defaults for common backup and migration tasks.

For example, the act of simply backing up a boot drive (`zfs send -R zroot@latest | zfs receive backup/zroot`) is difficult to construct and will likely result in errors and overlapping mounts. Zelta simplifies this process to:
- `zelta sync zroot backup/zroot`: Backs up the latest `zroot` snaphots to `backup/zroot`
- `zelta match zroot backup/zroot`: Confirms that the latest snapshots on the backup are identical.

It's both safer and easier to use for everone and simplifies complex backup and migration tasks for experts. We find it to be ideal for both routine maintenance and complex tasks like fleet backup management.

Zelta works with any snapshot management system (or none) and is used to back up thousands of volumes in conjunction with (zfsnap)[https://github.com/zfsnap/zfsnap].


## Quick Start: Setup

`install.sh` will copy the awk scripts to `/usr/local/share/zelta/` and the `zelta` shell wrapper to `/usr/local/bin/`, and some symlinks for zelta synonyms, `zmatch` and `zpull`. See the (FAQ)[https://github.com/bellhyve/zelta/wiki/Home-&-FAQ] for more information. 

```sh
git clone https://github.com/bellhyve/zelta.git
cd zelta
sudo sh ./install.sh
```

In addition to the (FAQ)[https://github.com/bellhyve/zelta/wiki/Home-&-FAQ], man page drafts are also available on the (wiki)[https://github.com/bellhyve/zelta/wiki/Home-&-FAQ]. Point-of-use documentaition is also provided in the installed examples:
- zelta.conf[https://github.com/bellhyve/zelta/blob/main/zelta.conf] for policy-driven backups
- zelta.env[https://github.com/bellhyve/zelta/blob/main/zelta.env] for location and behavior overrides


## Quick Start: Back up your computer

In this example, we have an OS installed with a ZFS pool called `zroot`. After attaching a new blank drive to the system, we detect a new drive as `da2`. We can create a blank pool called `backups` with a command such as `zpool create backups da2`.

Zelta does not (yet) have a snapshot function, so let's make one.

```sh
zfs snapshot -r zroot@$(date +%Y-%m-%d_%H.%M.%S)
```

Let's perform a quick "sanity check" to make sure `zelta` is working by comparing our snapshot to itself, and then a target volume on our new drive that doesn't exist yet.

```sh
zelta match zroot zroot
zelta match zroot backups/my_zroot_backup
```

You should see a list of `target has latest source snapshot` for all volumes under zroot. If we "match" against an empty target, we should see a similar list with `snapshots only on source`, which is exactly what we expect. To back up, use `zelta sync`.

```sh
zelta sync zroot backups/my_zroot_backup
3G sent, 21/21 streams received in 10.34 seconds
```

Simply repeat the snapshot and final `zelta sync` process to update your backup. To learn more, see the `zelta sync` section of this document and this (manpage draft)[https://github.com/bellhyve/zelta/wiki/zelta-sync-(man-page-draft)].


## Quick Start: Back up the universe using a policy

`zelta match` and `zelta sync` are useful for migrations and backup scripts that deal with a small number of replication jobs interactively. To deal with dozens, you can use `zelta backup` perform many backups and receive a human-readable backup report or JSON detail.

In the below, we'll start by doing the same as the first example, backing up a local `zroot` source to `backups/my_zroot_backup` using a policy. Set up and edit **zelta.conf**.

```sh
vi /usr/local/etc/zelta/zelta.conf
```

First, let's make a configuration to test local backups. The first line below is a unique Site name of choice, representing a locaiton or backup set. Note the two spaces before host and dataset names:

```yaml
MyLocalBackups:
  localhost:
  - zroot: backups/my_zroot_backup
```

Run `zelta`. It will perform the backup operation and report some details if it succeeds, or an "⊜" symbol if it finds nothing to replication. Now we extend our policy with options and more volumes.

On your backup servers, create a backup user and give it access to replicate to your backup target (`zfs allow -u backup receive,mount,create backups`). Note that the backup user will not be able to receive any property it doesn't have permission to. Missing some permissions doesn't prevent successful backups, but if you'd like to back up a default FreeBSD 14 system with all properties, you'd need these additional permissions: `canmount,mountpoint,setuid,exec,atime,compression`.

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

If all went well, a `zfs list` command will show that you have a backup of the five volumes listed in the configuration: `backups/my_zroot_backup`, `backups/host1/one`, `backups/host1/two`, `backups/host2/three`, and `backups/host2/four`.

See the [configuration example](https://github.com/bellhyve/zelta/blob/main/zelta.conf) for more details and useful options.


## zelta match

`zelta match` (or `zmatch`) is a tool used for comparing ZFS datasets. It identifies the most recent matching snapshot between two given volumes. This tool is particularly useful for determining if datasets are in sync and identifying the latest common snapshot.

```sh
zelta match [source_volume] [target_volume]
```

## zelta sync

`zelta sync` (or `zpull`) handles the actual replication of ZFS snapshots between a source and a target volume. It uses the output of `zelta match` to determine which snapshots need to be sent and then performs the replication.

```sh
zelta sync [source_volume] [target_volume]
```

## zelta backup

`zelta backup` (or just `zelta`) orchestrates the replication process. The configuration file `zelta.conf` allows you to specify various parameters, including backup roots, sites, hosts, and datasets.

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
zelta [optional_site_host_or_dataset]
```

If one or more arguments are provided, ```zelta``` will limit the replication process to the specified sites, hosts, or datasets. If no argument is provided, it will process according to the settings in the configuration file.


## Installation and Requirements

- The scripts are compatible with most version of awk.
- Make sure ssh auth and "zfs allow" is correctly configured for all involved systems.


## Future

The previous version of the zelta suite used internally includes a zeport reporting tool and a zmove configuration editing tool, and need to be refactored before being added to this repository.


## Contributing

Testing and contributions to enhance these tools are welcome. Please feel free to submit pull requests or open issues for any bugs or feature requests.
