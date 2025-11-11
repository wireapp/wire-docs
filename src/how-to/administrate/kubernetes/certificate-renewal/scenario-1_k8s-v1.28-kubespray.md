# How to renew certificates on kubernetes 1.28.x

Kubernetes-internal certificates by default (see assumptions) expire after one year. Without renewal, your installation will cease to function.
This page explains how to renew certificates.

## Assumptions

- Kubernetes version 1.28.x
- installed with the help of [Kubespray](https://github.com/kubernetes-sigs/kubespray)
  - This page was tested using kubespray release 2.15 branch from 2024-12-18, i.e. commit `781f02fddab7700817949c2adfd9dbda21cc68d8`.
- setup: 3 scheduled nodes, each hosting master (control plane) +
  worker (kubelet) + etcd (cluster state, key-value database)

*NOTE: due to Kubernetes being installed with Kubespray, the Kubernetes
CAs (expire after 10yr) as well as certificates involved in etcd
communication (expire after 100yr) are not required to be renewed (any
time soon).*

**Official documentation:**

- [Certificate Management with kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)
- [PKI certificates and requirements](https://kubernetes.io/docs/setup/best-practices/certificates/)

## High-level description

1. verify current expiration date
2. issue new certificates
3. generate new client configuration (aka kubeconfig file)
4. restart control plane
5. drain node - restart kubelet - uncordon node again
6. repeat 3-5 on all other nodes

## Automated way

WIP:

## Step-by-step instructions

*Please note, that the following instructions may require privileged
execution. So, either switch to a privileged user or prepend following
statements with \`\`sudo\`\`. In any case, it is most likely that every
newly created file has to be owned by \`\`root\`\`, depending on kow
Kubernetes was installed.*

1. Verify current expiration date on each node

```bash
kubeadm certs check-expiration
```

2. Allocate a terminal session on one node and backup existing
   certificates & configurations. You can skip creating backups if your certificates have already expired and your service is going down.

```bash
cd /etc/kubernetes

cp -r ./ssl ./ssl.bkp

cp admin.conf admin.conf.bkp
cp controller-manager.conf controller-manager.conf.bkp
cp scheduler.conf scheduler.conf.bkp
cp kubelet.conf kubelet.conf.bkp
```

3. Renew certificates on that very node

```bash
kubeadm certs renew all
```

*Looking at the timestamps of the certificates, it is indicated, that apicerver, kubelet & proxy-client have been
renewed. This can be confirmed, by executing step 1. again*

4. Based on those renewed certificates, generate new kubeconfig files

The first command assumes it’s being executed on a master node. You may need to swap `masters` with `nodes` in
case you are running your cluster differently (for on-prem, we usually run a 3-node cluster with all `master` nodes).

```bash
kubeadm kubeconfig user --org system:masters --client-name kubernetes-admin  > /etc/kubernetes/admin.conf
kubeadm kubeconfig user --client-name system:kube-controller-manager > /etc/kubernetes/controller-manager.conf
kubeadm kubeconfig user --client-name system:kube-scheduler > /etc/kubernetes/scheduler.conf
```

*Again, check if ownership and permission for these files are the same
as all the others around them.*

And, in case you are operating the cluster from the current node, you may want to replace the user’s kubeconfig.
Afterwards, compare the backup version with the new one, to see if any configuration (e.g. pre-configured *namespace*)
might need to be moved over, too.

```bash
mv ~/.kube/config ~/.kube/config.bkp
cp /etc/kubernetes/admin.conf ~/.kube/config
chown $(id -u):$(id -g) ~/.kube/config
chmod 770 ~/.kube/config
```

5. Now that certificates and configuration files are in place, the
   control plane must be restarted. They typically run in containers, so
   the easiest way to trigger a restart, is to kill the processes
   running in there. Use (1) to verify, that the expiration dates indeed
   have been changed.

First, find the `kube-apiserver`, `kube-controller-manager` and `kube-scheduler` containers
```bash
crictl ps | grep kube
```

Now stop the containers by their IDs with (its the *first* one in the list):
```bash
crictl stop ID
```

6. Make *kubelet* aware of the new certificate

You can check the expiration of kubelet cert with, sometimes it can be out of sync with `kubeadm` ones. We recommend keeping them in sync!

```bash
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates
```

7. Drain the node (optional, will cause a small downtime if you skip, skip if your certs are already expired)

```bash
kubectl drain --delete-local-data --ignore-daemonsets $(hostname)
```

8. Stop the kubelet process

```bash
systemctl stop kubelet
```

9. Remove old certificates and configuration

```bash
mv /var/lib/kubelet/pki{,old}
mkdir /var/lib/kubelet/pki
```

10. Generate new kubeconfig file for the kubelet

```bash
kubeadm kubeconfig user --org system:nodes --client-name system:node:$(hostname) > /etc/kubernetes/kubelet.conf
```

11. Start kubelet again

```bash
systemctl start kubelet
```

12. [Optional] Verify kubelet has recognized certificate rotation

```bash
sleep 5 && systemctl status kubelet
```

13. Check kubelet certs

```bash
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates
```

14. Allow workload to be scheduled again on the node (if you drained the node beforehand)

```bash
kubectl uncordon $(hostname)
```

15. Copy certificates over to all the other nodes

Option A - you can ssh from one kubernetes node to another

```bash
# set the ip or hostname:
export NODE2=root@ip-or-hostname
export NODE3=...

scp ./ssl/apiserver.* "${NODE2}:/etc/kubernetes/ssl/"
scp ./ssl/apiserver.* "${NODE3}:/etc/kubernetes/ssl/"

scp ./ssl/apiserver-kubelet-client.* "${NODE2}:/etc/kubernetes/ssl/"
scp ./ssl/apiserver-kubelet-client.* "${NODE3}:/etc/kubernetes/ssl/"

scp ./ssl/front-proxy-client.* "${NODE2}:/etc/kubernetes/ssl/"
scp ./ssl/front-proxy-client.* "${NODE3}:/etc/kubernetes/ssl/"
```

Option B - copy via local administrator’s machine

```bash
# set the ip or hostname:
export NODE1=root@ip-or-hostname
export NODE2=
export NODE3=

scp -3 "${NODE1}:/etc/kubernetes/ssl/apiserver.*" "${NODE2}:/etc/kubernetes/ssl/"
scp -3 "${NODE1}:/etc/kubernetes/ssl/apiserver.*" "${NODE3}:/etc/kubernetes/ssl/"

scp -3 "${NODE1}:/etc/kubernetes/ssl/apiserver-kubelet-client.*" "${NODE2}:/etc/kubernetes/ssl/"
scp -3 "${NODE1}:/etc/kubernetes/ssl/apiserver-kubelet-client.*" "${NODE3}:/etc/kubernetes/ssl/"

scp -3 "${NODE1}:/etc/kubernetes/ssl/front-proxy-client.*" "${NODE2}:/etc/kubernetes/ssl/"
scp -3 "${NODE1}:/etc/kubernetes/ssl/front-proxy-client.*" "${NODE3}:/etc/kubernetes/ssl/"
```

Now repeat the process from step (4) on each node that is left
