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

### `brig` won't deploy in non-federated environments

The `5.24` `brig` chart has a bug that breaks deployment when federation is off. Workaround, in `values/wire-server/values.yaml`:

```yaml
brig:
  config:
    enableFederation: true
```

This is fixed at `5.25`, so once `5.25` is reached the workaround can be taken back out.

### `bin/helm-operations.sh` has a malformed `CERT_MASTER_EMAIL` default

Only relevant for fresh installs starting from `5.23.1` (rather than upgrading an existing deployment). The line in `bin/helm-operations.sh` on the `release-5.23.1` branch reads:

```bash
CERT_MASTER_EMAIL="certmaster@${CERT_MASTER_EMAIL}:-certmaster@${TARGET_SYSTEM}"
```

Bash `:-` defaults have to live inside `${}`. The fix that's already on `master`:

```bash
CERT_MASTER_EMAIL="${CERT_MASTER_EMAIL:-certmaster@example.com}"
```

Without this fix, `cert-manager` ACME registration fails with `400 urn:ietf:params:acme:error:invalidContact: Error validating contact(s) :: unable to parse email address` in the `cert-manager-ns` pod logs. Either patch the file or pass `CERT_MASTER_EMAIL` explicitly when invoking `helm-operations.sh`.

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

### 3. Add the new `background-worker` config

`background-worker` needs a few new fields. In `values/wire-server/values.yaml`:

```yaml
background-worker:
  config:
    federationDomain: example.com  # match the federation domain used everywhere else (brig, etc.)
    cassandraBrig:
      host: <cassandra-host-or-service>  # same value as the existing cassandra.host
    cassandraGalley:
      host: <cassandra-host-or-service>  # same value as the existing cassandra.host
    postgresql:
      host: <postgresql-host-or-service>
```

In `values/wire-server/secrets.yaml`:

```yaml
background-worker:
  secrets:
    pgPassword: <postgresql-password>
```

To grab the existing PostgreSQL password from a typical deploy:

```bash
d kubectl get secret postgresql-external -o jsonpath='{.data.password}' | base64 -d
```

Why: `background-worker` now runs jobs that need PostgreSQL access and that talk directly to the Cassandra keyspaces of `brig` and `galley`. The federation domain is needed for federation-related background tasks.

> **Warning about the `postgresMigration.conversation` default.** At this release the `background-worker` chart defaults `postgresMigration.conversation` to `postgresql`. That default must **not** be left in place when conversations haven't been migrated yet. The data is still in Cassandra, so a `postgresql` setting points the worker at an empty table. See the migration section below. This is the bug that caused conversations to disappear at `5.25` for installs that didn't migrate.

### 4. Update `gundeck.config.redis.host`

The Redis service hostname changed from `{{ .Release.Name }}-master` to `{{ .Release.Name }}`. With the standard `redis-ephemeral` release name, the in-cluster service is just `redis-ephemeral` now (used to be `databases-ephemeral-redis-ephemeral-master`).

Check the cluster:

```bash
d kubectl get svc | grep redis
```

The output looks something like this (the old `databases-ephemeral-*` services will still be there until the old chart is uninstalled, see "Cleanup"):

```
databases-ephemeral-redis-ephemeral-headless   ClusterIP   None            <none>   6379/TCP
databases-ephemeral-redis-ephemeral-master     ClusterIP   10.x.x.x        <none>   6379/TCP
redis-ephemeral                                ClusterIP   10.x.x.x        <none>   6379/TCP
redis-ephemeral-headless                       ClusterIP   None            <none>   6379/TCP
```

The one to use is the plain `redis-ephemeral`. In `values/wire-server/values.yaml`:

```yaml
gundeck:
  config:
    redis:
      host: redis-ephemeral
```

> **Bug in `wire-server-deploy` `5.24`**: the bundled `values/wire-server/prod-values.example.yaml` ships `gundeck.config.redis.host: databases-ephemeral-redis-ephemeral` (the old service). If that file was used as a starting point, override it to `redis-ephemeral` in the local `values.yaml`.

### 5. Run the wire-server helm upgrade

Once all the values are in place:

```bash
d helm upgrade --install wire-server ./charts/wire-server --timeout=15m0s \
  --values ./values/wire-server/values.yaml \
  --values ./values/wire-server/secrets.yaml
```

Watch in another terminal:

```bash
d kubectl get events
```

## Post-upgrade: migrate conversation data to PostgreSQL

This is the part that's been flaky in the past. Don't skip it.

It can only be done **after** the `5.24` `wire-server` helm upgrade has succeeded. Some required services don't exist yet on `5.23`, so trying to migrate before the upgrade just fails.

A Cassandra backup of `galley` should be taken before starting. Seriously.

The migration runs in three steps. Each step is a values change followed by a `helm upgrade --install wire-server ...`.

### Step 1: prepare wire-server for migration

In `values/wire-server/values.yaml`:

```yaml
galley:
  config:
    postgresMigration:
      conversation: migration-to-postgresql
background-worker:
  config:
    migrateConversations: false
    postgresMigration:
      conversation: migration-to-postgresql
```

Run the helm upgrade. Once it's set to `migration-to-postgresql`, do not switch back to `cassandra`. New conversations from this point on are written to PostgreSQL, reads still come from Cassandra.

### Step 2: run the actual migration

In `values/wire-server/values.yaml`:

```yaml
background-worker:
  config:
    migrateConversations: true
    postgresMigration:
      conversation: migration-to-postgresql
```

Run the helm upgrade. The `background-worker` pods restart and start moving data. This can take a long time on a database with a lot of conversations.

Watch the logs (look for `finished migration`):

```bash
d kubectl logs deployment/background-worker --tail=2000 | grep migrate-conversations
```

Or watch the metrics, both of these should hit `1.0`:

* `wire_local_convs_migration_finished`
* `wire_user_remote_convs_migration_finished`

### Step 3: switch reads over to PostgreSQL

Once the metrics are at `1.0`, in `values/wire-server/values.yaml`:

```yaml
galley:
  config:
    postgresMigration:
      conversation: postgresql
background-worker:
  config:
    migrateConversations: false
    postgresMigration:
      conversation: postgresql
```

Run the helm upgrade. From now on reads and writes both go to PostgreSQL. This configuration must be kept on every subsequent upgrade.

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
