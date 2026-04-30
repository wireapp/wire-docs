# Wire-Server `5.27.0` release

Reference based on these [`build.json` charts](https://raw.githubusercontent.com/wireapp/wire-builds/d8bdda07fd4c32937a5482711b6e322a32d0c784/build.json), and the [release changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-02-04).

Artifact:
[`wire-server-deploy-static-4b7ec1724ffa60fd86c5ffa697f7b41347f64267.tgz`](https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-4b7ec1724ffa60fd86c5ffa697f7b41347f64267.tgz)

## Heads up

Coming from `5.26.0`, or from `5.25.0` for deploys that skipped `5.26` because of the federation issues. Either is fine, there are no breaking changes between `5.25` and `5.27`.

No mandatory changes at this release. No known bugs.

## Things to know

`webapp`, `team-settings`, and `account-pages` are now their own standalone helm charts. They used to be subcharts of `wire-server`, they aren't anymore. So:

* They have their own values directories: `values/webapp/`, `values/team-settings/`, `values/account-pages/`.
* They get their own `helm upgrade --install` invocations, after the `wire-server` upgrade.
* For anyone used to looking for their config under `values/wire-server/values.yaml`, it's not there anymore.

## Post-upgrade: migrate team features to PostgreSQL (optional)

> **Back up before starting.** Take a backup of the Cassandra `galley` keyspace and of the target PostgreSQL database before running any of the steps below. The migration writes to PostgreSQL from step 1 onwards, and rolling back without a backup is not straightforward.

Same shape as the conversation data and conversation codes migrations. Only do this when conversation data and conversation codes have already been migrated, otherwise skip it.

Step 1, in `values/wire-server/values.yaml`:

```yaml
galley:
  config:
    postgresMigration:
      teamFeatures: migration-to-postgresql
background-worker:
  config:
    postgresMigration:
      teamFeatures: migration-to-postgresql
    migrateTeamFeatures: false
```

Run the helm upgrade.

Step 2, set `migrateTeamFeatures: true` on `background-worker` and run the helm upgrade again. Wait for `wire_team_features_migration_finished` to hit `1.0`.

Step 3, switch reads to PostgreSQL:

```yaml
galley:
  config:
    postgresMigration:
      teamFeatures: postgresql
background-worker:
  config:
    postgresMigration:
      teamFeatures: postgresql
    migrateTeamFeatures: false
```

Run the helm upgrade so `galley` and `background-worker` restart and start reading from PostgreSQL.

Step 4 (optional, only once everything is validated): the Cassandra `team_features_dyn` table can be dropped.

## Disk space note

Each upgrade in this series re-runs `setup-offline-sources`, which copies the new release's binaries, container images, and debs into `/opt/assets` on the assethost. After a few versions, the assethost runs out of space and the playbook fails with `no space left on device`.

When that happens, SSH into the **assethost** (not the adminhost) and clear it:

```bash
sudo rm -rvf /opt/assets
```

Then re-run `setup-offline-sources` from the adminhost.
