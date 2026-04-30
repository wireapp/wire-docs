# Wire-Server `5.30.0` release

For details, see the [release changelog](https://github.com/wireapp/wire-server/releases) on the wire-server repo.

Artifact:
[`wire-server-deploy-static-1349f499ee83c3c2a940dd017f71aeb184e3090c.tgz`](https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-1349f499ee83c3c2a940dd017f71aeb184e3090c.tgz)

## Heads up

Coming from `5.29.0`. In practice most deploys will be coming from `5.28` because `5.29` is broken and gets skipped (see the `5.29` page). The changes below cover both paths.

For deploys that skipped `5.29`, the `5.29` changes are still in effect at `5.30`, so the `5.29` page is worth a look too. The most important one to know about: at `5.29` `tags.proxy` was marked obsolete and a bunch of services were moved into the umbrella chart. The `tags.proxy` part has been undone for this release, see below.

No known bugs at this release.

## What must change

### 1. Set `tags.proxy` explicitly

At `5.29` `tags.proxy` was marked obsolete because `proxy` got moved into the umbrella chart. At `5.30` it's required again. So for deploys that removed it as part of the `5.29` upgrade, or that never had it (because they came straight from `5.28`), it has to go back into `values/wire-server/values.yaml` before this upgrade:

```yaml
tags:
  proxy: true   # deploy the proxy chart
```

Or to keep proxy off:

```yaml
tags:
  proxy: false  # don't deploy the proxy chart
```

### 2. Migrate off Restund (if not already done)

The `restund` helm chart and the underlying code stopped being shipped. Deploys still on Restund have to migrate to `coturn` before this upgrade. Coturn keeps being supported.

This is a planning step, not a values edit.

### 3. Run the wire-server helm upgrade

```bash
d helm upgrade --install wire-server ./charts/wire-server --timeout=15m0s \
  --values ./values/wire-server/values.yaml \
  --values ./values/wire-server/secrets.yaml
```

## Recommended cleanup (not strictly required)

`background-worker` now reuses `galley`'s configmap and secrets for the Cassandra, PostgreSQL, and federation domain settings. So a few `background-worker` overrides in the values files are now duplicated. Removing them is not required, but it's cleaner, and it keeps the two services aligned going forward.

The duplicates to drop:

* `background-worker.config.cassandraGalley`
* `background-worker.config.postgresql`
* `background-worker.config.federationDomain`
* `background-worker.secrets.pgPassword` (this one's in `secrets.yaml`)

## Disk space note

Each upgrade in this series re-runs `setup-offline-sources`, which copies the new release's binaries, container images, and debs into `/opt/assets` on the assethost. After a few versions, the assethost runs out of space and the playbook fails with `no space left on device`.

When that happens, SSH into the **assethost** (not the adminhost) and clear it:

```bash
sudo rm -rvf /opt/assets
```

Then re-run `setup-offline-sources` from the adminhost.
