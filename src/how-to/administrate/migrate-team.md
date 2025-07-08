# Migrate to new team features

This document describes how to migrate to the new team features of the wire app if the release is older than [5.12.0](https://docs.wire.com/latest/changelog/changelog.html#2025-03-06-chart-release-5120) in the air-gapped environment.

We added a [migrate-features](https://github.com/wireapp/helm-charts/tree/main/charts/migrate-faciliate) helm chart to facilitate the migration process as described in the release changelog in the wire-server-deploy bundle.

## Run the migration job

The chart sets up the `migrate-feature` job when it got installed with in the `default` namespace:

  ```sh
  helm install default ./charts/migrate-features
  ```
 
 Before running the helm command, make sure the chart `migrate-features` is present in the chart directory, if not please download the chart or copy it from our latest artifacts.

 ## Configuration

 The values of the chart contains the necessary configurable values.

 ```yaml
 job:
   name: migrate-features
   restartPolicy: Never
   backoffLimit: 4
   cassandraHost: cassandra-external # Replace with your Cassandra service name `kubectl get svc -n default`
   cassandraPort: 9042
   galleyKeyspace: galley
 ```

Most of configurable values can remain as it is but make sure the `cassandraHost` value by running:

```sh
kubectl get svc -n default` # assuming the services are in the default namespace
```
And the service name for the cassandra and replace the value of `cassandraHost` if it differs.

The value of the `appVersion` in the `Chart.yaml` is the image tag. Needs to be updated if there is a different image tag than `5.12.0` to be pulled.

## Troubleshoot and monitoring

After the helm installation check if the job is running

```sh
kubectl get jobs -n default
```

There will be a `migrate-features` job with `COMPLETION` status `1/1` when the job is done, it takes some time. If not, take a look into the pod logs or k8s events.

To check the k8s events run:

```sh
kubectl describe job migrate-features -n default
```

To check the logs run:

```sh
kubectl logs job/migrate-features -n default
```