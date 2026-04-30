# Wire-Server `5.24.0` release

Reference based on these [`build.json` charts](https://raw.githubusercontent.com/wireapp/wire-builds/79660a72c74c8644fb3717bd147368e4c5848117/build.json), and the [release changelog](https://github.com/wireapp/wire-server/releases/tag/v2025-11-26).

Artifact:
[`wire-server-deploy-static-f88a2db81e763f7376fc0f7ecc40166a3bc37ee8.tgz`](https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-f88a2db81e763f7376fc0f7ecc40166a3bc37ee8.tgz)

## Heads up

`5.24` is one of the heavier upgrades in this series. Two big things going on:

* `databases-ephemeral` is replaced by `redis-ephemeral`. The hostname `gundeck` uses for Redis changes.
* Conversation data moves from Cassandra to PostgreSQL. **The original docs called this optional. It must be treated as mandatory.** Skipping it here and then upgrading to `5.25` causes conversations to silently disappear from reads, because of a bad chart default at `5.25`. See the post-upgrade migrations section below.

This page assumes the source version is `5.23.x`.

One more thing: every value change documented on this page must be followed by an actual `d helm upgrade --install wire-server ...` run for the change to apply. The chart doesn't watch the `values.yaml`. Phrasing like "this change should restart all the `galley` pods" means "after the helm upgrade is re-run, the pods will restart". It doesn't happen by itself.

## Known bugs

There is a bug with our `brig` charts failing to deploy in a non-federated environment. If you are running a non-federated environment, to work around this, set the following configuration in your `brig`:

```yaml
brig:
  config:
    enableFederation: true
```

## What must change

Listed in the order things should be done.

### 1. Deploy `redis-ephemeral` (replaces `databases-ephemeral`)

The upstream chart for the in-cluster Redis was swapped. The new chart is `redis-ephemeral` and ships Redis `7.4.6` (the old chart was based on Bitnami). It only supports standalone deployments.

Deploy it **before** the `wire-server` upgrade. If `wire-server` is upgraded first with `gundeck.config.redis.host` already pointing at `redis-ephemeral`, gundeck won't be able to connect.

```bash
d helm upgrade --install redis-ephemeral ./charts/redis-ephemeral \
  --values ./values/redis-ephemeral/prod-values.example.yaml
```

Defaults are fine. Nothing should be carried over from `databases-ephemeral`, it's a different chart.

The old `databases-ephemeral` chart isn't auto-removed. Don't uninstall it yet either, wait until everything else is verified. See "Cleanup" at the bottom.

### 2. Edit `brig.config.rabbitmq` in the wire-server values

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
