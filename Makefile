ORIGINAL_DIR := $(shell pwd)

.PHONY: all
all: run

# Check if the required dependencies are installed
.PHONY: check-deps
check-deps:
	@command -v nix-shell >/dev/null 2>&1 || { echo "nix-shell required but not installed"; exit 1; }
	@command -v git >/dev/null 2>&1 || { echo "git required but not installed"; exit 1; }
	@make --version | grep -iq "^GNU Make 4" || { echo "GNU Make 4.x required"; exit 1; }
	@command -v rsync >/dev/null 2>&1 || { echo "nix-shell required but not installed"; exit 1; }

# creating temporary directory and copying the files - also ensuring that the current branch is checked out
.PHONY: prepare
prepare: check-deps
	@bash build/prepare.sh

# Run the all versions of the documentation
.PHONY: build
build: prepare
	@cd $$(cat .tmpdir) && nix-shell build/default.nix --run "bash build/build_versions.sh"

.PHONY: run
run: build
	@cd $$(cat .tmpdir) && git checkout gh-pages && \
	nix-shell ${ORIGINAL_DIR}/build/default.nix --run "python -m http.server 8000"

# It will serve the current branch only
.PHONY: current
current: prepare
	@BRANCH=$$(git branch --show-current) && cd $$(cat .tmpdir) && \
	nix-shell build/default.nix --run "pipenv run mike deploy $$BRANCH && \
	pipenv run mike set-default $$BRANCH && pipenv run mike serve -a 0.0.0.0:8000"

# Build the documentation tarball with all versions
.PHONY: archive
archive: build
	@cd $$(cat .tmpdir) && git checkout gh-pages && \
	grep -oE 'url=[^"]+' index.html | head -1 | sed 's/url=//' | cut -d '/' -f 1 > version
	@cd $$(cat .tmpdir) && { \
	    find . -type d -regextype posix-extended -regex '.*\/v[0-9]+\.[0-9]+(\.[0-9]+)?$$'; \
	    echo ".nojekyll"; \
	    echo "site"; \
	    echo "versions.json"; \
	    echo "index.html"; \
	    cat version; \
	} | sed 's|^\./||' | sort -u > archived_files
	@cd $$(cat .tmpdir) && \
	  nix-shell ${ORIGINAL_DIR}/build/default.nix --run "tar -czf ${ORIGINAL_DIR}/wire-docs.tar.gz -T archived_files"
	@cd $$(cat .tmpdir) && \
	  version=$$(cat version) && \
	  mv ${ORIGINAL_DIR}/wire-docs.tar.gz ${ORIGINAL_DIR}/wire-docs-$${version}.tar.gz
	@cd $$(cat .tmpdir) && \
	  version=$$(cat version) && \
	  echo "Built ${ORIGINAL_DIR}/wire-docs-$${version}.tar.gz"
	@cd $$(cat .tmpdir) && \
	  rm -f archived_files version

# Build the docker image
.PHONY: docker
docker: 
	@docker build --no-cache -t wire-docs . -f build/Dockerfile

# clean the temporary directories and tarball
.PHONY: clean
clean:
	@echo "Cleaning up tar and temporary directories $$(cat .tmpdir)"
	@if [ -f .tmpdir ]; then \
		rm -rf $$(cat .tmpdir); \
		rm -f .tmpdir; \
	fi
	@echo "Cleaning up tarballs: wire-docs*.tar.gz"
	@rm -f wire-docs*.tar.gz || true
