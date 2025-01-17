# Implementation plan

There are two types of implementation: demo and production.

## Demo installation (trying functionality out)

Please note that there is no way to migrate data from a demo
installation to a production installation - it is really meant as a way
to try things out.

Please note your data will be in-memory only and may disappear at any given moment!

What you need:

- a way to create **DNS records** for your domain name (e.g.
  `wire.example.com`)
- a way to create **SSL/TLS certificates** for your domain name (to allow
  connecting via `https://`)
- Either one of the following:
  - A kubernetes cluster (some cloud providers offer a managed
    kubernetes cluster these days).
  - One single virtual machine running ubuntu 18.04 with at least 20 GB of disk, 8 GB of memory, and 8 CPU cores.

A demo installation will look a bit like this:

![image](img/architecture-demo.png)

### Next steps for demo installation

If you already have a kubernetes cluster, your next step will be [Installing wire-server (demo) components using helm](helm.md#helm), otherwise, your next step will be [Installing kubernetes for a demo installation (on a single virtual machine)](kubernetes.md#ansible-kubernetes)

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
