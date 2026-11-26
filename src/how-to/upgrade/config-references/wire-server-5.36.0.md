# Wire-Server `5.36.0` release

For details, see the [release changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-09-18) on the wire-server repo.

Build manifest: [build.json](https://raw.githubusercontent.com/wireapp/wire-builds/acc9e3f5/build.json)

## Heads up

Coming from `5.35.0`.

No known bugs at this release.

This release finalizes API version `v18`. The new development version is `v19`.

## What must change

No mandatory Helm value change is required for a standard upgrade.

The release adds one Cassandra schema migration for `brig` (version `94`). It reduces `gc_grace_seconds` on some user tables. The `cassandra-migrations` job applies it during the `wire-server` upgrade. Make sure that the job completes before you continue.

The release adds one PostgreSQL migration (`20260625104559-add-user-migration-pending-deletes`). The services apply it at startup.

## Changed defaults

- The `preventAdminlessGroups` team feature is now `unlocked` by default. Its status stays `disabled`. If you want to keep team admins from turning it on, set `lockStatus: locked` in your overrides:

  ```yaml
  galley:
    config:
      settings:
        featureFlags:
          preventAdminlessGroups:
            defaults:
              status: disabled
              lockStatus: locked
  ```

- Wire Drive: the default storage limit (`galley.config.settings.featureFlags.cellsInternal.defaults.config.storage.totalLimitBytes`) changed from 1 TB (`"1000000000000"`) to unlimited (`"-1"`). Set an explicit value if you need a limit.

## Configuration changes

- A PostgreSQL connection string with a different number of hosts and ports now stops the service at startup with a clear error. Before, the service started with a wrong connection. Examine your `postgresql` settings before the upgrade.
- `gundeck` accepts optional `postgresql`, `postgresqlPool` and `secrets.pgPassword` settings. `gundeck` does not use PostgreSQL yet in this release. You do not have to set these values.
- `nginx-ingress-services`: if `accountPages.enabled` is `true`, `config.dns.accountPages` is now mandatory. The chart does not render without it.

## Optional: migrate user data to PostgreSQL

This release adds the migration of user data from Cassandra to PostgreSQL. The migration is disabled by default. You do not have to run it as part of the upgrade. You can start it at any later time, at your own discretion, on `5.36.0` or any later release. It uses the same three-step procedure as the other stores. See [Migration for existing installations](../../../developer/reference/config-options.md#migration-for-existing-installations) in the configuration options reference.

| Setting | `background-worker` flag | Metric when complete |
|---|---|---|
| `galley.config.postgresMigration.user` | `background-worker.config.migrateUsers` | `wire_user_migration_finished` = `1.0` |

!!! warning
    The user migration skips invalid users. An invalid user has no `name` or no `activated` value.
    For each skipped user, background-worker writes `Invalid user found, skipping` to its log,
    together with `UserHasNoName` or `UserHasNoActivated`.

    If you switch reads to PostgreSQL (`postgresMigration.user: postgresql`) and do not act on
    these log lines, these users stop existing in the system.

    To keep these users:

    1. Let the migration of the valid users complete.
    2. Collect all `Invalid user found, skipping` log lines from background-worker.
    3. In Cassandra, set a value for `name` and/or `activated` for each user that you want to keep.
    4. Run the migration again.
    5. Switch reads to PostgreSQL only after the log shows no more skipped users that you want to keep.

!!! note
    In `5.36.0`, the user migration can fail on users with invalid assets. `5.37.0` fixes this:
    the migration ignores invalid assets. We recommend that you start the user migration only
    after you upgrade to `5.37.0` or later.

## Federation

- A new opt-in policy can drop queued federation notifications when the remote backend supports no compatible API version.
- `preventAdminlessGroups` system notifications are now federated.
