# Wire-Server `5.33.0` release

For details, see the [release changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-06-12) on the wire-server repo.

Artifact:
[`wire-server-deploy-static-4a7c9ee5d6f0cd7bf5ef76b72324b61028176f52.tgz`](https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-4a7c9ee5d6f0cd7bf5ef76b72324b61028176f52.tgz)

Build manifest: [build.json](https://raw.githubusercontent.com/wireapp/wire-builds/refs/heads/pinned-offline-5.33.0/build.json)

## Heads up

Coming from `5.32.0`.

The background-worker migration timeout configuration was renamed from migrateConversationsOptions to migrationOptions. The old key is no longer read, so update any custom Helm overrides to the new name to avoid unexpected defaults.

No known bugs at this release.

## What must change

No changes are required for this release.

## Recommended cleanup (not strictly required)

If your custom values still contain duplicate `postgresMigration` entries in Brig or background-worker, remove them. Galley is the single source of truth for these settings.
