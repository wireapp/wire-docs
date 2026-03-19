# Migrate Galley Data from Cassandra to PostgreSQL

Use this procedure to migrate Galley-managed data from Cassandra to PostgreSQL. This migration is only required if you need channel search and channel management from Team Settings on releases that support PostgreSQL-backed conversation data.

The PostgreSQL tables used by these migrations, including `collaborators`, `schema_migrations`, `user_group`, and `user_group_member`, are defined in `postgres-schema.sql` and created during installation. They are empty by default until the matching migration is enabled and backfilled.

## Feature Availability

| Feature | Available from |
| --- | --- |
| `conversation` migration | `5.24.0` |
| `conversationCodes` migration | `5.26.0` |
| `teamFeatures` migration | `5.27.0` |


This guide covers these data domains:

- Conversations
- Conversation codes
- Team features

After the migration is complete, PostgreSQL becomes the authoritative store for the migrated domains.

## Before You Start

Make sure all of the following are true before changing any migration settings:

- You are running a `wire-server` release that supports the domain you want to migrate. See [Feature Availability](#feature-availability).
- PostgreSQL is deployed and reachable from the cluster. If you still need to set it up on your on-prem environment with our custom postgresql cluster, see [PostgreSQL High Availability Cluster - Quick Setup](postgresql-cluster.md).
- `galley` and `background-worker` both have PostgreSQL host, database, user, and password configured.
- The `cassandra-migrations` job for your Wire upgrade has already completed successfully.
- You have enough PostgreSQL connections available for the temporary migration workload.

The `cassandra-migrations` job only prepares schema and metadata. It does not copy conversation data from Cassandra into PostgreSQL. The data copy is performed by `background-worker`.

## PostgreSQL Connection Budget

`postgresqlPool.size` is a per-pod setting. To estimate how many PostgreSQL connections Wire can open, multiply each service pool size by the number of replicas for that service, then sum the results. In a standard Wire deployment sharing the same PostgreSQL primary, this means at least `brig`, `galley`, and `background-worker`.

Use this formula:

```text
total_postgresql_connections =
  (brig_pool_size * brig_replicas) +
  (galley_pool_size * galley_replicas) +
  (background_worker_pool_size * background_worker_replicas)
```

This number is the minimum application-side connection budget you should plan for on the PostgreSQL primary when Wire connects through the read-write service.

### Default starting point

The default pool size of `100` for `brig` and `galley` is intentionally generous. It gives flexibility and is a safe starting point when traffic is unknown or when you want to avoid early pool pressure.

Default calculation:

```text
brig:              100 * 3 = 300
galley:            100 * 3 = 300
background-worker:   5 * 3 = 15
total:                         615
```

If you use this layout, set `max_connections` above `605` and keep additional headroom for:

- PostgreSQL administrative sessions
- Monitoring and maintenance jobs
- Temporary migration increases
- Future replica scaling on the Wire side

### Low-traffic starting point

For staging, medium-sized, or other low-traffic environments, the default of `100` for `brig` and `galley` is often more than needed. A common reduced-pool starting point is:

```text
brig:               10 * 3 = 30
galley:             10 * 3 = 30
background-worker:   5 * 1 =  5
total:                          65
```

With this reduced layout, `max_connections = 100` is often a reasonable starting point because it leaves headroom above the 65 application-side connections. On self-managed PostgreSQL, set this in the PostgreSQL server configuration. In the provided Wire Ansible deployment, that means the `postgresql.conf` template.

### Tune from observed traffic

Do not stop at the default or reduced example. Watch the actual pool usage for at least 24 hours, then adjust both `postgresqlPool.size` and PostgreSQL `max_connections` from the observed traffic pattern.

Useful metrics for sizing:

- `wire_hasql_pool_session_count`: shows how many sessions are open over time
- `wire_hasql_pool_in_use`: shows how many connections are actively checked out
- `wire_hasql_pool_ready_for_use`: shows whether idle connections are available
- `wire_hasql_pool_session_failure_count`: should stay at `0`; increases indicate pool pressure or connectivity issues
- `rate(wire_hasql_pool_connection_established_count[5m])`: shows connection churn and can reveal undersized or unstable pools

Signs that the reduced sizing is sufficient:

- `wire_hasql_pool_session_count` stays well below the configured pool size for each pod
- `wire_hasql_pool_in_use` stays low and `wire_hasql_pool_ready_for_use` stays available
- `wire_hasql_pool_session_failure_count` remains `0`
- There are no acquisition timeout errors in service logs

Signs that you should increase the pool size and recalculate `max_connections`:

- `wire_hasql_pool_session_count` regularly approaches the configured pool size
- `wire_hasql_pool_in_use` remains high or `wire_hasql_pool_ready_for_use` frequently drops to `0`
- `wire_hasql_pool_session_failure_count` increases
- You see acquisition timeout errors or sustained connection churn

After changing a service pool size, recalculate the total connection budget and raise PostgreSQL `max_connections` accordingly.

For managed PostgreSQL and on-prem installations, always set `max_connections` above the total calculated for the pool sizes you actually chose.

## Migration States

Each domain is controlled with `postgresMigration.<domain>` and can be in one of these states:

- `cassandra`: reads and writes stay on Cassandra
- `migration-to-postgresql`: new writes go to both Cassandra and PostgreSQL
- `postgresql`: reads and writes use PostgreSQL only

For each domain, the migration always follows the same sequence:

1. Enable dual-write by setting `postgresMigration.<domain>: migration-to-postgresql`.
2. Start the backfill by setting the matching `migrate*` flag on `background-worker`.
3. Cut over by setting `postgresMigration.<domain>: postgresql` and turning the `migrate*` flag off again.

Once a domain is moved to `migration-to-postgresql`, do not set it back to `cassandra`.

## Important Rules

### Keep `galley` and `background-worker` aligned

`background-worker.config.postgresMigration.<domain>` must always match `galley.config.postgresMigration.<domain>`.

### Plan extra PostgreSQL capacity for the migration window

The steady-state pool size is often too small for the backfill step. If you see connection acquisition timeouts during migration, increase `background-worker.config.postgresqlPool.size` and `acquisitionTimeout` before retrying.

### Migrate one domain at a time

Do not migrate conversations, conversation codes, and team features in the same deployment. Finish one domain completely before starting the next one.

## Base Configuration

Start from a safe baseline where PostgreSQL is configured but Cassandra is still authoritative.

```yaml
galley:
  config:
    postgresql:
      host: postgresql-external-rw
      port: "5432"
      user: wire-server
      dbname: wire-server
    postgresMigration:
      conversation: cassandra
      conversationCodes: cassandra
      teamFeatures: cassandra

background-worker:
  config:
    postgresql:
      host: postgresql-external-rw
      port: "5432"
      user: wire-server
      dbname: wire-server
    postgresqlPool:
      size: 5
      acquisitionTimeout: 10s
      agingTimeout: 1d
      idlenessTimeout: 10m
    postgresMigration:
      conversation: cassandra
      conversationCodes: cassandra
      teamFeatures: cassandra
    migrateConversations: false
    migrateConversationCodes: false
    migrateTeamFeatures: false
```

Deploy this first and verify both services are healthy.

## Migration Procedure

Apply the following procedure to one domain at a time.

### Step 1: Enable dual-write

Set the selected domain to `migration-to-postgresql` in both `galley` and `background-worker`.

Example for conversations:

```yaml
galley:
  config:
    postgresMigration:
      conversation: migration-to-postgresql
      conversationCodes: cassandra
      teamFeatures: cassandra

background-worker:
  config:
    postgresMigration:
      conversation: migration-to-postgresql
      conversationCodes: cassandra
      teamFeatures: cassandra
    migrateConversations: false
```

After the rollout:

- `galley` should restart cleanly.
- New writes for that domain should be written to both Cassandra and PostgreSQL.
- No backfill should run yet.

### Step 2: Start the backfill

Enable the matching migration flag on `background-worker`.

Flags by domain:

- Conversations: `migrateConversations: true`
- Conversation codes: `migrateConversationCodes: true`
- Team features: `migrateTeamFeatures: true`

Example for conversations:

```yaml
background-worker:
  config:
    migrateConversations: true
    postgresqlPool:
      size: 10
      acquisitionTimeout: 30s
    migrateConversationsOptions:
      pageSize: 10000
      parallelism: 2
```

`migrateConversationsOptions` is only used for conversation migration. Conversation codes and team features do not use this block.

### Step 3: Monitor the migration

Use logs and Prometheus metrics to confirm progress.

Check `background-worker` logs:

```bash
kubectl logs -f deploy/background-worker -n default
```

Useful log patterns:

- `finished migration`
- `error occurred`
- `estimatedRows`

Useful Prometheus metrics:

| Metric | Meaning |
| --- | --- |
| `wire_local_convs_migration_finished` | Local conversation migration is complete when the value is `1` |
| `wire_user_remote_convs_migration_finished` | Remote conversation index migration is complete when the value is `1` |
| `wire_team_features_migration_finished` | Team features migration is complete when the value is `1` |
| `wire_hasql_pool_ready_for_use` | PostgreSQL pool is healthy when each pod reports ready connections |
| `wire_hasql_pool_session_failure_count` | Should remain `0` |

There is no dedicated Prometheus completion metric for conversation codes. Validate that migration through logs.

### Step 4: Cut over to PostgreSQL

When the migration has finished, set the selected domain to `postgresql` in both services and disable the matching migration flag.

Example for conversations:

```yaml
galley:
  config:
    postgresMigration:
      conversation: postgresql
      conversationCodes: cassandra
      teamFeatures: cassandra

background-worker:
  config:
    postgresMigration:
      conversation: postgresql
      conversationCodes: cassandra
      teamFeatures: cassandra
    migrateConversations: false
    postgresqlPool:
      size: 5
      acquisitionTimeout: 10s
```

After this rollout, the selected domain reads from PostgreSQL only.

## Recommended Domain Order

Migrate domains in this order:

1. Conversations
2. Conversation codes
3. Team features

This keeps the largest and most operationally sensitive migration first, when your rollback options are still best for the remaining domains.

## Final Configuration

When all domains have been migrated, both services should point all supported Galley data to PostgreSQL.

```yaml
galley:
  config:
    postgresql:
      host: postgresql-external-rw
      port: "5432"
      user: wire-server
      dbname: wire-server
    postgresMigration:
      conversation: postgresql
      conversationCodes: postgresql
      teamFeatures: postgresql

background-worker:
  config:
    postgresql:
      host: postgresql-external-rw
      port: "5432"
      user: wire-server
      dbname: wire-server
    postgresqlPool:
      size: 5
      acquisitionTimeout: 10s
      agingTimeout: 1d
      idlenessTimeout: 10m
    postgresMigration:
      conversation: postgresql
      conversationCodes: postgresql
      teamFeatures: postgresql
    migrateConversations: false
    migrateConversationCodes: false
    migrateTeamFeatures: false
```

## Post-Migration Checks

After the last cutover:

- Confirm `galley` and `background-worker` pods are healthy.
- Confirm `wire_hasql_pool_session_failure_count` stays at `0`.
- Confirm channel search and Team Settings channel management work as expected.
- Confirm no migration flags remain set to `true`.

## Troubleshooting

### Migration does not start

Check the migration flag names carefully. For example, `migrateConversations` is correct, while `migrateConversation` is ignored.

### Pods fail to start with a storage-location parse error

This usually means a `postgresMigration` value was written as a boolean instead of a string. Use only:

- `cassandra`
- `migration-to-postgresql`
- `postgresql`

### PostgreSQL acquisition timeouts appear during migration

Increase `background-worker.config.postgresqlPool.size` and `acquisitionTimeout`, then redeploy `background-worker`.

### No PostgreSQL pool metrics appear for `background-worker`

`background-worker` may not emit `wire_hasql_pool_*` metrics until it has attempted to use PostgreSQL. This is expected before the migration flag is enabled.
