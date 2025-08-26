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

## How to find a user's team from their email

There are two keyspaces `brig` and `galley` in Cassandra DB where team related data is distributed.

- The `galley` keyspace has the table called `team` which has the team name with team UUID.
- The `brig` keyspace has the table called `user` which has the user info including email, user ID and team UUID.

1. Get the team UUID from the `brig.user` table:

```sql
cqlsh> SELECT team
FROM brig.user
WHERE email = 'the-user@example.com'
ALLOW FILTERING;
```

Output will be a UUID like: `e93308fc-1676-4d53-af15-4b7f5fa7599a`

2. Use the team UUID to get the team name in `galley` keyspace:

```sql
cqlsh> SELECT name
FROM galley.team
WHERE team = e93308fc-1676-4d53-af15-4b7f5fa7599a;
```
Output will be the human-readable team name, e.g. "Spouse Comms".

Note: Please checkout the [test cassandra schema](https://github.com/wireapp/wire-server/blob/develop/cassandra-schema.cql) to get an understanding of the production database entities.
