# Wire Utility Tool

## Introduction

### Purpose

The Wire Utility Tool is a specialized debugging container designed to provide comprehensive monitoring, troubleshooting, and operational capabilities for Wire's backend infrastructure. It serves as a standardized toolkit for SRE teams, developers, and DevOps engineers working with Wire services in an air-gapped environment.

### Key Features

- **Multi-service support**: PostgreSQL, Cassandra, Elasticsearch, RabbitMQ, MinIO, Redis
- **Real-time monitoring**: Built-in health checks and status monitoring
- **Interactive debugging**: Full shell access with debugging tools
- **Kubernetes-native**: Designed for deployment in Kubernetes clusters via Helm
- **Security-focused**: Non-root execution, minimal attack surface
- **Extensible**: Easy to add new tools and services

### Use Cases

- **Incident Response**: Rapid troubleshooting during outages
- **Development**: Local testing and development environment setup
- **Operations**: Routine monitoring and maintenance tasks
- **Migration**: Data validation during service migrations
- **Performance Analysis**: System and service performance monitoring

### Deployment

The Wire Utility Tool is deployed as a Kubernetes StatefulSet via the official Wire Helm chart. See the [Wire Helm Charts repository](https://github.com/wireapp/helm-charts/tree/main/charts/wire-utility) for complete deployment instructions and configuration options.

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

## Deployment Guide

Wire utility tool is bundled together with the wire-server-deployment package.
### Prerequisites

- **Kubernetes cluster**: kubectl access to k8s cluster
- **Helm**: Helm chart deployment (see [Wire Helm Charts](https://github.com/wireapp/helm-charts/tree/main/charts/wire-utility))
- **RBAC permissions**: Pod exec and describe permissions
- **Network access**: Connectivity to Wire services

### Helm Deployment

The Wire Utility Tool is deployed via the official Wire Helm chart. Refer to the [Wire Helm Charts repository](https://github.com/wireapp/helm-charts/tree/main/charts/wire-utility) for complete deployment instructions, StatefulSet configuration, security contexts, and resource management.

The Helm chart handles:
- **StatefulSet configuration** with proper labels and annotations
- **Security contexts** and non-root execution
- **Resource limits and requests**
- **Network policies** and RBAC
- **Health checks** and probes
- **Volume mounts** for temporary storage

#### Basic Configuration

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

### How to Save the Image for Air-Gapped Environment

For air-gapped environments where internet access is not available, you need to manually download and distribute the Wire Utility Tool image to your Kubernetes nodes if you are not installing the tool from the off-line bundle.

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

Once the image is available on all nodes, you can proceed with the standard Helm deployment.

## Accessing the Tool

### Kubernetes Pod Access

Once deployed via the Wire Helm chart, access the utility pod for debugging:

```bash
# Get pod name
kubectl get pods -l app.kubernetes.io/name=wire-utility

# Interactive shell access
kubectl exec -it wire-utility-0 -- bash

# Ephemeral debug container (Kubernetes 1.25+)
kubectl debug -it wire-utility-0 --image=quay.io/wire/wire-utility-tool:latest -- bash
```

### Service Status Overview

The tool provides comprehensive service connectivity monitoring:

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
## Core Debugging Tools

The Wire Utility Tool provides comprehensive command-line interfaces and utilities for interacting with all supported services. Each service has dedicated tools and commands for monitoring, debugging, and administration.

### Status Monitoring
```bash
status                    # Show comprehensive service connectivity status
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

**Note**: RabbitMQ commands require the management plugin to be enabled. If the management plugin is disabled on your RabbitMQ nodes, `rabbitmqadmin` commands will fail with:

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

## System and Network Tools

Beyond service-specific debugging tools, the Wire Utility Tool includes general-purpose system and network utilities for comprehensive troubleshooting and monitoring.

### Network Diagnostics
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

### Development and Testing Tools
```bash
# Python interpreter (for scripting)
python3
python3 -c "import requests; print('Python available')"

# HTTP requests and testing
curl -X GET http://api.example.com
curl -X POST -d '{"key": "value"}' http://api.example.com

```

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
```

### Periodic Probing and Logging

The utility pod continuously monitors service health and generates logs:

#### Enabling Periodic Monitoring

Set the environment variable in your Helm values:

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
kubectl logs wire-utility-0

# Follow logs in real-time
kubectl logs -f wire-utility-0

# View logs from last hour
kubectl logs --since=1h wire-utility-0
```

#### Log Analysis

```bash
# Search for specific service issues
kubectl logs wire-utility-0 | grep -i "error\|failed\|unreachable"

# Count successful vs failed checks
kubectl logs wire-utility-0 | grep -c "is reachable\|connection successful\|is healthy"

# Monitor specific service
kubectl logs -f wire-utility-0 | grep "Cassandra"
```

### Internal API Access

Since the pod is deployed within the Kubernetes cluster, you can directly access internal APIs of wire components such as `brig`, `galley`.

#### Service Endpoints

```bash
# Example API from galley service
curl -X GET http://galley:8080/i/teams/<team_UUID> | jq '.'
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


## Configuration Reference

All of the necessary configurations are generated from the values/wire-server/values.yml and values/wire-server/secrets.yml of your wire-server-deploy bundle which gets passed when the wire-utility helm chart is installed.

#### Operational Settings

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ENABLE_PROBE_THREAD` | No | `false` | Enable periodic health checks |
| `HOSTNAME` | Auto | Pod name | Container hostname for logging |

