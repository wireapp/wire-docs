SHELL = bash

.DEFAULT_GOAL := docs

MKFILE_DIR = $(abspath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

DOCKER_USER   ?= quay.io/wire
DOCKER_IMAGE  = alpine-sphinx
DOCKER_TAG    ?= latest

# You can set these variables from the command line, and also
# from the environment for the first two.
SPHINXOPTS    ?= -q
SPHINXBUILD   ?= sphinx-build
SOURCEDIR     = $(MKFILE_DIR)/src
BUILDDIR      = $(MKFILE_DIR)/build

VENV_DIR = $(MKFILE_DIR)/.venv
VENV_BIN = $(VENV_DIR)/bin


.PHONY: docs
docs:
	docker run --rm -v $(MKFILE_DIR):/mnt $(DOCKER_USER)/$(DOCKER_IMAGE):$(DOCKER_TAG) make html

# Only build part of the documentation
# See 'exclude_patterns' in source/conf.py
docs-administrate:
	docker run --rm -e SPHINXOPTS='-t administrate' -v $(MKFILE_DIR):/mnt $(DOCKER_USER)/$(DOCKER_IMAGE):$(DOCKER_TAG) make html
	cd build && zip -r administration-wire-$$(date +"%Y-%m-%d").zip html

.PHONY: exec
exec:
	docker run -it -v $(MKFILE_DIR):/mnt $(DOCKER_USER)/$(DOCKER_IMAGE):$(DOCKER_TAG)

.PHONY: docker
docker:
	docker build -t $(DOCKER_USER)/$(DOCKER_IMAGE):$(DOCKER_TAG) $(MKFILE_DIR)

.PHONY: push
push:
	aws s3 sync $(BUILDDIR)/html s3://origin-docs.wire.com/

.PHONY: dev-install
dev-install:
	python3 -m venv --copies --clear $(VENV_DIR)
	$(VENV_BIN)/pip3 install sphinx sphinx-autobuild recommonmark

.PHONY: dev-run
dev-run: export PATH := $(VENV_BIN):$(PATH)
dev-run:
	rm -rf "$(BUILDDIR)"
	sphinx-autobuild \
		--port 3000 \
		--host 127.0.0.1 \
		-b html \
		$(SPHINXOPTS) \
		"$(SOURCEDIR)" "$(BUILDDIR)"

.PHONY: help
help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option. This "converts" unknown targets into sub-commands of
# the $(SPHINXBUILD) CLI. $(O) is meant as a shortcut for $(SPHINXOPTS).
.PHONY: Makefile
%: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
