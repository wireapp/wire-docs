This repo has been migrated into https://github.com/wireapp/wire-server at commit https://github.com/wireapp/wire-docs/commit/a360443306e80e2b9a865b9994e300efb6f15e0a

To migrate a PR:

1. rebase the PR branch on commit https://github.com/wireapp/wire-docs/commit/a360443306e80e2b9a865b9994e300efb6f15e0a
2. copy the contents of `wire-docs` to `/docs` of `wire-server`:
```
cp -r * ../wire-server/docs
```
3. Review updated files.
