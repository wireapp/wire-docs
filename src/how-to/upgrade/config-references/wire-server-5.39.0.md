# Wire-Server `5.39.0` release

For details, see the [release notes](https://github.com/wireapp/wire-server/releases/tag/v5.39.0) on the wire-server repo.

Build manifest: [build.json](https://raw.githubusercontent.com/wireapp/wire-builds/fea5e66c/build.json)

The charts are in the `https://s3-eu-west-1.amazonaws.com/public.wire.com/charts` Helm repository and at `oci://quay.io/wire/charts/stable/<chart>`, version `5.39.0`.

## Heads up

Coming from `5.38.0`. The release declares `upgrade_from: >=5.38.0`. If you run an older version, upgrade to `5.38.0` first. See the [5.38.0 notes](wire-server-5.38.0.md).

No known bugs at this release.

This release finalizes client API version `v19`. The new development version is `v20`.

The release declares these minimum versions of its dependencies. Check them before the upgrade:

| Dependency | Version |
|---|---|
| Kubernetes | `>= 1.33.0` |
| Helm | `>= 3.12.0` |
| PostgreSQL | `>= 17.0.0` |
| Cassandra | `>= 4.1.0` |
| Elasticsearch | `>= 6.8.0, < 7.0.0` |
| Redis | `>= 7.0.0` |
| RabbitMQ | `>= 3.13.0` |

## What must change

### 1. Move `conversationCodes` off `cassandra` before the upgrade

Meeting join codes are now stored only in PostgreSQL. If `galley.config.postgresMigration.conversationCodes` is still `cassandra` (the chart default), meeting creation and link refresh fail with `500 link-unavailable`. Reads of meetings that have no live join code fail in the same way, on every API version.

Before you upgrade to `5.39.0`, while you still run `5.38.0`, set:

```yaml
galley:
  config:
    postgresMigration:
      conversationCodes: migration-to-postgresql
```

Deploy this change on `5.38.0` and make sure that all pods are ready. Then upgrade to `5.39.0`.

With `migration-to-postgresql`, new conversation codes are written to both stores, and existing guest links stay readable from Cassandra. You do not have to run the backfill (`migrateConversationCodes`) for this step. If you already use `postgresql`, nothing changes.

Galley must also have a join-link URI: `settings.conversationCodeURI`, or the user's domain in `settings.multiIngress`.

### 2. Meeting emails (only if you send them)

Brig now renders and sends meeting emails. Galley no longer reads the sender, transport and branding under `galley.config.settings.meetings.email`, and no longer reads `galley.secrets.smtpPassword`. Brig uses its `emailSMS` configuration.

```yaml
galley:
  config:
    settings:
      meetings:
        emailsEnabled: true
brig:
  config:
    emailSMS:
      general:
        meeting:
          replyTo: "noreply@example.com" # optional
```

Meeting emails are sent only if the licence (see below) covers them. If the legacy `galley.config.settings.meetings.email` block is present, meeting emails stay enabled and its `replyTo` is used. To turn meeting emails off, remove the legacy block and set `emailsEnabled: false`.

### 3. Licence for meeting join links (only if you use them)

Joining a meeting by link now needs a licence. Without it, `POST /meeting/{domain}/{key}/{code}/join` and `GET /meeting/{domain}/{key}/{code}/code-check` return `403 id-feature-error`. Set the new top-level value:

```yaml
license: "<base64url licence payload>"
```

The chart renders it into galley and background-worker.

### 4. `ldap-scim-bridge` (only if you deploy it)

wire-server no longer publishes the `ldap-scim-bridge` chart. Take it from `oci://quay.io/wire/charts/stable/ldap-scim-bridge` (version `6.0.0` and later). The `5.x` charts that are already published stay available.

## Database migrations

There is no new Cassandra schema migration. The schema versions stay: `brig` `94`, `galley` `102`, `gundeck` `12`, `spar` `23`.

The services apply these PostgreSQL migrations at startup:

- `20261015120000-meetings-externally-managed-by`: adds three nullable columns to the meetings table.
- `20261019090000-meeting-join-code-backfill`: gives every meeting without a live join code a canonical one. It runs once and does not change existing codes or links.
- `20261102120000-meetings-conversation-guest-role`: stores the guest access role of existing meeting conversations.
- `20261020201733-budget`, `20261021102943-connections`, `20261022120000-custom-backend`, `20261027163611-nonce`: create the tables of the new stores. These tables stay unused until you start the matching migration.

## New migration settings

This release adds four new Cassandra-to-PostgreSQL migrations. All are disabled by default. You do not have to run them as part of the upgrade. You can start each of them at any later time, at your own discretion, on `5.39.0` or any later release. The chart renders the defaults:

```yaml
galley:
  config:
    postgresMigration:
      customBackend: cassandra
      budget: cassandra
      nonce: cassandra
      connections: cassandra
background-worker:
  config:
    migrateCustomBackend: false
    migrateNonce: false
    migrateConnections: false
```

| Setting | `background-worker` flag |
|---|---|
| `galley.config.postgresMigration.customBackend` | `migrateCustomBackend` |
| `galley.config.postgresMigration.nonce` | `migrateNonce` |
| `galley.config.postgresMigration.connections` | `migrateConnections` |
| `galley.config.postgresMigration.budget` | none (see below) |

Use the same three-step procedure as for the other stores. See [Migration for existing installations](../../../developer/reference/config-options.md#migration-for-existing-installations).

Login budgets (`budget`) have no backfill. Keep `budget: migration-to-postgresql` for at least the longest `limitFailedLogins.timeout` before you switch to `postgresql`.

## Optional changes

- `galley.config.settings.meetings.calendarOAuthClients`: OAuth client IDs of a calendar integration that can manage meetings. Upgrade nginz first, then set this value, then have the integration refresh its access tokens. Nothing changes while the list is empty.
- `galley.config.settings.featureFlags.mfa-totp`: a new team feature, disabled and locked by default. It is for interface testing only. No second factor is checked yet.
- `backoffice.config.ibisPort` and `backoffice.config.galebPort`: default `8080`, as before.

## Other chart changes

- `nginz.nginx_conf.ignored_upstreams` now defaults to `[log-analyzer]`. If you override this list, keep `log-analyzer` in it unless you run that service.
- `nginx-ingress-services`: the federator ingress now exposes only paths under `/federation`.

## Federation

- Federated MLS messages need federation API version `5` on both backends.
- `contact_status` in `POST /list-users` now covers federated users. Requests to a backend with federation API version below `5` log a warning until that backend is upgraded.
