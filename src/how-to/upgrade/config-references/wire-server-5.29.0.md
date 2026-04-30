# Wire-Server `5.29.0` release

> **This release is broken. Skip it. Upgrade from `5.28` directly to `5.30`.**
>
> The `5.29` charts have known issues that prevent reliable deployment. The wire-server release notes themselves recommend skipping this version. The changes documented below are still in effect at `5.30` (some of them tweaked further), and this page exists for reference. Real upgrade instructions are on the `5.30` page.

Reference based on these [`build.json` charts](https://raw.githubusercontent.com/wireapp/wire-builds/eaaec058bd49e392ab8727a02c568782f709c81a/build.json), and the [release changelog](https://github.com/wireapp/wire-server/releases/tag/v5.29.0).

Artifact:
[`wire-server-deploy-static-d5295d63b08c43a4983c27e33e5fff75acdb6663.tgz`](https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-d5295d63b08c43a4983c27e33e5fff75acdb6663.tgz)

## Heads up

Skip this version. The content below is reference material for what shipped in `5.29`. The changes are mostly carried into `5.30`, see the `5.30` page for the actual upgrade.

For reference purposes, the prior version is treated as `5.28.0`.

## Known bugs

No known bugs

## Mandatory (breaking) changes

Wire-server core services were migrated from subcharts into the umbrella chart templates. As a result, dependency tags for these services are now obsolete. Out of these, `proxy` service might be the only breaking change if it was not used previously and is unconfigured.

### `proxy`

If `proxy` was used previously and is already configured, you have no breaking changes.

Since proxy can no longer be "toggled off" the following configuration with dummy secrets is sufficient for deploy.

```
proxy:
  secrets:
    proxy_config: |-
      secrets {
              youtube    = "..."
              googlemaps = "..."
              soundcloud = "..."
              giphy      = "..."
              spotify    = "Basic ..."
      }
```

## Optional changes

### `wire-server`

This value in `wire-server` charts is now obsolete and can be removed if used:

```
tags:
  proxy: false # or true
```

### `proxy`

The following is full config options for the `proxy` chart and are shown as defaults as they come set in charts. They are not required to be set in your `values.yaml`. Do not change unless necessary.

```
proxy:
  replicaCount: 3
  image:
    repository: quay.io/wire/proxy
    tag: wire-server-release-version
  service:
    externalPort: 8080
    internalPort: 8080
  imagePullPolicy: ""
  metrics:
    serviceMonitor:
      enabled: false
  resources:
    requests:
      memory: "25Mi"
      cpu: "50m"
    limits:
      memory: "50Mi"
  config:
    logLevel: Info
    logFormat: StructuredJSON
    logNetStrings: false
    proxy: {}
    # Disable one ore more API versions. Please make sure the configuration value is the same in all these charts:
    # brig, cannon, cargohold, galley, gundeck, proxy, spar.
    disabledAPIVersions: [development]

  podSecurityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  secrets: {}
```