.. _configure-federation:

Configure Wire-Server for federation
=====================================

Background
-----------

Please first understand the current scope and aim of wire-server federation by reading :ref:`Understanding federation <federation-understand>`

Summary of necessary steps to configure federation
--------------------------------------------------

*(the steps will be detailed in the sections below)*

* Choose and set a backend domain name at the level of helm value overrides
* Set up multiple DNS records including an ``SRV`` record
* Generate and/or configure TLS certificates:
    * server certificates
    * client certificates
    * a selection of CA certificates you trust when interacting with other backends
* Configure helm charts : federator and ingress subcharts
* Test that your configurations work as expected.


Choose a :ref:`Backend Domain Name<glossary_backend_domain>`
---------------------------------------------------------------

As of the release [helm chart 0.129.0, Wire docker version 2.94.0] from
2020-12-15, a Backend Domain (set as ``federationDomain`` in configuration) is a
mandatory configuration setting.  Regardless of whether a backend wants to
enable federation or not, the operator must decide what its domain is going to
be. This helps in keeping things simpler across all components of Wire and also
enables to turn on federation in the future if required.

It is highly recommended that this domain is configured as
something that is controlled by the administrator/operator(s). The actual
servers do not need to be available on this domain, but you MUST be able to set
an SRV record for ``_wire-server-federator._tcp.<Backend Domain>`` that
informs other wire-server backends where to find your actual servers.

**IMPORTANT** Once this option is set, it cannot be changed without breaking
experience for all the users which are already using the backend.

Consequences of the choice of Backend Domain
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

* You need control over a specific subdomain of this backendDomain (to set an
  SRV DNS record). Without this control, you cannot federate with anyone.
* This backendDomain becomes part of the underlying identify of all users on
  your servers.

   * Example: Let's say you choose ``example.com`` as your backendDomain.
     Your user known to you as Alice, and known on your server with ID
     ``ac41a202-2555-11ec-9341-00163e5e6c00`` will become known for other
     servers you federate with as

     .. code:: json

        {
          "user": {
            "id": "ac41a202-2555-11ec-9341-00163e5e6c00",
            "domain": "example.com"
          }
        }

* As of October 2021, this domain is used in the UI alongside user information.
  (This may or may not change in the future)

   * Example: Using the same as above, for backends you federate with, Alice
     would be displayed with the human-readable username ``@alice@example.com``

.. warning ::

    As of October 2021, *changing* this Backend Domain after existing user activity
    with recent (versions later than ~May/June 2021) will lead to undefined
    (untested, not accounted for during development) behaviour on some or all
    client platforms (Web, Android, iOS) for those users: It's possible your
    clients could crash, or lose part of their data about themselves or other
    users and conversations, or otherwise exhibit unexpected behaviour. If at
    all possible, do not change this backend domain.

Set up multiple DNS records including an ``SRV`` record
---------------------------------------------------------

Assuming your :ref:`glossary_backend_domain` is ``example.com``, you want to set up an SRV record.


TODO include bit from the DNS page

TODO explain how to set dns to point to federator


Configure helm charts: federator and ingress subcharts
-------------------------------------------------------

TODO TLS certs

Configure the validation depth when handling client certificates
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

By default, ``verify_depth`` is ``1``, meaning that in order to validate an incoming request from another backend needs to have a client certificate that is directly (without any intermediate certificates) signed by a CA certificate from the trust store.

Example: If you trust a CA ``root`` which signs an intermediate ``intermediate-1`` which in turn signs ``intermediate-2`` which finally signs ``leaf``, and ``leaf`` is used during mutual TLS when validating incoming requests, then ``verify_depth`` would need to be set to ``3``.

.. code:: yaml

    # nginx-ingress-services/values.yaml
    tls:
      # the validation depth between a federator client certificate and tlsClientCA
      verify_depth: 1 # default: 1

Configure the allow list
~~~~~~~~~~~~~~~~~~~~~~~~

By default, federation is turned off (allow list set to the empty list):

.. code:: yaml

   # wire-server/values.yaml
   federator:
     optSettings:
       federationStrategy:
         allowedDomains: []

You can choose to federate with a specific list of allowed backends:

.. code:: yaml

   # wire-server/values.yaml
   federator:
     optSettings:
       federationStrategy:
         allowedDomains:
          - example.com
          - example.org

or, you can federate with everyone:

.. code:: yaml

   # wire-server/values.yaml
   federator:
     optSettings:
       federationStrategy:
         allowAll: true



Test that your configurations work as expected
----------------------------------------------

Test DNS
Test certs
Test
