Elasticsearch
------------------------------

.. include:: includes/intro.rst

For more information, see the `elasticsearch
documentation <https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html>`__

See cluster health and cluster nodes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

::

   curl 'http://localhost:9200/_cluster/health?pretty'
   curl 'http://localhost:9200/_cat/nodes?v&h=id,ip,name'

How to rolling-restart an elasticsearch cluster
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On each server one by one:

1. check your cluster is healthy (see above)
2. stop accepting writes::

    ES_IP=<the-ip-of-the-elasticsearch-node-to-stop>
    curl -sSf -XPUT http://localhost:9200/_cluster/settings -d "{ \"transient\" : {\"cluster.routing.allocation.exclude._ip\": \"$ES_IP\" }}"

3. ``systemctl stop elasticsearch`` (to stop the process)
4. do any operation you need, if any
5. ``systemctl start elasticsearch``
6. Wait for your cluster to be healthy again.
7. Do the same on the next server.
