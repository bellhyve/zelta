# Zelta Replication Suite

This suite of tools provides a streamlined approach for managing ZFS snapshot replication across various systems. It consists of three main components: ```zmatch```, ```zpull```, and ```zelta```, each designed to handle specific aspects of the snapshot replication process. ```zelta``` is intended to be run with *no* requirements on backup sources and *without elevated privileges.*

The goal of this project will be to keep the tools as simple as possible with intuitive defaults and few options. zelta works best as a cron job in conjunction with a snapshot creating and pruning utility like the excellent [zfsnap](https://github.com/zfsnap/zfsnap).

### Quick Start: Setup

`pkg install -y git; git clone https://github.com/bellhyve/zelta.git ; cd zelta; cp zmatch zelta zpull /usr/local/bin/`

### Quick Start Example: Back up your computer

After adding a drive and creating a pool called "opt", e.g., `zpool create opt ada0`:

```sh
zfs snapshot -r zroot@`date -j +%Y-%m-%d_%H.%M.%S`
zpull zroot opt/Backups/myboot
```

zpull will respond with something like: `14 streams received, 4G copied in 14 seconds`

Simply repeat the process to update. zpull does not mount after replicated by default. Consider inheriting mountpoints for easier maintenance, e.g., `zfs inherit -r mountpoint opt/Backups`

### Quick Start: Back up the universe

On your backup servers, create a backup user (```pw useradd backup -m```) and give it access to replicate to your backup target (```zfs allow -u backup receive,mount,create opt/Backups```). Note that the backup user will not be able to receive any property it doesn't have permissions to. To back up a default FreeBSD 14 system, that would require: `receive,mount,create,canmount,mountpoint,setuid,exec,atime,compression`. Add a key (or create one using ```ssh-keygen```) for the backup user, and note that you will be using its public key file (usually ```/home/backup/.ssh/id_rsa.pub```).

On your source servers also create a backup user, and grant it access to send snapshots from your source volumes, e.g., ```zfs allow -u backup send,snapshot,hold tank/vm```. Add the contents of the backup servers' public keys to ```~backup/.ssh/authorized_keys``` (and set permissions if necessary).

Test ssh access from the backup servers to the source servers.

Set up and edit **zelta.conf** on your backup servers.

```sh
mkdir /usr/local/etc/zelta
vi /usr/local/etc/zelta/zelta.conf
```

First, let's make a configuration to test local backups. Note the two spaces before host and dataset names:

```yaml
MySites:
  localhost:
  - zroot: opt/Backups/myboot
```

Next, add some options and more datsets:

```yaml
BACKUP_ROOT: opt/Backups

MySites:
  localhost:
  - zroot
  host1:
  - tank/vm/one
  - tank/vm/two
  host1:
  - tank/jail/three
  - tank/jail/four
```

And so on. To run the replication process, run:

```sh
zelta
```

See the [configuration example](https://github.com/bellhyve/zelta/blob/main/zelta.conf) for more details.


## zmatch

```zmatch``` is a tool used for comparing ZFS datasets. It identifies the most recent matching snapshot between two given volumes. This tool is particularly useful for determining if datasets are in sync and identifying the latest common snapshot.

```sh
zmatch [source_volume] [target_volume]
```

## zpull

```zpull``` handles the actual replication of ZFS snapshots between a source and a target volume. It uses the output of ```zmatch``` to determine which snapshots need to be sent and then performs the replication.

```sh
zpull [source_volume] [target_volume]
```

## zelta

```zelta``` orchestrates the replication process, coordinating between ```zmatch``` and ```zpull```. It reads from a configuration file to determine which datasets to replicate and where to replicate them.

The configuration file ```zelta.conf``` allows you to specify various parameters, including backup roots, sites, hosts, and datasets. Each section of the config file defines a specific aspect of the replication process.

Example Configuration (```zelta.conf```):yaml
```yaml
BACKUP_ROOT: outerspace/Backups
PREFIX: 0

DAL1:
  fw1.dal1:
  - fw1-boot/jail/webproxy_bti
  host00.bts:
  - ssd00/jail/app1.asi
  ...
```

In ```zelta.conf```, you can define different sites, each with specific hosts and datasets. Several targeting options are provided for any backup naming hierarchy. See the [configuration example](https://github.com/bellhyve/zelta/blob/main/zelta.conf).

Usage:sh
```sh
zelta [optional_site_host_or_dataset]
```

If one or more arguments are provided, ```zelta``` will limit the replication process to the specified sites, hosts, or datasets. If no argument is provided, it will process according to the settings in the configuration file.

Installation and Requirements
- The scripts are compatible with awk using the NetBSD systime() extension (in FreeBSD base as of 2019).
- Awk is currently hardcoded to /usr/bin/awk.
- Install the scripts (zmatch, zpull, zelta) /usr/local/bin/ or any directory in PATH
- For zpull, make sure ssh auth and "zfs allow" is correctly configured for target systems.
- For zelta, edit /usr/local/etc/zelta/zelta.conf to match your environment and replication needs.

## Future

The previous version of the zelta suite used internally includes a zeport reporting tool and a zmove configuration editing tool, and need to be refactored before being added to this repository.

## Contributing

Testing and contributions to enhance these tools are welcome. Please feel free to submit pull requests or open issues for any bugs or feature requests.