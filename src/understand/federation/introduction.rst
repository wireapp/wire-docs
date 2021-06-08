Introduction
============

Federation is a feature that allows a collection of Wire backends to facilitate
connections between their respective users.

Goals
-----

If two Wire backends A and B are _federated_, the goal is for users of backend A
to be able to communicate with users of backend B and vice-versa in the same way
as if they were both part of the same backend.

Federated backends should be able to identify, discover and authenticate
one-another using the domain names under which they are reachable via the
network.

To enable federation, administrators of a Wire backend can decide to either
specifically list the backends that they want to federate with, or those that
they do _not_ want to federate with.

Federation is facilitated by a backend component called the _federator_, which
acts as the ingress and egress point for federated communication.

Non-Goals
---------

We aim to integrate federation into the Wire backend following a step-by-step
process as described in :ref:`federation roadmap<federation-roadmap>`. Early
versions are not meant to enable a completely open federation, but rather a
closed network of federated backends with a restricted set of features.

The aim of federation is not to replace the existing organizational structures
for Wire users such as teams and groups, but rather to complement them.
