.. _helm_prod:

Installing wire-server (production) components using Helm
=========================================================

.. note::

   Code in this repository should be considered *beta*. As of 2020, we do not (yet)
   run our production infrastructure on Kubernetes (but plan to do so soon).

Introduction
------------

The following will install a version of all the wire-server components. These instructions are for reference, and may not set up what you would consider a production environment, due to the fact that there are varying definitions of 'production ready'. These instructions will cover what we consider to be a useful overlap of our users' production needs. They do not cover load balancing/distributing, using multiple datacenters, federating wire, or other forms of intercontinental/interplanetary distribution of the wire service infrastructure. If you deviate from these directions and need to contact us for support, please provide the deviations you made to fit your production environment along with your support request.

Some of the instructions here will present you with two options: No AWS, and with AWS. The 'No AWS' instructions will not require any AWS infrastructure, but may have a reduced feature set. The 'with AWS' instructions will assume you have completed the setup procedures in :ref:`aws_prod`.

What will be installed?
^^^^^^^^^^^^^^^^^^^^^^^

-  wire-server (API)
    -  user accounts, authentication, conversations
    -  assets handling (images, files, ...)
    -  notifications over websocket
-  wire-webapp, a fully functioning web client (like ``https://app.wire.com/``)
-  wire-account-pages, user account management (a few pages relating to e.g. password reset procedures)

What will not be installed?
^^^^^^^^^^^^^^^^^^^^^^^^^^^

-  team-settings page
-  SSO Capabilities

Additionally, if you opt to do the 'No AWS' route, you will not get:

-  notifications over native push notifications via `FCM <https://firebase.google.com/docs/cloud-messaging/>`__/`APNS <https://developer.apple.com/notifications/>`__

Prerequisites
-------------

You need to have access to a Kubernetes cluster running a Kubernetes version , and the ``helm`` local binary on your PATH.
Your Kubernetes cluster needs to have internal DNS services, so that wire-server can find it's databases.
You need to have docker on the machine you are using to perform this installation with, or a secure data path to a machine that runs docker. You will be using docker to generate security credentials for your wire installation.

* If you want calling services, you need to have

  * FIXME

* If you don't have a Kubernetes cluster, you have two options:

  * You can get access to a managed Kubernetes cluster with the cloud provider of your choice.
  * You can install one if you have ssh access to a set of sufficiently large virtual machines, see :ref:`ansible-kubernetes`

* If you don't have ``helm`` yet, see `Installing helm <https://helm.sh/docs/using_helm/#installing-helm>`__.

Type ``helm version``, you should, if everything is configured correctly, see a result similar this:

::

    Client: &version.Version{SemVer:"v2.13.1", GitCommit:"618447cbf203d147601b4b9bd7f8c37a5d39fbb4", GitTreeState:"clean"}
    Server: &version.Version{SemVer:"v2.13.1", GitCommit:"618447cbf203d147601b4b9bd7f8c37a5d39fbb4", GitTreeState:"clean"}

In case ``kubectl version`` shows both Client and Server versions, but ``helm version`` does not show a Server version, you may need to run ``helm init``. The exact version matters less as long as both Client and Server versions match (or are very close).

Upgrading from Helm2 to Helm3
-----------------------------
Because of it's better support of offline environments, we prefer to use Helm3. This step is optional, but recommended for offline deployments.

Download and install the newest version of Helm 3 from get.helm.sh.

.. code:: shell

   curl https://get.helm.sh/helm-v3.1.0-linux-amd64.tar.gz -o helm-v3.1.0-linux-amd64.tar.gz
   tar -xzf helm-v3.1.0-linux-amd64.tar.gz --strip=1 --wildcards */helm
   sudo cp helm /usr/local/bin/

How to download charts for Helm 3 in an offline environment
-----------------------------------------------------------
If you are using the approach of the offline environment described in wire-server-deploy-networkless/vpc/README.md, with an 'assethost', that assethost will have a copy of the charts available from Helm.<domainname>. to download them on the admin host, and prepare them for installation:

.. code:: shell

   cd wire-server-deploy/
   wget -r -l 10 https://helm.internal.vpc/charts/
   mv helm.internal.vpc/charts/ ./wire
   rm $(find wire/ -name index*)

where 'internal.vpc' needs to be replaced with the domain you're using in your offline environment.

Preparing to install charts from the internet with Helm
-------------------------------------------------------
If your environment is online, you need to add the remote wire Helm repository, to download wire charts.

To enable the wire charts helm repository:

.. code:: shell

   helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts

(You can see available helm charts by running ``helm search wire/``. To see
new versions as time passes, you may need to run ``helm repo update``)

Great! Now you can start installing.

.. note::

    all commands below can also take an extra ``--namespace <your-namespace>`` if you don't want to install into the default Kubernetes namespace.

There is a shell script for doing a version of the following procedure with Helm 22. For reference, examine `prod-setup.sh <https://github.com/wireapp/wire-server-deploy/blob/develop/bin/prod-setup.sh>`__.

Watching changes as they happen
-------------------------------

Open a terminal and run:

.. code:: shell

   kubectl get pods -w

This will block your terminal and show some things happening as you proceed through this guide. Keep this terminal open and open a second terminal.

How to install charts that provide access to external databases
---------------------------------------------------------------

Before you can deploy the helm charts that tell wire where external services
are, you need the 'values' and 'secrets' files for those charts to be
configured. Values and secrets YAML files provide helm charts with the settings
that are installed in Kubernetes.

Assuming you have followed the procedures in the previous document, the values
and secrets files for cassandra, elasticsearch, and minio (if you are using it)
will have been filled in automatically. If not, examine the
``prod-values.example.yaml`` files for each of these services in
values/<servicename>/, copy them to ``values.yaml``, and then edit them.

Once the values and secrets files for your databases have been configured, you
have to write a ``values/databases-ephemeral/values.yaml`` file to tell
databases-ephemeral what external database services you are using, and what
services you want databases-ephemeral to configure. We recommend you use the
'redis' component from this only, as the contents of redis are in fact
ephemeral. Look at the ``values/databases-ephemeral/prod-values.example.yaml``
file

Once you have values and secrets for your environment, open a terminal and run:

.. code:: shell

   helm upgrade --install cassandra-external wire/cassandra-external -f values/cassandra-external/values.yaml --wait
   helm upgrade --install elasticsearch-external wire/elasticsearch-external -f values/elasticsearch-external/values.yaml --wait
   helm upgrade --install databases-ephemeral wire/databases-ephemeral -f values/databases-ephemeral/values.yaml --wait

If you are using minio instead of AWS S3, you should also run:

.. code:: shell

   helm upgrade --install minio-external wire/minio-external -f values/minio-external/values.yaml --wait
   
How to install fake AWS services for SNS / SQS / DynamoDB
---------------------------------------------------------
AWS SNS is required to send notifications to clients. If you use the fake-aws version, clients will use the websocket method to receive notifications, which keeps connections to the servers open, draining battery.
AWS SES and SQS are used for mail delivery, and reception, respectively. 


Open a terminal and run:

.. code:: shell

   cp values/fake-aws/prod-values.example.yaml values/fake-aws/values.yaml
   helm upgrade --install fake-aws wire/fake-aws -f values/fake-aws/values.yaml --wait

You should see some pods being created in your first terminal as the above command completes.


Preparing to install wire-server
--------------------------------
As part of configuring wire-server, we need to change some values, and provide some secrets. We're going to copy the files for this to a new folder, so that you always have the originals for reference.

.. note::

    this part of the process makes use of overrides for helm charts. You may wish to read :ref:`understand-helm-overrides` first.*


.. code:: shell

   mkdir -p my-wire-server
   cp values/wire-server/prod-secrets.example.yaml my-wire-server/secrets.yaml
   cp values/wire-server/prod-values.example.yaml my-wire-server/values.yaml


How to configure real SMTP (email) services
-------------------------------------------
In order for users to interact with their wire account, they need to receive mail from your wire server.

If you are using a mail server, you will need to provide your authentication credentials before setting up wire.

- Add your SMTP username in my-wire-server/values.yaml under ``brig.config.smtp.username``. You may need to add an entry for username.
- Add your SMTP pasword is my-wire-server/secrets.yaml under ``brig.secrets.smtpPassword``.


How to install fake SMTP (email) services
-----------------------------------------
If you are not making use of mail services, and are adding your users via some other means, you can use demo-smtp, as a placeholder.

.. code:: shell

   cp values/demo-smtp/prod-values.example.yaml values/demo-smtp/values.yaml
   helm install smtp wire/demo-smtp -f values/demo-smtp/values.yaml


You should see some pods being created in your first terminal as the above command completes.

How to install wire-server itself
---------------------------------

Open ``my-wire-server/values.yaml`` and replace ``example.com`` and other domains and subdomains with domains of your choosing. Look for the ``# change this`` comments. You can try using ``sed -i 's/example.com/<your-domain>/g' values.yaml``.

1. If you are not using team settings, comment out ``teamSettings`` under ``brig.config.externalURLs``.


Generate some secrets:

.. code:: shell

  openssl rand -base64 64 | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 42 > my-wire-server/restund.txt
  apt install docker-ce
  sudo docker run --rm quay.io/wire/alpine-intermediate /dist/zauth -m gen-keypair -i 1 > my-wire-server/zauth.txt

1. Add the generated secret from my-wire-server/restund.txt to my-wire-serwer/secrets.yaml under ``brig.secrets.turn.secret``
2. add **both** the public and private parts from zauth.txt to secrets.yaml under ``brig.secrets.zAuth``
3. Add the public key from zauth.txt to secrets.yaml under ``nginz.secrets.zAuth.publicKeys``

Great, now try the installation:

.. code:: shell

   helm install wire-server wire/wire-server -f my-wire-server/values.yaml -f my-wire-server/secrets.yaml --wait


How to direct traffic to your cluster
------------------------------------------

There are a few options available. The easiest option is to use an ingress with a node port, as this works everywhere and doesn't need a special setup.

.. code:: shell

   # (assuming you're in the root directory of wire-server-deploy)
   mkdir -p nginx-ingress-services && cd nginx-ingress-services
   cp ../values/nginx-ingress-services/demo-secrets.example.yaml secrets.yaml
   cp ../values/nginx-ingress-services/demo-values.example.yaml values.yaml

You should now have the following directory structure:

::

  .
  ├── nginx-ingress-services
  │   ├── secrets.yaml
  │   └── values.yaml
  └── my-wire-server
      ├── secrets.yaml
      └── values.yaml

Inside the ``nginx-ingress-services`` directory, open ``values.yaml`` and replace ``example.com`` with a domain of your choosing. You can try using ``sed -i 's/example.com/<your-domain>/g' values.yaml``.

Next, open ``secrets.yaml`` and add a TLS wildcard certificate and private key matching your domain. For ``example.com``, you need a certficate for ``*.example.com``. The easiest and cheapest option is `Let's Encrypt <https://letsencrypt.org/getting-started/>`__

Install the nodeport nginx ingress:

.. code:: shell

   helm upgrade --install nginx-ingress-controller wire/nginx-ingress-controller --wait
   helm upgrade --install nginx-ingress-services wire/nginx-ingress-services -f values.yaml -f secrets.yaml --wait

Next, we want to redirect port 443 for https to the port the nginx https ingress nodeport is listening on (31773), and port 80 to the nginz http port (31772). To do that, you have two options:

* Option 1: ssh into your kubernetes node, then execute: ``iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 31773``
* Option 2: Use ansible to do that, run the `iptables playbook <https://github.com/wireapp/wire-server-deploy/blob/master/ansible/iptables.yml>`__

How to set up DNS records
----------------------------

An installation needs 5 or 6 domain names (5 without audio/video support, 6 with audio/video support):

You need

* two DNS names for the so-called "nginz" component of wire-server (the main REST API entry point), these are usually called `nginz-https.<domain>` (or `wire-https.<domain>`) and `nginz-ssl.<domain>` (or `wire-https.<domain>`).
* one DNS name for the asset store (images, audio files etc. that your users are sharing); usually `assets.<domain>` or `s3.<domain>`.
* one DNS name for the webapp (equivalent of https://app.wire.com, i.e. the javascript app running in the browser), usually called `webapp.<domain>`.
* one DNS name for the account pages (hosts some html/javascript pages for e.g. password reset), usually called `account.<domain>`.
* (optional) one DNS name for team settings (to manage team membership if using PRO accounts), usually called `teams.<domain>`
* (optional) one DNS name for a audio/video calling server, usually called `restund01.<domain>`.

If you are on the most recent charts from wire-server-deploy, these are your names:

* nginz-https.<domain>
* nginz-ssl.<domain>
* webapp.<domain>
* assets.<domain>
* account.<domain>
* teams.<domain>

(Yes, they all need to point to the same IP address - this is necessary for the nginx ingress to know how to do internal routing based on virtual hosting.)

You may be happy with skipping the DNS setup and just make sure that the ``/etc/hosts`` on your client machine points all the above names to the right IP address:

::

   1.2.3.4 nginz-https.<domain> nginz-ssl.<domain> assets.<domain> webapp.<domain> teams.<domain> account.<domain>


Trying things out
---------------------------

At this point, with a bit of luck, everything should be working (if not, see :ref:`helm_prod_troubleshooting`)

Can you reach the nginz server?

::

    curl -i https://nginz-https.<domain>/status

You should get a 200 return code

::

    HTTP/1.1 200 OK
    Content-Type: text/plain
    Date: ...
    Server: nginx
    Content-Length: 0

Can you access the webapp? Open https://webapp.<your-domain> in your browser (Firefox/Chrome/Safari only)

.. _helm_prod_troubleshooting:

Troubleshooting
--------------------

Which version am I on?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

There are multiple artifacts which combine to form a running wire-server
deployment; these include:

-  docker images for each service
-  Kubernetes configs for each deployment (from helm charts)
-  configuration maps for each deployment (from helm charts)

If you wish to get some information regarding the code currently running
on your cluster you can run the following from ``wire-server-deploy`` (if you don't have wire-server-deploy, ``git clone https://github.com/wireapp/wire-server-deploy && cd wire-server-deploy`` first)::

   ./bin/deployment-info.sh <namespace> <deployment-name (e.g. brig)>

Example run:

::

   ./deployment-info.sh demo brig
   docker_image:               quay.io/wire/brig:2.50.319
   chart_version:              wire-server-0.24.9
   wire_server_commit:         8ec8b7ce2e5a184233aa9361efa86351c109c134
   wire_server_link:           https://github.com/wireapp/wire-server/releases/tag/image/2.50.319
   wire_server_deploy_commit:  01e0f261ca8163e63860f8b2af6d4ae329a32c14
   wire_server_deploy_link:    https://github.com/wireapp/wire-server-deploy/releases/tag/chart/wire-server-0.24.9

Note you'll need ``kubectl``, ``git`` and ``helm`` installed

It will output the running docker image; the corresponding wire-server
commit hash (and link) and the wire-server helm chart version which is
running. This will be helpful for any support requests.

Helm install / upgrade failed
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Usually, you want to run::

    kubectl get pods --all-namespaces

And look for any pods that are not ``Running``. Then you can::

    kubectl --namespace <namespace> logs <name-of-pod>

and/or::

    kubectl --namespace <namespace> describe <name-of-pod>

to know more.

As long as nobody is using your cluster yet, you can safely delete and re-create a specific Helm release (list releases with ``helm list --all``). Example delete the ``wire-server`` Helm release:

.. code:: shell

    helm delete --purge wire-server

It doesn't work, but my problem isn't listed here. Help!
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Feel free to open a github issue or pull request `here <https://github.com/wireapp/wire-docs>`_ and we'll try to improve the documentation.
