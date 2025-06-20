# Introduction

#### WARNING
It is *strongly recommended* to have followed and completed the demo installation [How to install Wire in a box (Demo)](demo-wiab.md) before continuing with this page. The demo installation is simpler, and already makes you aware of a few things you need (TLS certs, DNS, a VM, …).

#### NOTE
All required dependencies for doing an installation can be found here [Dependencies on operator’s machine](dependencies.md#dependencies).

A production installation consists of several parts:

Part 1 - you’re on your own here, and need to create a set of VMs as detailed in [Production installation (persistent data, high-availability)](planning.md#planning-prod)

Part 2 ([Installing kubernetes and databases on VMs with ansible](ansible-VMs.md#ansible-vms)) deals with installing components directly on a set of virtual machines, such as kubernetes itself, as well as databases. It makes use of ansible to achieve that.

Part 3 ([Installing wire-server (production) components using Helm](helm-prod.md#helm-prod)) is similar to the demo installation, and uses the tool `helm` to install software on top of kubernetes.

Part 4 ([Infrastructure configuration options](infrastructure-configuration.md#configuration-options)) details other possible configuration options and settings to fit your needs.

## What will be installed by following these parts?

- highly-available and persistent databases (cassandra, elasticsearch)
- kubernetes
- restund (audio/video calling) servers ( see also [Restund (TURN) servers](../../understand/restund.md#understand-restund))
- wire-server (API)
  -  user accounts, authentication, conversations
  -  assets handling (images, files, …)
  -  notifications over websocket
  -  single-sign-on with SAML
- wire-webapp
  - fully functioning web client (like `https://app.wire.com`)
- wire-account-pages
  - user account management (a few pages relating to e.g. password reset)

## What will not be installed?

- notifications over native push notification via [FCM](https://firebase.google.com/docs/cloud-messaging/)/[APNS](https://developer.apple.com/notifications/)

## What will not be installed by default?

- 3rd party proxying - requires accounts with third-party providers
- team-settings page for team management (including invitations, requires access to a private repository - get in touch with us for access)

## Getting support

[Get in touch](https://wire.com/pricing/).

## Next steps for high-available production installation

Your next step will be part 2, [Installing kubernetes and databases on VMs with ansible](ansible-VMs.md#ansible-vms)
