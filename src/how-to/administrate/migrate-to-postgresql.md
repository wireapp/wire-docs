# Migrate Galley Data from Cassandra to PostgreSQL

Use this procedure to migrate Galley-managed data from Cassandra to PostgreSQL. This migration is only required if you need channel search and channel management from Team Settings on releases that support PostgreSQL-backed conversation data.

The PostgreSQL tables used by these migrations, including `collaborators`, `schema_migrations`, `user_group`, and `user_group_member`, are defined in `postgres-schema.sql` and created during installation. They are empty by default until the matching migration is enabled and backfilled.

## Feature Availability

| Feature | Available from |
| --- | --- |
| `conversation` migration | `5.24.0` |
| `conversationCodes` migration | `5.26.0` |
| `teamFeatures` migration | `5.27.0` |


This guide covers these data categories:

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

Before starting the migration, make sure you have enough connections available. The budget planning itself belongs in the dedicated guide, so keep this step as a pointer to the canonical reference.

See [PostgreSQL Connection Budget](postgresql.md#postgresql-connection-budget) for how to calculate your connection budget, default and low-traffic starting points, and how to tune from observed traffic.

## Recommended Domain Order

Migrate domains in this order:

1. Conversations
2. Conversation codes
3. Team features

This keeps the largest and most operationally sensitive migration first, when your rollback options are still best for the remaining domains.

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
    postgresqlPool:
      size: 10
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

Backfill means copying the existing data for the domain from Cassandra into PostgreSQL while dual-write mode is already enabled.

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

- If you do not have Prometheus set up yet, use `kubectl logs` and/or directly check `background-worker` database queries in Postgres with `pg_stat_activity` and relevant counter tables to confirm migration progress.

  - Example from a background-worker pod (direct wire-server DB query, as in wire-utility-tool):

    ```bash
    kubectl exec -n <namespace> deploy/background-worker -- psql "postgresql://wire-server:password@postgresql-external-rw:5432/wire-server" -c "SELECT pid, usename, state, query_start, query FROM pg_stat_activity WHERE datname='wire-server' ORDER BY query_start DESC;"
    ```

  - If you have the `wire-utility-tool` helper script on your admin host, use:

    ```bash
    psql -c "SELECT pid, usename, query_start, query FROM pg_stat_activity WHERE state != 'idle';"
    ```

  - For more PostgreSQL troubleshooting and `pg_stat_activity` examples, see [Wire utility tool – PostgreSQL inspection](wire-utility-tool.md#postgresql-query-debugging).

  - You can also collect one-shot Prometheus / metrics scraping from individual services using `/i/metrics` (documented in [administrate/users.md](users.md#how-to-retrieve-metric-values-manually)).

    Example for service pod port-forwarding:

    ```bash
    kubectl --kubeconfig <path> -n wire port-forward service/galley 7777:8080
    curl -s http://127.0.0.1:7777/i/metrics | grep wire_hasql_pool_session_failure_count
    ```

  - Interpreting `pg_stat_activity` for this migration path:

    - `datname='wire-server'` and `usename='wire-server'` are normal.
    - `application_name` should be `background-worker` or `galley` for migration progress; if it is empty and `query` is app-domain SQL (e.g., `SELECT ... FROM apps WHERE ...`), that is normal application traffic.
    - `state='active'` with long `now()-query_start` means a query currently running; `state='idle'` means waiting on the client.
    - `wait_event_type` / `wait_event` show lock wait if non-empty.
    - `query` text like `SELECT * FROM pg_stat_activity ...` is your own monitoring query; ignore it for migration status.

  - Example migration-focused query:

    ```sql
    SELECT pid, usename, application_name, state, now() - query_start AS duration, query
    FROM pg_stat_activity
    WHERE datname='wire-server'
      AND application_name IN ('background-worker', 'galley')
    ORDER BY query_start DESC
    LIMIT 20;
    ```

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
