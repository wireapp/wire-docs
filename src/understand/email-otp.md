# Email OTP

## Overview

Wire can require team users to enter a 6-digit verification code (sent to their email) when performing sensitive operations. It's controlled by the `sndFactorPasswordChallenge` [feature flag](team-feature-settings.md) in galley, and it's off by default.

## What operations require OTP

When enabled, a verification code is required for:

- **Login** (after entering the correct password)
- **Adding a new device/client** (logging in from a new browser or device)
- **Creating [SCIM](../developer/reference/provisioning/scim-token.md) provisioning tokens**
- **Deleting a team**

Personal (non-team) users aren't affected, the `Email OTP` feature is only for team accounts. 

[SSO](single-sign-on/README.md) users aren't affected either since they authenticate through their identity provider (idP) instead of Wire's password flow. 

If you want `Email OTP` for SSO users, you need to set it up in your idP if it supports it. 

## Prerequisites

OTP sends codes by email, so you need a working email delivery path. That's either:

- A production SMTP relay configured as a smarthost
- The [`demo-smtp`](../how-to/install/troubleshooting.md) chart for testing (emails stay in the pod's local mail queue, never actually delivered)

If email delivery is broken, users won't be able to log in once `Email OTP` is on, because they'll never get their code, so it's critical to get email sending working first.

## Enabling Email OTP

Add this to `values/wire-server/values.yaml` under galley's [feature flags](team-feature-settings.md). If you're not familiar with helm values overrides, read [Overriding helm configuration settings](helm.md#overriding-helm-configuration-settings) first.

```yaml
galley:
  config:
    settings:
      featureFlags:
        sndFactorPasswordChallenge:
          defaults:
            status: enabled
            lockStatus: locked
```

Then helm upgrade:

```sh
helm upgrade --install --wait wire-server ./charts/wire-server \
  --values ./values/wire-server/values.yaml \
  --values ./values/wire-server/secrets.yaml
```

Galley pods will restart with the new config. For the full helm deployment process, see [Installing wire-server using Helm](../how-to/install/helm-prod.md).

### Lock status

The `lockStatus` setting controls whether team admins can change this setting (`Email OTP` enabled or not) on a per-team basis:

| Value      | Behavior                                                                               |
|------------|----------------------------------------------------------------------------------------|
| `locked`   | Team admins can't change it. Your default applies to all teams.                        |
| `unlocked` | Team admins can toggle `Email OTP` for their own team via the team management API.             |

For most setups you'll want `locked`, since `Email OTP` is typically meant to be enforced across the organization.

## Disabling Email OTP

Set status to `disabled`:

```yaml
galley:
  config:
    settings:
      featureFlags:
        sndFactorPasswordChallenge:
          defaults:
            status: disabled
            lockStatus: locked
```

Or just remove the `sndFactorPasswordChallenge` section, it defaults to disabled.

## Rate limiting

After 3 wrong code attempts, the code gets invalidated. New code requests are rate-limited, default is 5 minutes between requests. See also [Rate limiting of code generation requests](team-feature-settings.md#rate-limiting-of-code-generation-requests) for the full details.

You can configure the delay in brig:

```yaml
brig:
  config:
    optSettings:
      set2FACodeGenerationDelaySecs: 300
```

Value is in seconds. 300 (5 minutes) is the default and works fine for most cases.

## Verifying it works

Check galley's config to make sure the flag is there:

```sh
kubectl get configmap galley -o yaml | grep -A4 sndFactorPasswordChallenge
```

You should see `status: enabled`.

To actually test it: log in with a team user account. After the password, the webapp should ask for a verification code. If you're not sure how to create a team user, see [Investigative tasks](../how-to/administrate/users.md#create-a-team-using-the-scim-api).

## Getting verification codes from demo-smtp

If you're using [`demo-smtp`](../how-to/install/troubleshooting.md) (which doesn't deliver to real mailboxes), you can retrieve the code directly from its mail queue:

```sh
# Find the pod
kubectl get pods -l app=demo-smtp

# Get the code from the latest email
kubectl exec <demo-smtp-pod> -- sh -c \
  'ls -t /var/spool/exim4/input/*-D | head -1 | xargs grep X-Zeta-Code'
```

The `X-Zeta-Code` header has the 6-digit code.

This is more fully documented in the [`troubleshooting page`](../how-to/install/troubleshooting.md)

## Troubleshooting

**Users can't log in after enabling Email OTP**: Most likely email delivery is broken. If using `demo-smtp`, check that `RELAY_NETWORKS` includes the pod network CIDR (usually `10.233.0.0/16` or whatever your cluster uses). Look at brig logs:

```sh
kubectl logs -l app=brig --tail=50 | grep -i smtp
```

**Code never arrives**: Look in the demo-smtp mail queue (see section above) to confirm the email was generated. With a real SMTP relay, check that relay's logs. Common issue: SPF/DKIM/DMARC rejection by the recipient's mail server.

**"Error 6" in the webapp**: Generic client error, usually a 500 from brig. Check the browser's «console» for errors. Also check brig logs for the real error. Most common cause is SMTP delivery failure. 

For general debugging tips, see [Triaging Issues](../how-to/support/triaging_issues.md) and [Collecting information with the Web Inspector](../how-to/support/inspector.md).
