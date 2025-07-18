<a id="overview"></a>

# Architecture Overview

## Introduction

In a simplified way, the server components for Wire involve the following:

![image](img/architecture-server-simplified.svg)

The Wire clients (such as the Wire app on your phone) connect either directly or through a load balancer to the “Wire Server”.  The term “Wire Server” refers to a set of API server components that work together and also communicate with various databases. Both the API components and the databases are each deployed in a “cluster”, a setup where multiple instances of the same service run in parallel.This design ensures that if one instance fails, others continue to serve requests without disruption. This fault-tolerant setup is known as high availability, and it helps ensure a seamless experience for users even during component failures.

## Architecture and networking

### Client communications
Users use Wire Clients, either installed with the wire application locally, or by using the web version of the wire application. Let's take a look at the wire backend, from the perspective of a client device:
![image](img/architecture-client_communications.svg)

The above graph gives us a rough breakdown of which domains are used for which parts of the platform.

#### Wire Web Applications
The Wire web application is started by a web browser opening up https://webapp.example.com/ . Similarly, Teams in Wire are managed by loading the Team Management application, reachable at https://teams.example.com/ . Both of these web applications are static, which is to say, the application that is loaded uses the Wire API to perform all actions, and has no "state" in the backend. The 'account' application is not meant for users to directly access, and contains pages to manage password resets, and other special pages outside of the team settings or the Wire Webapp.

#### Wire API Access
All actions in the wire applications require wire API access, which is generally granted when a user logs into a wire client device (including webapp). There are no "long lived" connections in the API, when a client is using the application, they perform their API call, then the connection ends. 

#### Wire Websocket Notifications
As wire is an interactive application, from time to time, we need to tell the client something has happened. This involves holding open a "long lived" connection to the backend, via the WebSockets API over HTTP. 

#### Asset Retrieval
Files, Voice Messages, Pictures, and other items users upload to the wire backend for distribution are referred to as 'assets' in wire. Asset requests are handled on the "https://assets.example.com/" domain, which is separate from the rest of wire. This separation allows customers to use caching services (such as Cloudflare) to accelerate downloads and improve performance.

#### Calling
In general, both of wire's calling services have two phases of communicating with them: there's the signaling phase, which creates, reserves, and communicates about the call, then there is the active phase, where audio/video data is being transfered in-between the participants. Part of the signaling phase of all calls is performed by messages over the Wire Messaging Platform, in order to inform participants about the existence and location of a call.

##### Conference Calling
Conference calling in Wire is a managed dedicated service, named "SFT". This service uses HTTPS to perform the signaling parts of setting up a call, but uses a proprietary derivative of the TURN protocol over UDP to actually transfer calling content. This is why it goes both to a load balancer (for HTTPS), and to a firewall (to forward on UDP packets).

##### Personal Calling
Individual calling between pairs of participants in the wire application is managed by a version of https://github.com/coturn/coturn , which wire has extended for denial of service hardening. This service does not use HTTPS at any point, but does speak the TURN protocol, only deviating from the published standard in the area of authentication.

#### Mobile Notifications
At this point, you might be wondering "what's that Amazon thing up in the corner?". For mobile clients (AKA, cellphones), Wire utilizes Google and Apple push notification services to send a message to the client devices when they need to go check the backend for messages. This is because keeping a "long lived" connection to the backend causes a major battery draw on android, and is simply not possible on apple devices. If complete secrecy is required, the android client is permitted to go into a "websocket-only" mode, where it will use the websocket instead of the cell phone network. This, of course, drains the battery, as the messages required to keep the "long lived" connection going require regular contact to your backend, and require "waking up" the mobile device regularly, preventing it from going into deeper power savings modes.

### Focus on internet protocols

![image](img/architecture-tls-on-prem-2020-09.png)

### Focus on high-availability

The following diagram shows a usual setup with multiple VMs (Virtual Machines):

![image](../how-to/install/img/architecture-server-ha.png)

Wire clients (such as the Wire app on your phone) connect to a load balancer.

The load balancer forwards traffic to the ingress inside the kubernetes VMs. (Restund is special, see [Restund (TURN) servers](restund.md#understand-restund) for details on how Restund works.)

The nginx ingress pods inside kubernetes look at incoming traffic, and forward that traffic on to the right place, depending on what’s inside the URL passed. For example, if a request comes in for `https://example-https.example.com`, it is forwarded to a component called `nginz`, which is the main entry point for the [wire-server API](https://github.com/wireapp/wire-server). If, however, a request comes in for `https://webapp.example.com`, it is forwarded to a component called [webapp](https://github.com/wireapp/wire-webapp), which hosts the graphical browser Wire client (as found when you open [https://app.wire.com](https://app.wire.com)).

Wire-server needs a range of databases. Their names are: cassandra, elasticsearch, minio, redis, etcd.

All the server components on one physical machine can connect to all the databases (also those on a different physical machine). The databases each connect to each-other, e.g. cassandra on machine 1 will connect to the cassandra VMs on machines 2 and 3.

### Backend components startup

The Wire server backend is designed to run on a kubernetes cluster. From a high level perspective the startup sequence from machine power-on to the Wire server being ready to receive requests is as follow:

1. *Kubernetes node power on*. Systemd starts the kubelet service which makes the worker node available to kubernetes. For more details about kubernetes startup refer to [the official kubernetes documentation](https://kubernetes.io/docs/reference/setup-tools/kubeadm/implementation-details/). For details about the installation and configuration of kubernetes and worker nodes for Wire server see [Installing kubernetes and databases on VMs with ansible](../how-to/install/ansible-VMs.md#ansible-vms)
2. *Kubernetes workload startup*. Kubernetes will ensure that Wire server workloads installed via helm are scheduled on available worker nodes. For more details about workload scheduling refer to [the official kubernetes documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/). For details about how to install Wire server with helm refer to [Installing wire-server (production) components using Helm](../how-to/install/helm-prod.md#helm-prod).
3. *Stateful workload startup*. Systemd starts the stateful services (cassandra, elasticsearch and minio). See for instance [ansible-cassandra role](https://github.com/wireapp/ansible-cassandra/blob/master/tasks/systemd.yml#L10) and other database installation instructions in [Installing kubernetes and databases on VMs with ansible](../how-to/install/ansible-VMs.md#ansible-vms)
4. *Other services*. Systemd starts the restund docker container. See [ansible-restund role](https://github.com/wireapp/ansible-restund/blob/9807313a7c72ffa40e74f69d239404fd87db65ab/templates/restund.service.j2#L12-L19). For details about docker container startup [consult the official documentation](https://docs.docker.com/get-started/overview/#docker-architecture)

#### NOTE
For more information about Virual Machine startup or operating system level service startup, please consult your virtualisation and operating system documentation.

### Focus on pods

The Wire backend runs in [a kubernetes cluster](https://kubernetes.io/), with different components running in different [pods](https://kubernetes.io/docs/concepts/workloads/pods/).

This is a list of those pods as found in a typical installation.

HTTPS Entry points:

- `nginx-ingress-controller-controller`: [Ingress](https://kubernetes.github.io/ingress-nginx/) exposes HTTP and HTTPS routes from outside the cluster to services within the cluster.
- `nginx-ingress-controller-default-backend`: [The default backend](https://kubernetes.github.io/ingress-nginx/user-guide/default-backend/) is a service which handles all URL paths and hosts the nginx controller doesn’t understand (i.e., all the requests that are not mapped with an Ingress), that is 404 pages. Part of `nginx-ingress`.

Frontend pods:

- `webapp`: The fully functioning Web client (like [https://app.wire.com](https://app.wire.com)). [This pod](https://github.com/wireapp/wire-docs/blob/master/src/how-to/install/helm.rst#what-will-be-installed) serves the web interface itself, which then interfaces with other services/pods, such as the APIs.
- `account-pages`: [This pod](https://github.com/wireapp/wire-docs/blob/master/src/how-to/install/helm.rst#what-will-be-installed) serves Web pages for user account management (a few pages relating to e.g. password reset).
- `team-settings`: Team management Web interface (like [https://teams.wire.com](https://teams.wire.com)).

Pods with an HTTP API:

- `brig`: [The user management API service](https://github.com/wireapp/wire-server/tree/develop/services/brig). Connects to `cassandra` and `elastisearch` for user data storage, sends emails and SMS for account validation.
- `cannon`: [WebSockets API Service](https://github.com/wireapp/wire-server/blob/develop/services/cannon/). Holds WebSocket connections.
- `cargohold`: [Asset Storage API Service](../how-to/install/aws-prod.md). Amazon-AWS-S3-style services are used by `cargohold` to store encrypted files that users are sharing amongst each other, such as images, files, and other static content, which we call assets. All assets except profile pictures are symmetrically encrypted before storage (and the keys are only known to the participants of the conversation in which an assets was shared - servers have no knowledge of the keys).
- `galley`: [Conversations and Teams API Service](../understand/api-client-perspective/README.md). Data is stored in cassandra. Uses `gundeck` to send notifications to users.
- `nginz`: Public API Reverse Proxy (Nginx with custom libzauth module). A modified copy of nginx, compiled with a specific set of upstream extra modules, and one important additional module zauth_nginx_module. Responsible for user authentication validation. Forwards traffic to all other API services (except federator)
- `spar`: [Single Sign On (SSO)](https://en.wikipedia.org/wiki/Single_sign-on) and [SCIM](https://en.wikipedia.org/wiki/System_for_Cross-domain_Identity_Management). Stores data in cassandra.
- `gundeck`: Push Notification Hub (WebSocket/mobile push notifications). Uses redis as a temporary data store for websocket presences. Uses Amazon SNS and SQS.
- `federator`: [Connects different wire installations together](./federation/README.md). Wire Federation, once implemented, aims to allow multiple Wire-server backends to federate with each other. That means that a user 1 registered on backend A and a user 2 registered on backend B should be able to interact with each other as if they belonged to the same backend.

Supporting pods and data storage:

- `cassandra-ephemeral` (or `cassandra-external`): [NoSQL Database management system](https://github.com/wireapp/wire-server/tree/develop/charts/cassandra-ephemeral) ([https://en.wikipedia.org/wiki/Apache_Cassandra](https://en.wikipedia.org/wiki/Apache_Cassandra)). Everything stateful in wire-server (cassandra is used by `brig`, `galley`, `gundeck` and `spar`) is stored in cassandra.
  \* `cassandra-ephemeral` is for test clusters where persisting the data (i.e. loose users, conversations,…) does not matter, but this shouldn’t be used in production environments.
  \* `cassandra-external` is used to point to an external cassandra cluster which is installed outside of Kubernetes.
- `demo-smtp`: In “demo” installations, used to replace a proper external SMTP server for the sending of emails (for example verification codes). In production environments, an actual SMTP server is used directly instead of this pod. ([https://github.com/namshi/docker-smtp](https://github.com/namshi/docker-smtp))
- `fluent-bit`: A log processor and forwarder, allowing collection of data such as metrics and logs from different sources. Not typically deployed. ([https://fluentbit.io/](https://fluentbit.io/))
- `elastisearch-ephemeral` (or `elastisearch-external`): [Distributed search and analytics engines, stores some user information (name, handle, userid, teamid)](https://github.com/wireapp/wire-server/tree/develop/charts/elastisearch-external). Information is duplicated here from cassandra to allow searching for users. Information here can be re-populated from data in cassandra (albeit with some downtime for search functionality) ([https://www.elastic.co/what-is/elasticsearch](https://www.elastic.co/what-is/elasticsearch)).
  \* `elastisearch-ephemeral` is for test clusters where persisting the data doesn’t matter.
  \* `elastisearch-external` refers to elasticsearch IPs located outside kubernetes by specifying IPs manually.
- `fake-aws-s3`: Amazon-AWS-S3-compatible object storage using MinIO ([https://min.io/](https://min.io/)), used by cargohold to store (encrypted) assets such as files, posted images, profile pics, etc.
- `fake-aws-s3-reaper`: Creates the default S3 bucket inside fake-aws-s3.
- `fake-aws-sns`. [Amazon Simple Notification Service (Amazon SNS)](https://docs.aws.amazon.com/AmazonS3/latest/userguide/NotificationHowTo.html), used to push messages to mobile devices or distributed services. SNS can publish a message once, and deliver it one or more times.
- `fake-aws-sqs`: [Amazon Simple Queue Service (Amazon SQS) queue](https://docs.aws.amazon.com/AmazonS3/latest/userguide/NotificationHowTo.html), used to transmit any volume of data without requiring other services to be always available.
- `redis-ephemeral`: Stores websocket connection assignments (part of the `gundeck` / `cannon` architecture).

Short running jobs that run during installation/upgrade (these should usually be in the status ‘Completed’ except immediately after installation/upgrade):

- `cassandra-migrations`: Used to initialize or upgrade the database schema in cassandra (for example when the software is upgraded to a new version).
- `galley-migrate-data`: Used to upgrade data in `cassandra` when the data model changes (for example when the software is upgraded to a new version).
- `brig-index-migrate-data`: Used to upgrade data in `cassandra` when the data model changes in brig (for example when the software is upgraded to a new version)
- `elastisearch-index-create`: [Creates](https://github.com/wireapp/wire-server/blob/develop/charts/elasticsearch-index/templates/create-index.yaml#L29) an Elastisearch index for brig.
- `spar-migrate-data`: [Used to update spar data](https://github.com/wireapp/wire-server/blob/develop/charts/cassandra-migrations/templates/spar-migrate-data.yaml) in cassandra when schema changes occur.

As an example, this is the result of running the `kubectl get pods --namespace wire` command to obtain a list of all pods in a typical cluster:

```shell
NAMESPACE      NAME                                                      READY   STATUS      RESTARTS   AGE
wire           account-pages-54bfcb997f-hwxlf                            1/1     Running     0          85d
wire           brig-58bc7f844d-rp2mx                                     1/1     Running     0          3h54m
wire           brig-index-migrate-data-s7lmf                             0/1     Completed   0          3h33m
wire           cannon-0                                                  1/1     Running     0          3h53m
wire           cargohold-779bff9fc6-7d9hm                                1/1     Running     0          3h54m
wire           cassandra-ephemeral-0                                     1/1     Running     0          176d
wire           cassandra-migrations-66n8d                                0/1     Completed   0          3h34m
wire           demo-smtp-784ddf6989-7zvsk                                1/1     Running     0          176d
wire           elasticsearch-ephemeral-86f4b8ff6f-fkjlk                  1/1     Running     0          176d
wire           elasticsearch-index-create-l5zbr                          0/1     Completed   0          3h34m
wire           fake-aws-s3-77d9447b8f-9n4fj                              1/1     Running     0          176d
wire           fake-aws-s3-reaper-78d9f58dd4-kf582                       1/1     Running     0          176d
wire           fake-aws-sns-6c7c4b7479-nzfj2                             2/2     Running     0          176d
wire           fake-aws-sqs-59fbfbcbd4-ptcz6                             2/2     Running     0          176d
wire           federator-6d7b66f4d5-xgkst                                1/1     Running     0          3h54m
wire           galley-5b47f7ff96-m9zrs                                   1/1     Running     0          3h54m
wire           galley-migrate-data-97gn8                                 0/1     Completed   0          3h33m
wire           gundeck-76c4599845-4f4pd                                  1/1     Running     0          3h54m
wire           nginx-ingress-controller-controller-2nbkq                 1/1     Running     0          9d
wire           nginx-ingress-controller-controller-8ggw2                 1/1     Running     0          9d
wire           nginx-ingress-controller-default-backend-dd5c45cf-jlmbl   1/1     Running     0          176d
wire           nginz-77d7586bd9-vwlrh                                    2/2     Running     0          3h54m
wire           redis-ephemeral-master-0                                  1/1     Running     0          176d
wire           spar-8576b6845c-npb92                                     1/1     Running     0          3h54m
wire           spar-migrate-data-lz5ls                                   0/1     Completed   0          3h33m
wire           team-settings-86747b988b-5rt45                            1/1     Running     0          50d
wire           webapp-54458f756c-r7l6x                                   1/1     Running     0          3h54m
                  1/1     Running     0          3h54m
```

#### NOTE
This list is not exhaustive, and your installation may have additional pods running depending on your configuration.
