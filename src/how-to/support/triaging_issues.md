<a id="triaging_issues"></a>

# Triaging Issues with your Wire Deployment

## Introduction

In order to help our users and their support staff help themselves, we are providing some general guidance for first line troubleshooting of your wire installation.

## Being Prepared

If you are supporting the wire product, there are many things you can do before you have an incident, in order to help quickly resolve issues.

Please read and understand the content in https://docs.wire.com/latest/understand/overview.html.

### Know your Wire Deployment

In an outage there are many key questions you will need quick answers to, in order to properly triage and troubleshoot an issue. Having these facts either memorized, or written down clearly in a central location will expidite response times.

Quick Facts:
 * Who can administrate your Wire installation / How do you contact them?
 * Is your Wire Calling infrastructure hosted in a separate DMZ (Wire recommended), hosted alongside your Wire install, or are you using our Cloud Calling offering?
 * What does the network path look like between your users, and your wire installation?
 * Is there anything "out of the ordinary" about how your wire installation is configured?
 * Have there been any major changes or failures recently? Inside your network, or in the wider Internet? (think: Cloudflare, AWS, etc...)

### Know your Infrastructure
All products have dependencies; Wire is no different. Whether these be Internet, Power, or something like an SSO provider, dependencies break, and knowing what you're dependent on gets you closer to solutions quickly.

What to know:
 * What Domain Names are a part of your Wire installation? How are those domains resolved by the end users?
 * Who is your Internet Service Provider? 
 * What DNS service does your wire install use?
 * What network time source are your wire servers depending on?
 * What load balancers and firewalls are in use around your wire deployment?
 * What infrastructure does your Wire service run on?

### Know your Users

Knowing what your users are using, how they use it, and what they value in it can help you get your users what they value quickly.

Quick Facts:
 * What platforms are the users using, and in what porportion? (Web / Android / iOS / Windows / Mac / Linux / ...)
 * What is the network path between your users, and your wire services?
 * For mobile platforms:
   * How do your users recieve notifications? (APNS / FCM / WebSockets)
   * Are you managing wire on your users' mobile devices with a Mobile Device Management(MDM) product?
 * How do your users find your wire installation?
 * How do your users login to wire? What infrastructure does that depend on? (SSO, SCIM, LDAP, etc...)
 * What do your users use wire for? Mostly Messaging, mostly Calling, File sharing? 

### Take Backups
Both the wire backend, and the wire clients have backup and restore procedures. familiarize yourself with them, and ensure backups are taken regularly.

## Trouble-Shooting

When a user reports a problem with your Wire service, the first thing you need to determine is what the severity, and the urgency of their report is. If a user is reporting an icon failing to draw correctly at midnight, that might not be so bad, but if that icon is the 'call' button... that changes things. details matter.

Each of the diagrams on https://docs.wire.com/latest/understand/overview.html shows a different view of your platform. Let's go through each, and a few examples of problem, and how you troubleshoot them.

### DMZ Split

![image](../../understand/img/architecture-server-simplified.svg)

Your wire install is distributed across many physical computers, possibly in a datacenter. Wire recommends the deployment of wire in two clusters, one cluster for "calling", which is placed in your DMZ, and one cluster for "everything else", which lives in your secure hosting location. If your user is complaining about calling issues, knowing where your calling is located has become important.

If you or the user have access to the web client (not desktop, has to be a real web browser), you or the end user can download your calling server configuration as it is given by the backend, following the procedure in (inspector.md).

### Client Communications

![image](../../understand/img/architecture-client_communications.svg)

Users rely on their client devices connecting to their wire backend properly. 

your Wire backend has many domains which must be resolvable by your end users. these domains most likely point to load balancers in your environment, like pictured above.

If your problem is just effecting calling, making sure the calling domains are reachable.
If a user is having a problem with recieving notifications of new messages, they may be having trouble with their cell phone tower (on mobile), or perhaps issues with their web socket connection. remember that the user's problem is in front of them / in their hand; don't check that YOU can resolve the host, check that THEY can.

#### Routing

Once traffic has made it into your Wire environment, your load balancers and firewalls have to hand that traffic over to your wire install. Here you can see a more detailed view of how traffic enters your cluster.

Looking at this diagram, you can see that normally, calling services are completely separated from the rest of the backend. assuming this is the case (you do know your install, yes?), 


### Health Checks

When your users complain about a service, the first instinct is to check if the service is online yourself. This is the first form of health check. Which health checks you perform and in what order should be based on the user's complaint, not "just" what we expect to see.

https://docs.wire.com/latest/how-to/administrate/operations.html?h=health#health-checks


### What does healthy look like?
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

This cluster is running one of each service, but if you are deployed in high-availability, you will see three of each.
 
### Historic Issues

#### Cassandra NTP Sync

Summary:
From time to time, if your NTP services go out of service, and your cassandra database nodes are allowed to have their time to drift, your cassandra nodes may refuse quorum writes.

Symptomology:
There are errors in the brig logs about cassandra, refering to Quorum.

User Visible Problems:
brig is the first service to go, having problems logging people in.

