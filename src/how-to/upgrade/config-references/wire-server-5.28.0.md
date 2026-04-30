# Wire-Server `5.28.0` release

Reference based on these [`build.json` charts](https://raw.githubusercontent.com/wireapp/wire-builds/93632dd82237c122c93e0e37e02e5f2a1ba84746/build.json), and the [release changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-03-03).

Artifact:
[`wire-server-deploy-static-e16cdbfe2b3b42607bb8cddebad1c23c5e16e343.tgz`](https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-e16cdbfe2b3b42607bb8cddebad1c23c5e16e343.tgz)

## Heads up

Coming from `5.27.0`. No known bugs at this release.

## What must change

### 1. Update image overrides for `demo-smtp`, `fake-aws-ses`, `fake-aws-sns`, `legalhold`

These charts switched from a single `image` string to split `repository` + `tag` fields. The new format:

```yaml
affected-chart:
  image:
    repository: quay.io/wire/...
    tag: some-tag
```

Only matters for deploys that actually override images for any of these charts. Deploys using the bundled `prod-values.example.yaml` defaults aren't affected. `legalhold` in particular is optional and isn't even installed in standard `wire-server-deploy` setups, so most installs will never see it.

Edit the values for whichever of these charts is overridden, before running the corresponding helm upgrade.

### 2. Remove and re-create existing apps

Cassandra (in `brig.user`) now tracks user types per-user, but only for **newly created** users. For existing users and bots, the type is inferred. That works fine for users and bots, but it can't reliably distinguish apps from regular users. So any app created before `5.28` will show up as a regular user in API responses and search results.

To get correct app information, the affected apps must be removed from their team and re-created after the upgrade. Only relevant for deploys that created apps before their official support.

### 3. Run the wire-server helm upgrade

```bash
d helm upgrade --install wire-server ./charts/wire-server --timeout=15m0s \
  --values ./values/wire-server/values.yaml \
  --values ./values/wire-server/secrets.yaml
```

## Recommendations

### Upgrade Cassandra to `4.1.x` when convenient

From this release on, wire-server is only tested against Cassandra `4.1.x`. The codebase still works on `3.11`, `4.0`, and `4.1`, but only `4.1` and newer get testing going forward. So a Cassandra upgrade should be planned at some point, no rush.

## Disk space note

Each upgrade in this series re-runs `setup-offline-sources`, which copies the new release's binaries, container images, and debs into `/opt/assets` on the assethost. After a few versions, the assethost runs out of space and the playbook fails with `no space left on device`.

When that happens, SSH into the **assethost** (not the adminhost) and clear it:

```bash
sudo rm -rvf /opt/assets
```

Then re-run `setup-offline-sources` from the adminhost.
