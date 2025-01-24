ORIGINAL_DIR := $(shell pwd)
BUILD_DIR := build
NIX_SHELL := default.nix
TEMP_DIR := $(shell if [ -f .tmpdir ]; then cat .tmpdir; fi)

# creating temporary directory and copying the files
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
	cp -r --no-preserve=mode,ownership . $$TEMP_DIR || true

# Run the all versions of the documentation
.PHONY: run
run: prepare
	@TEMP_DIR=$$(cat .tmpdir) && cd $$TEMP_DIR && BUILD_DIR=$(BUILD_DIR) nix-shell $(BUILD_DIR)/$(NIX_SHELL) --run "bash ${BUILD_DIR}/build_versions.sh && pipenv run mike serve -a 0.0.0.0:8000"

# It will serve the current branch only
.PHONY: current
current: prepare
	@TEMP_DIR=$$(cat .tmpdir) && cd $$TEMP_DIR && BUILD_DIR=$(BUILD_DIR) nix-shell $(BUILD_DIR)/$(NIX_SHELL) --run "pipenv run mike deploy current && pipenv run mike set-default current && pipenv run mike serve -a 0.0.0.0:8000"

# Build the documentation tarball with all versions
.PHONY: build
build: prepare
	@TEMP_DIR=$$(cat .tmpdir) && cd $$TEMP_DIR && BUILD_DIR=$(BUILD_DIR) nix-shell $(BUILD_DIR)/$(NIX_SHELL) --run "bash ${BUILD_DIR}/build_versions.sh && tar -czf ${ORIGINAL_DIR}/wire-docs.tar.gz ."
	@echo "Built wire-docs.tar.gz"

# Build the docker image
.PHONY: docker
docker: 
	@docker build -t wire-docs . -f build/Dockerfile

# clean the temporary directories and tarball
.PHONY: clean
clean:
	@echo "Cleaning up tar and temporary directories..."
	@if [ -f .tmpdir ]; then \
		TEMP_DIR=$$(cat .tmpdir); \
		rm -rf $$TEMP_DIR; \
		rm -f .tmpdir; \
	fi
	@rm -f wire-docs.tar.gz || true
