# Wire Utility Tool

## Introduction

### Purpose

The Wire Utility Tool is a specialized debugging container designed to provide comprehensive monitoring, troubleshooting, and operational capabilities for Wire's backend infrastructure. It serves as a standardized toolkit for SRE teams, developers, and DevOps engineers working with Wire services in an offline environment.

### Key Features

- **Command Line Clients**: PostgreSQL, Cassandra, Elasticsearch, RabbitMQ, MinIO, Redis
- **Interactive debugging**: Full shell access with debugging tools
- **Kubernetes-native**: Designed for deployment in Kubernetes clusters via Helm
- **Security-focused**: Non-root execution, minimal attack surface

### Use Cases

- **Incident Response**: Rapid troubleshooting during outages
- **Development**: Local testing for development environments
- **Pre-Install Checks**: Can check an environment before deploying Wire
- **Operations**: Routine maintenance tasks with wire deployed

## Deployment

The Wire Utility Tool may be deployed one of three ways:

1. As a Kubernetes StatefulSet via the official Wire-provided Helm chart.
2. As a manually imported Kubernetes Deployment. (no Helm, no wire-server values.yaml required)
3. In docker.

Wire utility tool comes bundled together with the wire-server-deploy offline delivery bundle.

### Deployment in Kubernetes (after Wire is deployed, via Helm)

#### Prerequisites

- **Kubernetes cluster**: kubectl access to k8s cluster
- **Helm**: Helm chart deployment (see [Wire Helm Charts](https://github.com/wireapp/helm-charts/tree/main/charts/wire-utility))
- **RBAC permissions**: Pod exec and describe permissions
- **Network access**: Connectivity to Wire services

#### Installation

The Wire Utility Tool integrates with your existing Wire server deployment by reusing configuration from your main `values.yaml` and `secrets.yaml` files.

All the values required for the wire-utility to build connections with the Wire data sources are passed via your existing Wire server configuration files: `./values/wire-server/values.yaml` and `./values/wire-server/secrets.yaml`.

Install the wire-utility chart using Helm:

```bash
helm install wire-utility ./charts/wire-utility \
  -f ./values/wire-server/values.yaml \
  -f ./values/wire-server/secrets.yaml
```

The chart automatically inherits service endpoints and credentials from your main Wire deployment configuration.

> **Note**: you may have to prepend the helm command with `d`, if you are using the offline delivery bundle, and it's associated docker container.
```bash
d helm install wire-utility ./charts/wire-utility \
  -f ./values/wire-server/values.yaml \
  -f ./values/wire-server/secrets.yaml
```

### Deployment in Kubernetes (without Helm, or a valid Wire configuration)

If you do not yet have Wire deployed, you can still use the wire-utility container as a diagnostic tool, to ensure your infrastructure is functioning.

The Wire Utility Tool can be deployed by creating a yaml file like the following:
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: wire-utility-config
data:
  MINIO_SERVICE_ENDPOINT: "http://minio-external:9000"

  CASSANDRA_SERVICE_NAME: "cassandra-external"
  CASSANDRA_SERVICE_PORT: "9042"

  RABBITMQ_SERVICE_NAME: "rabbitmq-external"
  RABBITMQ_SERVICE_PORT: "5672"
  RABBITMQ_MGMT_PORT: "15672"

  ES_SERVICE_NAME: "elasticsearch-external"
  ES_PORT: "9200"

  PGHOST: "postgresql-external"
  PGPORT: "5432"
  PGUSER: "wire-server"
  PGDATABASE: "wire-server"

  # Set true for deeper automated checks every five minutes.
  ENABLE_PROBE_THREAD: "false"
---
apiVersion: v1
kind: Secret
metadata:
  name: wire-utility-secrets
stringData:
  MINIO_ACCESS_KEY: "replace-me"
  MINIO_SECRET_KEY: "replace-me"

  RABBITMQ_USERNAME: "replace-me"
  RABBITMQ_PASSWORD: "replace-me"

  # psql reads this standard PostgreSQL environment variable even though
  # the utility's Python entrypoint does not explicitly reference it.
  PGPASSWORD: "replace-me"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wire-utility
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wire-utility
  template:
    metadata:
      labels:
        app: wire-utility
    spec:
      automountServiceAccountToken: false
      containers:
        - name: wire-utility
          image: quay.io/wire/wire-utility-tool:latest
          imagePullPolicy: IfNotPresent

          envFrom:
            - configMapRef:
                name: wire-utility-config
            - secretRef:
                name: wire-utility-secrets

          securityContext:
            allowPrivilegeEscalation: false
            runAsNonRoot: true
            runAsUser: 65532
            capabilities:
              drop:
                - ALL

          resources:
            requests:
              cpu: 20m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

> **Note**: Replace the replace-me's with your actual secrets, and replace the '-external' with nothing, if you are using services inside of the cluster. for instance, if we have minio available inside of the kubernetes cluster, it's MINIO_SERVICE_ENDPOINT would need to point to "http://minio:9000", to corespond to a service definition of:
```
minio                                           ClusterIP   None            <none>        9000/TCP                     14d
```

(To see what your service definitions look like, run 'kubectl get services'.)

Once you have this file, you can use ```kubectl apply -f wire-utility-config.yaml``` to apply it to your kubernetes cluster. This will create a 'Deployment', which will automatically ensure you always have one wire-utility pod running.

#### Cleanup

Afterwards, if you want to remove the container, you must use ```kubectl delete deployment/wire-utility```.

## Deployment via Docker

### Load the container image
```bash
# Normal, online workflow
docker pull quay.io/wire/wire-utility-tool:latest

# Air‑gapped workflow – after you have run `docker save` on a machine with internet access:
docker load -i quay.io_wire_wire-utility-tool_latest.tar
```

> The tag you use (`latest`, `1.1.0`, …) must match the version you have in your Helm chart to avoid mismatched client binaries.

---  

### Run the container

The simplest “run‑once” invocation is:

```bash
docker run -d \
  --name wire-utility \
  --restart unless-stopped \
  --user 65532:65532 \
  --cap-drop ALL \
  --cap-add NET_RAW \
  --network host \                          # optional – use host networking if services are reachable on the host
  --env-file ./wire-utility.env            # plain‑text file with the variables from the K8s ConfigMap/Secret
  quay.io/wire/wire-utility-tool:latest
```

**Explanation of the flags**

| Flag | Reason |
|------|--------|
| `-d` | Run in the background – you can `docker logs -f` later. |
| `--name wire-utility` | Gives the container a predictable name for `exec` and `logs`. |
| `--restart unless-stopped` | Guarantees the pod is kept alive after a host reboot (mirrors the K8s Deployment “always‑on” behaviour). |
| `--user 65532:65532` | Enforces the non‑root security model used in the chart. |
| `--cap-drop ALL` + `--cap-add NET_RAW` | Mirrors the `securityContext` – we drop everything but keep the ability to run `ping`/`traceroute`. |
| `--network host` (optional) | If you run Docker on a host that already has network routes to your Wire services (e.g. a VM with a VPN attached), the “host” network avoids the need for extra `-p` port mappings. If you prefer isolated networking, omit this flag and publish the needed ports with `-p`. |
| `--env-file` | A single file that contains all the `KEY=VALUE` pairs you would otherwise put into a ConfigMap/Secret. Example file content (the same you see in the K8s manifest):

  ```bash
  MINIO_SERVICE_ENDPOINT=http://minio-external:9000
  CASSANDRA_SERVICE_NAME=cassandra-external
  CASSANDRA_SERVICE_PORT=9042
  RABBITMQ_SERVICE_NAME=rabbitmq-external
  RABBITMQ_SERVICE_PORT=5672
  RABBITMQ_MGMT_PORT=15672
  ES_SERVICE_NAME=elasticsearch-external
  ES_PORT=9200
  PGHOST=postgresql-external
  PGPORT=5432
  PGUSER=wire-server
  PGDATABASE=wire-server
  ENABLE_PROBE_THREAD=false
  ```

> **Note**: Secrets (`MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`, `PGPASSWORD`) should **never** be checked into source control. Keep them in a separate `.env.secrets` file and add it to `.gitignore`. Then pass it to Docker with an additional `--env-file ./wire-utility.secrets`.

## Common Usage Cases:

To use any of the functions in this container, you must first run a kubectl exec command, to get the container's shell prompt. You must follow 'getting into the container' each time you want to use it.

### Getting into the container:

Once deployed, you can access the utility pod for debugging:

With Kubernetes:
```bash
d kubectl exec -it deployment/wire-utility -- bash
```

With Docker:
```
docker exec -it wire-utility bash
```

If you are successful, you should see the following:
```
🔧 Welcome to Wire Utility Debug Pod
📊 Type 'status' to check service connectivity

=== Wire Utility Pod Status ===
Pod: wire-utility-66df8bb96f-j5gv7
Time: Tue Aug  4 11:35:18 UTC 2026

=== Connectivity ===
✅ MinIO        minio-external:9000
✅ Cassandra    cassandra-external:9042
✅ RabbitMQ     rabbitmq-external:5672
✅ Elasticsearch elasticsearch-external:9200
❌ PostgreSQL   postgresql-external:5432

=== Quick Commands ===
status                    # Show this status
mc ls wire-minio          # List MinIO buckets
mc admin info wire-minio  # Show MinIO server info
cqlsh                     # Connect to Cassandra
rabbitmqadmin list queues # List RabbitMQ queues
psql                      # Connect to PostgreSQL
es usages                 # Show all available Elasticsearch debug commands
es all                    # Run all Elasticsearch diagnostics (health, nodes, indices, etc.)

nonroot@wire-utility:~$
```

### Service Status Overview

The tool provides service connectivity monitoring:

```bash
# Check all service connectivity
status

# Output example:
# === Wire Utility Pod Status ===
# Pod: wire-utility-0
# Time: Mon Sep 11 10:30:00 UTC 2025
#
# === Connectivity ===
# ✅ MinIO        minio-external:9000
# ✅ Cassandra    cassandra-external:9042
# ✅ RabbitMQ     rabbitmq-external:5672
# ✅ Elasticsearch elasticsearch-external:9200
# ✅ PostgreSQL   postgresql:5432
#
# === Quick Commands ===
status                    # Show this status
mc ls wire-minio          # List MinIO buckets
mc admin info wire-minio  # Show MinIO server info
cqlsh                     # Connect to Cassandra
rabbitmqadmin list queues # List RabbitMQ queues
psql                      # Connect to PostgreSQL
es usages                 # Show all available Elasticsearch debug commands
es all                    # Run all Elasticsearch diagnostics (health, nodes, indices, etc.)
```

### MinIO Object Storage
```bash
# List all buckets
mc ls wire-minio

# Show server information
mc admin info wire-minio

# List objects in a bucket
mc ls wire-minio/bucket-name

# Copy files to/from MinIO
mc cp local-file wire-minio/bucket-name/
mc cp wire-minio/bucket-name/remote-file ./local-file

# Create bucket
mc mb wire-minio/new-bucket

# Set bucket policy
mc policy set public wire-minio/bucket-name
```

### Cassandra Database
```bash
# Interactive Cassandra shell
cqlsh

# Execute CQL commands directly
cqlsh -e "DESCRIBE KEYSPACES;"
cqlsh -e "SELECT * FROM keyspace.table_name LIMIT 10;"

# Check cluster status
cqlsh -e "SELECT peer, data_center, rack FROM system.peers;"

# Monitor query performance
cqlsh -e "SELECT * FROM system_traces.sessions LIMIT 5;"

# Schema inspection
cqlsh -e "DESCRIBE TABLE keyspace.table_name;"
```

### RabbitMQ Message Queue

> **Note**: RabbitMQ commands require the management plugin to be enabled. If the management plugin is disabled on your RabbitMQ nodes, `rabbitmqadmin` commands will fail with:

```bash
*** Could not connect: [Errno 111] Connection refused
```

**Resolution**: Enable the RabbitMQ management plugin on your RabbitMQ nodes:

```bash
sudo rabbitmq-plugins enable rabbitmq_management
```

This enables the management API (accessible on port 15672) which is required for:
- All `rabbitmqadmin` administrative commands
- Periodic health checks performed by the utility tool
- Web-based RabbitMQ management interface

The management plugin automatically enables the required dependencies (`rabbitmq_management_agent` and `rabbitmq_web_dispatch`).

```bash
# List all queues
rabbitmqadmin list queues

# Show queue details with message counts
rabbitmqadmin list queues name messages consumers

# List exchanges
rabbitmqadmin list exchanges

# List bindings
rabbitmqadmin list bindings

# Show overview information
rabbitmqadmin show overview

# Monitor message rates (run multiple times)
rabbitmqadmin list queues name messages | sort -k2 -n
```

### PostgreSQL Database
```bash
# Interactive PostgreSQL shell
psql

# Execute SQL commands directly
psql -c "SELECT count(*) FROM table_name;"
psql -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"

# List all databases
psql -l

# List tables in current database
psql -c "\dt"

# Check connection status
psql -c "SELECT version();"

# Monitor active queries
psql -c "SELECT pid, usename, query_start, query FROM pg_stat_activity WHERE state != 'idle';"
```

### Elasticsearch Search Engine
```bash
# Show all available Elasticsearch commands
es usages

# Check cluster health
es health

# List all indices
es indices

# Show cluster nodes
es nodes

# Display cluster settings
es settings

# Show current tasks
es tasks

# Cluster statistics
es stats
```

### System and Network Tools

Beyond service-specific debugging tools, the Wire Utility Tool includes general-purpose system and network utilities for comprehensive troubleshooting and monitoring.

#### Network Diagnostics
```bash
# Test connectivity to services
curl -I http://elasticsearch-external:9200
curl -I http://minio-external:9000

# DNS resolution
nslookup cassandra-external
dig cassandra-external

# Ping services
ping -c 3 cassandra-external
```

#### Development and Testing Tools
```bash
# HTTP requests and testing
curl -X GET http://api.example.com
curl -X POST -d '{"key": "value"}' http://api.example.com
```

#### Database-Specific APIs

```bash
# PostgreSQL: Check replication status
psql -c "SELECT * FROM pg_stat_replication;"

# Cassandra: System tables via CQL
cqlsh -e "SELECT * FROM system.schema_keyspaces;"

# Elasticsearch: Index statistics
curl -s $ES_SERVICE_NAME:$ES_PORT/_stats | jq '.indices'
```

#### Internal API Access

Since the pod is deployed within the Kubernetes cluster, you can directly access internal APIs of wire components such as `brig`, `galley`.

##### Service Endpoints

```bash
# Example API from galley service
curl -X GET http://galley:8080/i/teams/<team_UUID> | jq '.'
```

## Troubleshooting
**Troubleshooting Helm Template Errors**: If you encounter Helm template errors during installation due to missing keys (even when passing the wire-server values and secrets files), this typically indicates you're running an older version of wire-server. To resolve this:

1. Update the `./charts/wire-utility/values.yaml` file with the missing keys and appropriate default values
2. This ensures the utility tool deployment doesn't interfere with your existing Wire server setup
3. Refer to the latest wire-utility chart values for the required configuration keys

```yaml
# values.yaml (excerpt)
env:
  # Service endpoints
  MINIO_SERVICE_ENDPOINT: "http://minio-external:9000"
  CASSANDRA_SERVICE_NAME: "cassandra-external"
  CASSANDRA_SERVICE_PORT: "9042"
  RABBITMQ_SERVICE_NAME: "rabbitmq-external"
  RABBITMQ_SERVICE_PORT: "5672"
  ES_SERVICE_NAME: "elasticsearch-external"
  ES_PORT: "9200"
  PGHOST: "postgresql"
  PGPORT: "5432"

  # Optional: Enable periodic health checks
  ENABLE_PROBE_THREAD: "true"
```

## For Air-Gapped Environments

For air-gapped environments where internet access is not available, you need to manually download and distribute the Wire Utility Tool image to your Kubernetes nodes if you are not installing the tool from the offline bundle.

1. **Download the chart**: First, ensure the `wire-utility` chart is available in your `wire-server-deploy` charts directory.

2. **Pull the image**: Download the Wire Utility Tool image using Docker:

   ```bash
   docker pull quay.io/wire/wire-utility-tool:1.1.0
   ```

3. **Save the image**: Export the image to a tar file (replace forward slashes and colons with underscores for filesystem compatibility):

   ```bash
   docker save -o quay.io_wire_wire-utility-tool_1.1.0.tar quay.io/wire/wire-utility-tool:1.1.0
   ```

4. **Distribute to nodes**: Copy the `.tar` file to all Kubernetes nodes in your cluster.

5. **Import on each node**: Run this command on **each** Kubernetes node to import the image into containerd:

   ```bash
   ctr -n k8s.io images import quay.io_wire_wire-utility-tool_1.1.0.tar
   ```

6. **Verify import**: Confirm the image is available in containerd:

   ```bash
   ctr -n k8s.io images list | grep wire-utility
   ```

Once the image is available on all nodes, you can proceed with the standard deployment.

## Architecture Overview

### Container Structure

```
wire-utility-tool:<tag>
├── Base Image: Debian Bullseye Slim
├── System Tools: bash, curl, wget, networking utilities
├── Database Clients: psql, cqlsh, redis-cli
├── Message Queue: rabbitmqadmin
├── Storage: MinIO client (mc)
├── Search: Elasticsearch debug scripts
├── Monitoring: System monitoring tools (ps, top, free, etc.)
├── Python Runtime: Python 2.7 & 3.x with essential libraries
└── Entrypoint: Service monitoring and client configuration
```

### Service Integration

The tool integrates with Wire's core services through environment-based configuration:

- **PostgreSQL**: Primary relational database
- **Cassandra**: Distributed NoSQL database for chat data
- **Elasticsearch**: Search and analytics engine
- **RabbitMQ**: Message queue for async communication
- **MinIO**: S3-compatible object storage
- **Redis**: Caching and session storage

### Security Model

- **Non-root execution**: Runs as UID 65532 (`nonroot` user)
- **Minimal privileges**: No sudo access, restricted system access
- **Network isolation**: Access controlled via Kubernetes RBAC
- **Ephemeral nature**: No persistent data storage
- **Tool restrictions**: Only approved debugging tools included

## Workflow Examples

### Complete Service Health Check
```bash
# 1. Check overall status
status

# 2. Verify each service individually
curl -s http://minio-external:9000/minio/health/live
cqlsh -e "SELECT cluster_name FROM system.local;"
rabbitmqadmin show overview
psql -c "SELECT 1;"
curl -s http://elasticsearch-external:9200/_cluster/health
```

### Database Performance Investigation
```bash
# PostgreSQL: Check slow queries
psql -c "SELECT pid, now() - query_start as duration, query FROM pg_stat_activity WHERE state = 'active' AND now() - query_start > interval '30 seconds';"

# Cassandra: Monitor query traces
cqlsh -e "SELECT * FROM system_traces.sessions LIMIT 10 ALLOW FILTERING;"

# Elasticsearch: Check search performance
curl -s http://elasticsearch-external:9200/_nodes/stats | jq '.nodes[].indices.search'
```

### Message Queue Monitoring
```bash
# Check queue lengths
rabbitmqadmin list queues name messages_ready messages_unacknowledged

# Monitor consumer activity
watch -n 5 "rabbitmqadmin list queues name consumers messages"

# Check exchange bindings
rabbitmqadmin list bindings source exchange-name
```

## Periodic Probing and Logging

The utility pod can continuously monitor service health and generates logs:

#### Enabling Periodic Monitoring

Set the environment variable in your values file (if using helm) or your wire-utility-config.yaml:

```yaml
env:
  ENABLE_PROBE_THREAD: "true"
```

#### Log Output

When enabled, the pod generates periodic health check logs:

```
2025-09-11 10:30:00,123 INFO === Periodic Service Status Check ===
2025-09-11 10:30:00,124 INFO MinIO HTTP service http://minio-external:9000/minio/health/live is reachable
2025-09-11 10:30:00,125 INFO Cassandra (cassandra-external:9042) is healthy (CQL query succeeded)
2025-09-11 10:30:00,126 INFO RabbitMQ HTTP service http://rabbitmq-external:15672/api/overview is reachable
2025-09-11 10:30:00,127 INFO RabbitMQ nodes: [{'name': 'rabbit@node1', 'running': True}]
2025-09-11 10:30:00,128 INFO RabbitMQ running nodes: 1
2025-09-11 10:30:00,129 INFO Elasticsearch HTTP service http://elasticsearch-external:9200/_cluster/health is reachable
2025-09-11 10:30:00,130 INFO PostgreSQL connection successful
```

#### Viewing Logs

```bash
# View current logs
d kubectl logs wire-utility-0

# Follow logs in real-time
d kubectl logs -f wire-utility-0

# View logs from last hour
d kubectl logs --since=1h wire-utility-0
```

#### Log Analysis

```bash
# Search for specific service issues
d kubectl logs wire-utility-0 | grep -i "error\|failed\|unreachable"

# Count successful vs failed checks
d kubectl logs wire-utility-0 | grep -c "is reachable\|connection successful\|is healthy"

# Monitor specific service
d kubectl logs -f wire-utility-0 | grep "Cassandra"
```

