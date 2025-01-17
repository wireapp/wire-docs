# General - Linux

This section is about **how to perform a specific task**. If you want to **understand how a certain component works, please see** [Reference](../../understand/README.md#understand)

The rest of the page assumes you installed using the ansible playbooks from [wire-server-deploy](https://github.com/wireapp/wire-server-deploy/tree/master/ansible)

For any command below, first ssh into the server:

```default
ssh <name or IP of the VM>
```

## Which ports and network interface is my process running on?

The following shows open TCP ports, and the related processes.

```sh
sudo netstat -antlp | grep LISTEN
```

which may yield output like this:

```sh
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      1536/sshd
```

<a id="how-to-see-tls-certs"></a>

## How can I see if my TLS certificates are configured the way I expect?

#### NOTE
The following assumes you’re querying a server from outside (e.g. your laptop). See the next section if operating on a server from an SSH session.

You can use openssl to check, with e.g.

```sh
DOMAIN=example.com
PORT=443
echo Q | openssl s_client -showcerts -connect $DOMAIN:$PORT
```

or

```sh
DOMAIN=example.com
PORT=443
echo Q | openssl s_client -showcerts -connect $DOMAIN:$PORT 2>/dev/null | openssl x509 -inform pem -noout -text
```

To see only the validity (expiration):

```sh
DOMAIN=example.com
PORT=443
echo Q | openssl s_client -showcerts -connect $DOMAIN:$PORT 2>/dev/null | openssl x509 -inform pem -noout -text | grep Validity -A 2
```

## How can I see if my TLS certificates are configured the way I expect (special case kubernetes from a kubernetes machine)

When you first SSH to a kubernetes node, depending on the setup, DNS may not resolve, in which case you can use the `-servername` parameter:

```sh
# the IP of the network interface that kubernetes is listening on. 127.0.0.1 may or may not work depending on the installation. It's one of those from
# ifconfig | grep "inet addr"
IP=1.2.3.4
# PORT can be 443 or 31773, depending on the installation
PORT=443
# not the root domain, but one of the 5 subdomains for which kubernetes is serving traffic
DOMAIN=app.example.com

echo Q | openssl s_client -showcerts -servername $DOMAIN -connect $IP:$PORT 2>/dev/null | openssl x509 -inform pem -noout -text | grep Validity -A 2
```
