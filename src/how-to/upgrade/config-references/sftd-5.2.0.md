# SFTD `5.2.0` release

For details, see the [release notes](https://github.com/wireapp/wire-avs-service/releases/tag/v5.2.0) on the wire-avs-service repo.

Chart: `sftd` version `5.2.0`, from `https://s3-eu-west-1.amazonaws.com/public.wire.com/charts-avs` or `oci://quay.io/wire/charts/stable/sftd`.

## Heads up

Coming from chart `0.145.0` (sftd `5.0.80`). `5.0.80` is the oldest version that you can upgrade from directly.

The image and the chart now share one version number. The chart version jumps from `0.x` to `5.2.0`.

This release fixes audio problems in group calls: garbled audio when two speakers have a similar level, and audio that becomes very delayed after a stream was not used for some time.

## What must change

- **`initImage` is removed.** If your values set `initImage`, remove it. To override the image of the external IP helper, use `externalIpHelper.image`.
- **Air-gapped or mirrored registries:** mirror these images. The chart lists them in its `helm.sh/images` annotation.
  - `quay.io/wire/sftd:5.2.0`
  - `quay.io/wire/sftd_disco:1.1.1`
  - `docker.io/alpine/kubectl:1.35.1`
  - `docker.io/nginxinc/nginx-unprivileged:1.29.5-alpine3.23-perl`
- **If you override the join-call image:** the join-call proxy now runs `nginx-unprivileged` as UID `101`. An override that points to a different nginx image can break it.

## Changed defaults

- `terminationGracePeriodSeconds` changed from `10` to `0`. A rollout no longer waits 10 seconds per pod. Calls on a pod that stops end immediately. To keep the old behaviour, set:

  ```yaml
  terminationGracePeriodSeconds: 10
  ```

- If the external IP helper finds no external IP, the pod now starts with a warning and advertises its host addresses. Before, the pod went into a crash loop. Look for `WARNING: no external IP found` in the `get-external-ip` init container log. If the node is behind NAT, clients cannot reach sftd in this case.

## Optional changes

### `mediaIP`

`mediaIP` sets the address that sftd advertises to clients (the `-A` argument). If you do not set it, the chart uses the external IP from the helper, as before.

```yaml
# Accepted values: __SFT_EXT_IP__ (default), __SFT_HOST_IP__, __SFT_POD_IP__, or a literal address
mediaIP: __SFT_HOST_IP__
```

If clients reach the nodes directly, set `mediaIP` to `__SFT_HOST_IP__` or to a literal address. The chart then removes the external IP helper, its node-read RBAC and its startup delay of up to 5 minutes. Do not set it if the nodes are behind NAT.

### `advertiseInternalIp`

Set `advertiseInternalIp: true` to also advertise the pod IP as an ICE candidate (the `-B` argument). Use this if a TURN server in front of sftd must reach it on both an internal and an external address. Do not combine it with `mediaIP: __SFT_HOST_IP__` or `__SFT_POD_IP__`: the chart then fails to render.

### `clusterDomain`

Set `clusterDomain` only if your cluster uses a DNS domain other than `cluster.local`.

### Gateway API

This applies only if you set `gateway.enabled: true`. The nginx Ingress (`ingress.enabled: true`) is still the default and does not change.

- HTTPS now attaches to the Gateway through a `ListenerSet`. You need Gateway API CRDs and a controller that support `ListenerSet` v1 (tested with Envoy Gateway 1.9.2).
- `gateway.className` now defaults to `envoy`.
- If you use an existing Gateway (`gateway.create: false`), it must admit ListenerSets from the sftd namespace. For `wire-ingress`, use `gateway.allowedListenerNamespaces`.
- With a `mergeGateways` GatewayClass, set `gateway.envoyProxy.create: false`.
- TLS 1.3 is the default. `FIPS_202205_tls_profile: true` applies the Envoy FIPS 202205 profile.
