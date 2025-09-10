<a id="helm-prod"></a>

# Installing wire-server (production) components using Helm

## Introduction

The following will install a version of all the wire-server components. These instructions are for reference, and may not set up what you would consider a production environment, due to the fact that there are varying definitions of ‘production ready’. These instructions will cover what we consider to be a useful overlap of our users’ production needs. They do not cover load balancing/distributing, using multiple datacenters, federating wire, or other forms of intercontinental/interplanetary distribution of the wire service infrastructure. If you deviate from these directions and need to contact us for support, please provide the deviations you made to fit your production environment along with your support request.

Some of the instructions here will present you with two options: No AWS, and with AWS. The ‘No AWS’ instructions will not require any AWS infrastructure, but may have a reduced feature set. The ‘with AWS’ instructions will assume you have completed the setup procedures in [Configuring AWS and wire-server (production) components](aws-prod.md#aws-prod).

### What will be installed?

- wire-server (API)
  : - user accounts, authentication, conversations
  - assets handling (images, files, …)
  - notifications over websocket
- wire-webapp, a fully functioning web client (like `https://app.wire.com/`)
- wire-account-pages, user account management (a few pages relating to e.g. password reset procedures)

### What will not be installed?

- team-settings page
- SSO Capabilities

Additionally, if you opt to do the ‘No AWS’ route, you will not get:

- notifications over native push notifications via [FCM](https://firebase.google.com/docs/cloud-messaging/)/[APNS](https://developer.apple.com/notifications/)

## Prerequisites

You need to have access to a Kubernetes cluster running a Kubernetes version , and the `helm` local binary on your PATH.
Your Kubernetes cluster needs to have internal DNS services, so that wire-server can find it’s databases.
You need to have docker on the machine you are using to perform this installation with, or a secure data path to a machine that runs docker. You will be using docker to generate security credentials for your wire installation.

- If you want calling services, you need to have
  - FIXME
- If you don’t have a Kubernetes cluster, you have two options:
  - You can get access to a managed Kubernetes cluster with the cloud provider of your choice.
  - You can install one if you have ssh access to a set of sufficiently large virtual machines, see [installing kubernetes](ansible-VMs.md#installing-kubernetes).
- If you don’t have `helm` yet, see [Installing helm](https://helm.sh/docs/using_helm/#installing-helm). If you followed the instructions in [Dependencies on operator’s machine](dependencies.md#dependencies)  should have helm installed already.

Type `helm version`, you should, if everything is configured correctly, see a result similar this:

```default
version.BuildInfo{Version:"v3.1.1", GitCommit:"afe70585407b420d0097d07b21c47dc511525ac8", GitTreeState:"clean", GoVersion:"go1.13.8"}
```

In case `kubectl version` shows both Client and Server versions, but `helm version` does not show a Server version, you may need to run `helm init`. The exact version matters less as long as both Client and Server versions match (or are very close).

## Preparing to install charts from the internet with Helm

If your environment is online, you need to add the remote wire Helm repository, to download wire charts.

To enable the wire charts helm repository:

```shell
helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts
```

(You can see available helm charts by running `helm search repo wire/`. To see
new versions as time passes, you may need to run `helm repo update`)

Great! Now you can start installing.

There is a shell script for doing a version of the following procedure with Helm 22. For reference, examine [prod-setup.sh](https://github.com/wireapp/wire-server-deploy/blob/develop/bin/prod-setup.sh).

## Watching changes as they happen

Open a terminal and run:

```shell
kubectl get pods -w
```

This will block your terminal and show some things happening as you proceed through this guide. Keep this terminal open and open a second terminal.

## General installation notes

#### NOTE
All helm and kubectl commands below can also take an extra `--namespace <your-namespace>` if you don’t want to install into the default Kubernetes namespace.

## How to install charts that provide access to external databases

Before you can deploy the helm charts that tell wire where external services
are, you need the ‘values’ and ‘secrets’ files for those charts to be
configured. Values and secrets YAML files provide helm charts with the settings
that are installed in Kubernetes.

Assuming you have followed the procedures in the previous document, the values
and secrets files for cassandra, elasticsearch, and minio (if you are using it)
will have been filled in automatically. If not, examine the
`prod-values.example.yaml` files for each of these services in
values/<servicename>/, copy them to `values.yaml`, and then edit them.

Once the values and secrets files for your databases have been configured, you
have to write a `values/databases-ephemeral/values.yaml` file to tell
databases-ephemeral what external database services you are using, and what
services you want databases-ephemeral to configure. We recommend you use the
‘redis’ component from this only, as the contents of redis are in fact
ephemeral. Look at the `values/databases-ephemeral/prod-values.example.yaml`
file

Once you have values and secrets for your environment, open a terminal and run:

```shell
helm upgrade --install cassandra-external wire/cassandra-external -f values/cassandra-external/values.yaml --wait
helm upgrade --install elasticsearch-external wire/elasticsearch-external -f values/elasticsearch-external/values.yaml --wait
helm upgrade --install databases-ephemeral wire/databases-ephemeral -f values/databases-ephemeral/values.yaml --wait
```

If you are using minio instead of AWS S3, you should also run:

```shell
helm upgrade --install minio-external wire/minio-external -f values/minio-external/values.yaml --wait
```

## How to install fake AWS services for SNS / SQS

AWS SNS is required to send notifications to clients. SQS is used to get notified of any devices that have discontinued using Wire (e.g. if you uninstall the app, the push notification token is removed, and the wire-server will get feedback for that using SQS).

Note: *for using real SQS for real native push notifications instead, see also :ref:\`pushsns\`.*

If you use the fake-aws version, clients will use the websocket method to receive notifications, which keeps connections to the servers open, draining battery.

Open a terminal and run:

```shell
cp values/fake-aws/prod-values.example.yaml values/fake-aws/values.yaml
helm upgrade --install fake-aws wire/fake-aws -f values/fake-aws/values.yaml --wait
```

You should see some pods being created in your first terminal as the above command completes.

## Preparing to install wire-server

As part of configuring wire-server, we need to change some values, and provide some secrets. We’re going to copy the files for this to a new folder, so that you always have the originals for reference.

#### NOTE
This part of the process makes use of overrides for helm charts. You may wish to read [Overriding helm configuration settings](../../understand/helm.md#understand-helm-overrides) first.

```shell
mkdir -p my-wire-server
cp values/wire-server/prod-secrets.example.yaml my-wire-server/secrets.yaml
cp values/wire-server/prod-values.example.yaml my-wire-server/values.yaml
```

## How to install RabbitMQ

This is only required when federation needs to be enabled.

1. Generate password for rabbitmq:
   ```shell
   openssl rand -base64 64 | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 42 > my-wire-server/rabbitmq-password
   ```
2. Copy example values
   ```shell
   cp values/rabbitmq/prod-secrets.example.yaml values/rabbitmq/secrets.yaml
   cp values/rabbitmq/prod-values.example.yaml values/rabbitmq/values.yaml
   ```
3. Add the generated secret from `my-wire-server/rabbitmq-password` to
   `values/rabbitmq/secrets.yaml` under `rabbitmq.auth.password`.
4. Install the helm chart using:
   ```shell
   helm upgrade --install rabbitmq wire/rabbitmq -f values/rabbitmq/values.yaml -f values/rabbitmq/secrets.yaml
   ```

## How to configure real SMTP (email) services

In order for users to interact with their wire account, they need to receive mail from your wire server.

If you are using a mail server, you will need to provide your authentication credentials before setting up wire.

- Add your SMTP username in my-wire-server/values.yaml under `brig.config.smtp.username`. You may need to add an entry for username.
- Add your SMTP password is my-wire-server/secrets.yaml under `brig.secrets.smtpPassword`.

## How to install fake SMTP (email) services

If you are not making use of mail services, and are adding your users via some other means, you can use demo-smtp, as a placeholder.

```shell
cp values/demo-smtp/prod-values.example.yaml values/demo-smtp/values.yaml
helm upgrade --install smtp wire/demo-smtp -f values/demo-smtp/values.yaml
```

You should see some pods being created in your first terminal as the above command completes.

## How to install wire-server itself

Open `my-wire-server/values.yaml` and replace `example.com` and other domains and subdomains with domains of your choosing. Look for the `# change this` comments. You can try using `sed -i 's/example.com/<your-domain>/g' values.yaml`.

1. If you are not using team settings, comment out `teamSettings` under `brig.config.externalURLs`.

Generate some secrets:

```shell
openssl rand -base64 64 | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 42 > my-wire-server/restund.txt
apt install docker-ce
sudo docker run --rm quay.io/wire/alpine-intermediate /dist/zauth -m gen-keypair -i 1 > my-wire-server/zauth.txt
```

1. Add the generated secret from `my-wire-server/restund.txt` to `my-wire-server/secrets.yaml` under `brig.secrets.turn.secret`.
2. add **both** the public and private parts from `my-wire-server/zauth.txt` to `my-wire-server/secrets.yaml` under `brig.secrets.zAuth`.
3. Add the public key from `my-wire-server/zauth.txt` to `my-wire-server/secrets.yaml` under `nginz.secrets.zAuth.publicKeys`.
4. Add the generated secret from my-wire-server/rabbitmq-password to `my-wire-server/secerts.yaml` under `brig.secrets.rabbitmq.password` and `background-worker.secrets.rabbitmq.password`.

Great, now try the installation:

```shell
helm upgrade --install wire-server wire/wire-server -f my-wire-server/values.yaml -f my-wire-server/secrets.yaml --wait
```

<a id="helmdns"></a>

## DNS records

### How to set up DNS records

An installation needs 5 to 10 domain names (5 without audio/video support, federation and team settings, plus an additional one for each audio/video support and team settings, federation, SFTD and team settings):

You need

* two DNS names for the so-called “nginz” component of wire-server (the main REST API entry point), these are usually called nginz-https.<domain> and nginz-ssl.<domain>.
* one DNS name for the asset store (images, audio files etc. that your users are sharing); usually assets.<domain> or s3.<domain>.
* one DNS name for the webapp (equivalent of [https://app.wire.com](https://app.wire.com), i.e. the javascript app running in the browser), usually called webapp.<domain>.
* one DNS name for the account pages (hosts some html/javascript pages for e.g. password reset), usually called account.<domain>.
* (optional) one DNS name for SFTD support (conference calling), usually called sftd.<domain>
* (optional) one DNS name for team settings (to manage team membership if using PRO accounts), usually called teams.<domain>
* (optional) two DNS names for audio/video calling servers, usually called restund01.<domain> and restund02.<domain>. Two are used so during upgrades, you can drain one and use the second while work is happening on the first.
* (optional) one DNS name for the federator, usually called federator.<domain>.
* (optional) one DNS name for SFTD (conference calling), usually called sftd.<domain>.

If you are on the most recent charts, these are your names:

* nginz-https.<domain>
* nginz-ssl.<domain>
* webapp.<domain>
* assets.<domain>
* account.<domain>

And optionally:

* teams.<domain>
* sftd.<domain>
* restund01.<domain>
* restund02.<domain>
* federator.<domain>

All of these DNS records need to point to the same IP address, the IP you want to provide services on.

This is necessary for the nginx ingress to know how to do internal routing based on virtual hosting.

The only expections to this are:

* restund01, restund02  which need the appropriate DNS name pointed to them
* sftd which needs to point to the external IPs you are providing conference calling on

So sftd.<domain> should list both SFT servers, while each of the restund servers get their own respective domain name.

You may be happy with skipping the DNS setup and just make sure that the `/etc/hosts` on your client machine points all the above names to the right IP address:

```default
1.2.3.4 nginz-https.<domain> nginz-ssl.<domain> assets.<domain> webapp.<domain> teams.<domain> account.<domain> sftd.<domain> restund01.<domain> restund02.<domain> federator.<domain>
```

### How to direct traffic to your cluster

There are a few options available. The easiest option is to use an ingress with a node port, as this works everywhere and doesn’t need a special setup.

```shell
# (assuming you're in the root directory of wire-server-deploy)
mkdir -p nginx-ingress-services && cd nginx-ingress-services
cp ../values/nginx-ingress-services/demo-secrets.example.yaml secrets.yaml
cp ../values/nginx-ingress-services/demo-values.example.yaml values.yaml
```

You should now have the following directory structure:

```default
.
├── nginx-ingress-services
│   ├── secrets.yaml
│   └── values.yaml
└── wire-server
    ├── secrets.yaml
    └── values.yaml
```

Inside the `nginx-ingress-services` directory, open `values.yaml` and replace `example.com` with a domain of your choosing. You can try using `sed -i 's/example.com/<your-domain>/g' values.yaml`.

Next, open `secrets.yaml` and add a TLS wildcard certificate and private key matching your domain. For `example.com`, you need a certificate for `*.example.com`. The easiest and cheapest option is [Let’s Encrypt](https://letsencrypt.org/getting-started/)

The certificate should be provided in the [PEM format](https://knowledge.digicert.com/quovadis/ssl-certificates/ssl-general-topics/what-is-pem-format.html).

The format is as follows:

```yaml
secrets:
  tlsWildcardCert: |
    -----BEGIN CERTIFICATE-----
    ... <cert goes here>
    -----END CERTIFICATE-----

  tlsWildcardKey: |
    -----BEGIN RSA PRIVATE KEY -----
    ... <private key goes here>
    -----END RSA PRIVATE KEY-----
```

#### NOTE
[Let’s Encrypt](https://letsencrypt.org/getting-started/) & [cert-manager](https://cert-manager.io/docs/tutorials/acme/http-validation/)

As an alternative to providing your own certificate, you may want to allow for automated certificate issuing through
Let’s Encrypt. For this, you have to install the *cert-manager* first:

```shell
helm upgrade --install -n cert-manager-ns --set 'installCRDs=true' cert-manager jetstack/cert-manager
```

Afterwards, you have to make some minor adjustments to the `nginx-ingress-services/values.yaml` you have just copied
and edited. Make sure the following properties are set accordingly:

```yaml
tls:
  enabled: true
  useCertManager: true

certManager:
  # NOTE: You may set this to `true` when deploying the first time, just to make
  #       sure everything is order, and only to `false` before deploying again, so
  #       that a valid certificate is actually issued.
  inTestMode: false
  certmasterEmail: "ADD-VALID-ADDRESS-HERE"
```

Please note, in this case, you can omit the `secrets.yaml` file entirely.

Install the nodeport nginx ingress:

```shell
helm upgrade --install nginx-ingress-controller wire/nginx-ingress-controller --wait
helm upgrade --install nginx-ingress-services wire/nginx-ingress-services -f values.yaml -f secrets.yaml --wait
```

Next, we want to redirect port 443 to the port the nginx https ingress nodeport is listening on (31773), and, redirect port 80 to the nginz http port (31772) (for redirects only). To do that, you have two options:

* Option 1: ssh into your kubernetes node, then execute:
  * `iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 31773`
  * `iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 31772`
* Option 2: Use ansible to do that, run the [iptables playbook](https://github.com/wireapp/wire-server-deploy/blob/master/ansible/iptables.yml)

### Trying things out

At this point, with a bit of luck, everything should be working (if not, see the ‘troubleshooting’ section below)

Can you reach the nginz server?

```default
curl -i https://nginz-https.<domain>/status
```

You should get a 200 return code

```default
HTTP/1.1 200 OK
Content-Type: text/plain
Date: ...
Server: nginx
Content-Length: 0
```

Can you access the webapp? Open [https://webapp](https://webapp).<your-domain> in your browser (Firefox/Chrome/Safari only)

### Troubleshooting

#### Which version am I on?

There are multiple artifacts which combine to form a running wire-server
deployment; these include:

- docker images for each service
- Kubernetes configs for each deployment (from helm charts)
- configuration maps for each deployment (from helm charts)

If you wish to get some information regarding the code currently running
on your cluster you can run the following from `wire-server-deploy` (if you don’t have wire-server-deploy, `git clone https://github.com/wireapp/wire-server-deploy && cd wire-server-deploy` first):

```default
./bin/deployment-info.sh <namespace> <deployment-name (e.g. brig)>
```

Example run:

```default
./deployment-info.sh demo brig
docker_image:               quay.io/wire/brig:2.50.319
chart_version:              wire-server-0.24.9
wire_server_commit:         8ec8b7ce2e5a184233aa9361efa86351c109c134
wire_server_link:           https://github.com/wireapp/wire-server/releases/tag/image/2.50.319
wire_server_deploy_commit:  01e0f261ca8163e63860f8b2af6d4ae329a32c14
wire_server_deploy_link:    https://github.com/wireapp/wire-server-deploy/releases/tag/chart/wire-server-0.24.9
```

Note you’ll need `kubectl`, `git` and `helm` installed

It will output the running docker image; the corresponding wire-server
commit hash (and link) and the wire-server helm chart version which is
running. This will be helpful for any support requests.

#### Helm install / upgrade failed

Usually, you want to run:

```default
kubectl get pods --all-namespaces
```

And look for any pods that are not `Running`. Then you can:

```default
kubectl --namespace <namespace> logs <name-of-pod>
```

and/or:

```default
kubectl --namespace <namespace> describe <name-of-pod>
```

to know more.

As long as nobody is using your cluster yet, you can safely delete and re-create a specific Helm release (list releases with `helm list --all`). Example delete the `wire-server` Helm release:

```shell
helm delete --purge wire-server
```

#### It doesn’t work, but my problem isn’t listed here. Help!

Feel free to open a github issue or pull request [here](https://github.com/wireapp/wire-docs) and we’ll try to improve the documentation.
