# Wire-documents-structure

Source files for wire-server documentation hosted on <https://docs.wire.com>

## Reading the documentation

Visit <https://docs.wire.com/>

## Structure of the repository
- src 
    - It contains the files and directories for actual source of the documentation. The `src` directory has been processed based on [docs](https://github.com/wireapp/wire-server/tree/develop/docs). The earlier version was based on Sphinx, so it was converted to markdown and then ported for GitBook. Find the process for doing so below: 

    ```bash
    echo 'FROM python:3.12-slim

    RUN apt-get update && apt-get install -y \
        build-essential \
        git

    RUN pip install setuptools sphinx sphinx-markdown-builder sphinxcontrib.kroki sphinxcontrib.plantuml rst2pdf myst_parser sphinx_multiversion sphinx_reredirects sphinx_copybutton

    RUN git clone https://github.com/wireapp/wire-server.git

    CMD ["bash"]' > Dockerfile

    docker build -t python-sphinx .
    mkdir output-markdown || true
    docker run --rm -v $(pwd)/output-markdown:/out -v $(pwd):/app python-sphinx \
        sphinx-build -b markdown /wire-server/docs/src/ /out/
    ``` 
    The `src` directory is made up of `/output-markdown` with each `index.md` converted into `README.md` and an extra `SUMMARY.md`.
    ```bash
    cd output-markdown
    find . -type f -name 'index.md' -execdir mv {} README.md \;
    find . -type f -name '*.md' | sort | awk -F '/' '{print "- ["$NF"]("$0")"}' > ./SUMMARY.md
    ```

## Self hosting using mkdocs

```bash
# Create Dockerfile
cat <<EOF > Dockerfile

FROM python:3.12-slim
RUN apt-get update && apt-get install -y \\
    build-essential \\
    git

RUN pip install mkdocs mkdocs-material mike mkdocs-exclude mkdocs-minify-plugin mkdocs-redirects mkdocs-macros-plugin pymdown-extensions

RUN git clone https://github.com/wireapp/wire-docs.git

WORKDIR /wire-docs
CMD ["mkdocs", "serve"]
EOF

# Build Docker Image
docker build --no-cache -t python_mkdocs .

# Run Docker Container and Start MkDocs Server
docker run -d --net host python_mkdocs
```  

### Check in local browser
```bash
# open in your browser
elinks 127.0.0.1:8000
firefox 127.0.0.1:8000
```

## hosting multiple versions 

```bash
# create deploy_multiple_versions.sh

cat << EOF > deploy_multiple_versions.sh
#!/bin/bash

# Exit on any error
set -e

cd wire-docs/

# using dummy values for user.name and user.email as they are not required
git config --global user.name "Your Name"
git config --global user.email "youremail@example.com"

# Fetch all tags
git fetch --tags

# Get all tags
TAGS=\$(git tag | head -n 1)

# Calculate the latest and default tags
DEFAULT_TAG=\$(echo "\$TAGS" | sort -V | head -n 1)

for TAG in \$TAGS; do
    echo "Deploying tag: \$TAG"
    
    # Checkout the tag
    git checkout \$TAG

    if [ "\$TAG" == "\$DEFAULT_TAG" ]; then
        mike deploy --update-aliases \$TAG stable || true
    else
        mike deploy \$TAG || true
    fi
done

mike list --json > src/versions.json
mike set-default \$DEFAULT_TAG
EOF

chmod +x deploy_multiple_versions.sh

cat <<EOF > Dockerfile

FROM python:3.12-slim
RUN apt-get update && apt-get install -y \\
    build-essential \\
    git

RUN pip install mkdocs mkdocs-material mike mkdocs-exclude mkdocs-minify-plugin mkdocs-redirects mkdocs-macros-plugin pymdown-extensions

RUN git clone https://github.com/wireapp/wire-docs.git

# Copy deployment script
COPY deploy_multiple_versions.sh /deploy_multiple_versions.sh

# Make script executable
RUN chmod +x /deploy_multiple_versions.sh

# Execute the deployment script
RUN /deploy_multiple_versions.sh || { echo 'Script failed!' ; exit 1; }

WORKDIR /wire-docs
CMD ["mike", "serve"]
EOF

# Build Docker Image
docker build --no-cache -t docs_multi_version .

# Run Docker Container and Start MkDocs Server
docker run -d --net host docs_multi_version mike serve -a 0.0.0.0:8000
```
