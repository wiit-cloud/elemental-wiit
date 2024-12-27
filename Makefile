DOCKER?=docker

# Inputs
UBUNTU_REPO?=ubuntu
UBUNTU_VERSION?=noble-20241118.1
ELEMENTAL_TOOLKIT_REPO?=ghcr.io/rancher/elemental-toolkit/elemental-cli
ELEMENTAL_TOOLKIT_VERSION?=v2.2.1

# Outputs
ELEMENTAL_BUILD?=dev
ELEMENTAL_REPO?=ghcr.io/max06/elemental-ubuntu
ELEMENTAL_TAG?=$(UBUNTU_VERSION)-$(ELEMENTAL_TOOLKIT_VERSION)-$(ELEMENTAL_BUILD)

.PHONY: build-base-os
build-base-os:
	$(DOCKER) build \
			--build-arg ELEMENTAL_TOOLKIT=$(ELEMENTAL_TOOLKIT_REPO):$(ELEMENTAL_TOOLKIT_VERSION) \
			--build-arg UBUNTU_REPO=$(UBUNTU_REPO) \
			--build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) \
			-t $(ELEMENTAL_REPO)/base-os:$(ELEMENTAL_TAG) \
			$(if [ -n "$(GITHUB_RUN_NUMBER)" ]; then echo "--push"; fi) \
			-f Dockerfile.base.os .

.PHONY: build-bare-metal-os
build-bare-metal-os:
	$(DOCKER) build \
			--build-arg ELEMENTAL_BASE=$(ELEMENTAL_REPO)/base-os:$(ELEMENTAL_TAG) \
			-t $(ELEMENTAL_REPO)/bare-metal-os:$(ELEMENTAL_TAG) \
			$(if [ -n "$(GITHUB_RUN_NUMBER)" ]; then echo "--push"; fi) \
			-f Dockerfile.bare-metal.os .

.PHONY: build-bare-metal-iso
build-bare-metal-iso:
	$(DOCKER) build \
			--build-arg ELEMENTAL_BASE=$(ELEMENTAL_REPO)/bare-metal-os:$(ELEMENTAL_TAG) \
			-t $(ELEMENTAL_REPO)/bare-metal-iso:$(ELEMENTAL_TAG) \
			$(if [ -n "$(GITHUB_RUN_NUMBER)" ]; then echo "--push"; fi) \
			-f Dockerfile.bare-metal.iso .
