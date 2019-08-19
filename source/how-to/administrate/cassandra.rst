Cassandra
--------------------------

.. include:: includes/intro.rst

This section only covers the bare minimum, for more information, see the `cassandra
documentation <https://cassandra.apache.org/doc/latest/>`__

How to see cluster health
~~~~~~~~~~~~~~~~~~~~~~~~~~

You want to see `UN` (`Up` & `Normal`) everywhere::

   nodetool status

How to inspect tables and data manually
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

::

   cqlsh
   # from the cqlsh shell
   describe keyspaces
   use <keyspace>;
   describe tables;
   select * from <tablename> WHERE <primarykey>=<some-value> LIMIT 10;

How to rolling-restart a cassandra cluster
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On each server one by one:

1. check your cluster is healthy: ``nodetool status``
2. ``nodetool drain`` (to stop accepting writes and flush data to disk)
3. ``systemctl stop cassandra`` (to stop the process)
4. do any operation you need, if any
5. ``systemctl start cassandra``
6. Wait for your cluster to be healthy again.
7. Do the same on the next server.


