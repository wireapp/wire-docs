# Using PostgreSQL as default database instead of Cassandra

Wire is switching away from Cassandra as the underlying database in favour of PostgreSQL. This process is currently in progress and is being done in smaller logical segments. This page will be updated when a new segment is available in PostgreSQL.

The shown settings can only be applied in a fresh installation! If you are already running a `wire-server` instance that has used Cassandra, please refer to the PostgreSQL migration guide [here](migrate-to-postgresql.md).

## Feature Availability

| Feature                        | Available from |
|--------------------------------|----------------|
| `conversation`                 | `5.24.0`       |
| `conversationCodes`            | `5.26.0`       |
| `teamFeatures`                 | `5.27.0`       |
| `domainRegistration`           | `5.32.0`       |
| `users` (experimental)         | `5.33.0`       |

## Configuration

Since the release of 5.32.0 we now have a single source of truth which database should be used in `galley`. For older releases the following configuration should be applied to both `galley` and `background-worker` with the same keys and values. Refer to [Feature Availability](#feature-availability) above which can you use, based on your deployment version.

```
galley:
  config:
    postgresMigration:
      conversation: postgresql
      conversationCodes: postgresql
      teamFeatures: postgresql
      domainRegistration: postgresql
      #user: postgresql # experimental, don't use in prod yet

# for older than 5.32 deployments, this is also required
#   |
#   V
background-worker:
  config:
    postgresMigration:
      conversation: postgresql
      conversationCodes: postgresql
      teamFeatures: postgresql
      # other features are not listed as they are in older than 5.32.0 releases
```