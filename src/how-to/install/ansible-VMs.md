<a id="ansible-vms"></a>

# Installing kubernetes and databases on VMs with ansible

## Introduction

In a production environment, some parts of the wire-server
infrastructure (such as e.g. cassandra databases) are best configured
outside kubernetes. Additionally, kubernetes can be rapidly set up with
kubespray, via ansible. This section covers installing VMs with ansible.

## Assumptions

- A bare-metal setup (no cloud provider)
- All machines run ubuntu 18.04
- All machines have static IP addresses
- Time on all machines is being kept in sync
- You have the following virtual machines:

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

(It’s up to you how you create these machines - kvm on a bare metal
machine, VM on a cloud provider, real physical machines, etc.)

## Preparing to run ansible

<!-- TODO: section header unifications/change -->

### Adding IPs to hosts.ini

Go to your checked-out wire-server-deploy/ansible folder:

```default
cd wire-server-deploy/ansible
```

Copy the example hosts file:

```default
cp hosts.example.ini hosts.ini
```

- Edit the hosts.ini, setting the permanent IPs of the hosts you are
  setting up wire on.
- On each of the lines declaring a database service node (
  lines in the `[all]` section beginning with cassandra, elasticsearch,
  or minio) replace the `ansible_host` values (`X.X.X.X`) with the
  IPs of the nodes that you can connect to via SSH. these are the
  ‘internal’ addresses of the machines, not what a client will be
  connecting to.
- On each of the lines declaring a kubernetes node (lines in the `[all]`
  section starting with ‘kubenode’) replace the `ip` values
  (`Y.Y.Y.Y`) with the IPs which you wish kubernetes to provide
  services to clients on, and replace the `ansible_host` values
  (`X.X.X.X`) with the IPs of the nodes that you can connect to via
  SSH. If the IP you want to provide services on is the same IP that
  you use to connect, remove the `ip=Y.Y.Y.Y` completely.
- On each of the lines declaring an `etcd` node (lines in the `[all]`
  section starting with etcd), use the same values as you used on the
  coresponding kubenode lines in the prior step.
- If you are deploying Restund for voice/video services then on each of the
  lines declaring a `restund` node (lines in the `[all]` section
  beginning with restund), replace the `ansible_host` values (`X.X.X.X`)
  with the IPs of the nodes that you can connect to via SSH.
- Edit the minio variables in `[minio:vars]` (`prefix`, `domain` and `deeplink_title`)
  by replacing `example.com` with your own domain.

There are more settings in this file that we will set in later steps.

<!-- TODO: remove this warning, and remove the hostname run from the cassandra playbook, or find another way to deal with it. -->

#### WARNING
Some of these playbooks mess with the hostnames of their targets. You
MUST pick different hosts for playbooks that rename the host. If you
e.g. attempt to run Cassandra and k8s on the same 3 machines, the
hostnames will be overwritten by the second installation playbook,
breaking the first.

At the least, we know that the cassandra, kubernetes and restund playbooks are
guilty of hostname manipulation.

### Authentication

#### NOTE
If you use ssh *keys*, and the user you login with is either root or can elevate to root without a password, you don’t need to do anything further to use ansible. If, however, you use password authentication for ssh access, and/or your login user needs a password to become root, see [Manage ansible authentication settings](ansible-authentication.md#ansible-authentication).

## Running ansible to install software on your machines

You can install kubernetes, cassandra, restund, etc in any order.

#### NOTE
In case you only have a single network interface with public IPs but wish to protect inter-database communication, you may use the `tinc.yml` playbook to create a private network interface. In this case, ensure tinc is setup BEFORE running any other playbook. See [tinc](ansible-tinc.md#tinc)

### Installing kubernetes

Kubernetes is installed via ansible.

To install kubernetes:

From `wire-server-deploy/ansible`:

```default
ansible-playbook -i hosts.ini kubernetes.yml -vv
```

When the playbook finishes correctly (which can take up to 20 minutes), you should have a folder `artifacts` containing a file `admin.conf`. Copy this file:

```default
mkdir -p ~/.kube
cp artifacts/admin.conf ~/.kube/config
```

Make sure you can reach the server:

```default
kubectl version
```

should give output similar to this:

```default
Client Version: version.Info{Major:"1", Minor:"19", GitVersion:"v1.19.7", GitCommit:"1dd5338295409edcfff11505e7bb246f0d325d15", GitTreeState:"clean", BuildDate:"2021-01-13T13:23:52Z", GoVersion:"go1.15.5", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"19", GitVersion:"v1.19.7", GitCommit:"1dd5338295409edcfff11505e7bb246f0d325d15", GitTreeState:"clean", BuildDate:"2021-01-13T13:15:20Z", GoVersion:"go1.15.5", Compiler:"gc", Platform:"linux/amd64"}
```

### Cassandra

- If you would like to change the name of the cluster, in your
  ‘hosts.ini’ file, in the `[cassandra:vars]` section, uncomment
  the line that changes ‘cassandra_clustername’, and change default
  to be the name you want the cluster to have.
- If you want cassandra nodes to talk to each other on a specific
  network interface, rather than the one you use to connect via SSH,
  In your ‘hosts.ini’ file, in the `[all:vars]` section,
  uncomment, and set ‘cassandra_network_interface’ to the name of
  the ethernet interface you want cassandra nodes to talk to each
  other on. For example:

```ini
[cassandra:vars]
# cassandra_clustername: default

[all:vars]
## set to True if using AWS
is_aws_environment = False
## Set the network interface name for cassandra to bind to if you have more than one network interface
cassandra_network_interface = eth0
```

(see
[defaults/main.yml](https://github.com/wireapp/ansible-cassandra/blob/master/defaults/main.yml)
for a full list of variables to change if necessary)

- Use ansible to deploy Cassandra:

```default
ansible-playbook -i hosts.ini cassandra.yml -vv
```

### ElasticSearch

- In your ‘hosts.ini’ file, in the `[all:vars]` section, uncomment
  and set ‘elasticsearch_network_interface’ to the name of the
  interface you want elasticsearch nodes to talk to each other on.
- If you are performing an offline install, or for some other reason
  are using an APT mirror other than the default to retrieve
  elasticsearch-oss packages from, you need to specify that mirror
  by setting ‘es_apt_key’ and ‘es_apt_url’ in the `[all:vars]`
  section of your hosts.ini file.

```ini
[all:vars]
# default first interface on ubuntu on kvm:
elasticsearch_network_interface=ens3

## Set these in order to use an APT mirror other than the default.
# es_apt_key = "https://<mymirror>/linux/ubuntu/gpg"
# es_apt_url = "deb [trusted=yes] https://<mymirror>/apt bionic stable"
```

- Use ansible and deploy ElasticSearch:

```default
ansible-playbook -i hosts.ini elasticsearch.yml -vv
```

### Minio

Minio is used for asset storage, in the case that you are not
running on AWS infrastructure, or feel uncomfortable storing assets
in S3 in encrypted form. If you are using S3 instead of Minio, skip
this step.

- In your ‘hosts.ini’ file, in the `[all:vars]` section, make sure
  you set the ‘minio_network_interface’ to the name of the interface
  you want minio nodes to talk to each other on. The default from the
  playbook is not going to be correct for your machine. For example:
- In your ‘hosts.ini’ file, in the `[minio:vars]` section, ensure you
  set minio_access_key and minio_secret key.
- If you intend to use a `deep link` to configure your clients to
  talk to the backend, you need to specify your domain (and optionally
  your prefix), so that links to your deep link json file are generated
  correctly. By configuring these values, you fill in the blanks of
  `https://{{ prefix }}assets.{{ domain }}`.

```ini
[minio:vars]
minio_access_key = "REPLACE_THIS_WITH_THE_DESIRED_SECRET_KEY"
minio_secret_key = "REPLACE_THIS_WITH_THE_DESIRED_SECRET_KEY"
# if you want to use deep links for client configuration:
#minio_deeplink_prefix = ""
#minio_deeplink_domain = "example.com"

[all:vars]
# Default first interface on ubuntu on kvm:
minio_network_interface=ens3
```

- Use ansible, and deploy Minio:

```default
ansible-playbook -i hosts.ini minio.yml -vv
```

### Restund

For instructions on how to install Restund, see [this page](restund.md#install-restund).

### IMPORTANT checks

> After running the above playbooks, it is important to ensure that everything is setup correctly. Please have a look at the post install checks in the section [Verifying your installation](post-install.md#checks)
```default
ansible-playbook -i hosts.ini cassandra-verify-ntp.yml -vv
```

### Installing helm charts - prerequisites

The `helm_external.yml` playbook is used to write or update the IPs of the
databases servers in the `values/<database>-external/values.yaml` files, and
thus make them available for helm and the `<database>-external` charts (e.g.
`cassandra-external`, `elasticsearch-external`, etc).

Due to limitations in the playbook, make sure that you have defined the
network interfaces for each of the database services in your hosts.ini,
even if they are running on the same interface that you connect to via SSH.
In your hosts.ini under `[all:vars]`:

```ini
[all:vars]
minio_network_interface = ...
cassandra_network_interface = ...
elasticsearch_network_interface = ...
# if you're using redis external...
redis_network_interface = ...
```

Now run the helm_external.yml playbook, to populate network values for helm:

```default
ansible-playbook -i hosts.ini -vv --diff helm_external.yml
```

You can now can install the helm charts.

#### Next steps for high-available production installation

Your next step will be [Installing wire-server (production) components using Helm](helm-prod.md#helm-prod)
