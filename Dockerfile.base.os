ARG ELEMENTAL_TOOLKIT
ARG SOURCE_REPO
ARG SOURCE_VERSION

FROM ${ELEMENTAL_TOOLKIT} AS toolkit

FROM ${SOURCE_REPO}:${SOURCE_VERSION} AS os

ENV VERSION=${SOURCE_VERSION}
ARG ELEMENTAL_REPO
ARG ELEMENTAL_TAG

# Custom commands
RUN zypper install -y \
    nmap \
    tcpdump \
    wget \
    podman \
    openvswitch

# Add a bunch of system files
COPY files/ /

# IMPORTANT: /etc/os-release is used for versioning/upgrade. The
# values here should reflect the tag of the image currently being built
ARG IMAGE_REPO=norepo
ARG IMAGE_TAG=latest
RUN \
    sed -i -e "s|^IMAGE_REPO=.*|IMAGE_REPO=\"${IMAGE_REPO}\"|g" /etc/os-release && \
    sed -i -e "s|^IMAGE_TAG=.*|IMAGE_TAG=\"${IMAGE_TAG}\"|g" /etc/os-release && \
    sed -i -e "s|^IMAGE=.*|IMAGE=\"${IMAGE_REPO}:${IMAGE_TAG}\"|g" /etc/os-release


# IMPORTANT: it is good practice to recreate the initrd and re-apply `elemental-init`
# command that was used in the base image. This ensures that any eventual change that should
# be synced in initrd included binaries is also applied there and consistent.
RUN elemental init --force immutable-rootfs,grub-config,dracut-config,cloud-config-essentials,elemental-setup