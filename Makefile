ORIGINAL_DIR := $(shell pwd)

.PHONY: all
all: run

# Check if the required dependencies are installed
.PHONY: check-deps
check-deps:
	@command -v nix-shell >/dev/null 2>&1 || { echo "nix-shell required but not installed"; exit 1; }
	@command -v git >/dev/null 2>&1 || { echo "git required but not installed"; exit 1; }

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
	nix-shell ${ORIGINAL_DIR}/build/default.nix --run "tar --exclude=.git --exclude=.current_branch -czf ${ORIGINAL_DIR}/wire-docs.tar.gz ."
# renaming the tarball with the default version set from build_versions.sh in index.html by mike 
	@cd $$(cat .tmpdir) && version=$$(grep -oE 'url=[^"]+' index.html | head -1 | sed 's/url=//' | cut -d '/' -f 1 ); \
	  mv ${ORIGINAL_DIR}/wire-docs.tar.gz ${ORIGINAL_DIR}/wire-docs-$${version}.tar.gz; \
	  echo "Built ${ORIGINAL_DIR}/wire-docs-$${version}.tar.gz"

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
