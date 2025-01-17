# Reference Guide

## 1. Architecture Overview
- [Architecture Overview](overview.md)
  - [Introduction](overview.md#introduction)
  - [Architecture and networking](overview.md#architecture-and-networking)

## 2. Single Sign-On and User Provisioning
- [Single Sign-On and User Provisioning](single-sign-on/README.md)
  - [Single sign-on and user provisioning: the user manual](single-sign-on/understand/main.md)
  - [Trouble shooting and FAQ](single-sign-on/trouble-shooting.md)
  - [Generic setup](single-sign-on/generic-setup.md)
  - [SSO integration with ADFS](single-sign-on/adfs/main.md)
  - [SSO integration with Azure](single-sign-on/azure/main.md)
  - [SSO integration with Centrify](single-sign-on/centrify/main.md)
  - [SSO integration with Okta](single-sign-on/okta/main.md)
  - [Internals for the intensely curious](../developer/reference/spar-braindump.md)

## 3. Audio/Video Calling (TURN/STUN)
- [Audio/video calling, restund servers (TURN/STUN)](restund.md)
  - [Introduction](restund.md#introduction)
  - [Architecture](restund.md#architecture)
  - [What is it used for](restund.md#what-is-it-used-for)
  - [Network](restund.md#network)
  - [Protocols and open ports](restund.md#protocols-and-open-ports)
  - [Amount of users and file descriptors](restund.md#amount-of-users-and-file-descriptors)
  - [Load balancing and high-availability](restund.md#load-balancing-and-high-availability)
  - [Discovery and establishing a call](restund.md#discovery-and-establishing-a-call)
  - [DNS](restund.md#dns)

## 4. Conference Calling 2.0 (SFT)
- [Conference Calling 2.0 (aka SFT)](sft.md)
  - [Background](sft.md#background)
  - [Architecture](sft.md#architecture)
  - [Establishing a call](sft.md#establishing-a-call)
  - [Prerequisites](sft.md#prerequisites)
- [Federated Conference Calling](sft.md#federated-conference-calling)
  - [Multi-SFT Architecture](sft.md#multi-sft-architecture)

## 5. Minio
- [Minio](minio.md)
  - [Minio philosophy](minio.md#minio-philosophy)
  - [Hurdles from the trenches: disk usage statistics; directories vs. disks](minio.md#hurdles-from-the-trenches-disk-usage-statistics-directories-vs-disks)

## 6. Helm
- [Helm](helm.md)
  - [Overriding helm configuration settings](helm.md#overriding-helm-configuration-settings)

## 7. Federation
- [Federation](federation/README.md)
  - [Federation Architecture](federation/architecture.md)
  - [Backend to backend communication](federation/backend-communication.md)
  - [Federation API](federation/api.md)

## 8. Connecting Wire Clients
- [Connecting Wire Clients](associate/README.md)
  - [How to associate a wire client to a custom backend using a deep link](associate/deeplink.md)
  - [How to use custom root certificates with wire clients](associate/custom-certificates.md)
  - [How to use a custom backend with the desktop client](associate/custom-backend-for-desktop-client.md)
  - [How to redirect email domains from cloud (or any other backend) to a custom backend](associate/sso-domain-redirect.md)

## 9. Client API Documentation
- [Client API documentation](api-client-perspective/README.md)
  - [Authentication](api-client-perspective/authentication.md)
  - [Swagger / OpenAPI documentation](api-client-perspective/swagger.md)

## 10. Crypto Libraries and Security
- [Crypto libraries and sources of randomness](crypto-libs.md)
- [Block personal user creation](block-user-creation.md)
  - [In Brig](block-user-creation.md#in-brig)
  - [In the WebApp](block-user-creation.md#in-the-webapp)
- [Classified Domains](classified-domains.md)

## 11. Federation Setup
- [Federation](configure-federation.md)
  - [Summary of necessary steps to configure federation](configure-federation.md#summary-of-necessary-steps-to-configure-federation)
  - [Choose a Backend Domain](configure-federation.md#choose-a-backend-domain)
  - [Consequences of the choice of a backend domain](configure-federation.md#consequences-of-the-choice-of-a-backend-domain)
  - [DNS setup for federation](configure-federation.md#dns-setup-for-federation)
  - [Generate and configure TLS server and client certificates](configure-federation.md#generate-and-configure-tls-server-and-client-certificates)
  - [Configure helm charts: federator and ingress and webapp subcharts](configure-federation.md#configure-helm-charts-federator-and-ingress-and-webapp-subcharts)
  - [Applying all configuration changes](configure-federation.md#applying-all-configuration-changes)
  - [Manually test that your configurations work as expected](configure-federation.md#manually-test-that-your-configurations-work-as-expected)

## 12. Legal Hold Setup
- [Installing and setting up Legal Hold](legalhold.md)
  - [Introduction](legalhold.md#introduction)
  - [Installing Legal Hold](legalhold.md#installing-legal-hold)
  - [Configuring Team Settings to use Legal Hold](legalhold.md#configuring-team-settings-to-use-legal-hold)

## 13. Security and Messaging
- [Messaging Layer Security (MLS)](mls.md)

## 14. User Searchability
- [User Searchability](searchability.md)
  - [Searching users on the same backend](searchability.md#searching-users-on-the-same-backend)
  - [Searching users on another federated backend](searchability.md#searching-users-on-another-federated-backend)
  - [Changing the settings for a given team](searchability.md#changing-the-settings-for-a-given-team)

## 15. Server and Team Settings
- [Server and team feature settings](team-feature-settings.md)
  - [2nd factor password challenge](team-feature-settings.md#nd-factor-password-challenge)
  - [Rate limiting of code generation requests](team-feature-settings.md#rate-limiting-of-code-generation-requests)
  - [Guest links](team-feature-settings.md#guest-links)
  - [TTL for nonces](team-feature-settings.md#ttl-for-nonces)
  - [MLS End-to-End Identity](team-feature-settings.md#mls-end-to-end-identity)
  - [MLS Migration](team-feature-settings.md#mls-migration)
