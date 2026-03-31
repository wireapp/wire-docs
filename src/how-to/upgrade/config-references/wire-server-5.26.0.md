# Wire-Server 5.26.0 release

The following reference was written based on the following [`build.json` charts](https://raw.githubusercontent.com/wireapp/wire-builds/7023ffdd52f9de2a1eb5ce2e01cefaf16253274b/build.json).

For additional details, you can also read our [release changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-01-26).

## Known bugs

Previous release introduced a bug into `background-worker` default settings for `postgresMigration` and have now been correctly set to Cassandra. If you are relying on default values from our charts, but have migrated your conversations to PostgreSQL, update your config accordingly to keep using PostgreSQL. Specifically, this value:

```
background-worker:
  config:
    postgresMigration:
      conversation: postgresql | cassandra # default is cassandra, and should be if not migrated to postgresql
```

## Mandatory (breaking) changes

No mandatory changes.

## Optional changes

Conversation codes can now be migrated to PostgreSQL. For details, read our [changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-01-26).
