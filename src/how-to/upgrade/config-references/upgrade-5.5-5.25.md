# Wire Server Upgrade: 5.5 to 5.25

This document is a one-time jump from Wire Server backend 5.5 (2024-07-09 / git tag v2024-07-09) to 5.25 (2026-01-26 / git tag v2026-01-13), including the Webapp, Team Settings, and Account Pages charts.

For other Wire upgrade paths, use the official upgrade documentation:
https://docs.wire.com/latest/how-to/upgrade/05-config-reference.html

Read about the Wire Server changes from 5.5 to 5.25 at https://docs.wire.com/latest/changelog/changelog.html#2026-01-13-chart-release-5250.

## Before You Start

Start with an asciinema recording. Recording the terminal session stores the upgrade process and can later help reconstruct what happened during execution, troubleshooting, or handover.

Reference: https://asciinema.org/

Example:

```bash
asciinema rec wire-upgrade-5.5-5.25-1.cast
```

Node and inventory group names in this document follow the staging analogy used while preparing this runbook. In particular, `datanodes` refers to the group of data-service nodes, such as Cassandra, Elasticsearch, MinIO, PostgreSQL, RabbitMQ, and similar supporting services.

For production, do not assume that `datanodes` is the correct group for every Ansible command. Inspect the production inventory and choose the precise group or hosts that match the service you are working on.

## Scope

- Source version: Wire Server backend 5.5
- Target version: Wire Server backend 5.25
- Deployment type: offline or air-gapped `wire-server-deploy`
- Includes: backend services, external service definitions, Webapp, Team Settings, Account Pages, multi-ingress values, and Webapp follow-up upgrade
- Excludes: general upgrade paths outside this one-time 5.5 to 5.25 jump

## Operating Notes

Unless explicitly stated otherwise, run commands from the new extracted `wire-server-deploy` directory.

The offline bundle provides a `d` helper after sourcing `bin/offline-env.sh`. Use it for commands that need the tooling container.

Commands that should generally run through `d` or inside `d bash`:

- `ansible`
- `kubectl`
- `helm`
- `yq`
- [dyff](https://github.com/homeport/dyff)
- [multi_ingress_verify.sh](https://raw.githubusercontent.com/wireapp/wire-scripts/refs/heads/multi-ingress-verification/multi-ingress/multi_ingress_verify.sh)
- [rebalance-drained-node-pods.sh](https://raw.githubusercontent.com/wireapp/wire-scripts/refs/heads/k8s-scripts/k8s-scripts/rebalance-drained-node-pods.sh)
- [extract_images.sh](https://raw.githubusercontent.com/wireapp/wire-scripts/refs/heads/k8s-scripts/k8s-scripts/extract_images.sh)

Commands that should run after SSHing into a specific node:

- `apt`
- `nodetool`
- [cassandra_backup.sh](https://raw.githubusercontent.com/wireapp/wire-scripts/refs/heads/cassandra-ops/cassandra-scripts/cassandra_backup.sh)
- `crictl`

Commands or scripts that should run from a [wire-utility](https://docs.wire.com/latest/how-to/administrate/wire-utility-tool.html) context `d kubectl exec -ti wire-utility-0 -- bash`:

- `cqlsh`
- [create_team.sh](https://raw.githubusercontent.com/wireapp/wire-scripts/refs/heads/user-ops/user-ops/create_team.sh)
- [create_users.sh](https://raw.githubusercontent.com/wireapp/wire-scripts/refs/heads/user-ops/user-ops/create_users.sh)
- [analyze_clients.py](https://raw.githubusercontent.com/wireapp/wire-scripts/refs/heads/cassandra-ops/cqlsh-scripts/analyze_clients.py)
- [collect_user_cql_data.sh](https://raw.githubusercontent.com/wireapp/wire-scripts/refs/heads/cassandra-ops/cqlsh-scripts/collect_user_cql_data.sh)

Note: files written inside `wire-utility` are not persistent. If the `wire-utility` pod restarts, any files copied or created inside the pod will be lost.

These helper scripts may not be present in the deployment bundle or on the admin host. Download them from the linked source, or add them manually to the system before use. Review each script and run it in dry-run or read-only mode first when available.

Example for fetching a script from the raw link:

```bash
wget -O analyze_clients.py https://raw.githubusercontent.com/wireapp/wire-scripts/refs/heads/cassandra-ops/cqlsh-scripts/analyze_clients.py
chmod +x analyze_clients.py
```

The phase numbers below describe the task order. They are not strict calendar days; split or combine them according to the maintenance window, customer readiness, and operational risk.

## Phase 1: Readiness and Baseline Validation

Before starting this phase, confirm that asciinema recording is active.

### Client Validation Checklist

- [ ] A team exists with at least 3 users.
  - `bash create_team.sh -d dev.com`
  - `bash create_users.sh -d dev.com -c -n 3 -s 1 -a ADMIN_ID -t TEAMID`
- [ ] At least one user is logged in on each client type: iOS, Android, Web App, and Desktop if applicable.
- [ ] Preferably, each client uses a different user from the same team.
- [ ] At least 2 active 1:1 conversations exist among the users, with messages exchanged from all client types.
- [ ] At least 1 group conversation exists, with messages exchanged from every client.
- [ ] Text messages and file attachments have been exchanged.
- [ ] 1:1 and group calls have been successfully tested on all client types.
- [ ] Push notifications have been verified on iOS and Android.

Example mapping:

- Web App -> User 001
- Android through deep link -> User 002
- iOS through deep link -> User 003

### [Multi-Ingress](https://docs.wire.com/latest/how-to/install/multi-ingress.html) Validation (in a Multi-Ingress env)

Use this section if the deployment has multiple ingress domains. Consider having at least 3 more users to test those domains.

- [ ] Each ingress domain has been tested using a different client type.
- [ ] Users have exchanged text messages and file attachments in 1:1 and group conversations across all domains.
- [ ] 1:1 and group calls have been verified across all ingress domains.
- [ ] Push notifications have been verified on Android and iOS for all ingress domains.

Example mapping:

-  Domain 1 → Web App (User 004)
-  Domain 2 → Android via deep link (User 005)
-  Domain 3 → iOS via deep link (User 006)

### Verify Current Cluster, Certs, Helm Charts, and VMs

Check the cert validity for all main domains and multi-ingress domains (if applicable). If cert expire date is near (1 week or less), it is recommended to update the certs before continuing further.

```bash
# cert expiry date for main domain
curl -vI https://nginz-ssl.example.com 2>&1 | grep -i 'expire date'
# cert expiry date for multi-ingress domain
curl -vI https://nginz-ssl.red.example.com 2>&1 | grep -i 'expire date'
```

Check the current Kubernetes state before changing anything.

```bash
d kubectl get pods -A
```

Check Helm diffs for the current version. This should confirm that the deployed charts match the currently checked-out values.

```bash
d bash
```

Run the rest of this block inside the `d bash` shell.

```bash
for chart in webapp team-settings wire-server account-pages databases-ephemeral elasticsearch-external fake-aws ingress-nginx-controller minio-external nginx-ingress-services rabbitmq-external reaper; do
  cmd=(helm diff "$chart" "charts/$chart")

  values_file="values/$chart/values.yaml"
  secrets_file="values/$chart/secrets.yaml"

  if [[ -f "$values_file" ]]; then
    cmd+=(--values "$values_file")
  fi

  if [[ -f "$secrets_file" ]]; then
    cmd+=(--values "$secrets_file")
  fi

  echo "Running: ${cmd[*]}"
  "${cmd[@]}"
done
```

### Check Node State With Ansible

Check disk space on all Kubernetes nodes and datastore nodes before moving the deployment package.

Verify time and timezone consistency.

```bash
d ansible all -i ansible/inventory/offline/inventory.yml -m shell -a 'date +%FT%T.%4N%:z'
```

Verify MTU consistency across all VMs.

```bash
d ansible all -i ansible/inventory/offline/inventory.yml -m shell -a "ip link show | grep mtu"
```

Check the APT sources on all nodes.

```bash
d ansible datanodes,kube-node -i ansible/inventory/offline/inventory.yml -m shell -a 'grep -hE "^(deb|deb-src)" /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null'
```

If package sources need to be copied from the asset host, confirm the source and destination first.

```bash
# d ansible assethost -i ansible/inventory/offline/inventory.yml -m fetch -a "src=/etc/apt/sources.list dest=./apt-fixes flat=yes"
# d ansible datanodes,kube-node -i ansible/inventory/offline/inventory.yml -m copy -a "src=apt-fixes/assethost/etc/apt/sources.list dest=/etc/apt/sources.list mode=0644"
```

Check available package updates.

```bash
d ansible datanodes,kube-node -i ansible/inventory/offline/inventory.yml -m shell -a 'apt update >/dev/null && apt list --upgradable 2>/dev/null'
```

The package repository should point to the internal or approved external mirror that keeps systems up to date.

If node updates are required, update nodes manually in a rolling manner.

Run the rest of this block inside the `d bash` shell.

```bash
export DRAIN_TIME="$(date -u  +%Y-%m-%dT%H:%M:%SZ)"
export DRAIN_NODE="kubenode3"
kubectl cordon kubenode3
kubectl drain kubenode3 --ignore-daemonsets --delete-emptydir-data
```

SSH into the drained node and update it.

```bash
ssh demo@kubenode3
sudo apt update >/dev/null && sudo apt list --upgradable 2>/dev/null
sudo apt upgrade
sudo reboot
```

After the node returns and is uncordoned, use the rebalance helper only if pod distribution needs to be corrected.

```bash
rebalance-drained-node-pods.sh
```

`rebalance-drained-node-pods.sh` helps rebalance workloads after a Kubernetes node is drained, restarted, and uncordoned. It does this by identifying pods created after the drain and, when dry-run is disabled, deleting candidates one at a time so Kubernetes can reschedule them.

Run it from the admin host tooling environment after `source bin/offline-env.sh`, preferably inside `d bash`. If the script is not present, create it from the linked source in the Operating Notes.

Before draining, capture the node and drain start time:

```bash
export DRAIN_NODE="<node>"
export DRAIN_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

If the exact drain time is unavailable, use `DRAIN_AGO_SECONDS=<seconds>` instead. The script shows candidate pods and pod distribution first, and runs in dry-run mode by default. Set `DRY_RUN=false` only after reviewing the candidates.

```bash
DRY_RUN=false rebalance-drained-node-pods.sh
```

Use `INCLUDE_SYSTEM=true` only if system namespaces must be included. By default, system namespaces are excluded. Deleting pods does not guarantee they return to `DRAIN_NODE`; final placement is decided by the Kubernetes scheduler based on resources and scheduling constraints.

Check that `nodetool` is present on Cassandra nodes.

```bash
d ansible cassandra -i ansible/inventory/offline/inventory.yml -m shell -a "which nodetool"
```

### Check Monitoring State

Verify that Grafana [metrics](https://github.com/wireapp/wire-server-deploy/blob/WPB-25750-monitoring-changes/offline/instrument_monitoring.md) and dashboards are working.

Check disk usage on Kubernetes nodes.

```bash
d ansible kube-node -i ansible/inventory/offline/inventory.yml -m shell -a "df -h"
```

Check CPU flags to confirm the AVX-512 instruction gap.

Upgrading to Wire Server version 5.16 or later may lead to `SIGILL` or invalid opcode crashes in the `brig` component on some environments. This can happen when AVX-512 CPU instructions are exposed inconsistently by the virtualization layer.

The failure mode is:

- The KVM hypervisor exposes AVX-512 through raw CPUID.
- AVX-512 is masked or absent from `/proc/cpuinfo`.
- The `brig` binary checks raw CPUID at runtime and sees AVX-512 as available.
- `brig` selects AVX-512 optimized code paths.
- The CPU cannot actually execute those instructions.
- `brig` crashes with invalid opcode or `SIGILL`.

Verify the CPU flags reported inside Kubernetes and compare them with the flags reported by the Kubernetes nodes. The AVX-512 flags should be consistent between these checks.

```bash
d kubectl exec -ti wire-utility-0 -- lscpu | grep -i flags
```

Check AVX-512 flags exposed through `/proc/cpuinfo` on all Kubernetes nodes.

```bash
d ansible kube-node -i ansible/inventory/offline/inventory.yml -m shell -a "grep -o 'avx512[^ ]*' /proc/cpuinfo | sort -u"
```

Optionally compare the full `lscpu` flags from all Kubernetes nodes.

```bash
d ansible kube-node -i ansible/inventory/offline/inventory.yml -m shell -a "lscpu | grep -i flags"
```

If the AVX-512 flags differ between these checks, make CPU feature exposure consistent before upgrading. The preferred fix is to disable AVX-512 in the VM or hypervisor CPU configuration, or to choose a VM CPU model that does not expose AVX-512. This is possible when the virtualization platform allows CPU feature masking, but the exact steps are platform-specific.

Do not rely on a generic `avx512=off` kernel parameter unless it is documented and supported by the OS or virtualization vendor for this environment. If a vendor-supported kernel argument is used, append it without overwriting existing kernel arguments.

Sources for this guidance:

- QEMU/KVM supports CPU model and feature customization, for example disabling a CPU feature with `-cpu host,<feature>=off`: https://www.qemu.org/docs/master/system/qemu-cpu-models.html#syntax-for-configuring-cpu-models
- libvirt domain XML supports fine-tuning guest CPU features with `<feature policy='disable' .../>`: https://libvirt.org/formatdomain.html#cpu-model-and-topology
- The upstream Linux kernel command-line parameter documentation is the consolidated reference for generic kernel parameters. `avx512=off` is not listed there, so treat it as vendor or distro specific unless the platform documentation says otherwise: https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html

```bash
sudo cp /etc/default/grub /etc/default/grub.bak.$(date +%F-%H%M%S)
sudo vi /etc/default/grub
# Append the vendor-supported AVX-512 disable argument, for example avx512=off,
# to the existing GRUB_CMDLINE_LINUX value without removing other arguments.
sudo update-grub
sudo reboot
```

After reboot, verify both the active kernel command line and the CPU flags.

```bash
d ansible kube-node -i ansible/inventory/offline/inventory.yml -m shell -a "cat /proc/cmdline"
d ansible kube-node -i ansible/inventory/offline/inventory.yml -m shell -a "grep -o 'avx512[^ ]*' /proc/cpuinfo | sort -u"
```

Check Cassandra disk usage.

```bash
d ansible cassandra -i ansible/inventory/offline/inventory.yml -m shell -a "df -h"
```

## Phase 2: Workspace, Backups, and Infrastructure Preparation

Before starting this phase, confirm that asciinema recording is active.

### Prepare the New Deployment Workspace

Rename the old deployment package.

```bash
mv wire-server-deploy wire-server-deploy-old
```

Download the 5.25 deployment bundle and extract it as `wire-server-deploy`.

```bash
wget https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-0035454cd1562518958c1459cbcdcafc80512ac8.tgz
tar xzf wire-server-deploy-static-0035454cd1562518958c1459cbcdcafc80512ac8.tgz
```

Clean old Docker containers and images from the old environment which were used with the old 5.5 environment.

Do not run a blanket container removal command on a shared admin host. The goal is only to remove stopped or obsolete containers created from the old `wire-server-deploy` admin/tooling image so that the old image can be removed. If additional containers are running on this host, inspect them first and remove only the containers and images that are safe to delete.

```bash
docker ps -a
docker image ls | grep -E 'wire-server-deploy|container-wire-server-deploy'

# Remove only confirmed obsolete containers.
docker rm <container-id>

# Remove only confirmed obsolete images.
docker image rm <image-id>
```

Clean the old `zauth` image as well.

```bash
docker image ls | grep zauth
docker image rm <image-id>
```

Source the new offline environment.

```bash
source bin/offline-env.sh
```

Copy the Kubernetes admin config from the old package.

```bash
mkdir ansible/inventory/offline/artifacts/
cp ../wire-server-deploy-old/ansible/inventory/offline/artifacts/admin.conf ansible/inventory/offline/artifacts/
```

Verify Kubernetes access from the new workspace.

```bash
d kubectl get nodes
```

### Take Cassandra Backups

Take a Cassandra backup before touching Cassandra nodes.

Reference: https://docs.wire.com/latest/how-to/administrate/backup-disaster-recovery.html#backing-up-cassandra

Check for existing snapshots.

```bash
d ansible -i ansible/inventory/offline/inventory.yml cassandra -b -m shell -a 'nodetool listsnapshots | grep backup_'
```

Back up the schema.

```bash
d kubectl exec -t wire-utility-0 -- /usr/local/bin/cqlsh -e "DESCRIBE SCHEMA" > cassandra_schema_$(date +%F).cql
```

Take backups on all Cassandra nodes individually.

Reference: https://raw.githubusercontent.com/wireapp/wire-scripts/refs/heads/cassandra-ops/cassandra-scripts/cassandra_backup.sh

```bash
bash cassandra_backup.sh
```

Confirm snapshots after backup.

```bash
d ansible -i ansible/inventory/offline/inventory.yml cassandra -b -m shell -a 'nodetool listsnapshots | grep backup_'
```

### Verify Inventory for PostgreSQL and RabbitMQ

Create a new inventory and compare it with the old inventory.

```bash
cp ../wire-server-deploy-old/ansible/inventory/offline/inventory.yml ansible/inventory/offline/inventory.yml.old
```

Check whether RabbitMQ is already exposed as an external service.

```bash
d kubectl get endpoints | grep -i rabbitmq
```

If the external RabbitMQ service does not exist, install RabbitMQ on datanodes or dedicated RabbitMQ nodes.

Update the new inventory for the asset host, RabbitMQ IPs, and PostgreSQL IPs.

Reference inventory:
https://raw.githubusercontent.com/wireapp/wire-server-deploy/refs/heads/release-5.25-R2/ansible/inventory/offline/staging.yml

Verify datanodes, including dedicated PostgreSQL and RabbitMQ nodes.

```bash
d ansible datanodes -i ansible/inventory/offline/inventory.yml -m shell -a 'date +%FT%T.%4N%:z;hostname;ip addr'
```

Verify new inventory groups and keys.

```bash
d yq eval .postgresql ansible/inventory/offline/inventory.yml
d yq eval .postgresql_rw ansible/inventory/offline/inventory.yml
d yq eval .postgresql_ro ansible/inventory/offline/inventory.yml
d yq eval '."rmq-cluster"' ansible/inventory/offline/inventory.yml
```

### Set Up Asset Host, PostgreSQL, and RabbitMQ

Prepare the asset host for the new offline artifact if a clean asset tree is required.

Warning: `/opt/assets` is the source for offline packages and container images. Moving or removing it while nodes still depend on the old asset tree can break package installation or image seeding. Do not change it until the new artifact is available, the maintenance plan is confirmed, and no current operation depends on the old asset tree. Keep the old `wire-server-deploy` directory to be able to generate the `assethost` again.

```bash
ssh demo@assethost
sudo systemctl status serve-assets && sudo systemctl stop serve-assets
sudo rm -rf /opt/assets
```

Set up the asset host and offline package sources.

```bash
d ansible-playbook -i ansible/inventory/offline/inventory.yml ansible/setup-offline-sources.yml
```

Fix time synchronization if it is not synced.

Install PostgreSQL.

```bash
d ansible-playbook -i ansible/inventory/offline/inventory.yml ansible/postgresql-deploy.yml
```

Install RabbitMQ on VMs if RabbitMQ is not already provided externally.

```bash
d ansible-playbook -i ansible/inventory/offline/inventory.yml ansible/roles/rabbitmq-cluster/tasks/configure_dns.yml
d ansible-playbook -i ansible/inventory/offline/inventory.yml ansible/rabbitmq.yml
```

Check whether related Kubernetes services exist.

```bash
d ansible-playbook -i ansible/inventory/offline/inventory.yml ansible/helm_external.yml
```

Deploy `postgresql-endpoint-manager`.

Load the image, if it has not been loaded.

```bash
d ansible kube-node -i ansible/inventory/offline/inventory.yml -m shell -a 'curl -q "{{ assethost_host }}/containers-helm/quay.io_wire_postgres-endpoint-manager_1.0.0.tar" | ctr -n=k8s.io images import -'
```

Install or upgrade the chart.

```bash
d helm upgrade --install postgresql-external charts/postgresql-external --values values/postgresql-external/values.yaml
d kubectl get pods
d kubectl logs -f postgres-endpoint-manager-PODID
```

Replace `postgres-endpoint-manager-PODID` with the actual pod name.

### Prepare Helm Chart Values for 5.25

Keep the existing 5.5 values as the reference while preparing the 5.25 values. To understand what each of values further means - find the detailed values.yaml file [here](https://github.com/wireapp/wire-server/tree/v2026-01-13/charts). For reference, how older helm chart values looked like can be found with [5.5 version helm charts](https://github.com/wireapp/wire-server/tree/v2024-07-09/charts). These charts also present in each artifact at `charts` directory for local reference.


Copy the old values from `wire-server-deploy-old/values` to `old-values`
```bash
cp -r ../wire-server-deploy-old/values old-values/
```

Generate Wire Server secrets.

```bash
bin/offline-secrets.sh
```

Comment out `main` from `bin/helm-operations.sh` before sourcing it, by manually editing it - if required.

```bash
grep main bin/helm-operations.sh
```

Expected output:
```
main() {
#main
```

Prepare Wire Server values - it will create a working copy for values.yaml and secrets.yaml. These should help us to get started with prepared helm chart values for 5.25 with our domain.

*Note*: Before running the below command - please ensure that the `main` function at the end of file is commented.

Run the rest of this block inside the `d bash` shell.

```bash
export TARGET_SYSTEM="example.com" CERT_MASTER_EMAIL="certmaster@example.com" DEPLOY_CERT_MANAGER=FALSE DEPLOY_CALLING_SERVICES=FALSE
source bin/helm-operations.sh
process_values "prod" "values"
process_values "prod" "secrets"
sync_pg_secrets
configure_values
```

Fix file ownership if needed.

```bash
sudo chown -R demo:demo values
```

Enable metrics again.

```bash
d yq eval -i '
  .brig.metrics.serviceMonitor.enabled = true |
  .proxy.metrics.serviceMonitor.enabled = true |
  .cannon.metrics.serviceMonitor.enabled = true |
  .cargohold.metrics.serviceMonitor.enabled = true |
  .galley.metrics.serviceMonitor.enabled = true |
  .gundeck.metrics.serviceMonitor.enabled = true |
  .nginz.metrics.serviceMonitor.enabled = true |
  .spar.metrics.serviceMonitor.enabled = true
' values/wire-server/values.yaml

d yq eval -i '."ingress-nginx".controller.metrics.enabled = true | ."ingress-nginx".controller.metrics.serviceMonitor.enabled = true' values/ingress-nginx-controller/values.yaml
```

Compare Helm chart values and secrets for `wire-server`, `webapp`, `team-settings`, and `account-pages`.

Use the `wire-server-deploy-admin` image or the dyff container, then compare old and new values.

```bash
d dyff between old-values/wire-server/values.yaml values/wire-server/values.yaml
d dyff between old-values/wire-server/secrets.yaml values/wire-server/secrets.yaml
```

When comparing values, focus on added and removed keys. Update `values/wire-server/values.yaml` accordingly.

When comparing secrets, copy old secret values into the new secrets file where required. Expected differences at the end should be limited to:

- Twilio changes
- `brig.secrets.pgPassword`
- `galley.secrets.mlsPrivateKeys` or `mlsPrivateKeys`
- `background-worker.secrets.pgPassword`

Confirm the final expected secret differences for this deployment.

### Verify Multi-Ingress Values (in a Multi-Ingress env)

Set up multi-ingress values for all domains in the `wire-server` Helm chart.

Reference script:
https://raw.githubusercontent.com/wireapp/wire-scripts/refs/heads/multi-ingress-verification/multi-ingress/multi_ingress_verify.sh

```bash
# main domain=example.com
# multi ingress domain = red.example.com
d bash bin/multi_ingress_verify.sh -f values/wire-server/values.yaml -m example.com -d red.example.com
```

Set up `nginx-ingress-services` values.

```bash
cp old-values/nginx-ingress-services/values.yaml values/nginx-ingress-services/values.yaml
```

For all multi-ingress domains, ideally no change is required. Copy the files from the old directory and repeat per domain.

```bash
cp old-values/nginx-ingress-services/red-values.yaml values/nginx-ingress-services/red-values.yaml
cp old-values/nginx-ingress-services/red-cert.pem values/nginx-ingress-services/red-cert.pem
cp old-values/nginx-ingress-services/red-key.pem values/nginx-ingress-services/red-key.pem
```

Generate or validate nginx values for a domain.

```bash
d bash bin/multi_ingress_verify.sh --check-nginx -m example.com -d red.example.com --nginx-values values/nginx-ingress-services/red-values.yaml --create-nginx-values
```

Compare old and new domain-specific nginx values.

```bash
d dyff between old-values/nginx-ingress-services/red-values.yaml values/nginx-ingress-services/red-values.yaml
```

Update differences caused by name changes if any.

If `values/wire-server/values.yaml` has been updated, then verify the difference agin:
```bash
d dyff between old-values/wire-server/values.yaml values/wire-server/values.yaml
```

### Check Webapp, Team Settings, and Account Pages Values

Copy and compare Webapp values.

```bash
cp old-values/webapp/values.yaml values/webapp/values.yaml
d dyff between values/webapp/prod-values.example.yaml values/webapp/values.yaml
```

Fix Webapp values by considering both the old deployment values and the new example values.

Compare Team Settings and Account Pages values.

```bash
d dyff between old-values/team-settings/values.yaml values/team-settings/values.yaml
d dyff between old-values/account-pages/values.yaml values/account-pages/values.yaml
```

### Load Required Helm Chart Images

Check disk usage first.

```bash
d ansible kube-node -i ansible/inventory/offline/inventory.yml -m shell -a "df -h | head -5"
```

Seed offline Helm container images.

```bash
# Skip system-containers, i.e. Kubernetes-required images, unless Kubernetes itself is being upgraded.
d ansible-playbook -i ansible/inventory/offline/inventory.yml ansible/seed-offline-containerd.yml --skip-tags system-containers
```

If disk size is small, reduce the asset host image list to the images required for this deployment.

```bash
d bin/extract_images.sh versions/helm_image_tree.json > images_needed.txt
d ansible assethost -i ansible/inventory/offline/inventory.yml -m fetch -a "src=/opt/assets/containers-helm/index.txt dest=./current-big-list flat=yes"
d ansible assethost -i ansible/inventory/offline/inventory.yml -m copy -a "src=images_needed.txt dest=/opt/assets/containers-helm/index.txt mode=0644"
d ansible assethost -i ansible/inventory/offline/inventory.yml -m shell -a "cat /opt/assets/containers-helm/index.txt"
d ansible kube-node -i ansible/inventory/offline/inventory.yml -m shell -a "df -h | head -5"
```

## Phase 3: Helm Diff and Pre-Upgrade Chart Work

Before starting this phase, confirm that asciinema recording is active.

When reviewing Helm diffs, understand both the explicit value changes and the implicit chart-default changes. Most configuration comes from the upstream chart defaults unless it is overridden in `values/CHART/values.yaml`. Look for resource or deployment changes in the backend, image tag changes, service type changes, jobs or hooks, migration-related settings, and default values or features that become enabled by the new chart. Also identify any manual additions or live patches applied directly to Kubernetes objects outside Helm, because those changes may not be represented in chart values and can be overwritten or behave differently after a Helm upgrade.

Upstream Helm chart values for the target release can be reviewed in the 5.25 charts at https://github.com/wireapp/wire-server/tree/v2026-01-13/charts. Older 5.5 chart values are available at https://github.com/wireapp/wire-server/tree/v2024-07-09/charts. The same chart defaults are also available locally in the extracted artifact under `charts/CHART/values.yaml`.

### Check External Service Chart Diffs

Verify external service chart values before upgrading them.
Run the rest of this block inside the `d bash` shell.

```bash
for chart in elasticsearch-external minio-external rabbitmq-external cassandra-external postgresql-external; do
  cmd=(helm diff "$chart" "charts/$chart")

  values_file="values/$chart/values.yaml"
  secrets_file="values/$chart/secrets.yaml"

  if [[ -f "$values_file" ]]; then
    cmd+=(--values "$values_file")
  fi

  if [[ -f "$secrets_file" ]]; then
    cmd+=(--values "$secrets_file")
  fi

  echo "Running: ${cmd[*]}"
  "${cmd[@]}"
done
```

### Upgrade Other Charts

To check all the existing helm charts run:
```bash
d helm list
```

After each Helm install, upgrade, or uninstall, check Kubernetes state before moving on.

```bash
d kubectl get pods
```

Also review the relevant Wire Server Grafana dashboard after major backend chart changes. A Helm upgrade may not always restart pods if the rendered pod template does not change; it can still update Helm release state, chart metadata, or values. Confirm the intended resources actually changed before relying on a Helm success message.

During the maintenance window, keep a test group conversation available. Send a message every 5 minutes, and after every main Helm chart upgrade, to record the user-visible state of messaging. During intentional service scale-down, message delivery may fail; record the time and the expected reason.

Resolve Helm chart differences by upgrading external and supporting charts.

Example for MinIO:

```bash
d helm diff minio-external charts/minio-external --values values/minio-external/values.yaml
d helm upgrade --install minio-external charts/minio-external --values values/minio-external/values.yaml
```

Test new values with `wire-utility`. The `wire-utility` chart confirms whether all external services can be reached. Files written inside `wire-utility` are not persistent, so copy out anything you need before restarting or replacing the pod.

```bash
d helm upgrade --install wire-utility charts/wire-utility --values values/wire-server/values.yaml --values values/wire-server/secrets.yaml
# wait for the new wire-utility-0 pod to come up
d kubectl exec -ti wire-utility-0 -- status
```

The `status` command should show all connections as healthy.

Upgrade supporting charts. Before changing each chart, review the `helm diff` output and make sure the impact is understood.

```bash
# fake-aws for in-cluster sqs and sns services
d helm diff fake-aws charts/fake-aws --values values/fake-aws/values.yaml
d helm upgrade --install fake-aws charts/fake-aws --values values/fake-aws/values.yaml

# to clean stale connections between cannon and redis pods
d helm diff reaper charts/reaper --values values/reaper/values.yaml
d helm upgrade --install reaper charts/reaper --values values/reaper/values.yaml
```
Verify the pods post upgrading the helm charts.

Warning: check the diff of the `ingress-nginx-controller` chart carefully because it directly affects how traffic reaches the cluster. If the ingress `Service` type, node ports, load balancer settings, or external traffic policy changes, prepare the firewall and routing changes before upgrading.

```bash
d helm diff ingress-nginx-controller charts/ingress-nginx-controller --values values/ingress-nginx-controller/values.yaml
# Verify the above output before running the below command
d helm upgrade --install ingress-nginx-controller charts/ingress-nginx-controller --values values/ingress-nginx-controller/values.yaml
```
Verify the pods post upgrading the helm charts.

Install `smtp` and `databases-ephemeral` after scaling down Wire services.

Before starting the Wire Server upgrade, run a quick diff check for the core user-facing charts. Make sure you understand the changes proposed for each chart and it aligns with your environment.

Run the rest of this block inside the `d bash` shell.

```bash
for chart in wire-server webapp team-settings account-pages; do
  cmd=(helm diff "$chart" "charts/$chart")

  values_file="values/$chart/values.yaml"
  secrets_file="values/$chart/secrets.yaml"

  if [[ -f "$values_file" ]]; then
    cmd+=(--values "$values_file")
  fi

  if [[ -f "$secrets_file" ]]; then
    cmd+=(--values "$secrets_file")
  fi

  echo "Running: ${cmd[*]}"
  "${cmd[@]}"
done
```

## Phase 4: Wire Server Backend Upgrade

Before starting this phase, confirm that asciinema recording is active.

### Pre-Migration Checks

Check Cassandra schema versions before migration.

```bash
d kubectl exec -t wire-utility-0 -- /usr/local/bin/cqlsh -e "SELECT version FROM brig.meta WHERE id=1 ORDER BY version DESC LIMIT 1;SELECT version FROM gundeck.meta WHERE id=1 ORDER BY version DESC LIMIT 1;SELECT version FROM galley.meta WHERE id=1 ORDER BY version DESC LIMIT 1;SELECT version FROM spar.meta WHERE id=1 ORDER BY version DESC LIMIT 1;"
```

Expected source versions, in query order:

- `brig`: V81
- `gundeck`: V11
- `galley`: V92
- `spar`: V18

### Scale Down Wire Services

Maintenance window starts here. Scaling these services to 0 replicas causes Wire client traffic to fail or become unavailable until the backend is upgraded and services are running again.

Before continuing, confirm:

- User communications and maintenance window are active.
- Incoming traffic is disabled or drained if the customer requires a hard traffic stop during migration.
- Prepare to perform a Cassandra backup post all pods have been stopped.

```bash
d kubectl scale --replicas=0 deployment brig galley gundeck cargohold spar nginz webapp reaper account-pages team-settings
d kubectl scale --replicas=0 sts cannon
# confirm these are 0 for the above deployments and statefulsets
d kubectl get deployments
d kubectl get sts
# confirm if all pods have been terminated successfully - wait for them to terminate
d kubectl get pods
```

### Backup Again Before Migration and post traffic cut off

**Note:** Start the backup once confirmed that there are no active wire-server, account-pages and team-settings pods.

Check Cassandra disk usage.

```bash
d ansible cassandra -i ansible/inventory/offline/inventory.yml -m shell -a "df -h"
```

SSH into the Cassandra nodes and run the backup script.

```bash
bash cassandra_backup.sh
```

Confirm that backup snapshots were created for the current date.

```bash
d ansible -i ansible/inventory/offline/inventory.yml cassandra -b -m shell -a 'nodetool listsnapshots | grep backup_$(date +%F)'
```

### Upgrade Wire-Service Dependent Charts

Upgrade dependent charts after scale-down (all pods of the above wire services have terminated successfully) and before the main Wire Server migration.

Replace `demo-smtp` with `smtp`.

```bash
# demo-smtp won't be required and it would be updated with smtp
d helm uninstall demo-smtp
d helm install smtp charts/smtp --values values/smtp/values.yaml
```

Uninstall the old `databases-ephemeral` release and install the new one.

```bash
# to update the service name for redis
d helm upgrade --install databases-ephemeral charts/databases-ephemeral --values values/databases-ephemeral/values.yaml
```
Verify the pods post upgrading the helm charts.

### Upgrade Wire Server and Run Cassandra Migrations

Upgrade the `wire-server` Helm chart and let the Cassandra migrations run.

```bash
d helm upgrade --timeout=20m --install wire-server charts/wire-server --values values/wire-server/values.yaml --values values/wire-server/secrets.yaml
```

While the upgrade is running, watch for pod failures in parallel.

```bash
d kubectl get pods
```
Also check the Wire Server Grafana dashboard while the backend pods restart. Watch for error spikes, failing migrations, unhealthy pods, and datasource connectivity issues.

Verify Cassandra schema versions after migration.

```bash
d kubectl exec -t wire-utility-0 -- /usr/local/bin/cqlsh -e "SELECT version FROM brig.meta WHERE id=1 ORDER BY version DESC LIMIT 1;SELECT version FROM gundeck.meta WHERE id=1 ORDER BY version DESC LIMIT 1;SELECT version FROM galley.meta WHERE id=1 ORDER BY version DESC LIMIT 1;SELECT version FROM spar.meta WHERE id=1 ORDER BY version DESC LIMIT 1;"
```

Expected target versions:

- `brig`: 91
- `gundeck`: 12
- `galley`: 101
- `spar`: 21

At the end, confirm that all pods should be up and running.

Send a message in the test group conversation and record the result before proceeding to the next main chart upgrade.

### Run the One-Time Team Features Migration

Run the one-time `migrate-features` chart after the Wire Server upgrade.

```bash
d helm install migrate-features charts/migrate-features
d kubectl get pods
d kubectl logs -f job/migrate-features
d kubectl wait --for=condition=complete job/migrate-features --timeout=1800s
# Expect output only in case of features which got migrated
d kubectl exec -it wire-utility-0 -- cqlsh -e "SELECT team, migration_state FROM galley.team_features LIMIT 5;"
```

### Bring Back Reaper

Bring `reaper` back up.

```bash
d kubectl scale --replicas=1 deployment reaper
```

### Upgrade Webapp, Team Settings, and Account Pages

Upgrade the user-facing charts after the backend upgrade.

```bash
d helm upgrade --install webapp charts/webapp --values values/webapp/values.yaml
d helm upgrade --install team-settings charts/team-settings --values values/team-settings/values.yaml --values values/team-settings/secrets.yaml
d helm upgrade --install account-pages charts/account-pages --values values/account-pages/values.yaml
```
Verify the pods post upgrading the helm charts.

After these chart upgrades, send another message in the test group conversation and check the Wire Server Grafana dashboard for user-visible errors.

### Check Final Core Chart Diff

Run the final Helm diff for core charts.

Run the rest of this block inside the `d bash` shell.

```bash
for chart in wire-server webapp team-settings account-pages; do
  cmd=(helm diff "$chart" "charts/$chart")

  values_file="values/$chart/values.yaml"
  secrets_file="values/$chart/secrets.yaml"

  if [[ -f "$values_file" ]]; then
    cmd+=(--values "$values_file")
  fi

  if [[ -f "$secrets_file" ]]; then
    cmd+=(--values "$secrets_file")
  fi

  echo "Running: ${cmd[*]}"
  "${cmd[@]}"
done
```

## Phase 5: Nginx Ingress Services and Multi-Ingress

Before starting this phase, confirm that asciinema recording is active.

### Update Main Nginx Ingress Services Chart

Check the main domain.

```bash
# list all helm charts
d helm list
# check the difference
d helm diff nginx-ingress-services charts/nginx-ingress-services --values values/nginx-ingress-services/values.yaml --set-file secrets.tlsWildcardCert=values/nginx-ingress-services/cert.pem --set-file secrets.tlsWildcardKey=values/nginx-ingress-services/key.pem
# once changes are confirmed - apply the changes
d helm upgrade --install nginx-ingress-services charts/nginx-ingress-services --values values/nginx-ingress-services/values.yaml --set-file secrets.tlsWildcardCert=values/nginx-ingress-services/cert.pem --set-file secrets.tlsWildcardKey=values/nginx-ingress-services/key.pem
```

### Update Multi-Ingress Domains (in a Multi-Ingress env)

Repeat this section for every multi-ingress domain.

```bash
# to find out the name of the ingress
d helm list
d helm diff nginx-ingress-services-red charts/nginx-ingress-services --values values/nginx-ingress-services/red-values.yaml --set-file secrets.tlsWildcardCert=values/nginx-ingress-services/red-cert.pem --set-file secrets.tlsWildcardKey=values/nginx-ingress-services/red-key.pem
d helm upgrade --install nginx-ingress-services-red charts/nginx-ingress-services --values values/nginx-ingress-services/red-values.yaml --set-file secrets.tlsWildcardCert=values/nginx-ingress-services/red-cert.pem --set-file secrets.tlsWildcardKey=values/nginx-ingress-services/red-key.pem
```
After upgrading, patch the CSP for each multi-ingress domain's ingress.

Verify the pods post upgrading the helm charts.

Reference:
https://github.com/wireapp/wire-docs/blob/WPB-25750-multi-ingress-fix/src/how-to/install/multi-ingress.md#patch-the-csp-content-security-policy-for-each-multi-ingress-domain

### Expected Deeplink Changes (in a Multi-Ingress env)

After `nginx-ingress-services` is upgraded, the deeplink structure changes:

- You no longer need to host your own deeplink service.
- Deeplinks should be available from `nginz`.

```bash
# It will respond with the deeplink for red.example.com
curl https://nginz-https.red.example.com/deeplink.json
# It will respond with the deeplink for example.com
curl https://nginz-https.example.com/deeplink.json
```

## Phase 6: Post-Upgrade Validation

Before starting this phase, confirm that asciinema recording is active.

### Cluster and Service Checks

```bash
d kubectl get pods -A
d kubectl get deployments
d kubectl get sts
```

Check `wire-utility` datasource status.

```bash
d kubectl exec -ti wire-utility-0 -- status
```

Check Cassandra schema versions again if needed.

```bash
d kubectl exec -t wire-utility-0 -- /usr/local/bin/cqlsh -e "SELECT version FROM brig.meta WHERE id=1 ORDER BY version DESC LIMIT 1;SELECT version FROM gundeck.meta WHERE id=1 ORDER BY version DESC LIMIT 1;SELECT version FROM galley.meta WHERE id=1 ORDER BY version DESC LIMIT 1;SELECT version FROM spar.meta WHERE id=1 ORDER BY version DESC LIMIT 1;"
```

Check team feature migration state.

```bash
d kubectl exec -it wire-utility-0 -- cqlsh -e "SELECT team, migration_state FROM galley.team_features LIMIT 5;"
```

### Client Checks

Test with all clients to confirm functionality after the upgrade.

- [ ] Login works on iOS.
- [ ] Login works on Android.
- [ ] Login works on Web App.
- [ ] Login works on Desktop if applicable.
- [ ] Existing 1:1 conversations are visible.
- [ ] Existing group conversations are visible.
- [ ] New text messages work.
- [ ] File attachments work.
- [ ] 1:1 calls work.
- [ ] Group calls work.
- [ ] Push notifications work on iOS and Android.

Webapps may log users out. Log back in and confirm that conversations are present.

## Follow-Up: Upgrade Webapp to 2026-06-08-production.0

Before continuing, make sure that the following docker image is present on all the k8s nodes:
- `quay.io/wire/webapp:2026-06-08-production.0`

After the main upgrade has stabilized, upgrade Webapp to `2026-06-08-production.0` by updating `.image.tag = 2026-06-08-production.0` `values/webapp/values.yaml`.

- Comment/remove the the `MAX_API_VERSION` and `FEATURE_USE_CORE_CRYPTO` from envVars.
- Add `BRAND_NAME: "Wire"` as envVars.
```bash
d yq eval '{"image": .image.tag, "MAX_API_VERSION": .envVars.MAX_API_VERSION, "FEATURE_USE_CORE_CRYPTO": .envVars.FEATURE_USE_CORE_CRYPTO, "BRAND_NAME": .envVars.BRAND_NAME }' values/webapp/values.yaml
# image: 2026-06-08-production.0
# MAX_API_VERSION: null
# FEATURE_USE_CORE_CRYPTO: null
# BRAND_NAME: Wire
# Verify the helm diff
d helm diff  webapp charts/webapp --values values/webapp/values.yaml
```
After verifying the above output - run the following command to upgrade the helm chart.

```bash
d helm upgrade --install webapp charts/webapp --values values/webapp/values.yaml
d kubectl get pods
```

Observe the change for some time with users.

## Follow-Up: Cassandra to PostgreSQL

Make sure to backup Cassandra before starting the migration to Postgresql. Post-upgrade, plan the Cassandra to PostgreSQL migration separately as explained at https://docs.wire.com/latest/how-to/administrate/migrate-to-postgresql.html. 

## Rollback and Stop Conditions

Stop and reassess before proceeding if any of these are true:

- Cassandra backups cannot be verified.
- The new inventory does not correctly represent PostgreSQL and RabbitMQ nodes.
- `wire-utility` cannot connect to Cassandra, PostgreSQL, RabbitMQ, Elasticsearch, or MinIO.
- Helm diff shows unexpected destructive changes that are not understood.
- Cassandra schema versions do not match the expected source versions before migration.
- Cassandra schema versions do not match the expected target versions after migration.
- `migrate-features` does not complete successfully.
- Core services enter repeated crash loops after the backend upgrade.
