# Installation Guide

## 1. Planning an Installation
- [How to plan an installation](planning.md)
  - [Demo installation (trying functionality out)](planning.md#demo-installation-trying-functionality-out)
  - [Production installation (persistent data, high-availability)](planning.md#production-installation-persistent-data-high-availability)

## 2. Version Requirements
- [Version requirements](version-requirements.md)
  - [Persistence](version-requirements.md#persistence)

## 3. Dependencies on Operator’s Machine
- [Dependencies on operator’s machine](dependencies.md)
  - [(Alternative) Installing dependencies using Direnv and Nix](dependencies.md#alternative-installing-dependencies-using-direnv-and-nix)

## 4. Installing Kubernetes (Demo)
- [How to install kubernetes (Demo)](kubernetes.md)
  - [How to set up your hosts.ini file](kubernetes.md#how-to-set-up-your-hosts-ini-file)
  - [Passwordless authentication](kubernetes.md#passwordless-authentication)
  - [Minio setup](kubernetes.md#minio-setup)
  - [How to install kubernetes](kubernetes.md#how-to-install-kubernetes)

## 5. Installing Wire-Server using Helm (Demo)
- [How to install wire-server using Helm (Demo)](helm.md)
  - [Introduction](helm.md#introduction)
  - [Prerequisites](helm.md#prerequisites)
  - [How to start installing charts from wire](helm.md#how-to-start-installing-charts-from-wire)
  - [Watching changes as they happen](helm.md#watching-changes-as-they-happen)
  - [How to install in-memory databases and external components](helm.md#how-to-install-in-memory-databases-and-external-components)
  - [How to install wire-server itself](helm.md#how-to-install-wire-server-itself)

## 6. Introduction
- [Introduction](prod-intro.md)
  - [What will be installed by following these parts?](prod-intro.md#what-will-be-installed-by-following-these-parts)
  - [What will not be installed?](prod-intro.md#what-will-not-be-installed)
  - [What will not be installed by default?](prod-intro.md#what-will-not-be-installed-by-default)
  - [Getting support](prod-intro.md#getting-support)
  - [Next steps for high-available production installation](prod-intro.md#next-steps-for-high-available-production-installation)

## 7. Installing Kubernetes and Databases
- [How to install kubernetes and databases](ansible-VMs.md)
  - [Introduction](ansible-VMs.md#introduction)
  - [Assumptions](ansible-VMs.md#assumptions)
  - [Preparing to run ansible](ansible-VMs.md#preparing-to-run-ansible)
  - [Running ansible to install software on your machines](ansible-VMs.md#running-ansible-to-install-software-on-your-machines)

## 8. Configuring AWS Services
- [How to configure AWS services](aws-prod.md)
  - [Introduction](aws-prod.md#introduction)
  - [Using real AWS services for SNS](aws-prod.md#using-real-aws-services-for-sns)
  - [Using real AWS services for SES / SQS](aws-prod.md#using-real-aws-services-for-ses-sqs)
  - [Using real AWS services for S3](aws-prod.md#using-real-aws-services-for-s3)

## 9. Installing Wire-Server using Helm
- [How to install wire-server using Helm](helm-prod.md)
  - [Introduction](helm-prod.md#introduction)
  - [Prerequisites](helm-prod.md#prerequisites)
  - [Preparing to install charts from the internet with Helm](helm-prod.md#preparing-to-install-charts-from-the-internet-with-helm)
  - [Watching changes as they happen](helm-prod.md#watching-changes-as-they-happen)
  - [General installation notes](helm-prod.md#general-installation-notes)
  - [How to install charts that provide access to external databases](helm-prod.md#how-to-install-charts-that-provide-access-to-external-databases)
  - [How to install fake AWS services for SNS / SQS](helm-prod.md#how-to-install-fake-aws-services-for-sns-sqs)
  - [Preparing to install wire-server](helm-prod.md#preparing-to-install-wire-server)
  - [How to install RabbitMQ](helm-prod.md#how-to-install-rabbitmq)
  - [How to configure real SMTP (email) services](helm-prod.md#how-to-configure-real-smtp-email-services)
  - [How to install fake SMTP (email) services](helm-prod.md#how-to-install-fake-smtp-email-services)
  - [How to install wire-server itself](helm-prod.md#how-to-install-wire-server-itself)
  - [DNS records](helm-prod.md#dns-records)

## 10. Infrastructure Configuration
- [Infrastructure configuration](infrastructure-configuration.md)
  - [Redirect some traffic through a http(s) proxy](infrastructure-configuration.md#redirect-some-traffic-through-a-http-s-proxy)
  - [Enable push notifications using the public appstore / playstore mobile Wire clients](infrastructure-configuration.md#enable-push-notifications-using-the-public-appstore-playstore-mobile-wire-clients)
  - [Controlling the speed of websocket draining during cannon pod replacement](infrastructure-configuration.md#controlling-the-speed-of-websocket-draining-during-cannon-pod-replacement)
  - [Control nginz upstreams (routes) into the Kubernetes cluster](infrastructure-configuration.md#control-nginz-upstreams-routes-into-the-kubernetes-cluster)
  - [Separate incoming websocket network traffic from the rest of the https traffic](infrastructure-configuration.md#separate-incoming-websocket-network-traffic-from-the-rest-of-the-https-traffic)
  - [You may want](infrastructure-configuration.md#you-may-want)
  - [Metrics/logging](infrastructure-configuration.md#metrics-logging)
  - [SMTP server](infrastructure-configuration.md#smtp-server)
  - [Load balancer on bare metal servers](infrastructure-configuration.md#load-balancer-on-bare-metal-servers)
  - [Load Balancer on cloud-provider](infrastructure-configuration.md#load-balancer-on-cloud-provider)
  - [Real AWS services](infrastructure-configuration.md#real-aws-services)
  - [Persistence and high-availability](infrastructure-configuration.md#persistence-and-high-availability)
  - [Security](infrastructure-configuration.md#security)
  - [3rd-party proxying](infrastructure-configuration.md#rd-party-proxying)
  - [Routing traffic to other namespaces via nginz](infrastructure-configuration.md#routing-traffic-to-other-namespaces-via-nginz)
  - [Marking an installation as self-hosted](infrastructure-configuration.md#marking-an-installation-as-self-hosted)
  - [Configuring authentication cookie throttling](infrastructure-configuration.md#configuring-authentication-cookie-throttling)
  - [S3 Addressing Style](infrastructure-configuration.md#s3-addressing-style)
  - [I have a team larger than 500 users](infrastructure-configuration.md#i-have-a-team-larger-than-500-users)

## 11. Monitoring Wire-Server
- [How to monitor wire-server](monitoring.md)
  - [Dashboards](monitoring.md#dashboards)

## 12. Centralized Logs for Wire-Server
- [How to see centralized logs for wire-server](logging.md)
  - [Introduction](logging.md#introduction)
  - [Status](logging.md#status)
  - [Prerequisites](logging.md#prerequisites)
  - [Installing required helm charts](logging.md#installing-required-helm-charts)
  - [Configuring fluent-bit](logging.md#configuring-fluent-bit)
  - [Post-install kibana setup](logging.md#post-install-kibana-setup)
  - [Usage after installation](logging.md#usage-after-installation)
  - [Nuking it all.](logging.md#nuking-it-all)
  - [Debugging](logging.md#debugging)

## 13. Ingress-Controller (Getting Traffic In)
- [Ingress-controller (getting traffic in)](ingress.md)
  - [Installing in a cloud-like environment](ingress.md#installing-in-a-cloud-like-environment)
  - [Installing on bare-metal without dynamic load balancer support](ingress.md#installing-on-bare-metal-without-dynamic-load-balancer-support)

## 14. Web App Settings
- [Web app settings](web-app-settings.md)
  - [Enforce desktop application only](web-app-settings.md#enforce-desktop-application-only)
  - [Enforce constant bit rate](web-app-settings.md#enforce-constant-bit-rate)
  - [Disable media plugins](web-app-settings.md#disable-media-plugins)
  - [Enable extra entropy (only on Windows)](web-app-settings.md#enable-extra-entropy-only-on-windows)

## 15. Installing Conference Calling 2.0 (aka SFT)
- [Installing Conference Calling 2.0 (aka SFT)](sft.md)
  - [Background](sft.md#background)

## 16. Installing Restund
- [Installing Restund](restund.md)
  - [Background](restund.md#background)
  - [Installation instructions](restund.md#installation-instructions)

## 17. Configure TLS Ciphers
- [Configure TLS ciphers](tls.md)
  - [Ingress Traffic (wire-server)](tls.md#ingress-traffic-wire-server)
  - [Egress Traffic (wire-server/federation)](tls.md#egress-traffic-wire-server-federation)
  - [SFTD (ansible)](tls.md#sftd-ansible)
  - [SFTD (kubernetes)](tls.md#sftd-kubernetes)
  - [Coturn (kubernetes)](tls.md#coturn-kubernetes)
  - [Restund (ansible)](tls.md#restund-ansible)
  - [Restund (kubernetes)](tls.md#restund-kubernetes)

## 18. Managing Authentication with Ansible
- [Managing authentication with ansible](ansible-authentication.md)
  - [How to use password authentication when you ssh to a machine with ansible](ansible-authentication.md#how-to-use-password-authentication-when-you-ssh-to-a-machine-with-ansible)
  - [Configuring SSH keys](ansible-authentication.md#configuring-ssh-keys)
  - [Sudo without password](ansible-authentication.md#sudo-without-password)

## 19. Using Tinc
- [Using tinc](ansible-tinc.md)

## 20. Troubleshooting During Installation
- [Troubleshooting during installation](troubleshooting.md)
  - [Problems with CSP on the web based applications (webapp, team-settings, account-pages)](troubleshooting.md#problems-with-csp-on-the-web-based-applications-webapp-team-settings-account-pages)
  - [Problems with ansible and python versions](troubleshooting.md#problems-with-ansible-and-python-versions)
  - [Flaky issues with Cassandra (failed QUORUMs, etc.)](troubleshooting.md#flaky-issues-with-cassandra-failed-quorums-etc)
  - [I deployed `demo-smtp` but I’m not receiving any verification emails](troubleshooting.md#i-deployed-demo-smtp-but-i-m-not-receiving-any-verification-emails)
  - [I deployed `demo-smtp` and I want to skip email configuration and retrieve verification codes directly](troubleshooting.md#i-deployed-demo-smtp-and-i-want-to-skip-email-configuration-and-retrieve-verification-codes-directly)
  - [Obtaining Brig logs, and the format of different team/user events](troubleshooting.md#obtaining-brig-logs-and-the-format-of-different-team-user-events)
  - [Diagnosing and addressing bad network/disconnect issues](troubleshooting.md#diagnosing-and-addressing-bad-network-disconnect-issues)
  - [Diagnosing issues with installation steps.](troubleshooting.md#diagnosing-issues-with-installation-steps)
  - [Verifying correct deployment of DNS / DNS troubleshooting.](troubleshooting.md#verifying-correct-deployment-of-dns-dns-troubleshooting)

## 21. Verifying Your Installation
- [Verifying your installation](post-install.md)
  - [NTP Checks](post-install.md#ntp-checks)
  - [Logs and Data Protection checks](post-install.md#logs-and-data-protection-checks)
  - [Demo installation (trying functionality out)](planning.md#demo-installation-trying-functionality-out)
  - [Production installation (persistent data, high-availability)](planning.md#production-installation-persistent-data-high-availability)

