# PostgreSQL High Availability Cluster - Quick Setup

## What You're Building

You're setting up a three-node PostgreSQL cluster where one node acts as the primary (handling all writes) and two nodes act as replicas (ready to take over if the primary fails). The system includes automatic failover capabilities through [repmgr](https://www.repmgr.org/docs/current/index.html) and split-brain protection to prevent data corruption during network partitions.

## Prerequisites

Before you begin, ensure you have three Ubuntu servers with static IP addresses and SSH access configured.

## Step 1: Define Your Inventory

Create or edit your inventory file at `ansible/inventory/offline/hosts.ini`. This file tells Ansible about your three PostgreSQL servers and how they should be configured.

```ini
[all]
postgresql1 ansible_host=192.168.122.236
postgresql2 ansible_host=192.168.122.233
postgresql3 ansible_host=192.168.122.206

[postgresql:vars]
postgresql_network_interface = enp1s0
postgresql_version = 17
wire_dbname = wire-server
wire_user = wire-server
wire_pass = CHANGE_ME_strong_password_123 # use strong password, if this is commented out, a random password will be created automatically via ansible playbook.

[postgresql]
postgresql1
postgresql2
postgresql3

[postgresql_rw]
postgresql1

[postgresql_ro]
postgresql2
postgresql3
```

The structure here is important. The `postgresql_rw` group designates your primary node (the one that accepts writes), while `postgresql_ro` contains your replica nodes (which follow the primary and can be promoted if needed). The network interface variable tells PostgreSQL which network adapter to use for cluster communication between nodes.

## Step 2: Test Connectivity

Before running any deployment commands, verify that Ansible can reach all three servers. This quick check saves time by catching connection issues early.

```bash
d ansible all -i ansible/inventory/offline/hosts.ini -m ping
```

You should see three successful responses. If any node fails to respond, check your SSH configuration and network connectivity before proceeding.

## Step 3: Deploy the Complete Cluster

Run the main deployment playbook. This single command orchestrates the entire installation process, which takes approximately ten to fifteen minutes to complete.

```bash
d ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml
```

Behind the scenes, this playbook performs several sequential operations. First, it installs PostgreSQL version 17 and repmgr on all three nodes. Then it configures the first node as the primary and sets up the repmgr metadata database. Next, it clones the two replica nodes from the primary and registers them with the cluster. The playbook also deploys the split-brain detection system and creates the Wire database with the appropriate user credentials. Finally, it runs health checks to verify everything is working correctly.

## Step 4: Verify the Cluster

After deployment completes, check that your cluster is healthy and properly configured. SSH into any of the three nodes and run the cluster status command.

```bash
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show
```

You should see output showing one primary node marked with an asterisk and two standby nodes, all in the running state. The standby nodes should list the primary as their upstream node, confirming that replication is active.

Next, verify that all the critical services are running correctly on each node.

```bash
sudo systemctl status postgresql@17-main repmgrd@17-main detect-rogue-primary.timer
```

All three services should show as active. The postgresql service runs the database engine, repmgrd monitors cluster health and handles automatic failover, and the detect-rogue-primary timer prevents split-brain scenarios by checking for conflicting primary nodes every thirty seconds.

## Step 5: Check Replication Status

On the primary node, verify that both replicas are actively receiving data through streaming replication.

```bash
sudo -u postgres psql -c "SELECT application_name, client_addr, state FROM pg_stat_replication;"
```

You should see two rows, one for each replica, with the state showing as "streaming". This confirms that changes on the primary are being continuously replicated to both standby nodes.

## Step 6: Note Your Wire Database Credentials

During deployment, the playbook generated a secure password for the Wire database user. You'll find this password in the Ansible output under the task named "Display PostgreSQL setup completion". Save this password securely as you'll need it when configuring your Wire server to connect to this database cluster.

## Optional: Test Automatic Failover

If you want to verify that automatic failover works correctly, you can simulate a primary failure. On the current primary node, stop the PostgreSQL service.

```bash
sudo systemctl mask postgresql@17-main && sudo systemctl stop postgresql@17-main
```

Wait approximately thirty seconds, then check the cluster status from one of the replica nodes. You should see that one of the replicas has been automatically promoted to primary. The repmgrd daemon detects the failed primary, forms quorum with the remaining nodes, selects the best candidate based on replication lag and priority, and promotes it automatically. The other replica will automatically reconfigure itself to follow the new primary.

## What Happens During Failover

Understanding the failover process helps you trust the system. When the primary becomes unavailable, each repmgrd daemon tries to reconnect every five seconds. After five failed attempts (about 25 seconds), the daemons on the replica nodes communicate to reach consensus that the primary is truly down. They require at least two nodes to agree in a three-node cluster, preventing false positives from network hiccups. The system then selects which replica to promote based on two factors: how caught up each replica is with the primary's data, and the priority value you configured in the inventory. The selected replica is promoted to become the new primary using PostgreSQL's native promotion function. Finally, the remaining replica automatically detects the new primary and begins following it, and any Kubernetes services are updated to point to the new primary through the postgres-endpoint-manager component.

## Recovery Time Expectations

In the event of a primary failure, the PostgreSQL cluster itself recovers within thirty seconds. However, applications running in Kubernetes may take slightly longer to reconnect because the postgres-endpoint-manager updates Kubernetes endpoints on a two-minute polling cycle. This means your Wire services will experience between thirty seconds and two minutes of database unavailability during an unplanned failover event.


Please check [the details documentation](https://github.com/wireapp/wire-server-deploy/blob/main/offline/postgresql-cluster.md) on how to debug if there are some failover happens or the cluster requires some emergency recover from the wire-server-deploy repository.

## Next Steps

With your PostgreSQL HA cluster running, you're ready to integrate it with your Wire server deployment. The cluster runs independently outside Kubernetes, providing a stable database foundation. The postgres-endpoint-manager component (deployed separately) with postgres-external helm chart keeps your Kubernetes services pointed at the current primary node, ensuring seamless connectivity even during failover events.

### Install postgres-external helm chart

From wire-server-deploy directory run:

```bash
d helm upgrade --install postgresql-external ./charts/postgresql-external
```

This helm charts configures the services `postgresql-external-rw` and `postgresql-external-ro` with corresponding endpoints.

The helm chart configures a postgres-endpoint-manager cronjob which runs in every two minutes to check the current primary, if any failover happens, the cronjob updates the corresponding endpoints with current primary and standbys. If the cluster is stable the cronjob runs like a probe.

You can check the logs of the cronjob for details:

```bash
# get the cronjob pods
d kubectl get pods -A | grep postgres-endpoint-manager

# Inspect the logs of one of the pods to check how cronjob is detecting the primary and standby postgres nodes and updating when necessary.
d kubectl logs postgres-endpoint-manager-29329300-6zphm # replace this with the pods found by the above command
```

If you are interested how the endpoints get updated, you can check the [postgres-endpoint-manager](https://github.com/wireapp/postgres-endpoint-manager) repository



