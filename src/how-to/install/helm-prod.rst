.. _helm_prod:

Installing wire-server (production) components using helm
==============================================================

.. note::

   Code in this repository should be considered *beta*. As of 2019, we do not (yet)
   run our production infrastructure on kubernetes (but plan to do so soon).

Introduction
-----------------

The following will install a version of all the wire-server components. This setup is not recommended in production but will get you started.

What will be installed?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

-  wire-server (API)
    -  user accounts, authentication, conversations
    -  assets handling (images, files, ...)
    -  notifications over websocket
-  wire-webapp, a fully functioning web client (like ``https://app.wire.com``)
-  wire-account-pages, user account management (a few pages relating to e.g. password reset)

What will not be installed?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

-  notifications over native push notifications via `FCM <https://firebase.google.com/docs/cloud-messaging/>`__/`APNS <https://developer.apple.com/notifications/>`__
-  audio/video calling servers using :ref:`understand-restund`)
-  team-settings page

Prerequisites
--------------------------------

You need to have access to a kubernetes cluster, and the ``helm`` local binary on your PATH.
Your kubernetes cluster needs to have internal dns services, so that wire-server can find it's databases.
You need to have docker on the machine you are using to perform this installation with, or a secure data path to a machine that runs docker. You will be using docker to generate security credentials for your wire installation.

* If you don't have a kubernetes cluster, you have two options:

  * You can get access to a managed kubernetes cluster with the cloud provider of your choice.
  * You can install one if you have ssh access to a virtual machine, see :ref:`ansible-kubernetes`

* If you don't have ``helm`` yet, see `Installing helm <https://helm.sh/docs/using_helm/#installing-helm>`__.

Type ``helm version``, you should, if everything is configured correctly, see a result like this:

::

    Client: &version.Version{SemVer:"v2.13.1", GitCommit:"618447cbf203d147601b4b9bd7f8c37a5d39fbb4", GitTreeState:"clean"}
    Server: &version.Version{SemVer:"v2.13.1", GitCommit:"618447cbf203d147601b4b9bd7f8c37a5d39fbb4", GitTreeState:"clean"}


In case ``kubectl version`` shows both Client and Server versions, but ``helm version`` does not show a Server version, you may need to run ``helm init``. The exact version (assuming `v2.X.X` - at the time of writing v3 is not yet supported) matters less as long as both Client and Server versions match (or are very close).

Upgrading from Helm2 to Helm3
-----------------------------
Download and install the newest version of Helm 3 from get.helm.sh.

.. code:: shell

   curl https://get.helm.sh/helm-v3.1.0-linux-amd64.tar.gz -o helm-v3.1.0-linux-amd64.tar.gz
   tar -xzf helm-v3.1.0-linux-amd64.tar.gz --strip=1 --wildcards */helm
   sudo cp helm /usr/local/bin/

How to download charts in the Offline environment
--------------------------------------------------

.. code:: shell

   cd wire-server-deploy/
   wget -r -l 10 https://helm.wire.com/charts/
   mv helm.wire.com/charts/ ./wire
   rm $(find wire/ -name index*)

How to start installing charts from wire (Helm 2)
--------------------------------------------------

Enable the wire charts helm repository:

.. code:: shell

   helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts

(You can see available helm charts by running ``helm search wire/``. To see
new versions as time passes, you may need to run ``helm repo update``)

Great! Now you can start installing.

.. note::

    all commands below can also take an extra ``--namespace <your-namespace>`` if you don't want to install into the default kubernetes namespace.

There is a shell script for doing this with helm 2. cat bin/prod-setup.sh 

Watching changes as they happen
-------------------------------

Open a terminal and run:

.. code:: shell

    kubectl get pods -w

This will block your terminal and show some things happening as you proceed through this guide. Keep this terminal open and open a second terminal.

How to install charts that provide access to external databases
---------------------------------------------------------------

Open a terminal and run:

.. code:: shell

   helm install cassandra-external wire/cassandra-external/ -f values/cassandra-external/values.yaml --wait
   helm install elasticsearch-external wire/elasticsearch-external/ -f values/elasticsearch-external/values.yaml --wait
   helm install minio-external wire/minio-external/ -f values/minio-external/values.yaml --wait
   cp values/databases-ephemeral/prod-values.example.yaml values/databases-ephemeral/values.yaml
   helm install databases-ephemeral wire/databases-ephemeral -f values/databases-ephemeral/values.yaml --wait

How to install fake AWS services
--------------------------------

Open a terminal and run:

.. code:: shell

   cp values/fake-aws/prod-values.example.yaml values/fake-aws/values.yaml
   helm install fake-aws wire/fake-aws -f values/fake-aws/values.yaml --wait

You should see some pods being created in your first terminal as the above command completes.

How to install fake SMTP (email) services
----------------------------------------

.. code:: shell

   cp values/demo-smtp/prod-values.example.yaml values/demo-smtp/values.yaml
   helm install smtp wire/demo-smtp -f values/demo-smtp/values.yaml


You should see some pods being created in your first terminal as the above command completes.

How to install wire-server itself
---------------------------------------

.. note::

    the following makes use of overrides for helm charts. You may wish to read :ref:`understand-helm-overrides` first.*


.. code:: shell

   mkdir -p wire-server && cd wire-server
   cp values/wire-server/prod-secrets.example.yaml my-wire-server/secrets.yaml
   cp values/wire-server/prod-values.example.yaml my-wire-server/values.yaml

Open ``my-wire-server/values.yaml`` and replace ``example.com`` and other domains and subdomains with domains of your choosing. Look for the ``# change this`` comments. You can try using ``sed -i 's/example.com/<your-domain>/g' values.yaml``.

1. If you are not using team settings, comment out ``teamSettings`` under brig/config/externalURLs.


Generate some secrets:

.. code:: shell

  openssl rand -base64 64 | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 42 > my-wire-server/restund.txt
  docker run --rm quay.io/wire/alpine-intermediate /dist/zauth -m gen-keypair -i 1 > my-wire-server/zauth.txt

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

* two dns names for the so-called "nginz" component of wire-server (the main REST API entry point), these are usually called `nginz-https.<domain>` (or `wire-https.<domain>`) and `nginz-ssl.<domain>` (or `wire-https.<domain>`).
* one dns name for the asset store (images, audio files etc. that your users are sharing); usually `assets.<domain>` or `s3.<domain>`.
* one dns name for the webapp (equivalent of https://app.wire.com, i.e. the javascript app running in the browser), usually called `webapp.<domain>`.
* one dns name for the account pages (hosts some html/javascript pages for e.g. password reset), usually called `account.<domain>`.
* (optional) one dns name for team settings (to manage team membership if using PRO accounts), usually called `teams.<domain>`
* (optional) one dns name for a audio/video calling server, usually called `restund01.<domain>`.

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

At this point, with a bit of luck, everything should be working (if not, see :ref:`helm_troubleshooting`)

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

.. _helm_troubleshooting:

Troubleshooting
--------------------

Which version am I on?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

There are multiple artifacts which combine to form a running wire-server
deployment; these include:

-  docker images for each service
-  kubernetes configs for each deployment (from helm charts)
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

As long as nobody is using your cluster yet, you can safely delete and re-create a specific helm release (list releases with ``helm list --all``). Example delete the ``wire-server`` helm release:

.. code:: shell

    helm delete --purge wire-server

It doesn't work, but my problem isn't listed here. Help!
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Feel free to open a github issue or pull request `here <https://github.com/wireapp/wire-docs>`_ and we'll try to improve the documentation.
