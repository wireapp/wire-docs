# Coturn Client Certificate with Extended Key Usage (EKU)

This section is about **how to perform a specific task**. If you want to **understand how a certain component works, please see** [Reference](../../understand/README.md#understand)

This guide explains how to create and deploy a coturn client certificate with Extended Key Usage (EKU) support for federation DTLS connections. When coturn needs to authenticate with federation partner servers over DTLS on port 9191, the certificate must include both server and client authentication capabilities.

## Overview

Coturn federation DTLS connections (port 9191) require mutual TLS authentication. Your coturn certificate must be signed by a Certificate Authority (CA) that Wire Cloud trusts. The certificate must include both serverAuth and clientAuth Extended Key Usage (EKU) extensions.

### Prerequisites

- Coturn deployment via Helm in Kubernetes
- Access to the coturn Helm values configuration
- `openssl` command-line tool installed locally
- `kubectl` access to your cluster
- FQDN for your coturn deployment (e.g., `coturn.example.com`)
- **CA certificate** and **CA private key** — create one in Step 1 if you don't have one yet; once your federation partner (e.g. Wire Cloud) trusts your CA you can reuse it for all future renewals

### Deployment Model

The typical workflow for a self-managed coturn deployment:

1. **Select issuing CA** (create self-signed or use existing private CA)
2. **Send your CA** to Wire Cloud to add to their federation trust store
3. **Generate a coturn certificate** signed by that CA with serverAuth+clientAuth EKU
4. **Deploy coturn** with the certificate in Helm values
5. **Renew annually** by signing a new certificate with the same CA — no need to contact your federation partner again

## Step 1: Create a Self-Signed CA (skip if you already have one)

If your organization already has a CA and your federation partners already trusts it, skip to Step 2.

Otherwise, create a self-signed CA. You do this **once** — the CA is long-lived (10 years) and is reused for all future coturn certificate renewals without needing to contact your federation partners again.

```bash
# Generate CA private key (2048-bit RSA)
openssl genrsa -out my-ca-key.pem 2048

# Create CA certificate signing request
openssl req -new \
  -key my-ca-key.pem \
  -out my-ca.csr \
  -subj "/C=XX/O=Your Organization/CN=Your Organization CA"

# Self-sign the CA certificate (valid 10 years = 3650 days)
openssl x509 -req \
  -in my-ca.csr \
  -signkey my-ca-key.pem \
  -out my-ca.pem \
  -days 3650 \
  -extfile <(printf "basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid:always,issuer:always")
```

**Result**:
- `my-ca.pem` — CA certificate; send this to Wire Cloud to add to their federation trust store
- `my-ca-key.pem` — CA private key; keep this secure, it is needed for all future renewals
- `my-ca.csr` — can be deleted

**Important**: Wait until your federation partner confirms your CA is in their trust store before proceeding.

## Step 2: Create a Certificate Signing Request (CSR)

First, generate a private key and create a signing request for your coturn certificate.

```bash
# Create a coturn private key (2048-bit RSA)
openssl genrsa -out coturn-key.pem 2048

# OR use ECDSA if your organization prefers (recommended for modern deployments)
openssl ecparam -name secp256r1 -genkey -noout -out coturn-key.pem

# Create a certificate signing request with both server and client authentication EKU
# Replace coturn.example.com with your actual coturn FQDN
openssl req -new \
  -key coturn-key.pem \
  -out coturn.csr \
  -subj "/C=US/ST=State/L=City/O=Your Organization/CN=coturn.example.com" \
  -addext "subjectAltName=DNS:coturn.example.com,DNS:coturn-0.example.com,DNS:coturn-1.example.com,DNS:coturn-2.example.com" \
  -addext "extendedKeyUsage=serverAuth,clientAuth" \
  -addext "keyUsage=digitalSignature"
```

Verify the CSR:

```bash
openssl req -in coturn.csr -text -noout
```

## Step 3: Sign the Certificate with Your CA

Using your CA certificate and private key, sign the coturn certificate. This certificate will be valid for 365 days.

```bash
# Sign the CSR with your CA certificate and key
openssl x509 -req -days 365 \
  -in coturn.csr \
  -CA my-ca.pem \
  -CAkey my-ca-key.pem \
  -CAcreateserial \
  -out coturn-cert.pem \
  -extfile <(printf "subjectAltName=DNS:coturn.example.com,DNS:coturn-0.example.com,DNS:coturn-1.example.com,DNS:coturn-2.example.com\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth,clientAuth")
```

Verify the signed certificate:

```bash
openssl x509 -in coturn-cert.pem -text -noout
```

## Step 4: Verify Certificate Has Correct EKU

Before deploying, verify that your certificate includes both serverAuth and clientAuth extensions, and is signed by your CA:

```bash
# Check Extended Key Usage
openssl x509 -in coturn-cert.pem -text -noout | grep -A 3 "Extended Key Usage"
```

Expected output:

```
X509v3 Extended Key Usage:
    TLS Web Server Authentication, TLS Web Client Authentication
```

Verify the certificate issuer:

```bash
openssl x509 -in coturn-cert.pem -noout -issuer
# Output should show your CA's CN, e.g.: issuer=C=XX, O=Your Organization, CN=Your Organization CA
```

Verify the validity dates:

```bash
openssl x509 -in coturn-cert.pem -noout -dates
# Output should show: notBefore=... and notAfter=... (365 days from now)
```

## Step 5: Prepare Certificate Files

Display the PEM content of your certificate and private key, ready to copy into the Helm values file. The Helm chart encodes them automatically — paste the raw PEM including the `-----BEGIN`/`-----END` headers.

```bash
echo "=== Coturn Certificate ==="
cat coturn-cert.pem
echo ""
echo "=== Coturn Private Key ==="
cat coturn-key.pem
```

Copy both PEM strings for the next step.

## Step 6: Update Coturn Helm Values

Update your coturn Helm values file (`values/coturn/values.yaml`) with the PEM certificate and key. Use YAML block scalars (`|`) to preserve the multi-line PEM format:

```yaml
# Existing coturn configuration
# DTLS Federation certificate configuration
federate:
  dtls:
    tls:
      key: |
        -----BEGIN PRIVATE KEY-----
        <paste PEM private key content here>
        -----END PRIVATE KEY-----
      crt: |
        -----BEGIN CERTIFICATE-----
        <paste PEM certificate content here>
        -----END CERTIFICATE-----


## Step 7: Deploy Coturn with Updated Configuration

**Prerequisite**: Requires coturn chart version `4.6.2-federation-wireapp.44` or later.
Apply the updated Helm values:

```bash
# Navigate to wire-server-deploy directory
cd /path/to/wire-server-deploy

# Deploy or upgrade the coturn Helm chart with the updated values
helm upgrade --install coturn ./charts/coturn \
  -n default \
  -f values/coturn/values.yaml \
  --wait \
  --timeout 5m
```


Monitor the rollout:

```bash
kubectl rollout status statefulset/coturn -n default
```

The Helm chart will automatically:
1. Create a Kubernetes Secret with the certificate and key data
2. Mount the certificate in each coturn pod
3. Restart all coturn pods to pick up the new certificate
4. Update Helm release history for tracking and potential rollbacks

## Step 8: Verify Certificate is Deployed

After the Helm upgrade completes, verify that the certificate is properly mounted in the coturn pods:

```bash
# Get the coturn pod name
COTURN_POD=$(kubectl get pods -l app=coturn -n default -o jsonpath='{.items[0].metadata.name}')

# Verify the Kubernetes Secret was created
kubectl get secret coturn-dtls-certificate -n default -o yaml

# Check if certificate files exist in the pod
kubectl exec -it $COTURN_POD -n default -- ls -la /coturn-dtls-certificate/

# Verify the certificate content and EKU from the pod
kubectl exec -it $COTURN_POD -n default -- openssl x509 -in /coturn-dtls-certificate/tls.crt -text -noout | grep -A 3 "Extended Key Usage"
```

Expected output showing both serverAuth and clientAuth:

```
X509v3 Extended Key Usage:
    TLS Web Server Authentication, TLS Web Client Authentication
```

## Step 9: Test Federation DTLS Connection

To verify that coturn can now authenticate with federation partners, check the coturn logs:

```bash
# Get the coturn pod name (if not already set)
COTURN_POD=$(kubectl get pods -l app=coturn -n default -o jsonpath='{.items[0].metadata.name}')

# Stream coturn logs to watch for DTLS connections
kubectl logs -f $COTURN_POD -n default

# Or retrieve recent logs and filter for DTLS-related messages
kubectl logs $COTURN_POD -n default --tail=100 | grep -iE 'dtls|tls|certificate|federation'
```

Look for successful DTLS connection messages or client authentication confirmations in the logs.

### Check Helm Release History

To verify the chart was updated with your changes:

```bash
# View Helm release history
helm history coturn -n default

# Get current Helm values
helm get values coturn -n default | grep -A 10 "federate"
```

## Troubleshooting

### Certificate Not Loaded in Pod

**Symptom**: Coturn pod starts but certificate files are missing or old certificate is still in use.

**Solution**:

1. Verify the values file has the correct PEM certificate:
   ```bash
   grep -A 5 "federate:" values/coturn/values.yaml
   ```

2. Check if Helm Secret was created:
   ```bash
   kubectl get secret coturn-dtls-certificate -n default -o yaml
   ```

3. Verify pod is using the new certificate:
   ```bash
   COTURN_POD=$(kubectl get pods -l app=coturn -n default -o jsonpath='{.items[0].metadata.name}')
   kubectl exec $COTURN_POD -- openssl x509 -in /coturn-dtls-certificate/tls.crt -noout -dates
   ```

4. If pod still has old certificate, restart it:
   ```bash
   kubectl delete pod $COTURN_POD -n default
   kubectl wait --for=condition=ready pod -l app=coturn -n default --timeout=300s
   ```

### Certificate Missing Client EKU

**Symptom**: Coturn connects to federation partners but DTLS authentication fails.

**Solution**:

1. Verify the certificate has both serverAuth and clientAuth:
   ```bash
   openssl x509 -in coturn-cert.pem -text -noout | grep -A 3 "Extended Key Usage"
   ```

2. If output doesn't show both `TLS Web Server Authentication` and `TLS Web Client Authentication`, regenerate the certificate:
   - Follow Step 2 to create a new CSR with proper EKU flags
   - Follow Step 3 to sign it with your CA
   - Continue with Steps 5-7 to deploy

### Coturn Pod Fails to Start

**Symptom**: Pod enters `CrashLoopBackOff` after Helm upgrade.

**Solution**:

1. Check pod events:
   ```bash
   COTURN_POD=$(kubectl get pods -l app=coturn -n default -o jsonpath='{.items[0].metadata.name}')
   kubectl describe pod $COTURN_POD -n default
   ```

2. Check pod logs:
   ```bash
   kubectl logs $COTURN_POD -n default --previous
   ```

3. Verify the Secret data is valid:
   ```bash
   kubectl get secret coturn-dtls-certificate -n default -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | head -5
   ```

4. Check for YAML syntax errors in values file:
   ```bash
   helm lint ./charts/coturn -f values/coturn/values.yaml
   ```

5. If issues persist, rollback to previous Helm revision:
   ```bash
   helm rollback coturn -n default
   kubectl rollout status statefulset/coturn -n default
   ```

### Helm Upgrade Stuck or Slow

**Symptom**: `helm upgrade` command takes a long time or appears hung.

**Solution**:

1. Check pod restart status:
   ```bash
   kubectl get pods -n default | grep coturn
   ```

2. Increase timeout if needed:
   ```bash
   helm upgrade coturn ./charts/coturn -f values/coturn/values.yaml -n default --wait --timeout 10m
   ```

3. Check StatefulSet rollout status:
   ```bash
   kubectl rollout status statefulset/coturn -n default
   ```

### Certificate Signed by Wrong CA

**Symptom**: Certificate looks valid locally but federation partners can't authenticate.

**Solution**:

1. Verify certificate issuer matches your CA:
   ```bash
   openssl x509 -in coturn-cert.pem -noout -issuer
   ```

2. Verify the CA that signed the certificate:
   ```bash
   openssl x509 -in coturn-cert.pem -noout -text | grep -A 2 "Issuer:"
   ```

3. If wrong CA was used, regenerate the certificate using the correct CA:
   ```bash
   # Follow Step 2 to create a new CSR
   # Follow Step 3 to sign it with the CORRECT CA
   # Verify in Step 4 that issuer matches your trusted CA
   # Continue with Steps 5-7 to deploy
   ```

## Certificate Renewal

Renewal follows the same process as initial deployment (Steps 2–8). Your CA is already trusted by Wire Cloud — no need to notify them again. Plan renewal at least 30 days before expiry:

```bash
openssl x509 -in coturn-cert.pem -noout -dates
```

Then follow Steps 2–8 using your existing `my-ca.pem` and `my-ca-key.pem`.

### Rollback

If something goes wrong, rollback to the previous Helm release:

```bash
helm history coturn -n default
helm rollback coturn <revision> -n default
kubectl rollout status statefulset/coturn -n default
```

## Related Documentation

- [Coturn Installation](../install/) - General coturn setup in wire-server-deploy
- [Wire-Server TLS Configuration](tls.md) - TLS certificate management
- [Federation Configuration](../../understand/federation.md) - Understanding federation in Wire
