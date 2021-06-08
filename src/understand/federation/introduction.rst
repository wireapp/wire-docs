Introduction
============

Federation is a feature that allows a collection of Wire backends to facilitate
connection between their respective users.

If two Wire backends A and B are _federated_, the goal is for users of backend A
to be able to communicate with users of backend B and vice-versa in the same way
as if they were both part of the same backend.

Federated backends identify, discover and authenticate one-another using the
domain names under which they are reachable via the network.

To enable federation, administrators of a Wire backend can decide to either
specifically list the backends that they want to federate with, or those that
they do _not_ want to federate with.

Federation is facilitated by a backend component called the _federator_, which
acts as the ingress and egress point for federated communication.

In the following we document the architecture of a federated network of Wire
backends, how federated backends communicate and how individual backends can be
configured for federation.
