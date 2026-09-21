# Wire-Server `5.35.0` release

For details, see the [release changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-08-27) on the wire-server repo.

Artifact:
[`wire-server-deploy-static-9d7e52462edaaf8267cf8a34647dac18df3712c3.tgz`](https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-9d7e52462edaaf8267cf8a34647dac18df3712c3.tgz)

Build manifest: [build.json](https://raw.githubusercontent.com/wireapp/wire-builds/refs/heads/pinned-offline-5.35.0-teams-4.24.1/build.json)

## Head-ups

Coming from `5.34.0`.

This release adds more background-worker jobs and new default `jobs.*` settings. Review PostgreSQL pool sizing and `max_connections` for the added worker load.

The PostgreSQL connection pool implementation was changed to `hasql-resource-pool`. The `agingTimeout` setting is now ignored and should be considered deprecated.

```yaml
postgresqlPool:
  size: 100
  acquisitionTimeout: 10s
  agingTimeout: 1d # deprecated
  idlenessTimeout: 10m
```

The `backgroundEffects` team feature flag is deprecated. Its default is now enabled and locked, and the Helm override for it has been removed from the chart.

A few deprecated feature flags and meeting-related config changes; review them if you rely on legacy meeting behavior or meeting email invites.

## Must change

No mandatory migration or Helm value change is required for a standard upgrade.

If you override the `reaper` image in your values, update it: the default changed from `docker.io/bitnamilegacy/kubectl:1.32.4` to `docker.io/alpine/kubectl:1.36.3`. The image must include a POSIX shell at `/bin/sh`