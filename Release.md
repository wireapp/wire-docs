## Generating a Release and Artifact:

  - We follow GitHub's standard process for creating a `release`, as described in [GitHub's documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository#creating-a-release). We use the UI to create a release with the `Create new tag` option, which synchronizes the release creation with tag creation.

  **NOTE:** Each release should initially be marked as `Set as a pre-release` to allow for verification of the release notes and artifacts. If the release workflow fails, you can fix the issues and create a new release before publishing the final release.

  - In the release notes, you can either specify the changes based on commits or use the `Generate release notes` feature to automatically compile a history of commits on the main branch.

  - All releases should be based on the *main* branch. For each release, changes to the main branch are aggregated through *pull requests*.

  - Each pull request triggers a [build workflow](https://github.com/wireapp/wire-docs/blob/main/.github/workflows/build.yaml) to verify the structure of the documentation. This build process runs for all existing tags to ensure that building the current release does not break the processing of previous versions. It also builds the current branch to identify any navigation or markdown issues.

  - As some of the pages are being fetched from [wire-server](https://github.com/wireapp/wire-server/tree/develop) repo via a submodule. We expect to have a PR for updating the submodule pointer. In future, we will automate this process of updating the submodule to latest commits in wire-docs repo. Note: for each commit in wire-server repo for /docs, we have a github workflow (build) to verfiy the structure of documents.

  - Some pages are fetched from the [wire-server repository](https://github.com/wireapp/wire-server/tree/develop) via a submodule. We expect to open a pull request to update the submodule pointer when necessary. In the future, we plan to automate the process of updating the submodule to the latest commits from the wire-server repository.
  
  **Note:** For each commit in the wire-server repository that affects the /docs directory, a GitHub workflow (build) is triggered to verify the documentation structure.

  - Creating a release triggers a [release](https://github.com/wireapp/wire-docs/blob/main/.github/workflows/release.yaml) which builds all the previous tags and builts the document from current tag, at the end it creates tar file with all the documentation webpages. This tar can be used to serve the documentation via S3 web hosting or normal web server like apache, ngnix or python http.server.

  - Creating a release triggers a [release workflow](https://github.com/wireapp/wire-docs/blob/main/.github/workflows/release.yaml) that builds all previous tags and the documentation from the current tag. At the end of this process, a tar file containing all the documentation webpages is created. This tar file can be used to serve the documentation via S3 web hosting or with a standard web server such as Apache, Nginx, or Python's http.server.
