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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
   * Example: Using the same as above, for backends you federate with, Alice
     would be displayed with the human-readable username ``@alice@example.com``


Set up multiple DNS records including an ``SRV`` record
---------------------------------------------------------








