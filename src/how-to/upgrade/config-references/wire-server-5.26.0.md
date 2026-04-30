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

## Notes from the previous release

The `background-worker` chart default for `postgresMigration.conversation` is corrected at this release. It defaults to `cassandra` again, matching the `galley` default. Earlier versions of the chart defaulted to `postgresql`, which is exactly the bug that broke conversations on installs that hadn't migrated.

If `postgresMigration.conversation` was already set explicitly in `values/wire-server/values.yaml` (which `5.25` told operators to do), no action.

If the chart default at `5.25` was being relied on, **and** the migration was already done, the value has to be set explicitly to `postgresql` now, otherwise the new `cassandra` default flips the worker back to reading from Cassandra:

```yaml
background-worker:
  config:
    postgresMigration:
      conversation: postgresql
```

## Mandatory (breaking) changes

No mandatory changes.

## Optional changes

Conversation codes can now be migrated to PostgreSQL. For details, read our [changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-01-26).
