
# Troubleshooting Push Notifications

Use the following steps to determine whether the problem is with the Wire backend, the affected device, or the network used by the device.

## 1. Identify the scope of the problem

First determine:

* Are you hosting your own Wire backend, or are you using Wire Cloud?
* Are push notifications failing for all users?
* Are they failing only for one user or one device?
* Is the problem specific to Android, iOS, or both?

If you host your own Wire backend and notifications are failing for many or all users, start with the backend checks below.

If the issue affects only one user or device, or you are using Wire Cloud, start with [Device and network troubleshooting](#3-device-and-network-troubleshooting).

---

# 2. Self-hosted Wire: notifications failing for multiple users

## Enable Gundeck debug logging

Temporarily change the Gundeck log level in `values/wire-server/values.yaml`:

```yaml
gundeck:
  config:
    logLevel: Debug
```

The current Wire Server chart exposes Gundeck logging under `gundeck.config.logLevel`; the normal default is `Info`.

Review the Helm changes before applying them:

```bash
d helm diff upgrade wire-server charts/wire-server \
  --values values/wire-server/values.yaml \
  --values values/wire-server/secrets.yaml
```

Then apply the configuration:

```bash
d helm upgrade --install wire-server charts/wire-server \
  --values values/wire-server/values.yaml \
  --values values/wire-server/secrets.yaml
```

`helm diff upgrade` is the expected syntax for the Helm Diff plugin.

### Inspect Gundeck logs

```bash
kubectl logs -f -l app=gundeck
```

Look for errors or warnings while reproducing the notification problem.

You can also filter for push-related activity:

```bash
kubectl logs -f -l app=gundeck \
  | grep -Ev 'cassandra\.gundeck|WebSocket' \
  | grep -i push
```

If push-related operations appear, this confirms that Gundeck is processing or attempting native push operations. It does **not** by itself prove that FCM/APNs successfully delivered a notification to the device.

After troubleshooting, return the Gundeck log level to `Info` to avoid leaving verbose debug logging enabled.

---

# 3. Device and network troubleshooting

## Android / Firebase Cloud Messaging

Android devices using FCM need outbound connectivity on TCP ports:

* `5228`
* `5229`
* `5230`
* `443`

Firebase currently documents the following hosts for hostname-based filtering:

```text
mtalk.google.com
mtalk4.google.com
mtalk-staging.google.com
mtalk-dev.google.com
alt1-mtalk.google.com
alt2-mtalk.google.com
alt3-mtalk.google.com
alt4-mtalk.google.com
alt5-mtalk.google.com
alt6-mtalk.google.com
alt7-mtalk.google.com
alt8-mtalk.google.com
android.apis.google.com
device-provisioning.googleapis.com
firebaseinstallations.googleapis.com
```

Firebase recommends port-based filtering over maintaining an IP allowlist. It also notes that FCM's device connection cannot use a normal network proxy and that, when a VPN is active and cannot be bypassed, FCM traffic travels through the VPN.

Please confirm that your firewall, VPN, DNS filtering, or other security software is not blocking this traffic.

A basic connectivity test from a system on the same network is:

```bash
nc -vz mtalk.google.com 5228
nc -vz mtalk.google.com 5229
nc -vz mtalk.google.com 5230

curl -I https://firebaseinstallations.googleapis.com
```

A failed test is useful evidence of a network restriction. A successful test does not guarantee that the affected mobile device has identical network access.

## iOS / Apple Push Notification service

Apple devices need a persistent connection to APNs. For device-side APNs connectivity, Apple documents:

* TCP `5223` for APNs
* TCP `443` as a fallback
* Access to Apple's push network

Apple recommends allowing device traffic to Apple's `17.0.0.0/8` network where possible. TCP `443` or `2197` is used by notification providers when sending notifications **to APNs**, which is different from the device receiving notifications.

TLS inspection or interception of APNs traffic can also interfere with APNs connectivity.

---

# 4. Android device checks

On the affected Android device:

1. Enable Wire logging under:

   **Settings → Debug Settings → Enable logging**

2. Re-register the FCM push token under:

   **Settings → Debug Settings →  Re-register FCM push token**

3. Go to:

   **Settings → Network Settings**

   Temporarily disable **Keep Connection to Websocket**.

4. Send several messages to the device while Wire is in the background.

5. If notifications still do not arrive, enable **Keep Connection to Websocket**  again after the test.

Also check the Android operating-system settings:

* Notifications for Wire are allowed. Android 13 and later can require an explicit notification permission.
* Wire is not configured for restricted background battery usage. Restricted applications can have background activity or notifications delayed.
* Battery Saver or Extreme Battery Saver is not restricting Wire during the test.
* If Data Saver is enabled, allow unrestricted/background data for Wire.
* Do Not Disturb / Modes are not suppressing Wire notifications.

If ADB is available, you can check whether Wire is in the stopped state:

```bash
PACKAGE_NAME="com.wire" 

adb shell pm dump "$PACKAGE_NAME" | grep stopped
```

If you see:

```text
stopped=true
```

launch Wire again before repeating the notification test.

---

# 5. iOS device checks

On the affected iPhone or iPad:

1. Re-register the APNs token under:

   **Wire → Settings → Advanced → Reset Push Notifications Token**

2. Exchange several messages with the affected device while Wire is in the background.

3. In iOS, confirm:

   * **Settings → Notifications → Wire → Allow Notifications** is enabled.
   * Wire is not being silenced by an active **Focus** mode.
   * Wire notifications are not configured only for a **Scheduled Summary**, which can delay when they are presented.
   * The current Wi-Fi/VPN/firewall allows the APNs connectivity described above.

---

# 6. Compare with an independent push-notification application

To help distinguish a Wire-specific problem from a device/network push problem, install the `ntfy` application and subscribe to a random test topic.

For Android, use the **Google Play** version when specifically testing FCM. The F-Droid build of `ntfy` does not use Firebase. The official iOS application uses the platform push infrastructure for background delivery.

Choose a difficult-to-guess topic name and subscribe to it in the application.

Then send a notification:

```bash
TOPIC='wire-push-test-RANDOM-UNIQUE-VALUE'

curl \
  -H 'Title: Push notification test' \
  -H 'Priority: high' \
  -H 'Tags: white_check_mark' \
  -d 'This notification was sent through the ntfy HTTP API.' \
  "https://ntfy.sh/$TOPIC"
```

Leave `ntfy` in the background and repeat the test.

If notifications also consistently fail through `ntfy`, this strongly suggests a problem with the device, operating-system settings, VPN, firewall, or network push connectivity rather than the Wire backend. `ntfy` itself should also be confirmed operational before drawing that conclusion.

---

# 7. Collect Android diagnostics

If USB debugging is available, collect the Wire package information:

```bash
PACKAGE_NAME="com.wire"
adb shell dumpsys package "$PACKAGE_NAME" > wire-package.txt
```

You can also check whether the Google Play services FCM diagnostics activity is available:

```bash
adb shell am start -n com.google.android.gms/.gcm.GcmDiagnostics
```

Run the test:

1. With the VPN enabled.
2. Without the VPN.
3. Send several test messages in each state.
4. Capture screenshots of any relevant diagnostics/events.

To share Wire application logs:

**Android**

**Settings → Debug Settings → Share logs**

**iOS**

**Settings → Having trouble?**

Please include the approximate timestamp of each notification test so that device logs can be correlated with backend logs.

---

# 8. Self-hosted Wire: verify the user's registered push token

If the problem remains unresolved on a self-hosted installation, verify whether the affected device has a push token registered in Gundeck.

Enter the Wire utility pod:

```bash
d bash
kubectl exec -ti wire-utility-0 -- bash
cqlsh
```

Find the user:

```sql
SELECT id, email, handle
FROM brig.user
WHERE email = 'user@example.com'
ALLOW FILTERING;
```

Use the returned user ID to inspect the user's clients:

```sql
SELECT user, client, model, last_active, tstamp
FROM brig.clients
WHERE user = <USER_UUID>
ALLOW FILTERING;
```

Then inspect the registered push endpoints:

```sql
SELECT usr, arn, ptoken, client
FROM gundeck.user_push
WHERE usr = <USER_UUID>;
```

If the user has several Wire clients, match the `client` field in `gundeck.user_push` with the affected device.

A typical Android endpoint ARN resembles:

```text
arn:aws:sns:<region>:<account-id>:endpoint/GCM/<application-name>/<endpoint-id>
```

A typical iOS endpoint ARN resembles:

```text
arn:aws:sns:<region>:<account-id>:endpoint/APNS/<application-name>/<endpoint-id>
```

If no `gundeck.user_push` entry exists for the affected client, reset/re-register the push token on the device and repeat the query.

> Treat the user ID, client ID, endpoint ARN and push token as sensitive diagnostic data. Redact them before posting logs or command output in places where they are not required.

Send several ordinary Wire messages to the affected client after collecting this information.
---

# 9. Self-hosted Wire: verify the Amazon SNS endpoint

Wire's self-hosted push configuration uses the AWS settings under Gundeck. Current Wire deployment documentation places the AWS configuration under `gundeck.config.aws` and credentials under `gundeck.secrets`.

Review the configuration:

```bash
d bash
yq eval '.gundeck.config.aws' values/wire-server/values.yaml
yq eval .gundeck.secrets values/wire-server/secrets.yaml
```

Use an environment that has the AWS CLI available.

```bash
kubectl run sns-debug \
  --image=<AWS_CLI_IMAGE> \
  --restart=Never \
  --command -- sh -c 'while true; do sleep 3600; done'

kubectl exec -ti sns-debug -- sh
```

Configure the AWS CLI using your normal secure credential mechanism:

```bash
aws configure
```

Use the region configured in `gundeck.config.aws.region`.

---

## Check the platform application

```bash
aws sns get-platform-application-attributes \
  --platform-application-arn '<PLATFORM_APPLICATION_ARN>' \
  --region '<AWS_REGION>'
```

Amazon SNS exposes platform application attributes for APNs and GCM/FCM applications.

---

## Check the device endpoint

```bash
aws sns get-endpoint-attributes \
  --endpoint-arn '<ENDPOINT_ARN>' \
  --region '<AWS_REGION>'
```

Check at least:

```text
Enabled
Token
```

`Token` should match the token stored for the affected Wire client, and `Enabled` should be `true`. Amazon SNS can disable an endpoint after the upstream notification service reports that its device token is invalid.

If the token is different, or the endpoint is disabled, reset/re-register the push token in Wire and check the values again.

---

# 10. Send a direct Amazon SNS test

A direct SNS test bypasses normal Wire notification generation and helps test the path from SNS to FCM/APNs.

A successful `aws sns publish` response means SNS accepted the request; the final confirmation is whether the target device actually receives the test notification.

Amazon SNS requires platform-specific payloads to be JSON strings when `--message-structure json` is used. Current SNS also supports FCM HTTP v1 payloads through the `GCM` message key.

## Android / FCM

```bash
aws sns publish \
  --target-arn '<ANDROID_ENDPOINT_ARN>' \
  --message '{"default":"Test direct SNS","GCM":"{\"fcmV1Message\":{\"message\":{\"notification\":{\"title\":\"Test direct SNS\",\"body\":\"Test direct SNS\"},\"android\":{\"priority\":\"high\"},\"data\":{\"source\":\"sns-cli\"}}}}"}' \
  --message-structure json \
  --region '<AWS_REGION>'
```

## iOS / APNs

```bash
aws sns publish \
  --target-arn '<IOS_ENDPOINT_ARN>' \
  --message '{"default":"Test direct SNS","APNS":"{\"aps\":{\"alert\":{\"title\":\"Test direct SNS\",\"body\":\"Test direct SNS\"},\"sound\":\"default\"}}"}' \
  --message-attributes '{"AWS.SNS.MOBILE.APNS.PUSH_TYPE":{"DataType":"String","StringValue":"alert"}}' \
  --message-structure json \
  --region '<AWS_REGION>'
```

SNS supports platform-specific APNs payloads and recommends setting the APNs push type when appropriate.

If direct SNS notifications work but normal Wire notifications do not, the device's APNs/FCM connectivity and SNS endpoint are working, and the investigation should return to Wire/Gundeck notification generation.

If direct SNS notifications fail even after the device token has been reset, collect the information below and send it to Wire Support.

---

# 11. Information to provide to Wire Support

Please provide:

* Whether the deployment is Wire Cloud or self-hosted.
* Whether all users or only specific users/devices are affected.
* Android/iOS version.
* Wire application version.
* Approximate timestamps for several failed notification tests.
* Whether notifications work with and without the VPN.
* Result of the `ntfy` comparison test.
* Wire application logs.
* Relevant Gundeck logs for the same timestamps, for self-hosted deployments.
* The affected Wire client ID.
* Whether a `gundeck.user_push` entry exists for that client.
* Whether the SNS endpoint reports `Enabled=true`.
* Whether the token in SNS matches the registered token.
* Result of the direct SNS publish test.
* Android `dumpsys package` output, where applicable.
* Screenshots from Google Play services diagnostics, if that diagnostic screen is available.

Do not include AWS secret keys, passwords, or other credentials. Redact push tokens and other identifiers unless Wire Support specifically requires them for the investigation.
