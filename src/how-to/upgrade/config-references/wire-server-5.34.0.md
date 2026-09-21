# Wire-Server `5.34.0` release

For details, see the [release changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-07-07) on the wire-server repo.

Artifact:
[`wire-server-deploy-static-c1f882e49d9240374a57e1cae0ee28a9d93e7fe4.tgz`](https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-c1f882e49d9240374a57e1cae0ee28a9d93e7fe4.tgz)

Build manifest: [build.json](https://github.com/wireapp/wire-builds/blob/pinned-offline-5.34.0/build.json)

## Heads up

Coming from `5.33.0`.

No known bugs at this release.

## What must change

No changes are required for this release   

## Security enforcement

This version introduces an optional configuration to restrict which IdP descriptor signing certificates are accepted, based on their SHA-1 fingerprints. This option is only relevant to deployments using SSO.

```yaml
spar:
  config:
    idpCertFingerprintAllowlist:
      - 1A:F6:E7:A4:B7:23:EC:78:F2:4D:63:2F:D3:4C:C4:C1:B3:0E:8C:AB
```
