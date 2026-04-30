# Wire-Server `5.24.0` release

Reference based on these [`build.json` charts](https://raw.githubusercontent.com/wireapp/wire-builds/79660a72c74c8644fb3717bd147368e4c5848117/build.json), and the [release changelog](https://github.com/wireapp/wire-server/releases/tag/v2025-11-26).

Artifact:
[`wire-server-deploy-static-f88a2db81e763f7376fc0f7ecc40166a3bc37ee8.tgz`](https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-f88a2db81e763f7376fc0f7ecc40166a3bc37ee8.tgz)

## Known bugs

There is a bug with our `brig` charts failing to deploy in a non-federated environment. If you are running a non-federated environment, to work around this, set the following configuration in your `brig`:

```yaml
brig:
  config:
    enableFederation: true
```

## Mandatory (breaking) changes

### `brig`

In `values/wire-server/values.yaml`:

```yaml
brig:
  config:
    rabbitmq:
      host: rabbitmq-host-or-service
```

In `values/wire-server/secrets.yaml`:

```yaml
brig:
  secrets:
    rabbitmq:
      username: wire-server
      password: <rabbitmq-password>
```

`port` defaults to `5672`, only set it if the RabbitMQ instance listens somewhere else.

Why: starting at `5.23`, `rabbitmq` is deployed as an external service instead of in-cluster. `brig` can't rely on the in-cluster default service name anymore, so the hostname has to be set explicitly.

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
