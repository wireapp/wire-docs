# Administration Guide

## 1. Kubernetes

- [Kubernetes](kubernetes/README.md)
  - [Certificate renewal](kubernetes/certificate-renewal/README.md)
  - [How to restart a machine that is part of a Kubernetes cluster?](kubernetes/restart-machines/README.md)
  - [Upgrading a Kubernetes cluster](kubernetes/upgrade-cluster/README.md)
  - [Troubleshooting problems arising after Kubernetes cluster upgrades](kubernetes/upgrade-cluster/README.md#troubleshooting-problems-arising-after-kubernetes-cluster-upgrades)

## 2. Backup and Disaster Recovery

- [Backup and disaster recovery](backup-disaster-recovery.md)
  - [Introduction](backup-disaster-recovery.md#introduction)
  - [Backing up](backup-disaster-recovery.md#backing-up)
  - [Recovery procedure](backup-disaster-recovery.md#recovery-procedure)

## 3. Cassandra

- [Cassandra](cassandra.md)
  - [Check the health of a Cassandra node](cassandra.md#check-the-health-of-a-cassandra-node)
  - [How to inspect tables and data manually](cassandra.md#how-to-inspect-tables-and-data-manually)
  - [How to rolling-restart a Cassandra cluster](cassandra.md#how-to-rolling-restart-a-cassandra-cluster)

## 4. Elasticsearch

- [Elasticsearch](elasticsearch.md)
  - [How to rolling-restart an Elasticsearch cluster](elasticsearch.md#how-to-rolling-restart-an-elasticsearch-cluster)
  - [How to manually look into what is stored in Elasticsearch](elasticsearch.md#how-to-manually-look-into-what-is-stored-in-elasticsearch)
  - [Check the health of an Elasticsearch node](elasticsearch.md#check-the-health-of-an-elasticsearch-node)
  - [Check cluster health](elasticsearch.md#check-cluster-health)
  - [List cluster nodes](elasticsearch.md#list-cluster-nodes)
  - [Troubleshooting](elasticsearch.md#troubleshooting)

## 5. Etcd

- [Etcd](etcd.md)
  - [How to see cluster health](etcd.md#how-to-see-cluster-health)
  - [How to inspect tables and data manually](etcd.md#how-to-inspect-tables-and-data-manually)
  - [How to rolling-restart an Etcd cluster](etcd.md#how-to-rolling-restart-an-etcd-cluster)
  - [Backing up and restoring](etcd.md#backing-up-and-restoring)
  - [Troubleshooting](etcd.md#troubleshooting)

## 6. General - Linux

- [General - Linux](general-linux.md)
  - [Which ports and network interface is my process running on?](general-linux.md#which-ports-and-network-interface-is-my-process-running-on)
  - [How can I see if my TLS certificates are configured the way I expect?](general-linux.md#how-can-i-see-if-my-tls-certificates-are-configured-the-way-i-expect)
  - [How can I see if my TLS certificates are configured the way I expect (special case Kubernetes from a Kubernetes machine)](general-linux.md#how-can-i-see-if-my-tls-certificates-are-configured-the-way-i-expect-special-case-kubernetes-from-a-kubernetes-machine)

## 7. Minio

- [Minio](minio.md)
  - [Should you be using Minio?](minio.md#should-you-be-using-minio)
  - [Setting up interaction with Minio](minio.md#setting-up-interaction-with-minio)
  - [Minio maintenance](minio.md#minio-maintenance)
  - [Rotate root credentials](minio.md#rotate-root-credentials)
  - [Check the health of a MinIO node](minio.md#check-the-health-of-a-minio-node)

## 8. Operational Procedures

- [Operational procedures](operations.md)
  - [Reboot procedures](operations.md#reboot-procedures)
  - [Health checks](operations.md#health-checks)
  - [Draining pods from a node for maintenance](operations.md#draining-pods-from-a-node-for-maintainance)
  - [Understand release tags](operations.md#understand-release-tags)

## 9. Restund (TURN)

- [Restund (TURN)](restund.md)
  - [Wire-Server Configuration](restund.md#wire-server-configuration)
  - [How to see how many people are currently connected to the restund server](restund.md#how-to-see-how-many-people-are-currently-connected-to-the-restund-server)
  - [How to restart restund (with downtime)](restund.md#how-to-restart-restund-with-downtime)
  - [Rebooting a Restund node](restund.md#rebooting-a-restund-node)
  - [How to restart restund without having downtime](restund.md#how-to-restart-restund-without-having-downtime)
  - [How to renew a certificate for restund](restund.md#how-to-renew-a-certificate-for-restund)
  - [How to check which restund/TURN servers will be used by clients](restund.md#how-to-check-which-restund-turn-servers-will-be-used-by-clients)

## 10. Investigative Tasks

- [Investigative tasks (e.g. searching for users as server admin)](users.md)
  - [Manually searching for users in Cassandra](users.md#manually-searching-for-users-in-cassandra)
  - [Deleting a user which is not a team user](users.md#deleting-a-user-which-is-not-a-team-user)
  - [Searching and deleting users with no team](users.md#searching-and-deleting-users-with-no-team)
  - [Manual search on Elasticsearch (via brig, recommended)](users.md#manual-search-on-elasticsearch-via-brig-recommended)
  - [How to manually search for a user on Elasticsearch directly (not recommended)](users.md#how-to-manually-search-for-a-user-on-elasticsearch-directly-not-recommended)
  - [How to manually delete a user from Elasticsearch only](users.md#how-to-manually-delete-a-user-from-elasticsearch-only)
  - [Mass-invite users to a team](users.md#mass-invite-users-to-a-team)
  - [How to obtain logs from an Android client to investigate issues](users.md#how-to-obtain-logs-from-an-android-client-to-investigate-issues)
  - [How to obtain logs from an iOS client to investigate issues](users.md#how-to-obtain-logs-from-an-ios-client-to-investigate-issues)
  - [How to retrieve metric values manually](users.md#how-to-retrieve-metric-values-manually)
  - [Reset session cookies](users.md#reset-session-cookies)
  - [Identify all users using SSO](users.md#identify-sso-users)
  - [Create a team using the SCIM API](users.md#create-a-team-using-the-scim-api)

## 11. Manuals

- [Test an ingress is working from inside the cluster](manuals.md#test-an-ingress-is-working-from-inside-the-cluster)
- [Load an image into containerd in an offline/airgapped environment](manuals.md#load-an-image-into-containerd-in-an-offlineairgapped-environment)

<!-- TODO: .. include:: administration/redis.rst -->
