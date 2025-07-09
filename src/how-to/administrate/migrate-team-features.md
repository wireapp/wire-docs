# Migrate to new team features

This document describes how to migrate your team settings if the release is older than [5.12.0](https://docs.wire.com/latest/changelog/changelog.html#2025-03-06-chart-release-5120) in the air-gapped environment. If you do not perform this migration after deploying a newer release, your team settings will be in an inconsistent state, until this is run.

We added a [migrate-features](https://github.com/wireapp/helm-charts/tree/main/charts/migrate-faciliate) helm chart to facilitate the migration process.

## Run the migration job

When this chart is installed, it sets up a `migrate-feature` job in the `default` namespace:

  ```sh
  helm install default ./charts/migrate-features
  ```
 
 Before running the helm command, make sure the `migrate-features` chart is available in the charts directory, if not please download the chart or copy it from our latest artifacts.

 ## Configuration

 The values of the chart already contains the necessary configuration options.

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
And the service name for the cassandra and replace the value of `cassandraHost` if it differs.

## Troubleshoot and monitoring

After the helm installation check if the job is running

```sh
kubectl get jobs -n default
```

When the job is complete, you will see a `migrate-features` job with a `COMPLETION` status of `1/1`. This may take some time. If the job does not complete, check the pod logs or Kubernetes events.

To check the k8s events run:

```sh
kubectl describe job migrate-features -n default
```

To check the logs run:

```sh
kubectl logs job/migrate-features -n default
```