Minio
=====

Minio can be used to emulate an S3-compatible setup. When a native S3-like storage provider
is already present in your network or cloud provider, we highly advise using that instead.


Setting up Minio
----------------
Once Minio is installeed on the servers (For example through our provided ansible playbook),
one should install the minio client (mc) and configure it.

Per server, one should run the following command:

mc config host add <ALIAS> <YOUR-S3-ENDPOINT> <YOUR-ACCESS-KEY> <YOUR-SECRET-KEY>

The mc admin commands can then be used for cluster administration.
Our playbook will automatically add these config entries for you.

Minio philosophy
-----------------
Minio clusters are configured with a fixed size once, and cannot be resized
afterwards. It is thus important to make a good estimate about the amount of
data you are going to store.  The original philosophy was a set-up-and-forget
strategy.  You set up N disks and then you have a N/2 redundancy. Once half of
your disks are dead (or a bit earlier) it is time to set up a new cluster and
migrate everything using Minio's mirroring facilities. Of course this is not
ideal because the longer you have your cluster, the less space it will be able
to reliably store.  Hence minio has gotten some healing capabilities, which we
will cover how to use in the next section. It is possible to replace broken
disks with fixed disks, and then heal.

However, it is not possible to shrink or increase the cluster size. If the
cluster is starting to get full, you will need to set up a parallel bigger
cluster, mirror everything to the new cluster, and then swap the DNS entries to
the new one and then decomission the old one.


Minio maintenance
-----------------
There will be times where one wants to take a minio server down for
maintenance.  One might want to apply security patches, or want to take out a
broken disk and replace it with a fixed one.   Minio will not tell you the
health status of disks; you should have separate alerting and monitoring in
place to keep track of hardware health. One could look at S.M.A.R.T. values
that the disks produce with Prometheus node_exporter
(https://github.com/prometheus-community/node-exporter-textfile-collector-scripts/blob/master/smartmon.sh)

Special care has to be taken when restarting Minio nodes, but it should be safe
to do so.  Minio can operate in read-write mode with (N/2) + 1 instances
available in the cluster and it can operate in read-only mode with N/2 nodes
available in the cluster.  To ensure normal working of the cluster without down
time, we advice taking down servers and setting them up again one by one.

Stopping a server might potentially disrupt any API call that is being made to
minio.  Say if someone is writing to a bucket, and this API call is being
served by the server we are restarting, then this API call will be interrupted
and the user must retry.  When you shut down a node, one should take
precautions that subsequent API calls are sent to other nodes in the cluster.

A server can be stopped by running `systemctl stop minio-server`.  After that
`mc admin <server-name> status` should report the node as being down.  Writes
that happen during the server being down will obviously not be synced to the
server that is offline. It is important that once you bring the server back
online that you heal it. This will redistribute that data and parity
information such that the files that were written during the downtime are
redundant again.  If one does not heal a server after being down, and continues
to restart servers, then writes will become less and less durable over time. It
is thus recommended to heal a server once it is back up; before attemtping to
restart any other servers.

A heal is performed as follows: mc admin heal -r <server-name>

On a routine restart of the system, such a heal procedure should not take very
long, as there is already some data on the disk from before you shut the server
down. Of course if you replaced an unhealthy disk during the downtime, healing
might take a bit longer.

After the server has successfully been healed, you can continue restarting the
next server.  Repeat this process until all servers have been restarted


Note that there are other reasons but servers restarts that can cause nodes to
become out of sync.  For example, if there is a network failure that causes
some of the nodes to not be reachable, writes will be less durable too. It is
thus important to have good monitoring in place and respond accordingly.  Minio
itself will auto-heal the cluster every 24 hours if the administrator doesn't
trigger a heal themselves.




Hurdles from the trenches
-------------------------------------------------------------------------

I have done some more go code reading and have solved more minio mysteries
minio will   detect if a directory is a mount point and if it is call statfs(2)
to figure out the amount of available blocks and if it's not a mount directory,
it will just call  du . in a for loop and update some counter (which sounds
like a bad strategy to me)
github.com/minio/minio/blob/e6d8e272ced8b54872c6df1ef2ad556092280224/cmd/posix.go#L320-L352
so the answer is: if you use minio , e.g. with mountpoints, it will silently do
the right thing and if you configure it to use two directories on the samem
ount, it will siltently not crash but do something slightly incorrect instead.
(du is not a very reliable way to get Used metrics)

So the Used metric in `mc info` is lying. We should instead look at the `Total` and `Available`
metric which are derived from statfs. Those are already exposed by node-exporter anyway.

Moral of the story: we're probably getting weird numbers because we're not
using disks but we're using folders instead. We should use disks.


When doing a healing procedure , minio will give you feedback per bucket item.
If a bucket item hapens to be say 500Megabytes, it might look like the progress
is stuck, but it just means it doesn't update until the entire 500mb file is
healed. Don't worry and have a bit of patience.
