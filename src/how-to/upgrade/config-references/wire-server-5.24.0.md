# Wire-Server 5.24.0 release

The following reference was written based on the following [`build.json` charts](https://raw.githubusercontent.com/wireapp/wire-builds/79660a72c74c8644fb3717bd147368e4c5848117/build.json).

For additional details, you can also read our [release chagelog](https://github.com/wireapp/wire-server/releases/tag/v2025-11-26).

## Mandatory (breaking) changes

### `brig`

```yaml
brig:
  rabbitmq:
    host: rabbitmq-host-or-service
    port: 5672 # default
  secrets:
    rabbitmq:
      username: wire-server
      password: verysecurepassword
```

### `background-worker`

```yaml
background-worker:
  config:
    federationDomain: "example.com" # must match federation domain used for the instance in other services (brig etc.)
    cassandraBrig:
      host: your-cassandra-host-or-service # same as your current cassandra.host value
    cassandraGalley:
      host: your-cassandra-host-or-service # same as your current cassandra.host value
```

#### Conversation Data Migration

The following configuration is only mandatory if you decide to migrate conversation data to PostgreSQL at this stage.

Starting this release, migrating conversation data to PostgreSQL from Cassandra is possible. This is only required for channel search and channel management from Team Settings. Follow [this document](../../../developer/reference/config-options.md#using-postgresql-for-storing-conversation-data) for the steps and configuration required.

If you do so, the following configurations are for `background-worker` are required.

```yaml
background-worker:
  config:
    postgresql:
      host: your-postgresql-host-or-service
```

And for secrets:

```yaml
background-worker:
  secrets:
    pgPassword: "your-postgresql-password"
```

### `gundeck`

Upstream Helm chart for `redis-ephemeral` has been replaced. New Redis service hostname has been changed from `{{ .Release.Name }}-master` to `{{ .Release.Name }}`. Verify your Redis service name with:

```bash
kubectl get svc | grep redis
```

Then set accordingly:

```yaml
gundeck:
  config:
    redis:
      host: "your-redis-service"
```

## Optional changes

### `background-worker`

New settings, change only if required. The following are defaults as they come in charts

```yaml
background-worker:
  postgresql:
    host: postgresql # This one is already referenced in the mandatory category
    port: "5432"
    user: wire-server
    dbname: wire-server
  # Background jobs consumer configuration
  backgroundJobs:
    # Maximum number of in-flight jobs per process
    concurrency: 8
    # Per-attempt timeout in seconds
    jobTimeout: 60s
    # Total attempts, including the first try
    maxAttempts: 3
  postgresqlPool:
    size: 5
    acquisitionTimeout: 10s
    agingTimeout: 1d
    idlenessTimeout: 10m
```

### `gundeck`

New settings, change only if required. The following are defaults as they come in charts

```yaml
gundeck:
  config:
    redis:
      host: redis-ephemeral # This one is already referenced in the mandatory catefory
      port: 6379
      connectionMode: "master" # master | cluster
      enableTls: false
      insecureSkipVerifyTls: false
```    
