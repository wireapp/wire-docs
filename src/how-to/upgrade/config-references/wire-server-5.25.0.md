# Wire-Server `5.25.0` release

Reference based on these [`build.json` charts](https://raw.githubusercontent.com/wireapp/wire-builds/5a74084feeb1138925dcb671b333da0c76f88f08/build.json), and the [release changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-01-13).

Artifact:
[`wire-server-deploy-static-1ca0f1beecb9022e9c7cde2d3ab02fc7e90695e0.tgz`](https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-1ca0f1beecb9022e9c7cde2d3ab02fc7e90695e0.tgz)

## Heads up

Coming from `5.24.0`. If the deploy is still at `5.24` and the conversation data migration to PostgreSQL described on the `5.24` page hasn't been done yet, do that first. There's a chart-default bug at `5.25` that silently breaks anything that hasn't migrated, so it really matters.

## Notes from the previous release

The `brig` non-federated bug from `5.24` is fixed at `5.25`. If `enableFederation: true` was set in `values/wire-server/values.yaml` as a workaround, it can be removed (so it falls back to the default of `false`).

## What must change

### 1. Set `background-worker.config.postgresMigration.conversation` explicitly

The `5.25` `background-worker` chart ships with `postgresMigration.conversation` defaulting to `postgresql`. That's wrong for any deploy that hasn't migrated conversations to PostgreSQL yet, the data is still in Cassandra and the worker would be reading from an empty postgres table. This is the bug that may have caused conversations to disappear in real upgrades.

It has to be set explicitly. Either of these, depending on the actual state of the deploy:

If conversation data hasn't been migrated to PostgreSQL yet (most installs coming from `5.23`):

```yaml
background-worker:
  config:
    postgresMigration:
      conversation: cassandra
```

If the migration was already done (per the `5.24` page):

```yaml
background-worker:
  config:
    postgresMigration:
      conversation: postgresql
```

Set this before running the wire-server helm upgrade. The default is corrected back to `cassandra` at `5.26`.

### 2. Make sure `mlsPrivateKeys` is configured (even if MLS is off)

Webapp builds from after November 2025 need `mlsPrivateKeys` set on the backend, even when MLS is disabled and the deploy is Proteus-only. Without the keys, the endpoint `v13/mls/public-keys` returns `400`, and the webapp throws `MLSService is required to construct ConversationService with MLS capabilities`.

Check `values/wire-server/secrets.yaml` has something like:

```yaml
galley:
  secrets:
    mlsPrivateKeys:
      removal:
        ed25519: |
          -----BEGIN PRIVATE KEY-----
          ...
          -----END PRIVATE KEY-----
```

If it's missing, generate the keys with `bin/offline-secrets.sh`. Environments that were originally deployed from older `wire-server-deploy` versions may not have run that script and won't have the keys.

### 3. If `galley.settings.featureFlags.cells` is overridden, add the new fields

The `cells` feature flag schema gained new required fields at this release: `channels`, `groups`, `one2one`, `users`, `collabora`, `publicLinks`, `storage`, `metadata`. Any local override of `cells` in the `values.yaml` has to add them.

If `cells` isn't overridden and the chart default is in use, no action needed.

### 4. Run the wire-server helm upgrade

Once values and secrets are updated:

```bash
d helm upgrade --install wire-server ./charts/wire-server --timeout=15m0s \
  --values ./values/wire-server/values.yaml \
  --values ./values/wire-server/secrets.yaml
```

## Optional changes

### `nginx-ingress-services` private key rotation policy

`cert-manager` certificate private key rotation policy is now configurable, both for the ingress and the federator. Useful when client key pinning is in use and keys need to survive renewals.

```yaml
nginx-ingress-services:
  federator:
    tls:
      privateKey:
        rotationPolicy: Always
  tls:
    privateKey:
      rotationPolicy: Always
```

* `Always` (default): regenerate the key on each renewal.
* `Never`: keep the same key across renewals (for key pinning).

Edit `values/nginx-ingress-services/values.yaml` during the nginx ingress upgrade step. Only relevant for `cert-manager`-based deploys with a key pinning requirement.

### `background-worker` migration tunables

When the conversation migration is being run at `5.25` rather than at `5.24` (please don't, but if it has to happen), page size and parralelism can now be tuned:

```yaml
background-worker:
  config:
    migrateConversationsOptions:
      pageSize: 10000
      parallelism: 2
```

### New migration failure metrics

Two metrics for tracking migration failures:

* `wire_local_convs_migration_failed`
* `wire_user_remote_convs_migration_failed`

If either of these hits `1`, the migration has failed. The actual error will be in the `background-worker` logs. To retry, restart the `background-worker` pods.

These go alongside the already-existing `wire_local_convs_migration_finished` and `wire_user_remote_convs_migration_finished` ones.

## Disk space note

Each upgrade in this series re-runs `setup-offline-sources`, which copies the new release's binaries, container images, and debs into `/opt/assets` on the assethost. After a few versions, the assethost runs out of space and the playbook fails with `no space left on device`.

When that happens, SSH into the **assethost** (not the adminhost) and clear it:

```bash
sudo rm -rvf /opt/assets
```

Then re-run `setup-offline-sources` from the adminhost.
