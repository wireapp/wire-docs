# Wire-Server `5.32.0` release

For details, see the [release changelog](https://github.com/wireapp/wire-server/releases) on the wire-server repo.

Artifact:
[`wire-server-deploy-static-682349dc9df15ca1db6dd1e93d3c4a02d9152502.tgz`](https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-682349dc9df15ca1db6dd1e93d3c4a02d9152502.tgz)

## Heads up

Coming from `5.30.0`. In practice most deploys will be coming from `5.30` because `5.31` is broken and gets skipped. The changes below cover both paths.

No known bugs at this release.

## What must change

No changes are required for this release.

## Recommended cleanup (not strictly required)

postgresMigration now has a single source of truth in the Galley chart values. Galley, Brig, and background-worker all read their PostgreSQL migration settings from there.

The duplicates to drop:

* `background-worker.config.postgresMigration`
* `brig.config.postgresMigration`

## For users of the full wire-server-deploy-static deployment package

1NOTE: Each upgrade in this series re-runs `setup-offline-sources`, which copies the new release's binaries, container images, and debs into `/opt/assets` on the assethost. After a few versions, the assethost runs out of space and the playbook fails with `no space left on device`.

When that happens, SSH into the **assethost** (not the adminhost) and clear it:

```bash
sudo rm -rvf /opt/assets
```

Then re-run `setup-offline-sources` from the adminhost.
