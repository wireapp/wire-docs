## Generating a Release and Artifact:

### Release Creation Process
  - We follow GitHub's standard process for creating a `release`, as described in [GitHub's documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository#creating-a-release). We use the UI to create a release with the `Create new tag` option, which synchronizes the release creation with tag creation.

  **NOTE:** Each release should initially be marked as `Set as a pre-release` to allow for verification of the release notes and artifacts. If the release workflow fails, you can fix the issues and create a new release before publishing the final release.

### Release Notes
For release notes, you can either:
- Manually specify changes based on commits
- Use the `Generate release notes` feature to automatically compile commit history from the main branch

### Branch and Pull Request Workflow
- All releases should be based on the *main* branch. For each release, changes to the main branch are aggregated through *pull requests*.

- Each pull request triggers a [build workflow](.github/workflows/build.yaml) that:
  - Verifies documentation structure
  - Builds the current branch (as `latest`) to identify navigation or Markdown issues

### Deployment Process
Each push to the main branch triggers a [deploy workflow](.github/workflows/deploy.yaml) that:
- Builds the `latest` documentation
- Pushes the `latest` build to the S3 bucket for live serving

### Submodule Management
Some pages are fetched from the [wire-server](https://github.com/wireapp/wire-server/tree/develop) repository via submodules. We expect to submit pull requests for updating submodule pointers. In the future, we plan to automate this process to keep the wire-docs repository synchronized with the latest commits.

**Note:** For each commit to `/docs` in the wire-server repository, a [build workflow](https://github.com/wireapp/wire-server/blob/develop/.github/workflows/build.yaml) verifies the document structure.
  
### Release Workflow
Creating a release triggers a [release workflow](https://github.com/wireapp/wire-docs/blob/main/.github/workflows/release.yaml) that:
1. Builds documentation for the current tag
2. Creates a tar file containing all documentation web pages
3. Pushes the tag (`ref_name`) to the S3 bucket for live serving

The tar file created during the release can be used to serve documentation via standard web servers such as Apache, Nginx, or Python's `http.server`.
