# Back Up a Local Pool

Given a precious pool called `tank` and a secondary pool called `sink`:

```sh
zelta backup tank sink/Backups/tank
```

The above command will create a dated snapshot of the pool `tank` and replicate it recursively to `sink/Backups/tank`. To perform this action every night at midnight, put the same command in cron via `crontab -e`:

```
@daily zelta backup tank sink/Backups/tank
```

You can also make a remote backup via `ssh` by defining an endpoint and dataset in the format `[user@]host:target/dataset`,  For example: 
```sh
zelta backup tank backup@remote.host:sink/Backups/tank`
```


# Confirm Matching Replicas

We frequently use `zelta match` to identify if a replica is up to date. To confirm the backup in the first example is complete, you can run the following:

```sh
% zelta backup tank sink/Backups/tank
target has latest source snapshot: @2024-01-26_14.38.15
target has latest source snapshot: @/ROOT2024-01-26_14.38.15
...
```

If you see `target has latest source snapshot`, everything is up to date. Otherwise, `zelta match`'s output can help you evaluate your replica's status and decide what to do next. Some responses are:
* `guid mismatch on: @...`: Snapshots were taken on both the source and target and must be resolved before replicating. Consider making a new replica with `zelta backup` or carefully use `zfs rollback`, and check your snapshot policy on the source and target.
* `need snapshot for source: ...`: Your dataset tree is "Swiss cheesed" with missing snapshots so it cannot be replicated safely with `zelta sync`'s default mode. But using `zelta backup` or `zelta sync -S` will create a snapshot for you and perform the replication.
* `no source snapshots found` or `invalid target`: These messages often appear when entering the source endpoint/dataset name incorrectly.


# Review a Backup

Zelta does not assume that backups will be writeable. For recovery, always first consider retrieving backup files in the `.zfs/snapshot` directory on your source/primary replica as a potentially safe and efficient recovery option. However, depending on security concerns, disaster recovery, and DR testing scenarios, it will be most necessary to work with a writeable temporary clone of the backup, which consumes almost no additional space on the pool. Use the `zelta clone` command to create this environment.
```sh
zelta clone sink/Backups/tank sink/temp/cloned-tank`
```

Consider naming the clones clearly to remind you that they can be safely deleted. When done with the clones, you can destroy them with a privileged user without affecting your backup:
```sh
zfs destroy -r sink/temp/cloned-tank`
```


# Use ZFS's Native `zfs send -R`

Although you will likely find `zelta sync -I` or `zelta backup` more complete and useful, using `zfs send -R` for both new and updated streams can be much faster because fewer snapshots need to be listed before computing the replication stream. If you're confident you're always using recursive snapshots consistently, use:
```sh
zelta sync -R -d1 tank sink/Backups/tank
```

You can also instruct Zelta sync to only create a new snapshot if new data has been written to the source dataset:
```sh
zelta sync -sRd1 tank sink/Backups/tank
```


# Safely migrate a VM or container instance (failover and failback)

This example describes the process of performing moving a VM between twin hosts. Zelta reduces the number of commands needed versus using `ssh` and additional `zfs` commands manually and will help you avoid common pitfalls in a failover/failback process. This example is expanded upon below in the `Automatic Instance Migration` use case example. Once set up, the failover/failback requires 5 commands to perform safely that can be easily be added to part of your vm/instance control scripts. *To-do: A soon-to-be-added `zelta sync -s` switch will snapshot a pool only if it has been written to since its last snapshot, which will provide an additional safety check before starting a host.`

### Prepare for a fast failover

In this example, we have a pair of twin hosts, `host1` and `host2`, with similar configurations:
* `host1` has a pool called `ssd1` currently running a VM called `win11.belltower.atlantis2`.
* `host2` has a pool called `ssd2`, with a hypervisor configuration which can also load a VM beneath this dataset.
* Virtual bridging configurations are identical between the systems, e.g., a bridge named `lan` is available on both systems linked to the same physical switch or VLAN.
* An account called `twin` is on both systems with ssh access between the two systems and `zfs allow` permissions for `send,snapshot,hold,receive,mount,create,snapshot,readonly` and any local permission set on VM dataset and sub dataset.
* Zelta will be installed for user `twin` on `host1`.
* The VMs contain their configuration files within the VM's parent dataset. If this is not the case in your setup, it's recommend the instance configurations be kept up to date on both twin hosts.
* In this example we'll use `vm stop` and `vm start` as the names of our control scripts which start and stop the hypervisor process.

Review the list above and be sure to double check `ssh` access for the `twin` user (preferably via key, without a password) and critical `zfs allow` permissions are set. You likely will need `compress,volmode,recordsize` or other permissions to replicate a variety of VMs. No destructive permissions are required for the proposed workflow.

### Perform the initial sync

To minimize downtime perform the initial sync while our VM is still running on `host1`. We'll use the `zelta sync -S` flag to make a snapshot and replicate it to `host2`.

```sh
myuser% sudo su - twin
twin% zelta sync -Sm ssd1/vm/win11.belltower.atlantis2 host2:ssd2/vm/win11.belltower.atlantis2
snapshot created: ssd1/vm/win11.belltower.atlantis2@2024-01-26_09.43.08
36G sent, 1/1 streams received in 29.88 seconds
```

### Perform the failover

To reduce downtime as much as possible, we'll use the following workflow:
* Perform another online sync from `host1` to `host2`.
* Shut down the VM on `host1`.
* Set `readonly` permissions the VM to prevent further writes. (At Bell Tower, we also unmount the VM.)
* Perform a final sync to `host2`
* Boot on `host2`.

For simplicity, we will assume you are running as an account with full `sudo` privileges and will run `vm` and `zfs` commands as `root`.

On `host1`:
```sh
sudo -u twin zelta sync -S ssd1/vm/win11.belltower.atlantis2 host2:ssd2/vm/win11.belltower.atlantis2
sudo vm stop win11.belltower.atlantis2
sudo zfs set readonly=on ssd1/vm/win11.belltower.atlantis2
sudo -u twin zelta sync -S ssd1/vm/win11.belltower.atlantis2 host2:ssd2/vm/win11.belltower.atlantis2
```

On `host2`:
```sh
sudo zfs set readonly=off ssd2/vm/win11.belltower.atlantis2
sudo zfs mount ssd1/vm/win11.belltower.atlantis2
sudo vm start win11.belltower.atlantis2
```

### Failing back

On `host2`:
```sh
sudo vm stop win11.belltower.atlantis2
sudo zfs set readonly=on ssd2/vm/win11.belltower.atlantis2
```

On `host1`:
```sh
sudo -u twin zelta sync -S host2:ssd2/vm/win11.belltower.atlantis2 ssd1/vm/win11.belltower.atlantis2
sudo zfs set readonly=off ssd1/vm/win11.belltower.atlantis2
sudo vm start win11.belltower.atlantis2
```

### Conclusion

Using the `readonly` flag or unmounting datasets before the final sync ensure that syncing can be performed between hosts without requiring a `zfs rollback`. Consider adding VM control scripts including `readonly` checks to ensure this is maintained in a disciplined way by your system administrators.

After performing the first sync, using `zelta sync` or `zelta policy` to continue frequent replication between hosts will further reduce the time and stress required to perform these actions. We recommend process be implemented in addition to, not a replacement for, your overall local and remote backup procedures.


# Creating Visualizations With Grafana

Using `zelta`'s JSON output mode, it's easy to create various backup visualizations in Grafana. These can be helpful for getting an overview of smaller bottlenecks that would be otherwise difficult to monitor, and provide early warnings for hosts that are slow to list and need to be pruned. The following examples were creating using a subset of Bell Tower's production backups. To make this happen:
* Use `zelta -j` or the `JSON: 1` sinkion in the policy.
* Redirect Zelta's cron output to a JSON log.
* Import the JSON into an SQLite database.
* Visualize the SQLite database(s) in Grafana.

## Graph Examples
<img width="50%" alt="Bandwidth Line Graph Example" src="https://github.com/bellhyve/zelta/assets/76711576/b97e7af2-075b-4554-92fe-7f3a1fc76529">
<img width="50%" alt="Cumulative Replication Time Chart" src="https://github.com/bellhyve/zelta/assets/76711576/79d90e32-4ee7-457a-95cd-fab27a2c0f6e">

## Setting Up SQLite

Here's some example Python code for importing the Zelta Policy output into a new or existing SQLite database.

```python
import json
import sqlite3
import sys

def read_json_objects(file):
    obj_str = ''
    depth = 0
    for line in file:
        for ch in line:
            if ch == '{':
                depth += 1
            if depth > 0:
                obj_str += ch
            if ch == '}':
                depth -= 1
                if depth == 0:
                    yield obj_str
                    obj_str = ''

# Connect to SQLite database
conn = sqlite3.connect(sys.argv[2])
cursor = conn.cursor()

# Create a table
cursor.execute('''CREATE TABLE IF NOT EXISTS data (json_data TEXT)''')

# Read and insert JSON data from file
with open(sys.argv[1], 'r') as file:
    for json_obj_str in read_json_objects(file):
        try:
            json_object = json.loads(json_obj_str)
            cursor.execute("INSERT INTO data (json_data) VALUES (?)", [json.dumps(json_object)])
        except json.JSONDecodeError as e:
            print(f"Error decoding JSON: {e}")

# Commit changes and close the connection
conn.commit()
conn.close()
```

## Setting Up Grafana

Be sure to capture Time appropriately so you can zoom in and out based on time. Here's an example visualization of a `BACKUP_ROOT` called `rust pool/Backups`:

```sql
SELECT
  json_extract(json_data, '$.startTime') as Time,
  REPLACE(json_extract(json_data, '$.targetVolume'), 'rustpool/Backups/', '') as Volume,
  json_extract(json_data, '$.replicationSize') as ""
FROM data
ORDER BY Time
```

And here's a visualization of the cumulative time consumed for each replication over the selected date range:

```sql
SELECT
  REPLACE(json_extract(json_data, '$.targetVolume'), 'rustpool/Backups/', '') as Volume,
  (sum(json_extract(json_data, '$.endTime')) - sum(json_extract(json_data, '$.startTime'))) as TotalTime
FROM data
WHERE
  json_extract(json_data, '$.startTime') >= ${__from:date:seconds} AND
  json_extract(json_data, '$.startTime') <=  ${__to:date:seconds}
GROUP by Volume
ORDER by TotalTime DESC
``` 


# Automatic Instance Migration

This is a proof of concept for providing a warm failover scenario simply by setting the appropriate ZFS properties. Snapshots are only taken, and replications are performed, only on the host where the instance is running. By avoiding snapshots unless a `written` property has been incremented, and keeping the `readonly` property set for the offline replica, a "split brain" scenario is impossible.

### Setup

A server called zelta-test-1 has 4 jails in `tank/jail`. We want them to sync to `zelta-test-2:tank/jail` bidirectionally, based on where the jail is started. This example is an attempt to provide the minimum code to do that.

### zelta.conf
```yaml
LetsGo:
  zelta-test-1:
  - tank/jail: zelta-test-2:tank/jail
  zelta-test-2:
  - tank/jail: zelta-test-1:tank/jail
```

### sentinel.sh

This script could be run on either of the servers, or a third "tie breaker" server that could handle exceptions.

```sh
INSTANCES="tank/jail/inst1 tank/jail/inst2 tank/jail/inst3 tank/jail/inst4"
RETENTION_POLICY='--2d'
TIME_FORMAT='date +%Y-%m-%d_%H.%M.%S'
SNAP=$($TIME_FORMAT)$RETENTION_POLICY
ssh zelta-test-1 "zfs list -Hpr -oname,written $INSTANCES |
        awk '{if (\$2) print \$1}' | \
        xargs -n1 -I% zfs snapshot %@$SNAP"
ssh zelta-test-2 "zfs list -Hpr -oname,written $INSTANCES |
        awk '{if (\$2) print \$1}' | \
        xargs -n1 -I% zfs snapshot %@$SNAP"
zelta
```


## Usage

Run the `sentinel` process frequently to keep the servers in sync to sinkimize for your expected RPO.

To safely cutover a VM or container, unmounting it after shutting down. Once unmounted or set to readonly, run your `sentinel` manually to snapshot and sync one last time.

To cause a VM or container to sync, simply mount and start it. Any changes to the instance will increment the `written` flag, causing the `sentinel` to snapshot and replicate it.


### Output

On zelta-test-1, we've started inst1, inst2, and inst4.

We've started inst3, stopped it, and restarted it on zelta-test-2, and back again.

Zelta is able to thread the changes back and forth successfully, regardless of where the instances are running.

```sh
LetsGo
  zelta-test-1
    tank/jail: 234K: ✔ transferred in 1.78s
  zelta-test-2
    tank/jail: 32K: ✔ transferred in 0.57s
LetsGo
  zelta-test-1
    tank/jail: 238K: ✔ transferred in 1.82s
  zelta-test-2
    tank/jail: 78K: ✔ transferred in 0.65s
LetsGo
  zelta-test-1
    tank/jail: 234K: ✔ transferred in 1.7s
  zelta-test-2
    tank/jail: 78K: ✔ transferred in 0.63s
```


### To-do

Ideally we need a sentinel process to do a few more things.
* Avoid overlapping of snapshotting and syncing jobs, e.g., `pgrep zfs || [run snapshot process]`
* For additional backups servers, we'd want to skip replicating the continuous snapshots. To do this, we could add a snapshot prediction mechanism in Zelta.
* Simplify resolution of "split brain" scenarios, or protect against snapshot writes when the instance is off on a given host, e.g., add readonly flags or unmount instance datasets not in use. 
