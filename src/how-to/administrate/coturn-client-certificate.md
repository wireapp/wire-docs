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
  -addext "subjectAltName=DNS:coturn.example.com,DNS:coturn-0.coturn.default.svc.cluster.local,DNS:coturn-1.coturn.default.svc.cluster.local" \
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
  -extfile <(printf "subjectAltName=DNS:coturn.example.com,DNS:coturn-0.coturn.default.svc.cluster.local,DNS:coturn-1.coturn.default.svc.cluster.local\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth,clientAuth")
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
nodeSelector:
  wire.com/role: coturn

replicaCount: 3
coturnTurnListenIP: "__COTURN_POD_IP__"
coturnTurnExternalIP: "__COTURN_EXT_IP__"
coturnTurnRelayIP: "__COTURN_POD_IP__"

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

# Existing secrets configuration
secrets:
  zrestSecrets:
    - "<your-turn-secret>"

# Rate limiting allowlist for federation.
# Add all IPs that coturn must accept connections from without rate limiting:
#
#   1. Internal node IPs — the Kubernetes node IPs where coturn pods are scheduled.
#      Add one entry per node.
#
#   2. Cluster gateway / NAT IP — if your cluster routes outgoing traffic through
#      a single gateway or NAT IP, add that IP too (coturn sees it as the source).
#
#   3. Public (external) IPs of each coturn replica — the IPs advertised externally
#      for each StatefulSet pod (coturn-0, coturn-1, coturn-2, ...).
#
#   4. Federation partner IPs — IP addresses or CIDR ranges of Wire Cloud or other
#      federation partners that connect to coturn on port 9191.
#
# Example:
config:
  verboseLogging: false
  ratelimit:
    allowlist:
      - "192.168.1.10"    # node-1 internal IP
      - "192.168.1.11"    # node-2 internal IP
      - "192.168.1.12"    # node-3 internal IP
      - "192.168.1.1"     # cluster gateway / NAT IP (if applicable)
      - "203.0.113.10"    # coturn-0 external/public IP
      - "203.0.113.11"    # coturn-1 external/public IP
      - "203.0.113.12"    # coturn-2 external/public IP
      - "198.51.100.0/24" # federation partner IP range
```

### Example YAML Values

```yaml
federate:
  dtls:
    tls:
      key: |
        -----BEGIN PRIVATE KEY-----
        MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7W8z1K2...
        -----END PRIVATE KEY-----
      crt: |
        -----BEGIN CERTIFICATE-----
        MIIDazCCAlOgAwIBAgIUfQ2Z7x8zV0Q8JvZ0Q0Q0Q0Q0Q0AwDQYJKoZIhvcNAQEL...
        -----END CERTIFICATE-----
```

## Step 7: Deploy Coturn with Updated Configuration

**Prerequisite**: The coturn chart must be at version `0.0.44` or later. Support for manually providing a self-signed certificate via `federate.dtls.tls.key`/`crt` was added in this version — earlier versions only support cert-manager-managed certificates. Verify your chart version:

```bash
helm show chart ./charts/coturn | grep '^version:'
```

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

Or if using helmfile:

```bash
helmfile sync
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

## Complete Example

This example shows the full end-to-end workflow. Replace `coturn.example.com`, the subject fields, and the replica SANs with your actual FQDN and organization details.

### Step 1: Create Your Self-Signed CA (One-Time Setup)

Create your own CA to manage federation independently:

```bash
# Generate CA private key (2048-bit RSA)
openssl genrsa -out my-ca-key.pem 2048

# Create CA certificate signing request
openssl req -new \
  -key my-ca-key.pem \
  -out my-ca.csr \
  -subj "/C=XX/O=Your Organization/CN=Your Organization CA"

# Self-sign CA certificate (valid 10 years = 3650 days)
openssl x509 -req \
  -in my-ca.csr \
  -signkey my-ca-key.pem \
  -out my-ca.pem \
  -days 3650 \
  -extfile <(printf "basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid:always,issuer:always")
```

**Result**: Three files
- `my-ca.pem` - CA certificate (send this to Wire Cloud)
- `my-ca-key.pem` - CA private key (keep secure, needed for renewals)
- `my-ca.csr` - Can be deleted

**Next**: Send `my-ca.pem` to Wire Cloud to add to their federation trust store.

### Step 2: Create Coturn Certificate Signed by Your CA

Once Wire Cloud has added your CA to their trust store, create the coturn certificate:

```bash
# Generate coturn private key and CSR in one command
openssl req -noenc -newkey rsa:2048 \
  -keyout coturn-federation-key.pem \
  -out coturn-federation.csr \
  -subj "/C=XX/O=Your Organization/CN=coturn.example.com"

# Sign with your CA (valid 1 year)
openssl x509 -req -days 365 \
  -in coturn-federation.csr \
  -CA my-ca.pem \
  -CAkey my-ca-key.pem \
  -CAcreateserial \
  -out coturn-federation-cert.pem \
  -sha256 \
  -extfile <(printf "subjectAltName=DNS:coturn.example.com,DNS:coturn-0.example.com,DNS:coturn-1.example.com,DNS:coturn-2.example.com\nextendedKeyUsage=serverAuth,clientAuth")
```

**Result**: Three files
- `coturn-federation-cert.pem` - Signed coturn certificate
- `coturn-federation-key.pem` - Coturn private key
- `coturn-federation.csr` - Can be deleted

### Step 3: Verify the Certificate

```bash
# Verify it's signed by your CA
openssl verify -CAfile my-ca.pem coturn-federation-cert.pem
# Output: coturn-federation-cert.pem: OK

# Check Extended Key Usage
openssl x509 -in coturn-federation-cert.pem -noout -text | grep -A 3 "Extended Key Usage"
# Output should show: TLS Web Server Authentication, TLS Web Client Authentication

# Check Subject Alternative Names
openssl x509 -in coturn-federation-cert.pem -noout -text | grep -A 1 "Subject Alternative Name"
# Output should show: DNS:coturn.example.com, DNS:coturn-0/1/2.example.com

# Check validity dates
openssl x509 -in coturn-federation-cert.pem -noout -dates
# Output: notBefore=... notAfter=... (1 year from now)
```

### Step 4: Deploy

Update `values/coturn/values.yaml` with the PEM content:

```yaml
federate:
  dtls:
    tls:
      key: |
        -----BEGIN PRIVATE KEY-----
        <paste coturn-federation-key.pem content here>
        -----END PRIVATE KEY-----
      crt: |
        -----BEGIN CERTIFICATE-----
        <paste coturn-federation-cert.pem content here>
        -----END CERTIFICATE-----
```

Deploy:

```bash
helm upgrade coturn ./charts/coturn \
  -n default \
  -f values/coturn/values.yaml \
  --wait \
  --timeout 5m
```

### Step 5: Verify in Kubernetes

```bash
# Get pod name
COTURN_POD=$(kubectl get pods -l app=coturn -n default -o jsonpath='{.items[0].metadata.name}')

# Verify certificate is deployed
kubectl exec $COTURN_POD -- openssl x509 -in /coturn-dtls-certificate/tls.crt -noout -dates

# Verify EKU
kubectl exec $COTURN_POD -- openssl x509 -in /coturn-dtls-certificate/tls.crt -text -noout | grep -A 3 "Extended Key Usage"
```

### Annual Certificate Renewal

When the certificate expires:

```bash
# Generate new private key and CSR
openssl req -noenc -newkey rsa:2048 \
  -keyout coturn-federation-key.pem \
  -out coturn-federation.csr \
  -subj "/C=XX/O=Your Organization/CN=coturn.example.com"

# Sign with EXISTING CA (same CA, already trusted by Wire Cloud)
openssl x509 -req -days 365 \
  -in coturn-federation.csr \
  -CA my-ca.pem \
  -CAkey my-ca-key.pem \
  -CAcreateserial \
  -out coturn-federation-cert.pem \
  -sha256 \
  -extfile <(printf "subjectAltName=DNS:coturn.example.com,DNS:coturn-0.example.com,DNS:coturn-1.example.com,DNS:coturn-2.example.com\nextendedKeyUsage=serverAuth,clientAuth")

# Update values/coturn/values.yaml — replace the key/crt block scalars with the new PEM content:
#   federate:
#     dtls:
#       tls:
#         key: |
#           -----BEGIN PRIVATE KEY-----
#           <new coturn-federation-key.pem content>
#           -----END PRIVATE KEY-----
#         crt: |
#           -----BEGIN CERTIFICATE-----
#           <new coturn-federation-cert.pem content>
#           -----END CERTIFICATE-----

helm upgrade coturn ./charts/coturn \
  -n default \
  -f values/coturn/values.yaml \
  --wait
```

**Key point**: No need to contact Wire Cloud again for renewal — the CA is already trusted. Just generate a new certificate signed by the same CA and deploy it.

---

## Certificate Renewal

When your coturn certificate approaches expiration (typically 365 days), you need to generate and deploy a new certificate signed by your CA before the old one expires.

### Renewal Process

1. **Generate a new CSR** (follow Step 2):
   ```bash
   # Create a new private key
   openssl genrsa -out coturn-key-new.pem 2048
   
   # Create a new certificate signing request
   openssl req -new \
     -key coturn-key-new.pem \
     -out coturn-new.csr \
     -subj "/C=US/ST=State/L=City/O=Your Organization/CN=coturn.example.com" \
     -addext "subjectAltName=DNS:coturn.example.com,DNS:coturn-0.coturn.default.svc.cluster.local,DNS:coturn-1.coturn.default.svc.cluster.local" \
     -addext "extendedKeyUsage=serverAuth,clientAuth" \
     -addext "keyUsage=digitalSignature"
   ```

2. **Sign the new certificate with your CA** (follow Step 3):
   ```bash
   openssl x509 -req -days 365 \
     -in coturn-new.csr \
     -CA my-ca.pem \
     -CAkey my-ca-key.pem \
     -CAcreateserial \
     -out coturn-cert-new.pem \
     -extfile <(printf "subjectAltName=DNS:coturn.example.com,DNS:coturn-0.coturn.default.svc.cluster.local,DNS:coturn-1.coturn.default.svc.cluster.local\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth,clientAuth")
   ```

3. **Verify the new certificate** (follow Step 4):
   ```bash
   openssl x509 -in coturn-cert-new.pem -text -noout | grep -A 3 "Extended Key Usage"
   openssl x509 -in coturn-cert-new.pem -noout -dates
   ```

4. **Prepare the new certificate and key** (follow Step 5):
   ```bash
   cat coturn-cert-new.pem
   cat coturn-key-new.pem
   ```

5. **Backup current values file**:
   ```bash
   cp values/coturn/values.yaml values/coturn/values.yaml.backup.$(date +%Y%m%d-%H%M%S)
   ```

6. **Update values file** with the new PEM certificate and key:
   ```yaml
   federate:
     dtls:
       tls:
         key: |
           -----BEGIN PRIVATE KEY-----
           <paste new PEM private key content here>
           -----END PRIVATE KEY-----
         crt: |
           -----BEGIN CERTIFICATE-----
           <paste new PEM certificate content here>
           -----END CERTIFICATE-----
   ```

7. **Verify YAML syntax**:
   ```bash
   helm lint ./charts/coturn -f values/coturn/values.yaml
   ```

8. **Redeploy coturn** with the new certificate (follow Step 7):
   ```bash
   helm upgrade coturn ./charts/coturn \
     -n default \
     -f values/coturn/values.yaml \
     --wait \
     --timeout 5m
   ```

9. **Verify deployment** (follow Step 8):
   ```bash
   COTURN_POD=$(kubectl get pods -l app=coturn -n default -o jsonpath='{.items[0].metadata.name}')
   
   # Check new certificate is deployed
   kubectl exec $COTURN_POD -- openssl x509 -in /coturn-dtls-certificate/tls.crt -noout -dates
   
   # Verify Extended Key Usage
   kubectl exec $COTURN_POD -- openssl x509 -in /coturn-dtls-certificate/tls.crt -text -noout | grep -A 3 "Extended Key Usage"
   ```

10. **Check Helm release history**:
    ```bash
    helm history coturn -n default
    ```

### Renewal Checklist

- [ ] Calculate expiration date: `openssl x509 -in coturn-cert.pem -noout -dates`
- [ ] Plan renewal at least 30 days before expiration
- [ ] Generate new CSR with same FQDN and EKU extensions
- [ ] Sign with your CA certificate
- [ ] Verify new certificate has correct EKU and issuer
- [ ] Backup current values file
- [ ] Prepare new PEM certificate and key files
- [ ] Update values file with new PEM content
- [ ] Run `helm lint` to verify YAML syntax
- [ ] Run `helm upgrade` with `--wait` flag
- [ ] Verify pod restart completed successfully
- [ ] Verify new certificate in pod
- [ ] Test federation DTLS connections
- [ ] Document renewal date in your records

### Rollback to Previous Certificate

If something goes wrong during renewal, rollback to the previous certificate:

```bash
# View Helm release history
helm history coturn -n default

# Rollback to the previous release (e.g., revision 5)
helm rollback coturn 5 -n default

# Verify rollback
kubectl rollout status statefulset/coturn -n default
```

## Related Documentation

- [Coturn Installation](../install/) - General coturn setup in wire-server-deploy
- [Wire-Server TLS Configuration](tls.md) - TLS certificate management
- [Federation Configuration](../../understand/federation.md) - Understanding federation in Wire
