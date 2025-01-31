TEMP_DIR := $(shell if [ -f .tmpdir ]; then cat .tmpdir; fi)
ORIGINAL_DIR := $(shell pwd)

# creating temporary directory and copying the files - also ensuring that the current branch is checked out
.PHONY: prepare
prepare:
	@if [ -f .tmpdir ]; then \
		if [ ! -d "$$(cat .tmpdir)" ]; then \
			TEMP_DIR=$$(mktemp -d); \
			echo $$TEMP_DIR > .tmpdir; \
		else \
			TEMP_DIR=$$(cat .tmpdir); \
		fi; \
	else \
		TEMP_DIR=$$(mktemp -d); \
		echo $$TEMP_DIR > .tmpdir; \
	fi; \
	echo "Using temporary directory: $$TEMP_DIR"; \
	if [ -f $$TEMP_DIR/.current_branch ]; then \
		git checkout $$(cat .$$TEMP_DIR/current_branch); \
	else \
		echo "no .current_branch file found"; \
	fi; \
	cp -r --no-preserve=mode,ownership . $$TEMP_DIR || true
	
# Run the all versions of the documentation
.PHONY: build
build: prepare
	@TEMP_DIR=$$(cat .tmpdir) && cd $$TEMP_DIR && nix-shell build/default.nix --run "bash build/build_versions.sh"

.PHONY: run
run: build
	@TEMP_DIR=$$(cat .tmpdir) && cd $$TEMP_DIR && nix-shell build/default.nix --run "pipenv run python -m http.server 0.0.0.0:8000"

# It will serve the current branch only
.PHONY: current
current: prepare
	@TEMP_DIR=$$(cat .tmpdir) && cd $$TEMP_DIR && BRANCH=$$(cat .$$TEMP_DIR/current_branch) && nix-shell build/default.nix --run "pipenv run mike deploy $$BRANCH && pipenv run mike set-default $$BRANCH && pipenv run mike serve -a 0.0.0.0:8000"

# Build the documentation tarball with all versions
.PHONY: archieve
archieve: build
	@TEMP_DIR=$$(cat .tmpdir) && cd $$TEMP_DIR && nix-shell build/default.nix --run "tar -czf ${ORIGINAL_DIR}/wire-docs.tar.gz $$(cat .tmpdir)"
	@echo "Built ${ORIGINAL_DIR}/wire-docs.tar.gz"

# Build the docker image
.PHONY: docker
docker: 
	@docker build --no-cache -t wire-docs . -f build/Dockerfile

# clean the temporary directories and tarball
.PHONY: clean
clean:
	@echo "Cleaning up tar and temporary directories $$(cat .tmpdir)"
	@if [ -f .tmpdir ]; then \
		TEMP_DIR=$$(cat .tmpdir); \
		rm -rf $$TEMP_DIR; \
		rm -f .tmpdir; \
	fi
	@rm -f wire-docs.tar.gz || true
