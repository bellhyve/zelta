# Zelta Replication Suite

This suite of tools provides a streamlined approach for managing ZFS snapshot replication across various systems. It consists of three main components: ```zmatch```, ```zpull```, and ```zelta```, each designed to handle specific aspects of the snapshot replication process. ```zelta``` is intended to be run with *no* requirements on ZFS backup sources and assumes no elevated privileges. 

The goal of this project will be to keep the tools as simple as possible with intuitive defaults and few options. zelta works best as a cron job in conjunction with a snapshot creating and pruning utility like the excellent [zfsnap](https://github.com/zfsnap/zfsnap).


### Quick Start: Setup

`pkg install -y git; git clone https://github.com/bellhyve/zelta.git ; cd zelta; cp zmatch zelta zpull /usr/local/bin/`

### Quick Start Example: Back up your computer

After adding a drive and creating a pool called "opt", e.g., `zpool create opt ada0`, let's make a new snapshot of zroot.

```sh
zfs snapshot -r zroot@`date -j +%Y-%m-%d_%H.%M.%S`
```

First, use ```zelta match``` (or ```zmatch```) to see  the list of snapshots we'll back up.

```sh
zmatch zroot opt/Backups/localhost/zroot
```

We'll get a list of the snapshots we just made and the cumulative size of everything missing from ```opt```. By default, our replication tool, ```zelta replicate``` (or ```zpull```), will copy just the latest snapshot to save time. Use ```zelta match -R``` if you prefer to replicate zroot's entire snapshot history.

```sh
zpull zroot opt/Backups/myboot
```

zpull will probably respond with something like: `14 streams received, 4G copied in 14 seconds`. If you get an error, it might mean that your account needs additional ```zfs allow``` settings.

Simply repeat the process to update.

```sh
zmatch zroot opt/Backups/myboot
zpull zroot opt/Backups/myboot
```

The ```zelta match``` isn't actually necessary, but it's nice to see that our backup worked. That's it! You can pop your ```zfs snapshot``` and ```zelta replicate``` commands in your crontab to keep your system backed up.


### Quick Start: Back up the universe

On your backup servers, create a backup user (```pw useradd backup -m```) and give it access to replicate to your backup target (```zfs allow -u backup receive,mount,create opt/Backups```). Note that the backup user will not be able to receive any property it doesn't have permissions to. To back up a default FreeBSD 14 system, that would require: `receive,mount,create,canmount,mountpoint,setuid,exec,atime,compression`. Add a key (or create one using ```ssh-keygen```) for the backup user, and note that you will be using its public key file (usually ```/home/backup/.ssh/id_rsa.pub```).

On your source servers also create a backup user, and grant it access to send snapshots from your source volumes, e.g., ```zfs allow -u backup send,snapshot,hold tank/vm```. Add the contents of the backup servers' public keys to ```~backup/.ssh/authorized_keys``` (and set permissions if necessary).

Test ssh access from the backup servers to the source servers.

We can now use ```zelta match``` and ```zelta replicate``` on our backup server to check and replicate from our sources and beneath a local dataset. For example:

```sh
zelta replicate host1:zroot opt/Backups/host1/zroot
zelta replicate host2:zroot opt/Backups/host2/zroot
```

It never hurts to double check. Use ```zelta match``` to make sure we have our latest source snapshots in exactly the right place.
 
```sh
zelta match host1:zroot opt/Backups/host1/zroot
zelta match host2:zroot opt/Backups/host2/zroot
```

We're ready to create a backup policy in **zelta.conf** and back them up with one command.

```sh
mkdir -p /usr/local/etc/zelta
vi /usr/local/etc/zelta/zelta.conf
```

Let's make a simple policy for all of our previous examples.

```yaml
Snapshots:
  localhost:
  - zroot: opt/Backups/localhost/zroot
  - zroot: opt/Backups/localhost/zroot
  host1:
  - zroot: opt/Backups/host1/zroot
  localhost:
  - zroot: opt/Backups/host2/zroot
```

Just run ```zelta``` to have it loop through your backups.

```zelta``` has several useful configuration options. Here's are a few tweaks to the version above.

```yaml
BACKUP_ROOT: opt/Backups        # The top level of our backup target
HOST_PREFIX: 1                  # Add the hostname to the target snapshot name
RETRY: 2                        # Retry twice for failed replication attempts
INTERMEDIATE: 1                 # Retreive intermediate snapshots

Snapshots:
  localhost:
  - zroot                       # Since we've specified BACKUP_ROOT and HOST_PREFIX
  - zroot                       # there's no need to explicitly set the target name.
  host1:
  - zroot
  localhost:
  - zroot
```

And so on. To run the replication process again, run:

```sh
zelta
```

See the [configuration example](https://github.com/bellhyve/zelta/blob/main/zelta.conf) for more details.


## zelta match (zmatch)

```sh
zelta match [user@][host:]source/volume [user@][host:]source/volume
```

```zelta match``` (or ```zmatch```) is a tool used for comparing ZFS datasets. It identifies the most recent matching snapshot between two given volumes. This tool is particularly useful for determining if datasets are in sync and identifying the latest common snapshot.


## zelta replicate (zpull)

```sh
zelta replicate [source_volume] [target_volume]
```

```zelta replicate``` (or ```zpull```) handles the replication of ZFS snapshots between a source and a target volume. It uses the output of ```zelta match``` to determine which snapshots need to be sent and then performs the replication.


## zelta

Usage:sh
```sh
zelta [optional_site_host_or_dataset]
```

```zelta``` orchestrates the replication process. It reads from a configuration file to determine which datasets to replicate and where to replicate them.

The configuration file ```zelta.conf``` allows you to specify various parameters, including backup roots, sites, hosts, and datasets. Each section of the config file defines a specific aspect of the replication process.

In ```zelta.conf```, you can define different sites, each with specific hosts and datasets. Several targeting options are provided for any backup naming hierarchy. See the [configuration example](https://github.com/bellhyve/zelta/blob/main/zelta.conf).

If arguments are provided, ```zelta``` will limit the replication process to the specified sites, hosts, or datasets. If no argument is provided, it will process according to the settings in the configuration file.

Installation and Requirements
- The scripts are compatible with "one true awk" on FreeBSD and other systems.
- Awk is currently hardcoded to /usr/bin/awk.
- For zpull, make sure ssh auth and "zfs allow" is correctly configured for target systems.
- For zelta, edit /usr/local/etc/zelta/zelta.conf to match your environment and replication needs.

## Additional Features

Features are described in detail in the [configuration example](https://github.com/bellhyve/zelta/blob/main/zelta.conf).


## Future

- JSON and other output formats for reporting.
- A basic configuration editor to help keep the host list up to date.

## Contributing

Testing and contributions to enhance these tools are welcome. Please feel free to submit pull requests or open issues for any bugs or feature requests.
