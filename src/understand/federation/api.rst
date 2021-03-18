API
====

TODO.

..
   TODO: currently implemented endpoints: one endpoint for handle search, document it manually alongside the protobuf
   TODO: warning about reflecting current implementation only


You can download the latest :download:`router.proto <https://raw.githubusercontent.com/wireapp/wire-server/develop/libs/wire-api-federation/proto/router.proto>`.

..
   note: the following depends on the assumption that wire-docs is a sibling folder to wire-server. Perhaps we can instead have CI download that file when building docs into the static folder, for instance.
   literalinclude should have the advantage to also work for pdf output (unlike links)

.. literalinclude:: ../../../../wire-server/libs/wire-api-federation/proto/router.proto
   :linenos:
   :language: protobuf
