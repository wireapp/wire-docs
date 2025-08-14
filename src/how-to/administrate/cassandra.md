# Cassandra

This section is about **how to perform a specific task**. If you want to **understand how a certain component works, please see** [Reference](../../understand/README.md#understand)

The rest of the page assumes you installed using the ansible playbooks from [wire-server-deploy](https://github.com/wireapp/wire-server-deploy/tree/master/ansible)

For any command below, first ssh into the server:

```default
ssh <name or IP of the VM>
```

This section only covers the bare minimum, for more information, see the [cassandra
documentation](https://cassandra.apache.org/doc/latest/)

<a id="check-the-health-of-a-cassandra-node"></a>

## Check the health of a Cassandra node

To check the health of a Cassandra node, run the following command:

```sh
ssh <ip of cassandra node> /opt/cassandra/bin/nodetool status
```

or if you are running a newer version of wire-server (altough it should be backwards compatibile)

```sh
ssh <ip of cassandra node> /opt/cassandra/bin/nodetool -h ::FFFF:127.0.0.1 status
```

You should see a list of nodes like this:

```sh
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address         Load       Tokens          Owns (effective)   Host ID                                Rack
UN  192.168.220.13  9.51MiB    256             100.0%             3dba71c8-eea7-4e35-8f35-4386e7944894   rack1
UN  192.168.220.23  9.53MiB    256             100.0%             3af56f1f-7685-4b5b-b73f-efdaa371e96e   rack1
UN  192.168.220.33  9.55MiB    256             100.0%             RANDOMLY-MADE-UUID-GOES-INTHISPLACE!   rack1
```

A `UN` at the begginng of the line, refers to a node that is `Up` and `Normal`.

You can also check the logs of the cassandra server with

```default
journalctl -u cassandra.service 
```

## How to inspect tables and data manually

```sh
cqlsh
# from the cqlsh shell
describe keyspaces
use <keyspace>;
describe tables;
select * from <tablename> WHERE <primarykey>=<some-value> LIMIT 10;
```

If your local install does not have cqlsh available, you can use docker instead:

```default
sudo docker run -it --rm cassandra:3.11 cqlsh 172.16.0.132 9042
```

## How to rolling-restart a cassandra cluster

For maintenance you may need to restart the cluster.

On each server one by one:

1. check your cluster is healthy: `nodetool status` or `nodetool -h ::FFFF:127.0.0.1 status` (in newer versions)
2. `nodetool drain && systemctl stop cassandra` (to stop accepting writes and flush data to disk; then stop the process)
3. do any operation you need, if any
4. Start the cassandra daemon process: `systemctl start cassandra`
5. Wait for your cluster to be healthy again.
6. Do the same on the next server.

## Migration 

The following process was made in particular for a K8ssandra migration, but the same process can be applied in a cassandra-to-cassandra migration.

> **⚠️ Important:**  
> This migration involves approximately **1 hour of downtime**.  
> Plan accordingly and notify your users.  
> Shut down the `wire-server` before starting the migration.  
> Have users create backups for extra safety.

Tools used:
- `nodetool`
- `sstableloader`
- `cqlsh`

Both tools come with our solutions for Cassandra and K8ssandra.

---

### Prepare your new cassandra/k8ssandra cluster
Install and prepare your Cassandra/K8ssandra cluster. 
For K8ssandra you can use our testing [solution](https://github.com/wireapp/wire-server-deploy/blob/master/offline/k8ssandra_setup.md) and charts as needed.  

> **Note:** Some modifications may be required for your environment if you decide to use our k8ssandra solution.

---

### Update Service References
Change all service references to Cassandra hosts (`cassandra.host`) in `values/wire-server/values.yaml`.

Example:
```yaml
cassandra-migrations:
  # images:
  #   tag: some-tag (only override if you want a newer/different version than what is in the chart)
  cassandra:
    host: <new-cassandra-or-k8ssandra-service-here>
    replicationFactor: 3
```

Or apply a `sed`:

```bash
sed -i 's/<old-cassandra-service>/<new-cassandra-or-k8ssandra-service>/g' values/wire-server/values.yaml
```

---

### Reinstall wire-server

Reinstall `wire-server` so migration jobs can apply the required keyspace and table structure to your new cluster.

---

### Flush data on all nodes

Flush the data on each Cassandra node in the old cluster to ensure all in-memory writes are persisted to disk.

```bash
nodetool flush brig
nodetool flush galley
nodetool flush spar
nodetool flush gundeck
```
---

### Copy SSTables

Copy SSTables from one Cassandra node for the required keyspaces (brig, spar, gundeck, and galley).

If Cassandra was installed using Wire's Ansible playbook, data will be under `/mnt/cassandra/data`.

```bash
cp -r /mnt/cassandra/data/brig    backup/
cp -r /mnt/cassandra/data/spar    backup/
cp -r /mnt/cassandra/data/galley  backup/
cp -r /mnt/cassandra/data/gundeck backup/
```
---

### Move backup into the new cluster

For Cassandra just copy it to the new cluster. 
For K8ssandra, make a volume mount pointing to the backup directory (if supported by your charts), or copy files directly into one of the datacenter pods.

Example using `kubectl cp`

```bash
kubectl cp backup k8ssandra-cluster-datacenter-1-default-sts-0:/tmp -n <k8ssandra-namespace>
```
---

### Run sstableloader

Run `sstableloader` for each table in each keyspace.
For simplicity and automation, the following script can be used.
Adjust BACKUP_DIR and HOSTS for your setup.

HOSTS can point to a single or multiple nodes. For K8ssandra migration it is recommended to point it to K8ssandra headless service.

`sstableloader` will discover the cluster topology and stream data accordingly.

```bash
#!/bin/bash
set -euo pipefail

BACKUP_DIR="backup"

HOSTS=""

for keyspace in "$BACKUP_DIR"/*; do
    [ -d "$keyspace" ] || continue
    echo "===== Keyspace: $(basename "$keyspace") ====="

    for table in "$keyspace"/*; do
        [ -d "$table" ] || continue
        echo "----- Loading table: $(basename "$table") -----"
        sstableloader -d "$HOSTS" "$table"
    done
done

```

#### Notes on duration
- tested on a small DB with 2000 fresh users (15-20 minutes)
- for production databases longer in use a longer migration is expected

---

One the script has finished execution, the migration is complete.
You can verify by comparing the count of tables between the old and the new cluster using `cqlsh`, for example:

```cqlsh
SELECT COUNT(*) from brig.user;
```

The count between the two should be the same.
Once verified, you can bring the `wire-server` service back online.