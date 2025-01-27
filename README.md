# Wire-documents-structure

Wire documentation is hosted on <https://docs.wire.com>. This project is made using Mkdocs.

## Structure of the repository
- src 
    - It contains the files and directories for actual source of the documentation. The `src` directory has been processed based on [docs](https://github.com/wireapp/wire-server/tree/develop/docs). The earlier version was based on Sphinx, so it was converted to markdown and then ported for GitBook. Find the process for doing in `build/old-docs.md`.  

- build 
    - It contains scripts used by Makefile to support different types of builds.
    ### Prerequisites
    
    - Make
    - Nix
    - Docker (optional)


        ### Makefile Targets

        - `make run`
            - This target serves the documentation site locally using Mike (Mkdocs). It allows you to preview the documentation as it will appear when hosted `for all the tags`. It will be hosted on `0.0.0.0:8000`

        - `make build`
            - This target builds the processed gh-pages branch and site directory for the documentation. The output is generated in the main directory as `wire-docs.tar.gz`.

        - `make run`
            - This target runs the documentation site locally using Mike (Mkdocs) as we do in `make run` but only for the `current` branch. The current changes will be visible under version `current`. It will be hosted on `0.0.0.0:8000`

        - `main docker`
            - This target builds a Docker image for the documentation site. It uses the Dockerfile present in the repository to create an image. It processes the tags present in the `online` [repo](https://github.com/wireapp/wire-docs.git). To run and test the image locally, we recommend the following command:
                ```bash
                docker run -d p 8000:8000 --health-cmd="curl --fail http://localhost:8000 || exit 1" --health-interval=30s --health-retries=3 --health-timeout=5s wire-docs
                ```
        - `make clean`
            - This target cleans up the generated tarball files and directories from the build process.