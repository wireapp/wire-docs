# Wire-Server `5.37.0` release

For details, see the [release changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-10-05) on the wire-server repo.

Build manifest: [build.json](https://raw.githubusercontent.com/wireapp/wire-builds/70531ae0/build.json)

## Heads up

Coming from `5.36.0`.

No known bugs at this release.

## What must change

No mandatory Helm value change is required for a standard upgrade.

- `brig.config.emailSMS.general.emailSender` now rejects a domain whose last label starts with a digit (for example `noreply@example.123`). This matches the AWS SES rules. Make sure that your sender address is valid before the upgrade, or `brig` does not start.

The release adds three PostgreSQL migrations. The services apply them at startup:

- `20260803164250-blacklist`
- `20260804090521-password-reset`
- `20260923120000-meetings-mtype`

There is no new Cassandra schema migration.

## New migration settings

This release adds two new Cassandra-to-PostgreSQL migrations. Both are disabled by default. The chart defaults are:

```yaml
galley:
  config:
    postgresMigration:
      blockList: cassandra
      passwordReset: cassandra
background-worker:
  config:
    migrateBlockList: false
    migratePasswordReset: false
```

If you copy the full `postgresMigration` block into your own values, add the two new keys. Keep them at `cassandra` until you decide to migrate.

| Setting | `background-worker` flag | Metric when complete |
|---|---|---|
| `galley.config.postgresMigration.blockList` | `background-worker.config.migrateBlockList` | `wire_block_list_migration_finished` = `1.0` |
| `galley.config.postgresMigration.passwordReset` | `background-worker.config.migratePasswordReset` | `wire_password_reset_migration_finished` = `1.0` |

Use the same three-step procedure as for the other stores. See [Migration for existing installations](../../../developer/reference/config-options.md#migration-for-existing-installations).

The user migration (added in `5.36.0`) now ignores invalid assets. Before, it could fail on them. Read the warning about skipped users in the [5.36.0 notes](wire-server-5.36.0.md#optional-migrate-user-data-to-postgresql) before you start it.

## Optional changes

### `nginx-ingress-services`: extra CSP `connect-src` entries

If you use multi-ingress with `config.renderCSPInIngress: true`, you can now add extra `connect-src` entries. You need this if the webapp connects to SFT servers in a different domain:

```yaml
config:
  renderCSPInIngress: true
  cspExtraConnectSrc: "https://sft.example-calling.com https://second-domain-example.com"
```

### `wire-ingress`: TLS defaults

The `wire-ingress` chart (Envoy Gateway) now sets TLS 1.3 as the minimum and allows post-quantum key exchange. A new `FIPS_202205_tls_profile` setting can help with BSI TR-02102-2 conformance. This applies only if you use `wire-ingress`. See the `wire-ingress` chart README.

## Behaviour changes

- Adminless group protection and automatic admin promotion now apply to channels too.
- Removing a user from a team now always sends MLS remove proposals.
- API version `v19` (development) adds `type` and `link` fields to meetings. Existing API versions do not change.
