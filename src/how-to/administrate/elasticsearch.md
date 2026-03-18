# Elasticsearch

This section is about **how to perform a specific task**. If you want to **understand how a certain component works, please see** [Reference](../../understand/README.md#understand)

The rest of the page assumes you installed using the ansible playbooks from [wire-server-deploy](https://github.com/wireapp/wire-server-deploy/tree/master/ansible)

For any command below, first ssh into the server:

```default
ssh <name or IP of the VM>
```

For more information, see the [elasticsearch
documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)

<a id="restart-elasticsearch"></a>

## How to rolling-restart an elasticsearch cluster

For maintenance you may need to restart the cluster.

On each server one by one:

1. check your cluster is healthy (see above)
2. stop shard allocation:

```sh
ES_IP=<the-ip-of-the-elasticsearch-node-to-stop>
curl -sSf -XPUT http://localhost:9200/_cluster/settings -H 'Content-Type: application/json' -d "{ \"transient\" : {\"cluster.routing.allocation.exclude._ip\": \"$ES_IP\" }}"; echo;
```

You should expect some output like this:

```sh
{"acknowledged":true,"persistent":{},"transient":{"cluster":{"routing":{"allocation":{"exclude":{"_ip":"<SOME-IP-ADDRESS>"}}}}}}
```

1. Stop the elasticsearch daemon process: `systemctl stop elasticsearch`
2. do any operation you need, if any
3. Start the elasticsearch daemon process: `systemctl start elasticsearch`
4. re-enable shard allocation:

```sh
curl -sSf -XPUT http://localhost:9200/_cluster/settings -H 'Content-Type: application/json' -d "{ \"transient\" : {\"cluster.routing.allocation.exclude._ip\": null }}"; echo;
```

You should expect some output like this from the above command:

```sh
{"acknowledged":true,"persistent":{},"transient":{}}
```

1. Wait for your cluster to be healthy again.
2. Do the same on the next server.

## How to manually look into what is stored in elasticsearch

See also the elasticsearch sections in [Investigative tasks (e.g. searching for users as server admin)](users.md#investigative-tasks).

<a id="check-the-health-of-an-elasticsearch-node"></a>

## Check the health of an elasticsearch node

To check the health of an elasticsearch node, run the following command:

```sh
ssh <ip of elasticsearch node> curl localhost:9200/_cat/health
```

You should see output looking like this:

```default
1630250355 15:18:55 elasticsearch-directory green 3 3 17 6 0 0 0 - 100.0%
```

Here, the `green` denotes good node health, and the `3 3` denotes 3 running nodes.

## Check cluster health

This is the command to check the health of the entire cluster:

```sh
ssh <ip of elasticsearch node> curl 'http://localhost:9200/_cluster/health?pretty'
```

## List cluster nodes

This is the command to list the nodes in the cluster:

```sh
ssh <ip of elasticsearch node> curl 'http://localhost:9200/_cat/nodes?v&h=id,ip,name'
```

## How to recreate ES index

### Native way (somewhat)

Charts for `wire-server` will be needed, specifically, subchart `elasticsearch-index`.

Create a new index with the new mappings by configuring a `values.yaml` file like so:

```
elasticsearch:
  host: your-elasticsearch-host
  index: new-index-name # default/current is directory, so pick something else
image:
  tag: 5.23.0 # minimal wire-server version this was tested with
```

Find your current `elasticsearch-index-create` job and delete it:

```
kubectl get pods | grep elasticsearch
kubectl delete pod elasticsearch-index-create-xxxx
```

Then helm install the elasticsearch-index charts with the previously configured `values.yaml`:

```
helm install --upgrade elasticsearch-index charts/wire-server/charts/elasticsearch-index -f values.yaml
```

This will create a new index in ES cluster, to verify, log onto your ES cluster machine and run:

```
curl "localhost:9200/_cat/indices"
```

Depending on your ES setup, you might need to use https and provide credentials.
In the output you should see your new index there.

Next, configure `wire-server` values file to use both the new index and the old one (until we populate the new with old index data).

```
brig:
  config:
    elasticsearch:
      index: directory # default wire-server value
      additionalWriteIndex: new-index-name-here
```

Apply it:

```
kubectl upgrade --install wire-server charts/wire-server -f values/wire-server/values.yaml -f values/wire-server/secrets.yaml
```

Now use native reindex ES API in your ES cluster like so:

```
curl "localhost:9200/_reindex?wait_for_completion" -H 'Content-Type: application/json' -d '{"source": {"index": "directory"}, "dest": {"index": "new-index-name-here"}}'
```

Wait for the result. Now switch the main/additional indexes in `wire-server`.

```
brig:
  config:
    elasticsearch:
      index: new-index-name-here
      additionalWriteIndex: directory
```

Apply it:

```
kubectl upgrade --install wire-server charts/wire-server -f values/wire-server/values.yaml -f values/wire-server/secrets.yaml
```

Now log onto Team Settings and check your member list if it is correct.
If it is, you can stop using `additionalWriteIndex` and delete the old one.

### Helm way

Charts for `elasticsearch-migrate` will be needed:

```
wget https://s3-eu-west-1.amazonaws.com/public.wire.com/charts-develop/elasticsearch-migrate-0.1.0.tgz
```

Create a `values.yaml` to configure it:

```
reindexType: "reindex"
runReindex: false
elasticsearch:
  host: # your elasticsearch host here
  index: directory_new # name of new index
cassandra:
  host: # your cassandra host here
image:
  tag: 5.23.0 # or whichever version you are running atm, the current method has been tested with 5.23 and 5.25
```

This will create a new index called `directory_new` after it has been run. The name of a new index can be of your choosing, `directory_new` was selected as the previous default one was `directory`.

Run it with helm (mind the following command assumes some paths which might not be applicable in your installation):

```
helm upgrade --install elasticsearch-migrate charts/elasticsearch-migrate -f values/elasticsearch-migrate/values.yaml
```

Configure brig to use both the standard and the newly created index (usually in `values/wire-server/values.yaml`):

```
brig:
  config:
    elasticsearch:
      host: elasticsearch-external
      index: directory # current default name of index
      additionalWriteIndex: directory_new # new index (should match the name set in previous step)
```

Apply it (same assumptions regarding paths as our standard deployment process):

```
helm upgrade --install wire-server charts/wire-server -f values/wire-server/values.yaml -f values/wire-server/values.yaml
```

To backfill the new index, edit `values.yaml` for `elasticsearch-migrate` charts and set `runReindex` to true:

```
reindexType: "reindex"
runReindex: true
elasticsearch:
  host: # your elasticsearch host here
  index: directory_new
cassandra:
  host: # your cassandra host here
image:
  tag: 5.23.0 # or whichever version you are running atm, the current method has been tested with 5.23 and 5.25
```

Apply it again:

```
helm upgrade --install elasticsearch-migrate charts/elasticsearch-migrate -f elasticsearch-migrate/values.yaml
```

This should start a kubernetes `Job` named `elasticsearch-migrate-data` that might take several hours to run, depending on the amount of data it needs to re-create.
Galley pods might get OOMKilled during this, if that is the case, increase galley memory for requests and limits (we found in Wire Cloud prod 8Gi is sufficient):

```
galley:
  resources:
    requests:
      memory: 8Gi
    limits:
      memory: 8Gi
```

Reapply:

```
helm upgrade --install wire-server charts/wire-server -f values/wire-server/values.yaml -f values/wire-server/values.yaml
```

And then restart `elasticsearch-migrate`.

After the reindexing is complete, configure wire-server to read from the new index:

```
brig:
  config:
    elasticsearch:
      index: directory_new
elasticsearch-index:
  elasticsearch:
    index: directory_new
```

After verifying all is okay on the client side (check your Team Settings UI, if you can see your team user list). You can delete the old index in your ES cluster with:

curl -X DELETE “localhost:9200/directory”

## Aliasing

To alias an index, use the Native Elasticsearch API in your ES cluster like so:

```
curl -X POST "localhost:9200/_aliases" -H 'Content-Type: application/json' -d '{"actions": [{"add": {"index": "directory-name-here", "alias": "alias-for-that-directory"}}]}'

## Troubleshooting

Description:
**ES nodes ran out of disk space** and error message says: `"blocked by: [FORBIDDEN/12/index read-only / allow delete (api)];"`

Solution:

1. Connect to the node:

```sh
ssh <ip of elasticsearch node>
```

1. Clean up disk (e.g. `apt autoremove` on all nodes), then restart machines and/or the elasticsearch process

```sh
sudo apt autoremove
sudo reboot
```

As always make sure you [check the health of the process](#check-the-health-of-an-elasticsearch-node). before and after the reboot.

1. Get the elastichsearch cluster out of *read-only* mode, run:

```sh
curl -X PUT -H 'Content-Type: application/json' http://localhost:9200/_all/_settings -d '{"index.blocks.read_only_allow_delete": null}'
```

1. Trigger reindexing: From a kubernetes machine, in one terminal:

```sh
# The following depends on your namespace where you installed wire-server. By default the namespace is called 'wire'.
kubectl --namespace wire port-forward svc/brig 9999:8080
```

And in a second terminal trigger the reindex:

```sh
curl -v -X POST localhost:9999/i/index/reindex
```
