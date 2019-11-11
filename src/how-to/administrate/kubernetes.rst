

WIP


.. code::

    kubectl get pods | grep ingress

Set

.. code::

    POD=<name of a pod>
    kubectl describe pod $POD | grep "^Node:"

To see on which machine a specific pod is running.
