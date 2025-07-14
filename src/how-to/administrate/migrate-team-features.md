# Migrate to new team features

Release of [wire-server-5.12](https://docs.wire.com/latest/changelog/changelog.html#2025-03-06-chart-release-5120) introduces a new data storage format for team features. To migrate to the new format, we have added a [tool](https://github.com/wireapp/helm-charts/tree/main/charts/migrate-features) called `migrate-features` to our deployment bundle, which will have to be run, after upgrading to a `wire-server` release past 5.12. Migration has to be run only once.
If you do not perform this migration after deploying to a release past `5.12`, your team settings will be in an inconsistent state.

## Configuration

The values of the chart `migrate-features/values.yaml` already contains the necessary configuration options.

```yaml
job:
  name: migrate-features
  restartPolicy: Never
  backoffLimit: 4
  cassandraHost: cassandra-external # Replace with your Cassandra service name `kubectl get svc -n default`
  cassandraPort: 9042
  galleyKeyspace: galley
```

Most configuration values can remain as they are, but ensure the `cassandraHost` value is correct by running:

```sh
kubectl get svc -n default` # assuming the services are in the default namespace
```

If your cassandra installation differs from the standard `wire-server-deploy` setup, a hostname or an IP address of one of the cassandra nodes can be supplied here.

## Run the migration job

When this chart is installed, it sets up a `migrate-feature` job in the `default` namespace:

```sh
helm install default ./charts/migrate-features
```

Before running the helm command, make sure the `migrate-features` chart is available in the charts directory, if not please [download](https://github.com/wireapp/helm-charts/tree/main/charts/migrate-features) the chart or copy it from one of our latest artifact.

## Troubleshoot and monitoring

After the helm installation check if the job is running

```sh
kubectl get jobs -n default
```

When the job is complete, you will see a `migrate-features` job with a `COMPLETIONS` status of `1/1`. This may take some time. If the job does not complete, check the pod logs or Kubernetes events.

To check the pod events run:

```sh
kubectl describe job migrate-features -n default
```

To check the logs run:

```sh
kubectl logs job/migrate-features -n default
```

While the migration tool is running, team features are going to operate in read-only mode for the team that is currently being migrated. After migration, the new storage is going to be used. No other action should be required on the part of instance operators besides running the migration tool.
