General - Linux
--------------------------

.. include:: includes/intro.rst

How can I see if NTP is correctly set up?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This is an important part of your setup, particularly for your Cassandra nodes. You should use `ntpd` and our ansible scripts to ensure it is installed correctly, but here's some helpful info:

The following shows how to check for existing servers connected to (assumes `ntpq` is installed)

.. code:: sh

  ntpq -pn

which should yield something like this:

.. code:: sh

        remote           refid      st t when poll reach   delay   offset  jitter
   ==============================================================================
    time.example.    .POOL.          16 p    -   64    0    0.000    0.000   0.000
   +<IP_ADDR_1>      <IP_ADDR_N>      2 u  498  512  377    0.759    0.039   0.081
   *<IP_ADDR_2>      <IP_ADDR_N>      2 u  412  512  377    1.251   -0.670   0.063

if your output shows _ONLY_ the entry with a `.POOL.` as `refid` and a lot of 0s, something is probably wrong, i.e.:

.. code:: sh

        remote           refid      st t when poll reach   delay   offset  jitter
   ==============================================================================
    time.example.    .POOL.          16 p    -   64    0    0.000    0.000   0.000

What should you do if this is the case? Ensure that `ntp` is installed and that the servers in the pool (typically at `/etc/ntp.conf`) are reachable.

Which ports and network interface is my process running on?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The following shows open TCP ports, and the related processes.

.. code:: sh

   sudo netstat -antlp | grep LISTEN

which may yield output like this:

.. code:: sh

   tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      1536/sshd

How can I see if my TLS certificates are configured the way I expect?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You can use openssl to check, with e.g.

.. code:: sh

   DOMAIN=example.com
   PORT=443
   echo Q | openssl s_client -showcerts -connect $DOMAIN:$PORT

or

.. code:: sh

   DOMAIN=example.com
   PORT=443
   echo Q | openssl s_client -showcerts -connect $DOMAIN:$PORT 2>/dev/null | openssl x509 -inform pem -noout -text

To see only the validity (expiration):

.. code:: sh

   DOMAIN=example.com
   PORT=443
   echo Q | openssl s_client -showcerts -connect $DOMAIN:$PORT 2>/dev/null | openssl x509 -inform pem -noout -text | grep Validity -A 2
