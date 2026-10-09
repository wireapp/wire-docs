# Wire in a Box maintenance: controlled shutdown and startup

**Scope:** namespace `default`; three Kubernetes VMs, three data-node VMs, and `assethost`, running on the physical KVM/libvirt host.

**Execution:** run section by section. Stop on unexpected errors or failed health checks. Preserve VM addresses and identities; network renumbering requires a separate change plan.

**Version compatibility:** the overall procedure does not depend on a particular Wire release. Version matters where service-unit names, Kubernetes resource types, or command options differ. Record the installed configuration instead of assuming a PostgreSQL version or guessing whether Reaper/Spar are Deployments or StatefulSets.

Commands labelled **Host** run on the physical admin host. Commands labelled **Data VM** run over SSH on the specified data node. Replace `<...>` placeholders before execution.

Run commands in the stated environment. Use the `wire-server-deploy/` directory as the working root when using `d`. After opening a new shell or reconnecting, reinitialize the environment and run-specific variables/functions (`source bin/offline-env.sh`, `I`, `B`, and `k`) before continuing; shell functions and variables do not carry across sessions.

## 1. Record the current state

### 1.1 Admin environment and Kubernetes state

**Host - remain in the `wire-server-deploy/` directory when using `d`.**

```bash
cd wire-server-deploy/

# Optional recording; run before sourcing the environment.
asciinema rec shutdown-wire-gracefully.cast

source bin/offline-env.sh

I=ansible/inventory/offline/inventory.yml
B=maintenance/$(date +%Y%m%d-%H%M%S)

umask 077
mkdir -p "$B/host-config" "$B/datastore-checks/before-shutdown"

k() { d kubectl --namespace=default "$@"; }
record_check() {
  local name="$1" output rc
  shift
  output="$B/datastore-checks/$name.txt"
  mkdir -p "${output%/*}"
  if "$@" > "$output" 2>&1; then rc=0; else rc=$?; fi
  printf '\nCHECK_EXIT_STATUS=%s\n' "$rc" >> "$output"
  printf 'Saved %s (exit %s)\n' "$output" "$rc"
  return "$rc"
}

k config current-context
k get nodes -o wide
k get pods -o wide
k get deployments,statefulsets,daemonsets,cronjobs,hpa

cp "$I" "$B/inventory.yml"
k get nodes -o json > "$B/nodes.json"
k get deployments,statefulsets -o json > "$B/workloads.json"
k get daemonsets -o json > "$B/daemonsets.json"
k get cronjobs -o json > "$B/cronjobs.json"

jq -r '.items[] |
  [(.kind | ascii_downcase), .metadata.name, (.spec.replicas // 1)] |
  @tsv' "$B/workloads.json" > "$B/replicas.tsv"

d helm list -A > "$B/helm-releases.txt"
```

This uses `jq` on the host. The supplied [`offline-env.sh`](https://github.com/wireapp/wire-server-deploy/blob/master/bin/offline-env.sh) launches a new admin container for each `d` invocation and mounts the current directory. Keep maintenance files in the same directory, not solely inside a container. Alternatively, use `d bash` and plain `kubectl` inside it - do not nest `d`. ([Source](https://raw.githubusercontent.com/wireapp/wire-server-deploy/master/bin/offline-env.sh))

Check StatefulSet volume-retention settings:

```bash
k get statefulsets -o custom-columns=\
NAME:.metadata.name,WHEN-SCALED:.spec.persistentVolumeClaimRetentionPolicy.whenScaled
```

**Do not scale down a StatefulSet configured with `whenScaled: Delete` until its policy has been changed to `Retain` and the corresponding PVC owner references have reconciled.** Record that temporary change for later restoration.

### 1.2 VM definitions, networking and nftables

**Host:**

```bash
VMS="assethost datanode1 datanode2 datanode3 kubenode1 kubenode2 kubenode3"

sudo virsh list --all
sudo virsh net-list --all
sudo virsh pool-list --all

sudo virsh list --all --autostart --name > "$B/vm-autostart.txt"

for vm in $VMS; do
  sudo virsh dumpxml "$vm" > "$B/$vm.xml"
  sudo virsh autostart "$vm" --disable
done

ip -br address > "$B/addresses.txt"
ip route show table all > "$B/routes-v4.txt"
ip -6 route show table all > "$B/routes-v6.txt"
ip rule show > "$B/ip-rules.txt"
sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding \
  > "$B/forwarding.txt"

for path in /etc/netplan /etc/network /etc/systemd/network \
            /etc/libvirt /etc/nftables.conf /etc/nftables.d \
            /etc/sysctl.conf /etc/sysctl.d; do
  if sudo test -e "$path"; then
    sudo cp -a --parents "$path" "$B/host-config/"
  fi
done
```

Disabling VM autostart prevents an uncontrolled restart sequence after relocation; restore only previously enabled flags at the end. Confirm the VM names before running the loop. ([virsh reference](https://libvirt.org/manpages/virsh.html))

Check and capture nftables when installed:

```bash
if command -v nft >/dev/null; then
  sudo nft list tables
  sudo nft list ruleset > "$B/nftables.runtime"
  sudo nft -s list ruleset > "$B/nftables.compare"

  {
    printf 'flush ruleset\n'
    cat "$B/nftables.runtime"
  } > "$B/nftables.restore"

  sudo systemctl cat nftables > "$B/nftables-loader.txt" 2>&1 || true
fi
```

An inactive `nftables.service` does **not** prove that no rules exist: other components can manage the kernel ruleset. Identify and back up the actual persistent configuration, included files and custom loader. The runtime export alone does not establish reboot persistence. ([nftables ruleset operations](https://wiki.nftables.org/wiki-nftables/index.php/Operations_at_ruleset_level))

**Copy the maintenance directory, deployment configuration/secrets, and verified backups to storage outside the physical server being moved. `assethost` is not an independent backup location.**

## 2. Stop Wire workloads and take backups

### 2.1 Suspend scheduled work and ingress

**Host:**

Suspend the captured CronJobs, including `postgres-endpoint-manager`:

```bash
while read -r name; do
  k patch cronjob "$name" --type=merge \
    -p '{"spec":{"suspend":true}}'
done < <(jq -r '.items[].metadata.name' "$B/cronjobs.json")

k get cronjobs,jobs
```

Allow existing Jobs to finish, or stop them under an approved application-specific procedure, **before removing their dependencies**. Suspending a CronJob does not stop an already-running Job. ([Kubernetes CronJobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/))

Confirm no node matches the temporary selector:

```bash
k get nodes -l non-existing=true
```

The result must contain no nodes. Pause the captured Wire DaemonSets, including `ingress-nginx-controller-controller`:

```bash
while read -r name; do
  k patch daemonset "$name" --type=merge \
    -p '{"spec":{"template":{"spec":{"nodeSelector":{"non-existing":"true"}}}}}'
done < <(jq -r '.items[].metadata.name' "$B/daemonsets.json")
```

Apply this only to the reviewed Wire DaemonSets in `default`, not Kubernetes networking or storage DaemonSets in other namespaces.

### 2.2 Scale down applications, temporarily retaining `wire-utility`

```bash
while IFS=$'\t' read -r kind name replicas; do
  if [[ "$kind/$name" != "statefulset/wire-utility" ]]; then
    k scale "$kind/$name" --replicas=0
  fi
done < "$B/replicas.tsv"

k get deployments,statefulsets,daemonsets
k get pods -o wide
```

Wait for application pods to terminate cleanly. Retain `wire-utility` until the Cassandra schema export and online backups below are complete.

### 2.3 Cassandra backup

Follow only the backup section of [Take Cassandra backups](https://docs.wire.com/latest/how-to/upgrade/upgrade-5.5-5.25.html#take-cassandra-backups) - not the subsequent upgrade procedure.

Complete the schema export using `wire-utility`, take and verify snapshots on **all three Cassandra nodes**, and export the required backup files off the physical host. This is why `wire-utility` has not yet been stopped. ([Wire upgrade documentation](https://docs.wire.com/latest/how-to/upgrade/upgrade-5.5-5.25.html))

### 2.4 PostgreSQL identification and backup

**Each PostgreSQL VM:**

```bash
sudo -u postgres pg_lsclusters
```

Record the actual instance and port, then set these variables on that VM:

```bash
PG_INSTANCE='17-main'
PG_PORT='5432'
PG_UNIT="postgresql@${PG_INSTANCE}.service"
RM_UNIT="repmgrd@${PG_INSTANCE}.service"
RM_CONF="/etc/repmgr/${PG_INSTANCE}/repmgr.conf"

sudo -u postgres psql -p "$PG_PORT" -X -d postgres \
  -c 'SELECT pg_is_in_recovery();'

sudo -u postgres repmgr -f "$RM_CONF" cluster show
```

Exactly one node must report `f` - the **current primary** - and two must report `t`. Record the live roles; inventory groups or node numbers do not prove the current primary after a failover. Wire also runs `repmgrd` and `detect-rogue-primary`, which require controlled handling during shutdown. ([Wire PostgreSQL cluster administration](https://docs.wire.com/latest/how-to/administrate/postgresql-cluster.html))

Depending on the installed configuration, `repmgr cluster show` may print connection strings containing plaintext passwords. Do not copy or save unredacted output in maintenance notes, recordings, or evidence; redact credentials before recording or sharing the result.

**Current primary VM - inspect databases, schemas and tables:**

*Only from primary VM i.e. datanode1 or postgresql1*

```bash
DB='wire-server'

sudo -u postgres psql -p "$PG_PORT" -X -d postgres -c '\l+'
sudo -u postgres psql -p "$PG_PORT" -X -d "$DB" -c '\dn+'
sudo -u postgres psql -p "$PG_PORT" -X -d "$DB" -c '\dt *.*'

sudo -u postgres psql -p "$PG_PORT" -X -d "$DB" -c "
SELECT table_schema, count(*) AS tables
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
  AND table_schema NOT IN ('pg_catalog', 'information_schema')
GROUP BY table_schema
ORDER BY table_schema;"
```

PostgreSQL "namespaces" are schemas. Save the table counts with the backup evidence. ([PostgreSQL information schema](https://www.postgresql.org/docs/current/infoschema-tables.html))

**Manual full-cluster backup:**

```bash
umask 077
PB="$HOME/wiab-postgresql-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$PB"

sudo -u postgres pg_dumpall -p "$PG_PORT" > "$PB/cluster.sql" &&
  gzip "$PB/cluster.sql" &&
  gzip -t "$PB/cluster.sql.gz"

ls -lh "$PB/cluster.sql.gz"
```

`pg_dumpall` includes databases and cluster-wide objects such as roles. Its output is SQL, restored using `psql`, not `pg_restore`. ([pg_dumpall reference](https://www.postgresql.org/docs/17/app-pg-dumpall.html))

**Optional:** For an individually inspectable/exportable database archive:

```bash
sudo -u postgres pg_dump -p "$PG_PORT" -Fc -d "$DB" \
  > "$PB/$DB.dump"

sudo pg_restore --list "$PB/$DB.dump" > "$PB/archive-contents.txt"
# basic integrity/readability check
sudo pg_restore --file=/dev/null "$PB/$DB.dump"

# Optional: export the archive as SQL.
sudo pg_restore --file="$PB/$DB.sql" "$PB/$DB.dump"

(cd "$PB" && sha256sum cluster.sql.gz "$DB.dump" > SHA256SUMS)
```
([pg_dump reference](https://www.postgresql.org/docs/current/app-pgdump.html))

**Automated alternative - Host:**

The [PostgreSQL backup playbook](https://github.com/wireapp/wire-server-deploy/blob/master/ansible/postgresql-playbooks/postgresql-backup.yml) defaults to groups `postgresql_rw,postgresql_ro` and destination `/var/backups/postgresql` on `assethost`. It requires that inventory host, SSH/become access, running PostgreSQL and sufficient space on assethost and postgresql VM. If assethost is not running then ensure that inventory points out to a node where you can ssh.

The reviewed backup task lacks `pipefail`: a failed `pg_dumpall` can be hidden by successful gzip. Before relying on it, add `set -euo pipefail` at the beginning of that shell task and `args: {executable: /bin/bash}`.

```bash
PG_PRIMARY='datanode1'

d ansible-playbook -i "$I" \
  ansible/postgresql-playbooks/postgresql-backup.yml \
  -e "target_nodes=$PG_PRIMARY" \
  -e "backup_destination=/var/backups/postgresql"

d ansible assethost -i "$I" -m shell -a "ls -lh /var/backups/postgresql/*"
```

([Playbook source](https://raw.githubusercontent.com/wireapp/wire-server-deploy/master/ansible/postgresql-playbooks/postgresql-backup.yml))

MinIO's filesystem backup is taken **after MinIO stops**, in section 4.3.

### 2.5 Capture datastore visibility before shutdown

After scaling application workloads to zero in section 2.2, but before stopping `wire-utility` or any datastore, capture a compact data-visibility baseline. On the Host, set `PG_PRIMARY` and `PG_PORT` from section 2.4, `RMQ_VHOST` from the deployed RabbitMQ configuration, and `ES` to the reachable Elasticsearch API URL and its normal TLS/authentication settings:

```bash
PG_PRIMARY='<recorded primary inventory name>'
PG_PORT='<recorded PostgreSQL port>'
RMQ_VHOST='<application vhost>'
ES='http://<Elasticsearch-node-IP>:9200'
```

Keep the outputs under `$B/datastore-checks/before-shutdown/`; the `record_check` helper saves stdout, stderr, and exit status. Use the same values and commands after startup so the two sets can be compared.

```bash
record_check before-shutdown/postgresql \
  d ansible "$PG_PRIMARY" -i "$I" -m shell \
  -a "sudo -u postgres psql -X -p $PG_PORT -d wire-server -At -F '|' -c \"SELECT table_schema, count(*) FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND table_schema NOT IN ('pg_catalog','information_schema') GROUP BY table_schema ORDER BY table_schema\""

record_check before-shutdown/cassandra \
  d ansible datanodes -i "$I" -m shell -a 'sudo nodetool tablestats'

record_check before-shutdown/rabbitmq \
  d ansible datanode1 -i "$I" -m shell \
  -a "sudo rabbitmqctl list_queues -p '$RMQ_VHOST' name messages_ready messages_unacknowledged"

record_check before-shutdown/elasticsearch \
  curl -fsS "$ES/_cat/indices?h=health,status,index,docs.count,store.size"

record_check before-shutdown/minio \
  k exec wire-utility-0 -- mc du --depth 1 <alias>
```

Use the site's normal PostgreSQL connection settings, Cassandra JMX options, Elasticsearch TLS/authentication flags, and MinIO alias. Add the same Elasticsearch TLS/authentication options to both `_cat/indices` captures. Repeat the RabbitMQ queue check for each application vhost if the deployment has more than one. These summaries show that expected schemas/tables, queues, indices and buckets/objects are visible; they do not prove every stored value is intact. If a check fails or expected data is absent, stop and investigate before shutdown.

These checks are written after the initial maintenance-directory copy in section 1.2. Refresh and verify the off-host copy of `$B` before shutting down the physical host so it includes the baseline files.

## 3. Prepare and shut down the Kubernetes VMs

### 3.1 Stop the remaining utility pod

**Host:**

```bash
k scale statefulset/wire-utility --replicas=0

k get deployments,statefulsets,daemonsets
k get pods \
  --field-selector=status.phase!=Succeeded,status.phase!=Failed
```

**Gate:** no active Wire pods remain in `default`. Completed Job pods may remain; Kubernetes system/static pods are not expected to disappear.

### 3.2 Check and back up etcd

On an etcd member, use the installed `etcdctl` with the deployment's actual client certificate paths:

```bash
# Set ETCD_CA, ETCD_CERT and ETCD_KEY from the installed configuration.
sudo env ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert="$ETCD_CA" --cert="$ETCD_CERT" --key="$ETCD_KEY" \
  endpoint health --cluster

sudo env ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert="$ETCD_CA" --cert="$ETCD_CERT" --key="$ETCD_KEY" \
  snapshot save /var/backups/wiab-etcd.db
```

Validate the snapshot with the installed version's snapshot tool and copy it, the required certificates, and configuration off-host. See [Wire etcd administration](https://docs.wire.com/latest/how-to/administrate/etcd.html) and [Kubernetes etcd backup](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster).

Also record the live key count. From the Host, set `ETCD_MEMBER` to the inventory name of the checked member and `ETCD_CA`, `ETCD_CERT`, and `ETCD_KEY` to the actual certificate paths on that member, then save the result:

```bash
record_check before-shutdown/etcd \
  d ansible "$ETCD_MEMBER" -i "$I" -m shell \
  -a "sudo env ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert='$ETCD_CA' --cert='$ETCD_CERT' --key='$ETCD_KEY' get '' --prefix --count-only --write-out=fields"
```

This count is a coarse visibility check; routine Kubernetes writes can change it. The validated etcd snapshot remains the recovery point.

### 3.3 Cordon and shut down

**Host - use actual Kubernetes node names:**

```bash
k cordon kubenode1 kubenode2 kubenode3
```

For this full-cluster outage, application termination is the primary gate. Do not force-evict system pods merely to obtain "zero pods". Where the site's maintenance procedure requires draining, use:

```bash
k drain <node-name> --ignore-daemonsets --timeout=10m
```

Resolve PodDisruptionBudget or local-storage blockers explicitly; do not automatically add `--force`, `--disable-eviction`, or `--delete-emptydir-data`. Finish all required Kubernetes API operations **before** shutting down the VMs. ([Safely drain a node](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/))

```bash
for vm in kubenode1 kubenode2 kubenode3; do
  sudo virsh shutdown "$vm"
done

sudo virsh list --all
```

Wait until all three show **shut off**. `virsh shutdown` is asynchronous; successful submission does not mean shutdown has completed. Do not substitute `virsh destroy`. ([virsh reference](https://libvirt.org/manpages/virsh.html))

## 4. Stop the data services

### 4.0 Prevent services from automatically starting out of order

**Each data VM:** confirm actual service names, including the PostgreSQL variables recorded earlier.

```bash
systemctl list-unit-files | grep -E \
  'cassandra|postgresql@|repmgrd@|detect-rogue-primary|minio|rabbitmq|elasticsearch'

ES_UNIT=elasticsearch.service    # Replace if the installed unit differs.

UNITS=(
  cassandra.service
  "$PG_UNIT"
  "$RM_UNIT"
  detect-rogue-primary.timer
  detect-rogue-primary.service
  minio-server1.service
  minio-server2.service
  rabbitmq-server.service
  "$ES_UNIT"
)

sudo systemctl show "${UNITS[@]}" \
  -p Id -p ActiveState -p SubState -p UnitFileState \
  > "$HOME/wiab-units.before.txt"
```

Install a **temporary, persistent start condition** on these confirmed units. This prevents automatic startup after reboot without changing their normal enabled state. Ensure the following maintenance drop-in filename is not already used.

```bash
sudo install -d -m 0700 /var/lib/wiab-maintenance
sudo touch /var/lib/wiab-maintenance/hold

for unit in "${UNITS[@]}"; do
  sudo mkdir -p "/etc/systemd/system/$unit.d"

  printf '[Unit]\nConditionPathExists=!/var/lib/wiab-maintenance/hold\n' |
    sudo tee \
      "/etc/systemd/system/$unit.d/99-wiab-maintenance.conf" >/dev/null
done

sudo systemctl daemon-reload
```

This does **not** stop running services; stop them below. It also avoids replacing locally installed units with masks. Do not remove any pre-existing PostgreSQL fencing mask. ([systemd unit reference](https://manpages.debian.org/bookworm/systemd/systemd.unit.5.en.html))

### 4.1 Cassandra: all three nodes

Before the first stop, confirm all three nodes are `UN`:

```bash
sudo nodetool status
```

Then, **one node at a time**, using the deployment's normal JMX authentication options where required:

```bash
sudo nodetool drain
sudo systemctl stop cassandra
sudo systemctl status cassandra --no-pager
```

`drain` flushes tables and stops accepting writes; it does not replace stopping the service. Do not decommission nodes for maintenance. ([Cassandra nodetool drain](https://cassandra.apache.org/doc/4.1/cassandra/tools/nodetool/drain.html))

On this WIAB installation, a successful drain and `systemctl stop` can leave Cassandra reported as `failed` with exit status 143 because the unit classifies the requested SIGTERM as a failure. Treat only this verified signature as a completed stop: the drain succeeded, the journal records `DRAINED` and `Stopped Cassandra` without an intervening Cassandra error, and `systemctl show` confirms `MainPID=0`, `ExecMainStatus=143`, and `ActiveState=failed`. Preserve and record the state; do not reset it or change the unit as part of maintenance. Stop and investigate any different result.

### 4.2 PostgreSQL: pause failover, stop replicas, stop primary

Before stopping any PostgreSQL node, verify two streaming replicas on the current primary and allow them to catch up:

```bash
sudo -u postgres psql -p "$PG_PORT" -X -d postgres -c "
SELECT application_name, state, sync_state,
       sent_lsn, flush_lsn, replay_lsn
FROM pg_stat_replication;"
```

Pause automatic failover from a connected PostgreSQL node:

```bash
sudo -u postgres repmgr -f "$RM_CONF" service pause
sudo -u postgres repmgr -f "$RM_CONF" service status
```

**On all three nodes**, stop the failover and rogue-primary monitoring components:

```bash
sudo systemctl stop detect-rogue-primary.timer \
  detect-rogue-primary.service "$RM_UNIT"
```

Verify they are stopped everywhere. Then stop PostgreSQL on the **two recorded replicas first**, followed by the **recorded current primary**:

```bash
sudo systemctl stop "$PG_UNIT"
sudo systemctl status "$PG_UNIT" --no-pager
```

Do not promote a replica, run a switchover, or use an immediate/forced shutdown for this planned full-cluster stop. ([PostgreSQL monitoring](https://www.postgresql.org/docs/17/monitoring-stats.html))

### 4.3 MinIO: both instances on all three nodes

The referenced [MinIO playbook](https://github.com/wireapp/wire-server-deploy/blob/master/ansible/minio.yml) configures two layouts per node. Their systemd units are `minio-server1` and `minio-server2`, not a single generic `minio` unit. ([Playbook source](https://raw.githubusercontent.com/wireapp/wire-server-deploy/master/ansible/minio.yml))

**Each data VM:**

```bash
sudo systemctl stop minio-server1 minio-server2
sudo systemctl status minio-server1 minio-server2 --no-pager
```

Once **all six instances are stopped**, follow [Backing up MinIO](https://docs.wire.com/latest/how-to/administrate/backup-disaster-recovery.html#backing-up-minio).

Back up both configured data directories on all three nodes, including hidden metadata, and the relevant configuration. Verify and export the cold backups off-host before shutting down the VMs. ([Wire backup and disaster recovery](https://docs.wire.com/latest/how-to/administrate/backup-disaster-recovery.html))

### 4.4 RabbitMQ: record the shutdown order

Before the first stop:

```bash
sudo rabbitmqctl cluster_status
sudo rabbitmq-diagnostics -q check_local_alarms
```

Use a recorded order - for example, **datanode2 -> datanode3 -> datanode1** - and run on each node in that order:

```bash
sudo systemctl stop rabbitmq-server
sudo systemctl status rabbitmq-server --no-pager
```

Confirm each stop before proceeding. The last node stopped should be started first; record the **actual**, not merely intended, order. Do not reset the cluster or purge queues. ([RabbitMQ cluster role](https://raw.githubusercontent.com/wireapp/wire-server-deploy/master/ansible/roles/rabbitmq-cluster/tasks/cluster.yml))

### 4.5 Elasticsearch: preserve allocation settings and flush

**Host:** set a reachable Elasticsearch API endpoint; use the deployment's TLS/authentication settings where applicable.

```bash
ES='http://<Elasticsearch-node-IP>:9200'

curl -fsS "$ES/_cluster/health?pretty"
curl -fsS "$ES/_cat/nodes?v"

curl -fsS "$ES/_cluster/settings?flat_settings=true" \
  > "$B/es-settings.before.json"

jq '{
  persistent: {
    "cluster.routing.allocation.enable":
      (.persistent["cluster.routing.allocation.enable"] // null)
  },
  transient: {
    "cluster.routing.allocation.enable":
      (.transient["cluster.routing.allocation.enable"] // null)
  }
}' "$B/es-settings.before.json" > "$B/es-allocation.restore.json"

curl -fsS -X PUT "$ES/_cluster/settings" \
  -H 'Content-Type: application/json' \
  -d '{"persistent":{"cluster.routing.allocation.enable":"primaries"},
       "transient":{"cluster.routing.allocation.enable":null}}'

curl -fsS -X POST "$ES/_flush"
```

Confirm the allocation update is acknowledged and the flush reports no failed shards. Then **on all three Elasticsearch VMs**:

```bash
sudo systemctl stop "$ES_UNIT"
sudo systemctl status "$ES_UNIT" --no-pager
```

Keep the saved allocation settings for startup; do not permanently leave allocation restricted to primaries. ([Elasticsearch restart procedures](https://www.elastic.co/docs/deploy-manage/maintenance/start-stop-services/full-cluster-restart-rolling-restart-procedures))

### 4.6 Final service and VM shutdown checks

**Each data VM:**

```bash
sudo systemctl show "${UNITS[@]}" \
  -p Id -p ActiveState -p SubState -p MainPID -p ExecMainStatus
```

All listed components must have `MainPID=0`. An inactive service is stopped. For Cassandra, apply only the verified exit-143 exception in section 4.1; investigate any other failed or incomplete shutdown through the corresponding journal:

```bash
sudo journalctl -u <unit-name> --since '-15 minutes' --no-pager
```

**Host:**

```bash
for vm in datanode1 datanode2 datanode3 assethost; do
  sudo virsh shutdown "$vm"
done

sudo virsh list --all
```

Only after every VM is **shut off**, backups are independently accessible, and the recording has been closed:

```bash
sudo shutdown -h now
```

# Startup after relocation

## 5. Verify the physical host before starting VMs

Return to the `wire-server-deploy/` directory and select the **existing** maintenance directory; do not overwrite the pre-shutdown evidence.

```bash
cd wire-server-deploy/
B=maintenance/<recorded-directory>
umask 077
PG_PRIMARY='<recorded primary inventory name>'
PG_PORT='<recorded PostgreSQL port>'
RMQ_VHOST='<application vhost>'
ES='http://<Elasticsearch-node-IP>:9200'
ETCD_MEMBER='<etcd member inventory name>'
ETCD_CA='<member CA path>'
ETCD_CERT='<member client certificate path>'
ETCD_KEY='<member client key path>'
source bin/offline-env.sh
I=ansible/inventory/offline/inventory.yml
k() { d kubectl --namespace=default "$@"; }
mkdir -p "$B/datastore-checks/after-startup"
record_check() {
  local name="$1" output rc
  shift
  output="$B/datastore-checks/$name.txt"
  mkdir -p "${output%/*}"
  if "$@" > "$output" 2>&1; then rc=0; else rc=$?; fi
  printf '\nCHECK_EXIT_STATUS=%s\n' "$rc" >> "$output"
  printf 'Saved %s (exit %s)\n' "$output" "$rc"
  return "$rc"
}

ip -br address
ip route show table all
ip -6 route show table all
ip rule show
sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding

sudo virsh list --all
sudo virsh net-list --all
sudo virsh pool-list --all
```

Verify interfaces, bridges, addresses, routes, DNS, forwarding, storage mounts, VM disk availability, libvirt and Docker. Confirm the host clock is synchronized before starting the database VMs.

### Verify or recover nftables

```bash
sudo nft -s list ruleset > "$B/nftables.after"
diff -u "$B/nftables.compare" "$B/nftables.after"
```

Investigate missing chains, NAT/forwarding rules or changed interface references. Differences in dynamically managed rules are not automatically configuration loss.

Prefer restoring the original persistent files and their actual loader. **Do not blindly install a combined Docker/libvirt runtime dump as `/etc/nftables.conf`.**

Where full runtime restoration is appropriate, coordinate with the rule-owning services and use console/out-of-band access:

```bash
sudo nft -c -f "$B/nftables.restore"
sudo nft -f "$B/nftables.restore"
```

The saved file includes `flush ruleset`, allowing replacement in one transaction. Do not issue a separate `nft flush ruleset` over SSH. Recheck connectivity and persistence after restoration. ([nftables ruleset operations](https://wiki.nftables.org/wiki-nftables/index.php/Operations_at_ruleset_level))

## 6. Start the asset and data VMs

**Host:**

```bash
sudo virsh start assethost

for vm in datanode1 datanode2 datanode3; do
  sudo virsh start "$vm"
done

sudo virsh list

source bin/offline-env.sh
I=ansible/inventory/offline/inventory.yml
k() { d kubectl --namespace=default "$@"; }

d ansible datanodes -i "$I" -m shell \
  -a 'hostname; ip -br address; ip route'

d ansible datanodes -i "$I" -m shell \
  -a 'date +%FT%T.%4N%:z'
```

Compare guest addresses against the saved and current `ansible/inventory/offline/inventory.yml`. Check both `ansible_host` and any separate internal `ip` value; they need not be identical. The linked [`99-static`](https://github.com/wireapp/wire-server-deploy/blob/master/ansible/inventory/offline/99-static) is a reference inventory, not proof of your live addresses. ([Inventory source](https://raw.githubusercontent.com/wireapp/wire-server-deploy/master/ansible/inventory/offline/99-static))

The `date` command compares displayed times but does not prove synchronization. Check the configured NTP client on every data VM, for example:

```bash
timedatectl status
chronyc tracking
chronyc sources -v
```

For a different NTP implementation, use its equivalent checks. Resolve clock, address, hostname or storage problems **before releasing the database start holds**. ([chronyc reference](https://chrony-project.org/doc/4.6.1/chronyc.html))

### Release services individually

**Each data VM:** reuse the recorded PostgreSQL/service variables and define:

```bash
release_units() {
  local unit
  for unit in "$@"; do
    sudo rm \
      "/etc/systemd/system/$unit.d/99-wiab-maintenance.conf" || return 1
  done
  sudo systemctl daemon-reload
}
```

This removes only this runbook's temporary drop-ins, not existing overrides or fencing masks.

### 6.1 Cassandra

Start the configured seed node(s), then the remaining nodes:

```bash
release_units cassandra.service
sudo systemctl start cassandra
```

After all three have started:

```bash
sudo nodetool status
sudo journalctl -u cassandra -b --no-pager -n 100
```

Require all three nodes to reach `UN`, without persistent startup/schema/gossip errors. Do not bootstrap or decommission existing members. ([Cassandra nodetool guidance](https://cassandra.apache.org/doc/stable/cassandra/troubleshooting/use_nodetool.html))

**Host - after the Cassandra health gate passes:**

```bash
record_check after-startup/cassandra \
  d ansible datanodes -i "$I" -m shell -a 'sudo nodetool tablestats'
```

### 6.2 PostgreSQL

Start the **recorded primary first**, then both recorded replicas:

```bash
release_units "$PG_UNIT"
sudo systemctl start "$PG_UNIT"

sudo -u postgres psql -p "$PG_PORT" -X -d postgres \
  -c 'SELECT pg_is_in_recovery();'
```

Require exactly one primary and two replicas. On the primary, repeat the replication query from section 4.2 and require both replicas to be streaming.

Only after that topology is healthy, **on all three nodes**:

```bash
release_units "$RM_UNIT" \
  detect-rogue-primary.service detect-rogue-primary.timer

sudo systemctl start "$RM_UNIT"
sudo systemctl start detect-rogue-primary.timer
```

Then, from a connected PostgreSQL node:

```bash
sudo -u postgres repmgr -f "$RM_CONF" service unpause
sudo -u postgres repmgr -f "$RM_CONF" service status
sudo -u postgres repmgr -f "$RM_CONF" cluster show
```

After replication is healthy, capture the same table counts as the pre-shutdown baseline:

**Host:**

```bash
record_check after-startup/postgresql \
  d ansible "$PG_PRIMARY" -i "$I" -m shell \
  -a "sudo -u postgres psql -X -p $PG_PORT -d wire-server -At -F '|' -c \"SELECT table_schema, count(*) FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND table_schema NOT IN ('pg_catalog','information_schema') GROUP BY table_schema ORDER BY table_schema\""
```

Check PostgreSQL, repmgr and detector journals. Do not automatically unmask a PostgreSQL instance that was fenced by rogue-primary detection. ([Wire PostgreSQL cluster administration](https://docs.wire.com/latest/how-to/administrate/postgresql-cluster.html))

**Do not rerun `postgresql-deploy.yml` to restart services:** that provisioning workflow includes cleanup/redeployment operations. ([Deployment playbook](https://raw.githubusercontent.com/wireapp/wire-server-deploy/master/ansible/postgresql-deploy.yml))

### 6.3 MinIO

**All three nodes:**

```bash
release_units minio-server1.service minio-server2.service
sudo systemctl start --no-block minio-server1 minio-server2
```

Start all six instances before waiting for cluster health. Check their service states on the data VMs:

```bash
sudo systemctl status minio-server1 minio-server2 --no-pager
```

**Host - if `mc` is installed and configured here:**

```bash
record_check after-startup/minio mc du --depth 1 <alias>
```

Do not assume `mc` is installed on the physical host or that an application-only alias has administrative rights. When `wire-utility` is running, `mc` is also available through `k exec -it wire-utility-0 -- mc`. If no administrative client environment is available during this phase, defer the checks to section 7, before restoring Wire workloads.

If `mc admin info` is denied, obtain an authorized administrative alias/client before proceeding to section 8. Bucket listing and active systemd units do not replace the cluster/disk check. Require the expected endpoints/disks online and successful bucket access. ([MinIO playbook](https://raw.githubusercontent.com/wireapp/wire-server-deploy/master/ansible/minio.yml))

### 6.4 RabbitMQ

Start the **last node stopped first**, then promptly start the other two:

```bash
release_units rabbitmq-server.service
sudo systemctl start --no-block rabbitmq-server
```

Do not wait for complete cluster/queue health on the first node before starting its peers; newer metadata-store configurations require a majority. ([RabbitMQ clustering](https://www.rabbitmq.com/docs/clustering))

Once all three are started:

```bash
sudo rabbitmqctl cluster_status
sudo rabbitmq-diagnostics -q ping
sudo rabbitmq-diagnostics -q check_running
sudo rabbitmq-diagnostics -q check_local_alarms
```

Save the queue names and ready/unacknowledged message counts for the same vhost recorded before shutdown:

**Host:**

```bash
record_check after-startup/rabbitmq \
  d ansible datanode1 -i "$I" -m shell \
  -a "sudo rabbitmqctl list_queues -p '$RMQ_VHOST' name messages_ready messages_unacknowledged"
```

Require all expected members, no partitions and no unresolved alarms. Do not use `reset`, `join_cluster`, or `force_boot` as routine startup commands.

### 6.5 Elasticsearch

**All three nodes:**

```bash
release_units "$ES_UNIT"
sudo systemctl start --no-block "$ES_UNIT"
```

**Host - reset `ES` to the recorded endpoint:**

```bash
ES='http://<Elasticsearch-node-IP>:9200'

curl -fsS \
  "$ES/_cluster/health?wait_for_nodes=3&wait_for_status=yellow&timeout=120s"

curl -fsS -X PUT "$ES/_cluster/settings" \
  -H 'Content-Type: application/json' \
  -d @"$B/es-allocation.restore.json"

curl -fsS \
  "$ES/_cluster/health?wait_for_nodes=3&wait_for_status=green&timeout=120s"

curl -fsS "$ES/_cat/nodes?v"
```

Capture the index names, document counts and store sizes:

```bash
record_check after-startup/elasticsearch \
  curl -fsS "$ES/_cat/indices?h=health,status,index,docs.count,store.size"
```

Check the response body, including `timed_out`; HTTP success alone is not a health pass. Require three nodes and recovery to the approved healthy baseline, normally green. ([Elasticsearch restart procedures](https://www.elastic.co/docs/deploy-manage/maintenance/start-stop-services/full-cluster-restart-rolling-restart-procedures))

After all services and monitoring components have been released and verified, check that no maintenance drop-ins remain, then remove the marker on each data VM:

```bash
sudo find /etc/systemd/system \
  -path '*/99-wiab-maintenance.conf' -print

# Run only when the preceding command returns no remaining drop-ins.
sudo rm /var/lib/wiab-maintenance/hold
```

## 7. Start and verify Kubernetes

**Host:**

Initialize the deployment client from the `wire-server-deploy/` working root. Repeat this block after reconnecting or opening a new shell:

```bash
cd wire-server-deploy/
source bin/offline-env.sh
B=maintenance/<recorded-directory>
umask 077
PG_PRIMARY='<recorded primary inventory name>'
PG_PORT='<recorded PostgreSQL port>'
RMQ_VHOST='<application vhost>'
ES='http://<Elasticsearch-node-IP>:9200'
ETCD_MEMBER='<etcd member inventory name>'
ETCD_CA='<member CA path>'
ETCD_CERT='<member client certificate path>'
ETCD_KEY='<member client key path>'
k() { d kubectl --namespace=default "$@"; }
mkdir -p "$B/datastore-checks/after-startup"
record_check() {
  local name="$1" output rc
  shift
  output="$B/datastore-checks/$name.txt"
  mkdir -p "${output%/*}"
  if "$@" > "$output" 2>&1; then rc=0; else rc=$?; fi
  printf '\nCHECK_EXIT_STATUS=%s\n' "$rc" >> "$output"
  printf 'Saved %s (exit %s)\n' "$output" "$rc"
  return "$rc"
}
```

```bash
for vm in kubenode1 kubenode2 kubenode3; do
  sudo virsh start "$vm"
done

sudo virsh list
```

Start all three before expecting full control-plane/etcd health. Then:

```bash
k get --raw='/readyz?verbose'
k get nodes -o wide
# check for wire.com/external-ip - it should be set to Public IP if it is not attached to interface
k get node kubenode3 -o jsonpath='{.metadata.annotations.wire\.com/external-ip}'
d kubectl -n kube-system get pods -o wide
k get events --sort-by=.metadata.creationTimestamp
```

Verify etcd health using section 3.2's health command, guest IPs against inventory, guest time synchronization, CNI/DNS, annotation 'wire.com/external-ip' and node services. `/readyz` is the API server readiness check. ([Kubernetes API health checks](https://kubernetes.io/docs/reference/using-api/health-checks/))

After etcd endpoints and the Kubernetes API are healthy, compare the live key count with the pre-shutdown count:

```bash
record_check after-startup/etcd \
  d ansible "$ETCD_MEMBER" -i "$I" -m shell \
  -a "sudo env ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert='$ETCD_CA' --cert='$ETCD_CERT' --key='$ETCD_KEY' get '' --prefix --count-only --write-out=fields"
```

Uncordon only nodes that were schedulable before maintenance:

```bash
while read -r node; do
  k uncordon "$node"
done < <(
  jq -r '.items[] |
    select(.spec.unschedulable != true) |
    .metadata.name' "$B/nodes.json"
)

k wait --for=condition=Ready nodes --all --timeout=5m
```

Restore any required supporting controllers that were intentionally stopped in `default`, while keeping Wire application replicas at zero.

### Refresh PostgreSQL endpoints and start `wire-utility`

If `postgres-endpoint-manager` exists, run one controlled reconciliation while its schedule remains suspended:

```bash
JOB="postgres-endpoint-maint-$(date +%s)"

k create job --from=cronjob/postgres-endpoint-manager "$JOB"
k wait --for=condition=complete "job/$JOB" --timeout=180s
k logs "job/$JOB"

k get services,endpoints
```

Verify that PostgreSQL service endpoints identify the actual primary/replicas appropriately. Wire's endpoint manager exists to keep these mappings aligned with PostgreSQL roles. ([Wire PostgreSQL cluster administration](https://docs.wire.com/latest/how-to/administrate/postgresql-cluster.html))

```bash
k scale statefulset/wire-utility --replicas=1
k rollout status statefulset/wire-utility --timeout=5m
k exec -it wire-utility-0 -- status
```

If the MinIO client was unavailable during section 6.3, use the now-running utility pod to record bucket/object visibility before restoring Wire workloads:

```bash
record_check after-startup/minio \
  k exec wire-utility-0 -- mc du --depth 1 <alias>
```

Before section 8, compare each matching file under `$B/datastore-checks/before-shutdown/` and `$B/datastore-checks/after-startup/`. Confirm the expected PostgreSQL schemas/table counts, Cassandra table names, RabbitMQ queues, Elasticsearch indices, etcd keys, and MinIO buckets/objects remain visible. Per-node Cassandra statistics, RabbitMQ message counts, Elasticsearch document counts, and etcd key counts can change during normal operation; investigate unexpected missing structures or a substantial unexplained decrease rather than requiring byte-for-byte equality.

These read checks are visibility fingerprints, not full integrity tests. If checks succeed, expected data remains visible, and native health checks pass, do not restore solely because maintenance occurred. If a check fails or expected data is missing, stop before restoring Wire workloads, review the saved backup and investigate the discrepancy; do not restore automatically based only on a count difference.

The `databases-ephemeral-redis-ephemeral` workload is intentionally ephemeral and has no retained-data comparison in these files; verify that it starts healthy when restored in section 8.

Use [Wire Utility](https://docs.wire.com/latest/how-to/administrate/wire-utility-tool.html) to verify datasource connectivity. Its status output complements - not replaces - the native cluster-health checks above. A dependency intentionally still stopped, such as ephemeral Redis, should be rechecked after its startup step.

## 8. Restore Wire in the recorded order

Use the saved resource kinds and replica counts. This avoids guessing Reaper/Spar resource types and avoids replacing every original replica count with `3`.

**Host:**

```bash
lookup_workload() {
  awk -v name="$1" '
    $2 == name { line=$0; count++ }
    END {
      if (count == 1) print line;
      else exit 1;
    }' "$B/replicas.tsv"
}

up() {
  local row kind name saved
  row=$(lookup_workload "$1") || {
    echo "STOP: missing or ambiguous workload: $1"; return 1;
  }
  read -r kind name saved <<< "$row"

  if [[ "$saved" == 0 ]]; then
    echo "$name was already stopped; leaving it stopped."
    return 0
  fi

  k scale "$kind/$name" --replicas="${2:-$saved}"
}

check() {
  local row kind name saved
  row=$(lookup_workload "$1") || return 1
  read -r kind name saved <<< "$row"
  [[ "$saved" == 0 ]] && return 0

  k logs "$kind/$name" --all-containers=true --since=5m --tail=100
  k rollout status "$kind/$name" --timeout=5m
}
```

`up <name> 1` starts one instance. `up <name>` restores its recorded count. Run the following rows in order; omit optional components only when confirmed absent from this deployment.

| Order | Commands | Required check |
|---|---|---|
| 1 | `up account-pages 1`<br>`up team-settings 1`<br>`up background-worker 1` | Inspect background-worker logs; recheck after its downstream dependencies are available. |
| 2 | `up brig 1` | Inspect Brig logs. Do not yet require readiness if SMTP/SQS/SNS are still missing. |
| 3 | `up smtp 1` | Recheck Brig logs for SMTP connectivity. |
| 4 | `up fake-aws-sqs 1`<br>`up fake-aws-sns 1`<br>`check brig && up brig` | Recheck Brig after both AWS substitutes start; then restore its original replicas. |
| 5 | `up cargohold 1`<br>`check cargohold && up cargohold` | Confirm datastore/MinIO connectivity. |
| 6 | `up databases-ephemeral-redis-ephemeral 1`<br>`check databases-ephemeral-redis-ephemeral` | Confirm Redis readiness. |
| 7 | `up galley 1`<br>`check galley && up galley` | Inspect connection/startup errors before restoring replicas. |
| 8 | `up gundeck 1`<br>`check gundeck && up gundeck` | Inspect connection/startup errors before restoring replicas. |
| 9 | `up nginz 1` | Inspect Nginz logs; Cannon is started next. |
| 10 | `up cannon 1`<br>`check cannon && check nginz`<br>`up nginz`<br>`up cannon` | Recheck Nginz after Cannon becomes available. |
| 11 | `up reaper 1`<br>`up spar 1`<br>`check spar && up spar` | Use the recorded resource types, not both Deployment and StatefulSet attempts. |
| 12 | `up webapp`<br>`check webapp` | Confirm the web application is ready. |
| 13 | `up sftd 1`<br>`up coturn 1`<br>`up sftd-join-call 1` | Check all installed calling components after the group has started. |

For the dependency-specific log checks:

```bash
k logs deployment/background-worker --since=5m --tail=100
k logs deployment/brig --since=5m --tail=100
k logs deployment/nginz --since=5m --tail=100
```

Investigate persistent database authentication, connection, DNS, migration or retry errors. A workload becoming Ready does not by itself prove every external integration works.

Restore the recorded counts of remaining approved workloads - including supporting Helm components and services initially started with one replica:

```bash
while IFS=$'\t' read -r kind name replicas; do
  k scale "$kind/$name" --replicas="$replicas"
done < "$B/replicas.tsv"

k get deployments,statefulsets,pods -o wide
```

### Restore DaemonSets and CronJobs

Restore each DaemonSet's **original** selector, not an assumed empty selector:

```bash
while IFS=$'\t' read -r name selector; do
  k patch daemonset "$name" --type=json \
    -p "[{\"op\":\"replace\",
          \"path\":\"/spec/template/spec/nodeSelector\",
          \"value\":$selector}]"
done < <(
  jq -r '.items[] |
    [.metadata.name,
     ((.spec.template.spec.nodeSelector // {}) | tojson)] |
    @tsv' "$B/daemonsets.json"
)
```

After workloads and endpoints are healthy, restore each CronJob's original suspended state:

```bash
while IFS=$'\t' read -r name suspended; do
  k patch cronjob "$name" --type=merge \
    -p "{\"spec\":{\"suspend\":$suspended}}"
done < <(
  jq -r '.items[] |
    [.metadata.name, (.spec.suspend // false)] |
    @tsv' "$B/cronjobs.json"
)
```

Watch for catch-up Jobs when schedules resume. Restore any temporary PVC-retention changes only after the intended replicas are back, then resume the previously paused autoscaling/reconciliation. ([Kubernetes CronJobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/))

## 9. Final acceptance checks

```bash
k get nodes -o wide
k get deployments,statefulsets,daemonsets
k get pods -o wide
k get services,endpoints,ingresses
k get cronjobs,jobs
k get events --sort-by=.metadata.creationTimestamp

# While the utility pod is running:
k exec -it wire-utility-0 -- status
```

Confirm original replica counts, healthy data clusters, correct PostgreSQL endpoints, working ingress/TLS, expected certificates, and no persistent pod crashes.

Perform client checks for login, message delivery, attachments, web/account/team pages, notifications and configured calling services. Recheck background-worker, Brig and Nginz after these tests.

Finally, restore only the VM autostart flags recorded before maintenance:

```bash
while read -r vm; do
  [[ -n "$vm" ]] && sudo virsh autostart "$vm"
done < "$B/vm-autostart.txt"
```

**Maintenance is complete only when the functional checks pass and all temporary holds, selectors, suspended schedules and operational exceptions have been resolved.**
