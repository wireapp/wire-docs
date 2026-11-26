# Wire-Server `5.38.0` release

For details, see the [release changelog](https://github.com/wireapp/wire-server/releases/tag/2026-10-26) on the wire-server repo.

Build manifest: [build.json](https://raw.githubusercontent.com/wireapp/wire-builds/223f0cad/build.json)

## Heads up

Coming from `5.37.0`.

You can also upgrade directly from `5.35.0`. Releases `5.36.0` and `5.37.0` have no mandatory intermediate step: the `cassandra-migrations` job applies all pending Cassandra schema versions, and the services apply all pending PostgreSQL migrations in order at startup. Read the [5.36.0](wire-server-5.36.0.md) and [5.37.0](wire-server-5.37.0.md) notes too, because their configuration changes also apply.

No known bugs at this release.

This release detects silent PostgreSQL connection failures and discards the broken connections. Before, a service such as `galley` could keep a dead connection after a PostgreSQL failover or restart.

## What must change

No mandatory Helm value change is required for a standard upgrade.

- **Only if you override nginz routes in your values:** `oauth_scope` is deprecated. Use `oauth_scopes` with full scope names instead. If a route has both, `oauth_scopes` wins. The bundled chart is already updated.

  ```yaml
  # before
  - path: /conversations/([^/]*)/code
    oauth_scope: conversations_code
  # after
  - path: /conversations/([^/]*)/code
    oauth_scopes: ["read:conversations_code", "write-only:conversations_code", "delete-only:conversations_code"]
  ```

- nginz no longer exposes `/i/federation-status`. If your monitoring calls this endpoint through nginz, update it.

The release adds two PostgreSQL migrations. The services apply them at startup:

- `20261020124413-create-scim-user-index`
- `20261022130000-create-pending-scim-user-index`

Both create an index with `CREATE INDEX CONCURRENTLY`. On a large `wire_user` table this can take some time, but it does not lock the table.

There is no new Cassandra schema migration.

## New configuration

- `apiVersions.disabledFederationAPIVersions` (default `[development]`): a new top-level value in the `wire-server` chart. It is rendered into `brig`, `galley` and `cargohold`. Keep the default.
- `brig.secrets.turn.coturnSecret` (optional): the coturn `static-auth-secret`. If you set it, `GET /calls/config/v3` returns TURN credentials in the native coturn format. Set it only if **all** TURN servers that you advertise accept coturn long-term credentials. `turn.secret` stays in use for `/calls/config` and `/calls/config/v2`.

## Other chart changes

- `legalhold`: the PostgreSQL subchart now uses `bitnamilegacy/postgresql:11.10.0`, because `docker.io/bitnami` removed the old tags. If you mirror images, add this image.
- `fake-aws-s3`: the MinIO images now come from `quay.io/wire/mirror-images/minio/`. This chart is for test environments only.
- `wire-ingress` (only if you use it): needs Envoy Gateway 1.9 or later, Kubernetes 1.33 to 1.36 and Gateway API 1.6.1 CRDs. Federation needs `extensionApis.enableLua: true` in the controller configuration. The Envoy proxy fleet now has 3 replicas by default. See the `wire-ingress` chart README.

## Behaviour changes

- SCIM: `GET /scim/v2/Users` without a filter now works when user data is in PostgreSQL.
- Stealth users no longer appear in exact handle searches.
- The `profilePict` field is removed from the user profile.
- New MLS endpoints for targeted and transient messages.
