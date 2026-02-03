# Wire-Server 5.25.0 release

The following reference was written based on the following [`build.json` charts](https://raw.githubusercontent.com/wireapp/wire-builds/5a74084feeb1138925dcb671b333da0c76f88f08/build.json).

For additional details, you can also read our [release changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-01-13).

## Mandatory (breaking) changes

No mandatory changes in comparison to the last release.

## Optional changes

### `nginx-ingress-services`

Support for `cert-manager` certificate private key rotation policy has been added in this release. This allows preserving private keys across certificate renewals for client key pinning scenarios in both federator and ingress certificates. The following shown are defaults as they come in charts from referenced `build.json`.

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

Options are:
* Always (default) - regenerates key on each renewal
* Never - preserves key across renewals (for key pinning)

### `background-worker`

Configuring page size and parallelism for conversation migration to PostgreSQL is now possible. This can be configured like this:

```yaml
background-worker:
  config:
    migrateConversationsOptions:
      pageSize: 10000
      parallelism: 2
```
  