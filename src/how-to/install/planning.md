# Implementation plan

There are two types of implementation: demo and production.

## Demo installation (trying functionality out)

Please note that there is no way to migrate data from a demo
installation to a production installation - it is really meant as a way
to try things out.

Please note your data will be in-memory only and may disappear at any given moment!

### What you need:

- **System**: Ubuntu 24.04 (Focal) on amd64 architecture with following requirements:
    - CPU cores >= 16
    - Memory > 16 GiB
    - Disk > 200 GiB
- **DNS Records**: 
    - a way to create DNS records for your domain name (e.g. wire.example.com) 
    - Find a detailed explanation at [How to set up DNS records](demo-wiab.md#dns-requirements)
- **SSL/TLS certificates**:
    - a way to create SSL/TLS certificates for your domain name (to allow connecting via https://)
    - To ease out the process of managing certs, we recommend using [Let\'s Encrypt](https://letsencrypt.org/getting-started/) &
[cert-manager](https://cert-manager.io/docs/tutorials/acme/http-validation/)
- **Network**: No interference from UFW or other system specific firewalls, and IP forwarding enabled between network cards. Public internet access to download Wire artifacts and Ubuntu packages.
- **Packages**: Ansible and unzip (or git) on the localhost (any machine you have access to)
    - Ansible version: [core 2.16.3] or compatible
    - Note: The deployment will automatically install additional required packages on the deploy_node (see [Package Installation](#4-package-installation) section). You can skip this step using `--skip-tags install_pkgs` if these packages are already installed
- **Permissions**: Sudo access required for installation on remote_node
- **Ansible Playbooks**: 
  - The `ansible` directory from [wire-server-deploy repository](https://github.com/wireapp/wire-server-deploy)
  - Obtain it using **either** method:
    - **Download as ZIP:** [wire-server-deploy/archive/master.zip](https://github.com/wireapp/wire-server-deploy/archive/refs/heads/master.zip) (requires unzip)
    - **Clone with Git:** `git clone https://github.com/wireapp/wire-server-deploy.git` (requires git)
- **Network Access Requirements**:

| Protocol | Port(s)     | Purpose                                    |
|----------|-------------|--------------------------------------------|
| TCP      | 22          | SSH access (for remote management)         |
| TCP      | 80          | HTTP (certificate renewal)                 |
| TCP      | 443         | HTTPS (primary Wire access)                |
| TCP      | 3478        | Alternative STUN/TURN traffic              |
| UDP      | 3478        | STUN/TURN for voice/video calls            |
| UDP      | 32768-65535 | Voice/video calling traffic (Coturn/SFTD)  |

- Note: If outbound traffic is restricted, [Note on port ranges](https://docs.wire.com/latest/understand/notes/port-ranges.html) should be followed.


### Next steps for demo installation

When the above [requirements](#what-you-need) are achieved, continue with  the ansible playbook instructions for the [demo wire in a box](demo-wiab.md) installation. 


<a id="planning-prod"></a>

## Production installation (persistent data, high-availability)

What you need:

- a way to create **DNS records** for your domain name (e.g. `wire.example.com`)
- a way to create **SSL/TLS certificates** for your domain name (to allow connecting via `https://wire.example.com`)
- A **kubernetes cluster with at least 3 worker nodes and at least 3 etcd nodes** (some cloud providers offer a managed kubernetes cluster these days)
- minimum **17 virtual machines** for components outside kubernetes (cassandra, minio, elasticsearch, redis, restund)

A recommended installation of Wire-server in any regular data centre,
configured with high-availability will require the following virtual
servers:

| Name                                                 | Amount   | CPU Cores    | Memory (GB)   | Disk Space (GB)   |
|------------------------------------------------------|----------|--------------|---------------|-------------------|
| Cassandra                                            | 3        | 2            | 4             | 80                |
| MinIO                                                | 3        | 1            | 2             | 400               |
| ElasticSearch                                        | 3        | 1            | 2             | 60                |
| Kubernetes³                                          | 3        | 6¹           | 8             | 40                |
| Restund⁴                                             | 2        | 1            | 2             | 10                |
| **Per-Server Totals**                                | —        | 11 CPU Cores | 18 GB Memory  | 590 GB Disk Space |
| Admin Host²                                          | 1        | 1            | 4             | 40                |
| Asset Host²                                          | 1        | 1            | 4             | 100               |
| **Per-Server Totals with<br/>Admin and Asset Hosts** | —        | 13 CPU Cores | 26 GB Memory  | 730 GB Disk Space |
- ¹ Kubernetes hosts may need more ressources to support SFT (Conference Calling). See “Conference Calling Hardware Requirements” below.
- ² Admin and Asset Hosts can run on any one of the 3 servers, but that server must not allocate additional resources as indicated in the table above.
- ³ Etcd is run inside of Kubernetes, hence no specific resource allocation
- ⁴ Restund may be hosted on only 2 of the 3 servers, or all 3. Two nodes are enough to ensure high availability of Restund services

General Hardware Requirements

- Minimum 3 physical servers required
- Wire has a minimum requirement for a total of 16 Ubuntu 18.04 virtual machines across the 3 servers (in accordance with the table above)

Conference Calling Hardware Requirements

- Kubernetes Hosts may need additional resources for SFT services. For concurrent SFT users (SFT = Selective Forwarding Turn-server, ie. Conference calling), we recommend an extra 3% of CPU allocation, evenly distributed across the nodes (i.e. 1% more CPU per kubernetes server). So for every 100 users plan on adding one CPU core on each Kubernetes node. The SFT component runs inside of Kubernetes, and does not require a separate virtual machine for operation.

A production installation will look a bit like this:

![image](img/architecture-server-ha.png)

If you use a private datacenter (not a cloud provider), the easiest is
to have three physical servers, each with one virtual machine for each
server component (cassandra, minio, elasticsearch, redis, kubernetes,
restund)

It’s up to you how you create these VMs - kvm on a bare metal machine,
VM on a cloud provider, etc. Make sure they run ubuntu 18.04.

Ensure that your VMs have IP addresses that do not change.

Avoid `10.x.x.x` network address schemes, and instead use something like `192.168.x.x` or `172.x.x.x`. This is because internally, Kubernetes already uses a `10.x.x.x` address scheme, creating a potential conflict.

### Next steps for high-available production installation

Your next step will be [Installing kubernetes and databases on VMs with ansible](ansible-VMs.md#ansible-vms)
