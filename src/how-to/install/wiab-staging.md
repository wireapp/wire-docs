# WIAB Staging Deployment Guide

## Introduction

**Wire in a Box (WIAB) Staging** is a staging installation of Wire running on a single physical machine using KVM-based virtual machines. This setup replicates the multi-node production Wire architecture in a consolidated environment suitable for testing, evaluation, and learning about Wire's infrastructure—but **not for production use**.

> **Important:** This is a sandbox environment. Data from a staging installation **cannot be migrated to production**. WIAB Staging is designed for experimentation, validation, and understanding Wire's deployment model.

For a high-level comparison of WIAB Dev, WIAB Staging, and Production, see the [planning overview](planning.md) (in particular, [Artifact bundle and offline deployment](planning.md#artifact-bundle-and-offline-deployment)).

## Architecture overview

![Wire in a Box Staging Architecture](img/architecture-wiab-stag.png)

## Relation to production

WIAB Staging is designed to be structurally similar to a production deployment:

- Separate nodes for Kubernetes and stateful services.
- Use of offline artifacts, Ansible, and Helm for installation similar to production workflows.
- Able to test upgrade proceedures for production.

Key differences from production:

- All VMs run on a single physical host (single failure domain).
- Resource sizing is optimized for staging, not for peak production traffic.
- Calling services run with limited resources (replicas=1).
- [Calling services](../../understand/overview.md#calling) will share the same k8s cluster as Wire stateful services hence, all infrastructure will be DMZ (De-militarized zone).

If you need a fully supported, highly-available, secure, multi-datacenter deployment, use the **Production** path instead (see `ansible-VMs.md` and `helm-prod.md`).

## Requirements

- One physical machine with hypervisor support (KVM):
  - **Memory:** 55 GiB RAM
  - **Compute:** 29 vCPUs  (At least processor 6 cores)
  - **Storage:** 850 GB disk space (thin-provisioned)
  - 7 VMs with [Ubuntu 22](https://releases.ubuntu.com/jammy/) as per (#VM-Provisioning)
- **DNS Records**: 
    - a way to create DNS records for your domain name (e.g. wire.example.com) 
    - See [DNS Requirements for Wire Deployments](dns-requirements.md) for the full list of required hostnames and examples.
- **SSL/TLS certificates**:
    - a way to create SSL/TLS certificates for your domain name (to allow connecting via https://)
    - To simplify certificate management, we recommend using **Let’s Encrypt** together with **cert-manager** where internet access is available. See [TLS and Certificates](tls-certificates.md) to choose between cert‑manager + Let’s Encrypt and bring‑your‑own certificates.
- **Network**: 
    - SSH to the physical host and to the VMs.
    - HTTP/HTTPS and UDP traffic from clients to the cluster, without interference from host-level firewalls (UFW, nftables) on required ports.
    - IP forwarding between the host’s network interfaces when following the reference topology. Check [Network Traffic Configuration](#network-traffic-configuration) for more details.
- **Wire-server-deploy artifact**: Access to a `wire-server-deploy` offline artifact bundle (contact Wire support for the latest stable artifact). This tarball contains all required Bash scripts, deb packages, Ansible playbooks, Helm charts and container images to perform the installation. See the [planning overview](planning.md#artifact-bundle-and-offline-deployment) for how artifacts are used across WIAB Dev, WIAB Staging and Production.

> Note: Check [WIAB Dev](./planning.md#wiab-dev-single-vm-wire-in-a-box) solution if looking for more light weight installation of wire-server.

## VM Provisioning

We would require 7 VMs as per the following details, you can choose to use your own hypervisor to manage the VMs or use our [Wiab staging ansible provisioning playbook](https://github.com/wireapp/wire-server-deploy/blob/master/ansible/wiab-staging-provision.yml) against your physical node to setup the VMs.

**VM Architecture and Resource Allocation:**

| Hostname | Role | RAM | vCPUs | Disk |
|----------|------|-----|-------|------|
| assethost | Asset/Storage Server | 4 GiB | 2 | 100 GB |
| kubenode1 | Kubernetes Node 1 | 9 GiB | 5 | 150 GB |
| kubenode2 | Kubernetes Node 2 | 9 GiB | 5 | 150 GB |
| kubenode3 | Kubernetes Node 3 | 9 GiB | 5 | 150 GB |
| datanode1 | Data Node 1 | 8 GiB | 4 | 100 GB |
| datanode2 | Data Node 2 | 8 GiB | 4 | 100 GB |
| datanode3 | Data Node 3 | 8 GiB | 4 | 100 GB |
| **Total** | | **55 GiB** | **29** | **850 GB** |

*Note: These specifications are optimized for testing and validation purposes, not for performance benchmarking.*

**VM Service Distribution:**

- **kubenodes (kubenode1, kubenode2, kubenode3):** Run the Kubernetes cluster and host Wire backend services
- **datanodes (datanode1, datanode2, datanode3):** Run distributed data services:
  - Cassandra
  - PostgreSQL
  - Elasticsearch
  - Minio
  - RabbitMQ
- **assethost:** Hosts static assets like container images and debian binaries to be used by kubenodes and datanodes during installation.

## Getting the Ansible playbooks

> **Note:** If you prefer to manage VMs yourself with another hypervisor, you can skip this step and instead create the VMs manually with the specs shown above. Along with VM creation, you need to perform a few more steps like downloading the [wire-server-deploy artifact](planning.md#artifact-bundle-and-offline-deployment) and [setup network configuration](#network-traffic-configuration) including the firewall rules.

On an admin machine (your workstation or the physical host), obtain the `wire-server-deploy` repository:

- **Download as ZIP:**
  ```bash
  # requirements: wget and unzip 
  wget https://github.com/wireapp/wire-server-deploy/archive/refs/heads/master.zip
  unzip master.zip
  cd wire-server-deploy-master
  ```
- **Or clone with Git:**
  ```bash
  # requirements: git
  git clone https://github.com/wireapp/wire-server-deploy.git
  cd wire-server-deploy
  ```

You will use the `ansible` directory from this repository, along with the offline artifact bundle.

### WIAB staging ansible playbook overview

The ansible playbook will perform the following operations for you:

**System Setup & Networking**:
  - Updates all system packages and installs required tools (git, curl, docker, qemu, libvirt, yq, etc.)
  - Configures SSH, firewall (nftables), and user permissions (sudo, kvm, docker groups)

**wire-server-deploy Artifact & Ubuntu Cloud Image**:
  - Downloads wire-server-deploy static artifact and Ubuntu cloud image using public internet
  - Extracts artifacts and sets proper file permissions
  - *Note: The wire-server-deploy artifact downloaded corresponds to the currently supported wire-server backend version*

**Libvirt Network Setup and VM Creation**:
  - Removes default libvirt network and creates custom "wirebox" network
  - Launches VMs using the [offline-vm-setup.sh](https://github.com/wireapp/wire-server-deploy/blob/master/bin/offline-vm-setup.sh) bash script with KVM
  - Creates an SSH key directory at `/home/ansible_user/wire-server-deploy/ssh` for VM access

**Ansible Inventory Generation**:
  - Generates inventory.yml with actual VM IPs replacing placeholders
  - Configures network interface variables for all k8s-nodes and datanodes

*Note: Skip the Ansible playbook step if you are managing VMs with your own hypervisor.* 

### Provisioning the VMs with the WIAB Staging playbook

If you want Ansible to create and configure the 7 VMs for you on a single physical host, use the WIAB Staging playbook.
> Note: the SSH user for ansible `ansible_user` should have password-less `sudo` access. The physical host should be running Ubuntu 22.04.
1. Prepare an inventory for the physical host, based on [ansible/inventory/demo/wiab-staging.yml](https://github.com/wireapp/wire-server-deploy/blob/master/ansible/inventory/demo/wiab-staging.yml).
2. Adjust values such as:
   - Physical host address of adminhost eg. `example.com` and SSH user eg.`demo`
   - Ssh key to access the node `ansible_ssh_private_key_file='~/.ssh/id_ed25519'`
3. Run the provisioning playbook:
   ```bash
   ansible-playbook -i ansible/inventory/demo/wiab-staging.yml ansible/wiab-staging-provision.yml
   ```

*Note: Ansible core version 2.16.3 or compatible is required for this step*

## Secondary inventory for the VMs

Once the 7 VMs are running, ensure you have a **second Ansible inventory** that describes them based on [staging.yaml inventory](https://github.com/wireapp/wire-server-deploy/blob/master/ansible/inventory/offline/staging.yml) for further operations. In the offline bundle layout, this is typically `ansible/inventory/offline/inventory.yml` under `/home/ansible_user/wire-server-deploy` on the asset host or admin host.

> Note: If you have already used the [Wiab staging ansible provisioning playbook](#provisioning-the-vms-with-the-wiab-staging-playbook) to set up VMs, this file should have been prepared for you.

In that inventory you will:

- Set `ansible_user` (this user should have passwordless `sudo` access) and `ansible_ssh_private_key_file` under `all` vars.
- Assign each VM to the appropriate groups, for example:
  - `kube-master`, `kube-node`, `etcd` for Kubernetes nodes.
  - `datanodes` which will further map to `cassandra`, `cassandra_seed`, `elasticsearch`, `minio`, `rmq-cluster`, `postgresql` for data services.
  - `assethost` for assethost service

For a deeper explanation of offline inventories and VM roles in production-like setups, see [Installing kubernetes and databases on VMs with ansible](ansible-VMs.md#ansible-vms).

## Next steps

Since the secondary inventory is ready, please continue with the following steps:

> **Note**: All next steps assume that the wire-server-deploy artifact has been downloaded on the `adminhost` (your physical machine) and extracted at `/home/ansible_user/wire-server-deploy`. All commands from here on will be issued from this directory on the `adminhost`, ssh on the node before proceeding.

### Environment Setup

- **[Making tooling available in your environment](dependencies.md#making-tooling-available-in-your-environment)** 
  ```bash
  source bin/offline-env.sh
  ```
  Source the `bin/offline-env.sh` shell script by running to set up a `d` alias that runs commands inside a Docker container with all necessary tools for offline deployment.

- **Generating secrets** 
  ```bash
  # without the alias `d`
  ./bin/offline-secrets.sh
  ```
  Run to generate fresh secrets for Minio, coturn and Wire services. This creates secret files such as `ansible/inventory/group_vars/all/secrets.yaml` and `values/wire-server/secrets.yaml`. To understand which secrets are generated and where they are stored across Ansible and Helm, see [Secrets Overview](secrets-overview.md).

### Kubernetes & Data Services Deployment

- **Deploying Kubernetes and stateful services**
  ```bash
  d ./bin/offline-cluster.sh
  ```
  Run to deploy Kubernetes and stateful services (Cassandra, PostgreSQL, Elasticsearch, Minio, RabbitMQ). This script deploys all datastore infrastructure needed for Wire backend operations.

### Helm Operations to install Wire services and supporting Helm charts

**Helm chart deployment (automated):** The script `bin/helm-operations.sh` will deploy the charts for you. It prepares `values.yaml`/`secrets.yaml`, customizes them for your domain/IPs, then runs Helm installs in the correct order. For a detailed, production-focused reference of the same charts, see [Installing wire-server (production) components using Helm](helm-prod.md#helm-prod).

**User-provided inputs (set these before running):**
- `TARGET_SYSTEM`: your domain (e.g., `wire.example.com` or `example.dev`).
- `CERT_MASTER_EMAIL`: email used by cert-manager for ACME registration.
- `HOST_IP`: public IP that matches your DNS A record (auto-detected if empty).

**TLS / certificate behavior (cert-manager vs. Bring Your Own):**
- By default, `bin/helm-operations.sh` has `DEPLOY_CERT_MANAGER=TRUE`, which installs cert-manager and configures a Let’s Encrypt (HTTP-01) issuer for the ingress charts.
- If you **do not** want Let’s Encrypt / cert-manager (for example, you are using **[Bring Your Own certificates](docs_ubuntu_22.04.md#acquiring--deploying-ssl-certificates)**), disable this step by passing env variable `DEPLOY_CERT_MANAGER=FALSE` when running `bin/helm-operations.sh`.
  - When choosing `DEPLOY_CERT_MANAGER=FALSE`, ensure your ingress is configured and deployed with your own TLS secret(s) as described at [TLS and Certificates](tls-certificates.md).
  - When choosing `DEPLOY_CERT_MANAGER=TRUE`, ensure if further network configuration is required by following [cert-manager behaviour in NAT / bridge environments](#cert-manager-behaviour-in-nat--bridge-environments).

**To run the automated helm chart deployment with your variables**:
```bash
# example command - verify the variables before running it
d sh -c 'TARGET_SYSTEM="example.dev" CERT_MASTER_EMAIL="certmaster@example.dev" DEPLOY_CERT_MANAGER=TRUE ./bin/helm-operations.sh'
```

**Charts deployed by the script:**
- External datastores and helpers: `cassandra-external`, `elasticsearch-external`, `minio-external`, `rabbitmq-external`, `postgresql-external`, `databases-ephemeral`, `reaper`, `fake-aws`, `demo-smtp`.
- Wire services: `wire-server`, `webapp`, `account-pages`, `team-settings`, `smallstep-accomp`.
- Ingress and certificates: `ingress-nginx-controller`, `cert-manager`, `nginx-ingress-services`.
- Calling services: `sftd`, `coturn`.

**Values and secrets generation:**
- Creates `values.yaml` and `secrets.yaml` from `prod-values.example.yaml` and `prod-secrets.example.yaml` for each chart under `values/`.
- Backs up any existing `values.yaml`/`secrets.yaml` before replacing them.

*Note: The `bin/helm-operations.sh` script above deploys these charts; you do not need to run the Helm commands manually unless you want to customize or debug.*

## Network Traffic Configuration

### Bring traffic from the physical machine to Wire services in the k8s cluster

If you used the Ansible playbook [earlier](#provisioning-the-vms-with-the-wiab-staging-playbook), nftables firewall rules are pre-configured to forward traffic. If you set up VMs manually with your own hypervisor, you must manually configure network traffic flow using nftables as descibed below.

**Required Network Configuration:**

The physical machine (adminhost) must forward traffic from external clients to the Kubernetes cluster running Wire services. This involves:

1. **HTTP/HTTPS Traffic (Ingress)** - Forward ports 80 and 443 to the nginx-ingress-controller running on a Kubernetes node
   - Port 80 (HTTP) → Kubernetes node port 31772
   - Port 443 (HTTPS) → Kubernetes node port 31773

2. **Calling Services Traffic (Coturn/SFT)** - Forward media and TURN protocol traffic to Coturn/SFT
   - Port 3478 (TCP/UDP) → Coturn control traffic
   - Ports 32768-65535 (UDP) → Media relay traffic for WebRTC calling

> See [Network Ports and Connectivity](network-ports.md) for the full port matrix and production DMZ considerations.

**Implementation:**

Use the detailed nftables rules in [../ansible/files/wiab_server_nftables.conf.j2](https://github.com/wireapp/wire-server-deploy/blob/master/ansible/files/wiab_server_nftables.conf.j2) as the template. The nftable configuration template covers:
- Defining your network variables (Coturn IP, Kubernetes node IP, WAN interface)
- Creating NAT rules for HTTP/HTTPS ingress traffic
- Setting up TURN protocol forwarding for Coturn and traffic for SFTD

*Note: If you have already ran the playbook wiab-staging-provision.yml then it is already be configured for you. Confirm it by checking if the wire endpoint `https://webapp.TARGET_SYSTEM` is reachable from public internet or your private network (in case of private network), but not from the adminhost itself.*

You can also apply these rules using the Ansible playbook against your adminhost, by following:

```bash
# create the inventory.yml before running it
ansible-playbook -i inventory.yml ansible/wiab-staging-nftables.yml
```

You can run the above playbook from local system or where you have cloned/downloaded the [Wire server deploy ansible playbooks](#getting-the-ansible-playbooks).

The inventory `inventory.yml` should define the following variables:

```ini
[all:vars]
# Kubernetes node IPs
kubenode1_ip=192.168.122.11
kubenode2_ip=192.168.122.12
kubenode3_ip=192.168.122.13

# Calling services node (usually kubenode3)
calling_node_ip=192.168.122.13

# Host WAN interface name
inf_wan=eth0

# These are the same as wiab-staging.yml
# user and ssh key for adminhost
ansible_user='demo'
ansible_ssh_private_key_file='~/.ssh/id_ed25519'

```

### cert-manager behaviour in NAT / bridge environments

When cert-manager performs HTTP-01 self-checks inside the cluster, traffic can hairpin:

- Pod → Node → host public IP → DNAT → Node → Ingress

In NAT/bridge setups (for example, using `virbr0` on the host):

- If nftables rules DNAT in `PREROUTING` without a matching SNAT on `virbr0 → virbr0`, return packets may bypass the host and break conntrack, causing HTTP-01 timeouts and certificate verification failures.
- Strict `rp_filter` can drop asymmetric return packets.

Before changing anything, first verify whether certificate issuance is actually failing:

1. Check whether certificates are successfully issued:
   ```bash
   d kubectl get certificates
   ```
2. If certificates are not in `Ready=True` state, inspect cert-manager logs for HTTP-01 self-check or timeout errors:
   ```bash
   d kubectl logs -n cert-manager-ns <cert-manager-pod-id>
   ```

If you observe HTTP-01 challenge timeouts or self-check failures in a NAT/bridge environment, hairpin SNAT and relaxed reverse-path filtering handling may be required. One possible approach is:

- Relax reverse-path filtering to loose mode to allow asymmetric flows:
  ```bash
  sudo sysctl -w net.ipv4.conf.all.rp_filter=2
  sudo sysctl -w net.ipv4.conf.virbr0.rp_filter=2
  ```
  These settings help conntrack reverse DNAT correctly and avoid drops during cert-manager’s HTTP-01 challenges in NAT/bridge (`virbr0`) environments.

- Enable Hairpin SNAT (temporary for cert-manager HTTP-01):
  ```bash
  sudo nft insert rule ip nat POSTROUTING position 0 \
    iifname "virbr0" oifname "virbr0" \
    ip daddr 192.168.122.0/24 ct status dnat \
    counter masquerade \
    comment "wire-hairpin-dnat-virbr0"
  ```
  This forces DNATed traffic that hairpins over the bridge to be masqueraded, ensuring return traffic flows back through the host and conntrack can correctly reverse the DNAT.

  Verify the rule was added:
  ```bash
  sudo nft list chain ip nat POSTROUTING
  ```
  You should see a rule similar to:
  ```
  iifname "virbr0" oifname "virbr0" ip daddr 192.168.122.0/24 ct status dnat counter masquerade # handle <id>
  ```

- Remove the rule after certificates are issued:
  ```bash
  d kubectl get certificates
  ```

  Once Let’s Encrypt validation completes and certificates are issued, remove the temporary hairpin SNAT rule. Use the following pipeline to locate the rule handle and delete it safely:
  ```bash
  sudo nft -a list chain ip nat POSTROUTING | \
    grep wire-hairpin-dnat-virbr0 | \
    sed -E 's/.*handle ([0-9]+).*/\1/' | \
    xargs -r -I {} sudo nft delete rule ip nat POSTROUTING handle {}
  ```

For additional background on when hairpin NAT is required and how it relates to WIAB Dev and WIAB Staging, see [Hairpin networking for WIAB Dev and WIAB Staging](tls-certificates.md#hairpin-networking-for-wiab-dev-and-wiab-staging).

## Next steps and troubleshooting

- To understand individual Helm charts and their configuration options, see [Installing wire-server (production) components using Helm](helm-prod.md#helm-prod).
- For Kubernetes and database Ansible roles, see [Installing kubernetes and databases on VMs with ansible](ansible-VMs.md#ansible-vms).
- For TLS and certificates, see [TLS and Certificates](tls-certificates.md).
- For DNS and network ports, refer to [DNS Requirements for Wire Deployments](dns-requirements.md) and [Network Ports and Connectivity](network-ports.md).

If something goes wrong:

- Check pod status: `d kubectl get pods -A`.
- Inspect Helm releases: `d helm list -A`.
- Review Ansible output for failed tasks.

WIAB Staging is intended to be a safe place to experiment – you can always tear down the VMs and redeploy from scratch once you have corrected your configuration.
