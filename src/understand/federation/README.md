<a id="federation-understand"></a>

# Wire Federation

Wire Federation aims to allow multiple Wire-server
[backends](architecture.md#glossary-backend) to federate with each other: Users on on
different backends are be able to interact with each other as if they
are on the the same backend.

Federated backends are be able to identify, discover and authenticate
one-another using the domain names under which they are reachable via the
network. To enable federation, administrators of a Wire backend can decide to
either specifically list the backends that they want to federate with, or to
allow federation with all Wire backends reachable from the network. See
[Federation](../configure-federation.md#configure-federation).

#### NOTE
The Federation development is work in progress.

* [Federation Achitecture](architecture.md)
  * [Backends](architecture.md#backends)
  * [Backend domains](architecture.md#glossary-backend-domain)
  * [Federation Ingress](architecture.md#federation-ingress)
  * [Federator](architecture.md#federator)
  * [Service components](architecture.md#service-components)
* [Backend to backend communication](backend-communication.md)
  * [Authentication](backend-communication.md#authentication)
  * [Discovery](backend-communication.md#discovery)
  * [Authorization](backend-communication.md#allow-list)
  * [Example](backend-communication.md#example)
* [Federation API](api.md)
  * [Qualified Identifiers and Names](api.md#qualified-identifiers-and-names)
  * [Federated requests](api.md#federated-requests)
  * [List of Federation APIs exposed by Components](api.md#list-of-federation-apis-exposed-by-components)
  * [Example End-to-End Flows](api.md#example-end-to-end-flows)
  * [Ownership](api.md#ownership)
