Etcd
--------------------------

.. include:: includes/intro.rst

This section only covers the bare minimum, for more information, see the `etcd documentation <https://etcd.io/>`__

How to see cluster health
~~~~~~~~~~~~~~~~~~~~~~~~~~

If the file `/usr/local/bin/etcd-health.sh` is available, you can run

.. code:: sh

    etcd-health.sh

which should produce an output similar to::

    Cluster-Endpoints: https://127.0.0.1:2379
    cURL Command: curl -X GET https://127.0.0.1:2379/v2/members
    member 7c37f7dc10558fae is healthy: got healthy result from https://10.10.1.11:2379
    member cca4e6f315097b3b is healthy: got healthy result from https://10.10.1.10:2379
    member e767162297c84b1e is healthy: got healthy result from https://10.10.1.12:2379
    cluster is healthy

If that helper file is not available, create it with the following contents:

.. code:: bash

    #!/usr/bin/env bash

    HOST=$(hostname)

    etcdctl --endpoints https://127.0.0.1:2379 --ca-file=/etc/ssl/etcd/ssl/ca.pem --cert-file=/etc/ssl/etcd/ssl/member-$HOST.pem --key-file=/etc/ssl/etcd/ssl/member-$HOST-key.pem --debug cluster-health

and then make it executable: ``chmod +x /usr/local/bin/etcd-health.sh``

How to inspect tables and data manually
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code:: sh

    TODO


How to rolling-restart an etcd cluster
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On each server one by one:

1. Check your cluster is healthy (see above)
2. Stop the process with ``systemctl stop etcd`` (this should be safe since etcd clients retry their operation if one endpoint becomes unavailable, see `this page <https://etcd.io/docs/v3.3.12/learning/client-architecture/>`__)
3. Do any operation you need, if any.
4. ``systemctl start etcd``
5. Wait for your cluster to be healthy again.
6. Do the same on the next server.


Backing up and restoring
~~~~~~~~~~~~~~~~~~~~~~~~~
Though as long as quorum is maintained in etcd there will be no dataloss, it is still good to prepare 
for the worst. If a disaster takes out all nodes, then you might want to restore from an old backup.

Luckily, etcd can take periodic snapshots of your cluster and these can be used in cases of disaster recovery.



Troubleshooting
~~~~~~~~~~~~~~~~~~~~~~~~~~


How to recover from a single unhealthy etcd node after snapshot restore
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

After restoring an etcd machine from an earlier snapshot of the machine disk, etcd members may become unable to join.

Symptoms: That etcd process is unable to start and crashes, and other etcd nodes can't reach it::

    failed to check the health of member e767162297c84b1e on https://10.10.1.12:2379: Get https://10.10.1.12:2379/health: dial tcp 10.10.1.12:2379: getsockopt: connection refused
    member e767162297c84b1e is unreachable: [https://10.10.1.12:2379] are all unreachable

Logs from the crashing etcd::

    (...)
    Sep 25 09:27:05 node2 etcd[20288]: 2019-09-25 07:27:05.691409 I | raft: e767162297c84b1e [term: 28] received a MsgHeartbeat message with higher term from cca4e6f315097b3b [term: 30]
    Sep 25 09:27:05 node2 etcd[20288]: 2019-09-25 07:27:05.691620 I | raft: e767162297c84b1e became follower at term 30
    Sep 25 09:27:05 node2 etcd[20288]: 2019-09-25 07:27:05.692423 C | raft: tocommit(16152654) is out of range [lastIndex(16061986)]. Was the raft log corrupted, truncated, or lost?
    Sep 25 09:27:05 node2 etcd[20288]: panic: tocommit(16152654) is out of range [lastIndex(16061986)]. Was the raft log corrupted, truncated, or lost?
    Sep 25 09:27:05 node2 etcd[20288]: goroutine 90 [running]:
    (...)


Etcd will kick out nodes that run too far behind. So if you recover from an old disk snapshot, then it's write-ahead log number will likely be behind to what the rest of the cluster has already commited. If this happens, the node will be refused access to the cluster. To recover from such a scenario


From the docs I quote https://github.com/etcd-io/etcd/blob/master/Documentation/v2/admin_guide.md

> If a member’s data directory is ever lost or corrupted then the user should remove the etcd member from the cluster using etcdctl tool.
> A user should avoid restarting an etcd member with a data directory from an out-of-date backup. Using an out-of-date data directory can lead to inconsistency as the member had agreed to store information via raft then re-joins saying it needs that information again. For maximum safety, if an etcd member suffers any sort of data corruption or loss, it must be removed from the cluster. Once removed the member can be re-added with an empty data directory.

So lets first remove the node from the cluster.

These are the etcdv2 docs though so I don't trust them. But I also found a link to etcd3 docs with similar instructions:
https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/runtime-configuration.md#replace-a-failed-machine

The procedure to remove and add a member is documented here:
https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/runtime-configuration.md#remove-a-member

First lets make sure our broken member is stopped:
.. code:: sh

   root@node2:~# systemctl stop etcd

Now from a healthy node remove the broken node 

.. code:: sh

   root@node0:~# etcdctl3.sh  member remove e767162297c84b1e
   Member e767162297c84b1e removed from cluster 432c10551aa096af


By removing the member from the cluster, you signal the other nodes to not
expect it to come back with the right state. It will be considered dead and
removed from the peers.  This will allow the node to come up with an empty data
directory and it not getting kicked out of the cluster. The cluster should now
be healthy, but only have 2 members, and so it is not to resistent to crashes
at the moment!

.. code:: sh
   root@node0:~# etcd-health.sh 
   Cluster-Endpoints: https://127.0.0.1:2379
   cURL Command: curl -X GET https://127.0.0.1:2379/v2/members
   member 7c37f7dc10558fae is healthy: got healthy result from https://10.10.1.11:2379
   member cca4e6f315097b3b is healthy: got healthy result from https://10.10.1.10:2379
   cluster is healthy

Now from a healthy node, re-add the node you just removed, it should now be in the list as "unstarted",
instead of it not being healthy. 

.. code:: sh
   root@node0:~# etcdctl3.sh member add etcd_2 --peer-urls https://10.10.1.12:2380
   Member e13b1d076b2f9344 added to cluster 432c10551aa096af

   ETCD_NAME="etcd_2"
   ETCD_INITIAL_CLUSTER="etcd_1=https://10.10.1.11:2380,etcd_0=https://10.10.1.10:2380,etcd_2=https://10.10.1.12:2380"
   ETCD_INITIAL_CLUSTER_STATE="existing"
   root@node0:~# etcdctl3.sh member list
   7c37f7dc10558fae, started, etcd_1, https://10.10.1.11:2380, https://10.10.1.11:2379
   cca4e6f315097b3b, started, etcd_0, https://10.10.1.10:2380, https://10.10.1.10:2379
   e13b1d076b2f9344, unstarted, , https://10.10.1.12:2380, 


Now on the broken node, remove the on-disk state, which was corrupted, and start etcd
.. code:: sh

   root@node2:~# mv /var/lib/etcd /var/lib/etcd.bak
   root@node2:~# sudo systemctl start etcd

And now the cluster is healthy again!

.. code:: sh
   root@node2:~# etcd-health.sh
   Cluster-Endpoints: https://127.0.0.1:2379
   cURL Command: curl -X GET https://127.0.0.1:2379/v2/members
   member 7c37f7dc10558fae is healthy: got healthy result from https://10.10.1.11:2379
   member cca4e6f315097b3b is healthy: got healthy result from https://10.10.1.10:2379
   member e13b1d076b2f9344 is healthy: got healthy result from https://10.10.1.12:2379
   cluster is healthy


       
