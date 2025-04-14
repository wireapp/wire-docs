# Wire-documents-structure

Wire documentation is hosted on <https://docs.wire.com>. This project is made using Mkdocs.

## Structure of the repository
- src 
    - It contains the files and directories for actual source of the documentation. The `src` directory has been processed based on [docs](https://github.com/wireapp/wire-server/tree/develop/docs). The earlier version was based on Sphinx, so it was converted to markdown and then ported for Mkdocs. Find the process for doing in `build/old-docs.md`.

- Pages from external repositories (via Git submodules):

    - We intend to import some documentation pages from the backend repository [wire-server](https://github.com/wireapp/wire-server/tree/develop) into our project. Currently, many files reference wire-server; you can identify these files using the following command
    ```
    find . -type l -printf '%p -> %l\n' | grep './src'
    ```
    - To fetch the latest updates from wire-server, run the following command. Note: Execute this command only when the remote repository has been updated with new changes.

    ```
    git submodule update --remote --checkout --depth 1 -- wire-server
    ```

    - To checkout to a specific commit:
        ```
        cd wire-server && git fetch --depth=1 origin <commit-id> && git checkout <commit-id>
        ```
    
    - To verify the submodule status:
        ```
        git submodule status
        ```

    - To optionally update the src/changelog/README.md based on the new changelog.md, run the following command:
    ``` 
    rm src/changelog/README.md && \
    grep '^# ' src/changelog/changelog.md | \
    sed 's/^# //' | while IFS= read -r heading; \
    do anchor=$(echo "$heading" | sed -E 's/^\[?([0-9-]+)\]? *(\(([^)]+)\)|# *([0-9]+))$/\1-\3\4/' | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g;s/\.//g'); echo "* [$heading](changelog.md#$anchor)"; done > src/changelog/README.md
    ```

- build 
    - It contains scripts used by Makefile to support different usecases for builds. It is designed to run one build process at a time. All the local targets use a temporary directory stored in `.tmpdir` file for building/serving the changes. This is due to git-operations by tools like `mike` for mkdocs.
    ### Prerequisites
    
    - make
    - nix-shell
    - git
    - rsync
    - Docker (optional) - if building  a docker image, useful when testing without installing nix-shell

        ### Makefile Targets

        - `make current`
            - This target runs the documentation site locally using Mike (Mkdocs) as we do in `make run` but only for the `current` branch. The current changes will be visible under branch name as version name. It will be hosted on `0.0.0.0:8000`. It can also show other versions if they have been pre-built on your local host.

        - `make run`
            - This target serves the documentation site locally by first building all the existing tags and building current branch. It later hosts the webserver using python http module. It allows you to preview the documentation as it will appear when hosted `for all the tags and current branch`. It will be hosted on `0.0.0.0:8000`. Use it only if you want to build all existing tags by yourself.

        - `make archive`
            - This target archive the processed web pages for documentation for all the tags and current branch from the github branch gh-pages. The output is generated in the main directory as `wire-docs.tar.gz`.

        - `make build`
            - This target is being used by run and archive targets for building all the tags and current branch. It serves the layer to economise the re-building each time for archive and run targets. Note: if there are uncomitted changes in the `current` branchm then it is going to re-build the current branch everytime.

        - `main docker`
            - This target builds a Docker image for the documentation. It uses the Dockerfile present in the repository to create an image. It will be using `mike` module from python to host the documents, this is experimental to use `mike` for the container and not python `http` module. It processes the tags present in the `online` [repo](https://github.com/wireapp/wire-docs.git). To test current changes, rely on `make run` or `make current`. To run and test the docker image locally, we recommend the following command:
                ```bash
                docker run -d -p 8000:8000 --restart=always --health-cmd="curl --fail http://localhost:8000 || exit 1" --health-interval=30s --health-retries=3 --health-timeout=5s wire-docs
                ```
        - `make clean`
            - This target cleans up the generated tar files and tmp directories from the build process.

        - `make SHELL="/bin/bash -x" target`
            - To increase verbosity for make commands.

## Versioning criteria:
  - The version number will follow a three-part format: **A.B.C**

    - **A (Major Version)**: This indicates the minimum API contract version supported by the release. When this number increases, it signals the deprecation of an older API contract version. For example, V5.0.0 means the release supports API V5 and newer. Major versions can include breaking changes, such as database migrations or changes to the backend service structure.

    - **B (Feature Iteration)**: This number reflects feature updates that don’t affect API contract compatibility or introduce breaking changes. For example, V5.1.0 means the release supports API V5 and newer, and includes new features or improvements without altering the compatibility matrix.

    - **C (Fix Iteration)**: This is incremented for bug fixes or security updates that don’t introduce new features or modify compatibility. There are no breaking changes in a fix iteration.

    - The *first release*, `v0.0.0`, indicates that the documentation supports all API versions.

## Relationship Between Versions and Tags:
  - We plan to offer multiple versions of our documentation, with each version corresponding to a specific release in the wire-docs repository.

  - Each version release includes all built documents from previous releases. Releases are based on Git tags, which mark a specific point in your repository's history.

  - Once a new version or tag is released, it becomes immutable; future updates will require creating new versions, and no further edits will be permitted on that tag.
