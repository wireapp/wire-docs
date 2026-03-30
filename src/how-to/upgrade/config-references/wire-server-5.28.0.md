# Wire-Server 5.28.0 release

The following reference was written based on the following [`build.json` charts](https://raw.githubusercontent.com/wireapp/wire-builds/93632dd82237c122c93e0e37e02e5f2a1ba84746/build.json).

For additional details, you can also read our [release changelog](https://github.com/wireapp/wire-server/releases/tag/v2026-03-03).

## Known bugs

No known bugs

## Mandatory (breaking) changes

The following Helm charts were changed:

- `demo-smtp`
- `fake-aws-ses`
- `fake-aws-sns`
- `legalhold`

Image field overrides are now controlled with split values, `repository` + `tag`, unlike a full `image` string like previously, if you were using overrides in these charts, change to this format:

```
affected-chart:
  image:
    repository: quay.io/wire/...
    tag: some-tag
```

## Optional changes

No optional changes