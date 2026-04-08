# PostgreSQL

This section covers PostgreSQL administration for Wire deployments.

## Setup

- [PostgreSQL High Availability Cluster - Quick Setup](postgresql-cluster.md) — deploy and manage a three-node on-prem HA cluster with automatic failover.

## Migration

- [Migrate Galley Data from Cassandra to PostgreSQL](migrate-to-postgresql.md) — migrate conversation, conversation codes, and team features data from Cassandra to PostgreSQL.

## PostgreSQL Connection Budget

`postgresqlPool.size` is a per-pod setting. To estimate how many PostgreSQL connections Wire can open, multiply each service pool size by the number of replicas for that service, then sum the results. In a standard Wire deployment sharing the same PostgreSQL primary, this means at least `brig`, `galley`, and `background-worker`.

Calculate the total like this:

```text
total_postgresql_connections =
  (brig_pool_size * brig_replicas) +
  (galley_pool_size * galley_replicas) +
  (background_worker_pool_size * background_worker_replicas)
```

This value is the minimum application-side connection budget to plan for on the PostgreSQL primary when Wire connects through the read-write service.

### Default starting point

The default pool size of `100` for `brig` and `galley` is intentionally generous. It gives flexibility and is a safe starting point when traffic is unknown or when you want to avoid early pool pressure.

Default calculation:

```text
brig:              100 * 3 = 300
galley:            100 * 3 = 300
background-worker:   5 * 3 = 15
total:                         615
```

If you use this layout, set `max_connections` above `615` and keep additional headroom for:

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
