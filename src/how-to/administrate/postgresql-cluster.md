# PostgreSQL High Availability Cluster - Quick Setup

## What You're Building

A three-node PostgreSQL cluster with one primary node (handling writes) and two replicas (ready to take over on failure). The system includes automatic failover via [repmgr](https://www.repmgr.org/docs/current/index.html) and split-brain protection to prevent data corruption during network partitions.

## Prerequisites

Three Ubuntu servers with static IP addresses and SSH access configured.

## Step 1: Define Your Inventory

Create or edit your inventory file at `ansible/inventory/offline/hosts.ini` to define your PostgreSQL servers and their configuration.

```ini
[all]
postgresql1 ansible_host=192.168.122.236
postgresql2 ansible_host=192.168.122.233
postgresql3 ansible_host=192.168.122.206

[postgresql:vars]
postgresql_network_interface = enp1s0
wire_dbname = wire-server
wire_user = wire-server

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

The `postgresql_rw` group designates your primary node (accepts writes), while `postgresql_ro` contains replica nodes (follow the primary and can be promoted if needed). The network interface variable specifies which adapter to use for cluster communication.

## Step 2: Test Connectivity

Verify Ansible can reach all three servers:

```bash
d ansible all -i ansible/inventory/offline/hosts.ini -m ping
```

You should see three successful responses. If any node fails, check your SSH configuration and network connectivity.

## Step 3: Deploy the Complete Cluster

Run the deployment playbook (takes 10-15 minutes):

```bash
d ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml
```

This playbook installs PostgreSQL 17 and repmgr on all nodes, configures the primary node, clones and registers the replicas, deploys split-brain detection, creates the Wire database with credentials, and runs health checks.

## Step 4: Verify the Cluster

Check cluster status from any node:

```bash
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show
```

You should see one primary node (marked with asterisk) and two standby nodes, all running. Standby nodes should list the primary as their upstream node.

Verify critical services are running:

```bash
sudo systemctl status postgresql@17-main repmgrd@17-main detect-rogue-primary.timer
```

All three services should be active: postgresql (database engine), repmgrd (cluster health and failover), and detect-rogue-primary timer (checks for conflicting primaries every 30 seconds).

## Step 5: Check Replication Status

On the primary node, verify both replicas are receiving data via streaming replication:

```bash
sudo -u postgres psql -c "SELECT application_name, client_addr, state FROM pg_stat_replication;"
```

You should see two rows (one per replica) with state "streaming", confirming continuous replication to both standby nodes.

## Step 6: Wire Database Credentials

The playbook generates a secure password and stores it in the `wire-postgresql-external-secret` Kubernetes secret. Running `bin/offline-deploy.sh` automatically syncs this password to `brig` and `galley` service secrets in `values/wire-server/secrets.yaml`.

If deploying/upgrading wire-server manually, use one of these methods:

### Option 1: Run the sync script in the adminhosts container:

```bash
d bash
# Sync PostgreSQL password from K8s secret to secrets.yaml
./bin/sync-k8s-secret-to-wire-secrets.sh \
  wire-postgresql-external-secret \
  password \
  values/wire-server/secrets.yaml \
  .brig.secrets.pgPassword \
  .galley.secrets.pgPassword
```

This script retrieves the password from `wire-postgresql-external-secret`, updates multiple YAML paths, creates a backup at `secrets.yaml.bak`, verifies updates, and works with any Kubernetes secret and YAML file.

### Option 2: Manual Password Override

Override passwords during helm installation:

```bash
# Retrieve password from Kubernetes secret
PG_PASSWORD=$(kubectl get secret wire-postgresql-external-secret \
  -n default \
  -o jsonpath='{.data.password}' | base64 --decode)

# Install/upgrade with password override
helm upgrade --install wire-server ./charts/wire-server \
  --namespace default \
  -f values/wire-server/values.yaml \
  -f values/wire-server/secrets.yaml \
  --set brig.secrets.pgPassword="${PG_PASSWORD}" \
  --set galley.secrets.pgPassword="${PG_PASSWORD}"
```

## Optional: Test Automatic Failover

To verify automatic failover works, simulate a primary failure by stopping the PostgreSQL service on the primary node:

```bash
sudo systemctl mask postgresql@17-main && sudo systemctl stop postgresql@17-main
```

Wait 30 seconds, then check cluster status from a replica node:

```bash
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show
```

One replica should now be promoted to primary. The repmgrd daemon detected the failure, formed quorum, selected the best candidate based on replication lag and priority, and promoted it. The remaining replica automatically reconfigures to follow the new primary.

## What Happens During Failover

When the primary fails, repmgrd daemons retry connections every five seconds. After five failures (~25 seconds), the replicas reach consensus that the primary is down (requiring two-node quorum to prevent false positives). The system promotes the most up-to-date replica with the highest priority using PostgreSQL's native promotion function. The remaining replica detects the new primary and begins following it, while postgres-endpoint-manager updates Kubernetes services to point to the new primary.

## Recovery Time Expectations

The cluster recovers within 30 seconds of a primary failure. Applications running in Kubernetes may take up to 2 minutes to reconnect due to the postgres-endpoint-manager's polling cycle, resulting in 30 seconds to 2 minutes of database unavailability during unplanned failover.

## Troubleshooting

### Common Issues During Deployment


#### PostgreSQL Service Won't Start
If PostgreSQL fails to start after deployment:
```bash
# Check PostgreSQL logs
sudo journalctl -u postgresql@17-main -f

# Verify configuration files exist and are readable
sudo test -f /etc/postgresql/17/main/postgresql.conf && echo "Config file exists" || echo "Config file missing"
sudo -u postgres test -r /etc/postgresql/17/main/postgresql.conf && echo "Config readable by postgres user" || echo "Config not readable"

# Check PostgreSQL configuration syntax
sudo -u postgres /usr/lib/postgresql/17/bin/postgres --config-file=/etc/postgresql/17/main/postgresql.conf -C shared_preload_libraries

# Check disk space and permissions
df -h /var/lib/postgresql/
sudo ls -la /var/lib/postgresql/17/main/
```

#### Replication Issues
If standby nodes show "disconnected" status:
```bash
# On primary: Check if replicas are connecting
sudo -u postgres psql -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"



# Verify repmgr configuration
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node check
```

### Post-Deployment Issues

#### Split-Brain Detection
If you suspect multiple primaries exist, check the cluster status on each node:
```bash
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show

# Check detect-rogue-primary logs
sudo journalctl -u detect-rogue-primary.timer -u detect-rogue-primary.service
```

#### Failed Automatic Failover
If failover doesn't happen automatically:
```bash
# Check repmgrd status and logs
sudo systemctl status repmgrd@17-main
sudo journalctl -u repmgrd@17-main -f

# Verify quorum requirements
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show --compact

# Manual failover if needed
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf standby promote
```

#### Replication Lag Issues
If standby nodes fall behind:
```bash
# Check replication lag
sudo -u postgres psql -c "SELECT client_addr, sent_lsn, write_lsn, flush_lsn, replay_lsn, (sent_lsn - replay_lsn) AS lag FROM pg_stat_replication;"

```

#### Kubernetes Integration Issues
If postgres-external chart fails to detect the primary:
```bash
# Check postgres-endpoint-manager logs
d kubectl logs -l app=postgres-endpoint-manager

# Verify service endpoints
d kubectl get endpoints postgresql-external-rw postgresql-external-ro

# Test connectivity from within cluster
d kubectl run test-pg --rm -it --image=postgres:17 -- psql -h postgresql-external-rw -U wire-server -d wire-server
```

### Recovery Scenarios

For detailed recovery procedures covering complex scenarios such as:
- Complete cluster failure recovery
- Corrupt data node replacement
- Network partition recovery
- Emergency manual intervention
- Backup and restore procedures
- Disaster recovery planning

Please refer to the [comprehensive PostgreSQL cluster recovery documentation](https://github.com/wireapp/wire-server-deploy/blob/master/offline/postgresql-cluster.md) in the wire-server-deploy repository.

## Next Steps

With your PostgreSQL HA cluster running, integrate it with your Wire server deployment. The cluster runs independently outside Kubernetes. The postgres-endpoint-manager component (deployed with postgres-external helm chart) keeps Kubernetes services pointed at the current primary, ensuring seamless connectivity during failover.

### Install postgres-external helm chart

From the wire-server-deploy directory:

```bash
d helm upgrade --install postgresql-external ./charts/postgresql-external
```

This configures `postgresql-external-rw` and `postgresql-external-ro` services with corresponding endpoints.

The helm chart deploys a postgres-endpoint-manager cronjob that runs every 2 minutes to check the current primary. On failover, it updates endpoints with the current primary and standbys. When stable, it runs as a health probe.

Check cronjob logs:

```bash
# Get cronjob pods
d kubectl get pods -A | grep postgres-endpoint-manager

# Inspect logs to see primary/standby detection and updates
d kubectl logs postgres-endpoint-manager-29329300-6zphm # replace with actual pod name
```

See the [postgres-endpoint-manager](https://github.com/wireapp/postgres-endpoint-manager) repository for endpoint update details.



