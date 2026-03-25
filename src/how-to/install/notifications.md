# Mobile Push Notifications: FCM, APNs, and WebSocket Connectivity

This page explains how Wire delivers notifications to iOS and Android mobile clients,
the role of AWS SNS/SQS in that delivery path, and how to determine which notification
configuration is appropriate for your deployment based on your network's connectivity
to external services.

## Overview

In order for your users to respond promptly to messages sent to them, they must be
notified that a message exists. Phone operating systems however have the job of
keeping the battery from running out. This means that apps on phones have to go
through some special hoops in order to notify users, without always running,
and draining the battery. 

In order to notify users that a message or call has occured, Wire's mobile clients 
(iOS and Android) must be notified of incoming messages and calls even when the
application is not in the foreground. Wire supports multiple notification delivery
mechanisms:

| Mechanism | Platform | Requires external connectivity |
|---|---|---|
| Apple Push Notification service (APNs) | iOS only | Yes – mandatory |
| Firebase Cloud Messaging (FCM) | Android | Yes – recommended |
| WebSocket (persistent TCP connection) | Android only | No |

> **Note:** iOS does **not** support WebSocket-only notification delivery. APNs is the
> only mechanism by which a backgrounded or closed iOS application can be woken up to
> receive new messages or calls. If your network cannot reach APNs, iOS clients will
> only receive notifications while the Wire app is actively open and in the foreground.

## How Wire Uses Push Notifications

Wire's use of APNs and FCM is intentionally minimal in order to preserve end-to-end
security and user privacy.

Wire does **not** transmit any message content, call metadata, or user identifiers
through APNs or FCM. Instead, the notification payload sent via the OS push channel
is a simple wake-up signal. Upon receiving this signal, the Wire client application
opens a connection directly to your Wire backend server and retrieves any pending
messages or events over an encrypted channel.

This means:

- Google (FCM) and Apple (APNs) never see the content or metadata of your users'
  communications.
- All message data is exchanged directly between the Wire client and your Wire backend,
  end-to-end encrypted.
- The push notification is used only to prompt the client to poll the backend.

This is in contrast to most commercial messaging platforms, which embed message previews,
sender names, and other metadata directly in the push notification payload sent to
Google's and Apple's infrastructure.

## Architecture: How Notifications Flow

Wire's backend push notification routing is handled by the **Gundeck** service.
Gundeck is the notification hub for Wire: it manages both WebSocket delivery (via
the Cannon service) and mobile push notification delivery (via AWS SNS/SQS).

For mobile push notifications, the delivery path is as follows:
```
Wire backend (Gundeck)
    └─► AWS SNS  (Simple Notification Service)
            ├─► APNs  (Apple Push Notification service)
            │       └─► iOS Wire client
            └─► FCM   (Firebase Cloud Messaging)
                    └─► Android Wire client
```

Gundeck requires outbound connectivity to AWS SNS/SQS endpoints in order to dispatch
push notifications. Gundeck also requires working DNS resolution to reach these
endpoints.

> **Note:** Even in WebSocket-only deployments where FCM/APNs are not used, Gundeck
> still depends on an SQS-compatible API for internal event processing. In that
> case, the `fake-aws-sqs` service (part of the `fake-aws` Helm chart) provides a
> local mock SQS endpoint inside the Kubernetes cluster. See
> [How to install wire-server using Helm](helm-prod.html) for details.

## WebSocket Mode (Android Only)

The Wire Android client supports a persistent WebSocket connection to the Wire backend
as an alternative to FCM. When the setting **"Keep connection to WebSocket on"**
(found under Network Settings in the Android app) is enabled, the client maintains a
long-lived connection to your Wire backend's `cannon` service, even when the app is
in the background.

**Implications of WebSocket-only mode:**

- The Android device will receive notifications without requiring connectivity to
  Google's FCM infrastructure.
- The persistent connection requires the device to wake up at regular intervals to
  keep the socket alive, which causes **significantly higher battery drain** compared
  to FCM.
- This mode may be appropriate for high-security environments where connectivity to
  Google services is prohibited, but it should be considered a compromise.
- This mode is **not available on iOS**. There is no WebSocket-only mode for iOS clients.

## Choosing a Notification Delivery Option

Your choice is determined by whether your Wire backend servers and client devices can
reach the required external endpoints. Before proceeding with configuration, perform
the connectivity checks described in the next section.

### Option A: Wire-Managed SNS/SQS Relay (Recommended)

**Assumptions:**

- Your Wire backend servers have outbound HTTPS connectivity to AWS SNS and SQS
  endpoints (see [Connectivity Checks](#connectivity-checks) below).
- Your iOS and Android client devices have outbound connectivity to APNs and FCM
  respectively (this is standard for devices on public internet or typical corporate
  networks).
- You are using the standard public App Store (iOS) and Play Store (Android) Wire
  client applications.

**Provides:**

- Push notifications on both iOS and Android without any custom client builds.
- No need to create or manage an AWS account.
- No need to maintain SNS/SQS infrastructure.
- Standard Wire client apps are used without modification, reducing long-term
  maintenance burden.

**You need:**

- A contract with Wire that includes push notification proxying. Contact
  [Wire Sales or Support](https://wire.com) to arrange this.
- Wire will provision a dedicated AWS account and SNS/SQS environment for your
  deployment and supply you with the following credentials and configuration values:
  - AWS Account ID (`account`)
  - AWS Region (`region`)
  - SNS endpoint URL (`snsEndpoint`)
  - SQS endpoint URL (`sqsEndpoint`)
  - SQS queue name (`queueName`)
  - ARN environment identifier (`arnEnv`)
  - AWS Access Key ID (`awsKeyId`)
  - AWS Secret Access Key (`awsSecretKey`)

See [Enable push notifications using the public App Store / Play Store mobile Wire clients](infrastructure-configuration.html#enable-push-notifications-using-the-public-appstore-playstore-mobile-wire-clients)
for the full configuration procedure once you have received these credentials.

### Option B: Customer-Managed SNS/SQS Relay (Not Recommended)

**Assumptions:**

- Your Wire backend servers **cannot** reach the Wire-managed AWS SNS/SQS endpoints,
  for example due to network policy or firewall restrictions preventing outbound
  connections to AWS.
- You are able to provision and maintain your own AWS account and SNS/SQS
  infrastructure.

**Provides:**

- Push notification delivery when Wire's managed relay cannot be used.

**You need:**

- Your own AWS account with SNS and SQS configured to relay to APNs and FCM.
- Custom-built iOS and Android Wire client applications to support your non-standard
  push notification architecture. **This requires Wire to produce and maintain custom
  client builds on your behalf.**

**Caveats:**

- This option is **not recommended**. Maintaining custom client builds introduces
  significant ongoing overhead: every Wire client update must be repackaged and
  re-distributed, and any changes to the push notification architecture must be
  coordinated between your team and Wire.
- This option should only be pursued if there is a firm and irresolvable network
  policy preventing outbound connectivity to AWS SNS/SQS from your backend servers.
  Perform the connectivity checks below before concluding this is necessary.

### Option C: WebSocket-Only (Android Only, No External Push Services)

**Assumptions:**

- Your backend servers and/or client devices cannot reach APNs or FCM.
- You accept the battery life trade-off on Android devices.
- Your deployment does not include iOS clients, **or** you accept that iOS clients
  will only receive notifications when the app is open.

**Provides:**

- Notification delivery for Android clients without any dependency on Google or Apple
  infrastructure.

**You need:**

- The `fake-aws` Helm chart deployed in your cluster (provides mock SNS/SQS endpoints
  for Gundeck's internal use).
- Android users must manually enable **"Keep connection to WebSocket on"** in the
  Wire Android app under **Settings → Network Settings**.

See [How to install wire-server using Helm](helm-prod.html) for
the `fake-aws` configuration required for WebSocket-only mode.

## Connectivity Checks

Before deciding which option to implement, verify whether your Wire backend servers
can reach the required external endpoints. Run the following checks from a host inside
your Wire backend's network (e.g. a Kubernetes node or a pod with a shell).

### 1. Test connectivity to AWS SNS (required for Options A and B)

Replace `<region>` with your target AWS region (e.g. `eu-central-1`):
```bash
curl -v --max-time 10 https://sns..amazonaws.com
```

Expected: an HTTP response (even a 4xx status is acceptable — it confirms TCP and
TLS connectivity). A connection timeout or TLS handshake failure indicates the
endpoint is not reachable from your network.

### 2. Test connectivity to AWS SQS (required for Options A and B)
```bash
curl -v --max-time 10 https://sqs..amazonaws.com
```

Expected: an HTTP response. Same interpretation as above.

### 3. Validate AWS credentials supplied by Wire (Option A)

Once Wire has supplied your credentials, verify them using the AWS CLI before
applying them to your Helm configuration:
```bash
export AWS_REGION=
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export ENV=   # e.g. "production" or "staging"

aws sqs get-queue-url --queue-name "${ENV}-gundeck-events"
```

You should receive a response of the form:
```json
{
    "QueueUrl": "https://.queue.amazonaws.com//-gundeck-events"
}
```

If this command fails, do not proceed with configuring Gundeck. Contact Wire support
with the error output.

### 4. Test connectivity to APNs (iOS clients)

APNs uses TCP port 443 (with HTTP/2) or legacy port 2197. From a host on the same
network as your client devices (or from a device itself):
```bash
# Test primary APNs endpoint (HTTP/2 on port 443)
curl -v --max-time 10 https://api.push.apple.com

# Test legacy port (if port 443 is restricted on your client network)
curl -v --max-time 10 --connect-to ::api.push.apple.com:2197 https://api.push.apple.com
```

> **Note:** This check must be performed from the **client device's network**, not
> from your backend server. APNs connectivity is a requirement of the mobile device,
> not the Wire backend.

### 5. Test connectivity to FCM (Android clients)

FCM endpoints use HTTPS on port 443:
```bash
curl -v --max-time 10 https://fcm.googleapis.com
```

> **Note:** As with APNs, this check should be performed from the network where
> Android client devices will be operating.

## Decision Guide

Use the following to determine which option applies to your deployment:
```
Can your Wire backend servers reach AWS SNS/SQS?
│
├── YES ──► Do you have a Wire contract covering push notification proxying?
│           │
│           ├── YES ──► Use Option A (Wire-Managed SNS/SQS Relay). [Recommended]
│           │
│           └── NO  ──► Contact Wire to arrange this. Option A is strongly preferred.
│
└── NO  ──► Do you require iOS push notification support?
            │
            ├── YES ──► Option B (Customer-Managed SNS/SQS) is likely required.
            │           Contact Wire — this requires custom client builds.
            │
            └── NO  ──► Option C (WebSocket-only) may be sufficient for
                        Android-only deployments. Note the battery drain trade-off.
```
