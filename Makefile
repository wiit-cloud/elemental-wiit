DOCKER?=docker

# Inputs
SOURCE_VERSION?=2.2.2-3.12
RANCHER_SYSTEM_AGENT_VERSION?=v0.3.12

REGISTER_TAG=v1.7.2
REGISTER_COMMIT=5f0246b
REGISTER_COMMITDATE=2025-03-14

TOOLKIT_TAG=main
TOOLKIT_COMMIT=33f51de


# Outputs
ELEMENTAL_BUILD?=dev
ELEMENTAL_REPO?=ghcr.io/wiit-cloud/elemental-wiit
ELEMENTAL_TAG?=$(SOURCE_VERSION)-$(ELEMENTAL_BUILD)

.PHONY: build-base-os
build-base-os:
	$(DOCKER) build \
			--no-cache \
			--build-arg SOURCE_VERSION=$(SOURCE_VERSION) \
			--build-arg REGISTER_TAG=$(REGISTER_TAG) \
			--build-arg REGISTER_COMMIT=$(REGISTER_COMMIT) \
			--build-arg REGISTER_COMMITDATE=$(REGISTER_COMMITDATE) \
			--build-arg TOOLKIT_TAG=$(TOOLKIT_TAG) \
			--build-arg TOOLKIT_COMMIT=$(TOOLKIT_COMMIT) \
			--build-arg ELEMENTAL_REPO=$(ELEMENTAL_REPO) \
			--build-arg ELEMENTAL_TAG=$(ELEMENTAL_TAG) \
			--build-arg IMAGE_REPO=$(ELEMENTAL_REPO)/base-os \
			--build-arg IMAGE_TAG=$(ELEMENTAL_TAG) \
			--build-arg RANCHER_SYSTEM_AGENT_VERSION=$(RANCHER_SYSTEM_AGENT_VERSION) \
			-t $(ELEMENTAL_REPO)/base-os:$(ELEMENTAL_TAG) \
			$(if $(GITHUB_RUN_NUMBER),--push) \
			-f Dockerfile.base.os .

.PHONY: build-bare-metal-os
build-bare-metal-os:
	$(DOCKER) build \
			--build-arg ELEMENTAL_BASE=$(ELEMENTAL_REPO)/base-os:$(ELEMENTAL_TAG) \
			-t $(ELEMENTAL_REPO)/bare-metal-os:$(ELEMENTAL_TAG) \
			$(if $(GITHUB_RUN_NUMBER),--push) \
			-f Dockerfile.bare-metal.os .

.PHONY: build-bare-metal-iso
build-bare-metal-iso:
	$(DOCKER) build \
			--build-arg ELEMENTAL_BASE=$(ELEMENTAL_REPO)/bare-metal-os:$(ELEMENTAL_TAG) \
			-t $(ELEMENTAL_REPO)/bare-metal-iso:$(ELEMENTAL_TAG) \
			$(if $(GITHUB_RUN_NUMBER),--push) \
			-f Dockerfile.bare-metal.iso .
