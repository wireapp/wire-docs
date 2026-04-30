# Wire-Server `5.26.0` release

> **Federated environments: skip this version.**
>
> The `5.26` charts have unresolved issues in federated mode. The original release PR was closed without merging. Federated deploys should go straight from `5.25` to `5.27`.
>
> Non-federated deploys can apply `5.26` if they want, but there are no breaking changes between `5.25` and `5.27`, so skipping is also fine.

Reference based on these [`build.json` charts](https://raw.githubusercontent.com/wireapp/wire-builds/7023ffdd52f9de2a1eb5ce2e01cefaf16253274b/build.json), and the [release changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-01-26).

Artifact:
[`wire-server-deploy-static-6ccd1d01db71f30efa1164cf0f9fb6c1f6f5bf64.tgz`](https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-6ccd1d01db71f30efa1164cf0f9fb6c1f6f5bf64.tgz)

## Heads up

Coming from `5.25.0`. For deploys at any earlier version, do the `5.25` page first.

## Known bugs

Previous release introduced a bug into `background-worker` default settings for `postgresMigration` and have now been correctly set to Cassandra. If you are relying on default values from our charts, but have migrated your conversations to PostgreSQL, update your config accordingly to keep using PostgreSQL. Specifically, this value:

```
background-worker:
  config:
    postgresMigration:
      conversation: postgresql | cassandra # default is cassandra, and should be if not migrated to postgresql
```

## Mandatory (breaking) changes

No mandatory changes.

## Optional changes

Conversation codes can now be migrated to PostgreSQL. For details, read our [changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-01-26).
