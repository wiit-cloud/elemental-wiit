# syntax=docker/dockerfile:1.15.1-labs

FROM golang:1.24.3-bookworm AS builder

ARG TAG=v1.6.8
ARG COMMIT="d8008d7"
ARG COMMITDATE="2025-04-23"

ADD https://github.com/rancher/elemental-operator@$TAG .

ENV CGO_ENABLED=1
RUN go build  \
    -ldflags "-w -s  \
    -X github.com/rancher/elemental-operator/pkg/version.Version=$TAG  \
    -X github.com/rancher/elemental-operator/pkg/version.Commit=$COMMIT  \
    -X github.com/rancher/elemental-operator/pkg/version.CommitDate=$COMMITDATE"  \
    -o /usr/sbin/elemental-register ./cmd/register
ENV CGO_ENABLED=0
RUN go build  \
    -ldflags "-w -s  \
    -X github.com/rancher/elemental-operator/pkg/version.Version=$TAG  \
    -X github.com/rancher/elemental-operator/pkg/version.Commit=$COMMIT  \
    -X github.com/rancher/elemental-operator/pkg/version.CommitDate=$COMMITDATE"  \
    -o /usr/sbin/elemental-support ./cmd/support


ARG ELEMENTAL_TOOLKIT
ARG SOURCE_REPO
ARG SOURCE_VERSION

FROM golang:1.24.3-bookworm AS register
WORKDIR /src/

# hadolint ignore=DL3027
RUN LC_ALL=C DEBIAN_FRONTEND=noninteractive apt update
# hadolint ignore=DL3027,DL3059
RUN LC_ALL=C DEBIAN_FRONTEND=noninteractive apt install -y libssl-dev

ARG REGISTER_TAG=v1.6.8
ARG REGISTER_COMMIT=d8008d7
ARG REGISTER_COMMITDATE=2025-04-23

ADD https://github.com/rancher/elemental-operator.git#${REGISTER_TAG} .

ENV CGO_ENABLED=1
RUN go build  \
    -ldflags "-w -s  \
    -X github.com/rancher/elemental-operator/pkg/version.Version=${REGISTER_TAG}  \
    -X github.com/rancher/elemental-operator/pkg/version.Commit=${REGISTER_COMMIT}  \
    -X github.com/rancher/elemental-operator/pkg/version.CommitDate=${REGISTER_COMMITDATE}"  \
    -o /usr/sbin/elemental-register ./cmd/register
ENV CGO_ENABLED=0
RUN go build  \
    -ldflags "-w -s  \
    -X github.com/rancher/elemental-operator/pkg/version.Version=${REGISTER_TAG}  \
    -X github.com/rancher/elemental-operator/pkg/version.Commit=${REGISTER_COMMIT}  \
    -X github.com/rancher/elemental-operator/pkg/version.CommitDate=${REGISTER_COMMITDATE}"  \
    -o /usr/sbin/elemental-support ./cmd/support

FROM golang:1.24.3-alpine AS toolkit
WORKDIR /src/

ARG TOOLKIT_TAG=v2.2.2
ARG TOOLKIT_COMMIT=1fbc11e

ADD https://github.com/rancher/elemental-toolkit.git#${TOOLKIT_TAG} .

RUN go mod download
# hadolint ignore=DL3059
RUN go generate ./...
# hadolint ignore=DL3059
RUN go build \
    -ldflags "LDFLAGS:=-w -s \
    -X github.com/rancher/elemental-toolkit/v2/internal/version.version=${TOOLKIT_TAG} \
    -X github.com/rancher/elemental-toolkit/v2/internal/version.gitCommit=${TOOLKIT_COMMIT}" \
    -o /usr/bin/elemental

# hadolint ignore=DL3007
FROM registry.opensuse.org/opensuse/tumbleweed:latest AS os
ARG RANCHER_SYSTEM_AGENT_VERSION=v0.3.12

# install kernel, systemd, dracut, grub2 and other required tools
# hadolint ignore=DL3036,DL3037
RUN ARCH="$(uname -m)"; \
    [ "${ARCH}" = "aarch64" ] && ARCH="arm64"; \
    zypper ar -f https://download.opensuse.org/history/20250602/tumbleweed/repo/oss/ pinned-oss && \
    zypper --non-interactive install --no-recommends -- \
    bash-completion \
    bind-utils \
    btrfsmaintenance \
    btrfsprogs \
    curl \
    device-mapper \
    dhcp-client \
    dosfstools \
    dracut \
    e2fsprogs \
    findutils \
    frr \
    glibc-gconv-modules-extra \
    gptfdisk \
    grub2 \
    "grub2-${ARCH}-efi" \
    gzip \
    haveged \
    ipmitool \
    iproute2 \
    iputils \
    jq \
    kernel-default \
    less \
    lldpd \
    lvm2 \
    mtools \
    netcat \
    NetworkManager \
    NetworkManager-ovs \
    nmap \
    openssh-clients \
    openssh-server \
    openvswitch \
    ovmf \
    parted \
    patch \
    podman \
    rsync \
    screen \
    sed \
    shim \
    snapper \
    squashfs \
    sudo \
    systemd \
    tar \
    tcpdump \
    timezone \
    tmux \
    traceroute \
    unzip \
    vim \
    wget \
    which \
    wireshark \
    xorriso \
    yq \
    util-linux-systemd=2.40.4-4.2
# ☝️ only works for about a month. Tumbleweed package repos are deleted afterwards
# Keep an eye on https://software.opensuse.org/package/util-linux for 2.41.1
# Issue caused by https://github.com/util-linux/util-linux/issues/3474

# elemental-register dependencies
# hadolint ignore=DL3036,DL3037
RUN ARCH="$(uname -m)"; \
    [ "${ARCH}" = "aarch64" ] && ARCH="arm64"; \
    zypper --non-interactive install --no-recommends -- \
    dmidecode && \
    # Install nm-configurator
    curl -o /usr/sbin/nmc -L https://github.com/suse-edge/nm-configurator/releases/latest/download/nmc-linux-"$(uname -m)" && \
    chmod +x /usr/sbin/nmc

# SELinux policy and tools
# hadolint ignore=DL3036,DL3037
RUN ARCH="$(uname -m)"; \
    [ "${ARCH}" = "aarch64" ] && ARCH="arm64"; \
    zypper --non-interactive install --no-recommends -- \
    audit
# patterns-base-selinux \
# rke2-selinux \

# Add system files
COPY files/ /

# Enable SELinux. The security=selinux arg is set by default on Micro, but not on Tumbleweed.
RUN sed -i "s/selinux=1/security=selinux selinux=1/g" /etc/elemental/bootargs.cfg && \
    # Enforce SELinux
    # sed -i "s/enforcing=0/enforcing=1/g" /etc/elemental/bootargs.cfg && \
    chmod 0600 /etc/NetworkManager/system-connections/fabric.nmconnection


# Add elemental-register
COPY --from=register /usr/sbin/elemental-register /usr/sbin/elemental-register
COPY --from=register /usr/sbin/elemental-support /usr/sbin/elemental-support
# Add the elemental cli
COPY --from=toolkit /usr/bin/elemental /usr/bin/elemental

# Add the elemental-system-agent
ADD --chmod=0755 https://github.com/rancher/system-agent/releases/download/${RANCHER_SYSTEM_AGENT_VERSION}/rancher-system-agent-amd64 /usr/sbin/elemental-system-agent

# Enable essential services
RUN systemctl enable \
    elemental-register.timer \
    lldpd.service \
    NetworkManager.service \
    openvswitch.service \
    sshd.service \
    wait-for-internet.service \
    frr-ready.path && \
    # This is for testing purposes, do not do this in production.
    echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/rootlogin.conf && \
    # Make sure trusted certificates are properly generated
    /usr/sbin/update-ca-certificates && \
    # Ensure /tmp is mounted as tmpfs by default
    if [ -e /usr/share/systemd/tmp.mount ]; then \
    cp /usr/share/systemd/tmp.mount /etc/systemd/system; \
    fi; \
    # Save some space
    zypper clean --all && \
    rm -rf /var/log/update* && \
    printf '' > /var/log/lastlog && \
    rm -rf /boot/vmlinux*

# Update os-release metadata
ARG IMAGE_REPO=norepo
ARG IMAGE_TAG=latest
RUN echo TIMESTAMP="$(date +'%Y%m%d%H%M%S')" >> /etc/os-release && \
    echo GRUB_ENTRY_NAME=\"Elemental Wiit\" >> /etc/os-release && \
    echo IMAGE_REPO=\"${IMAGE_REPO}\" >> /etc/os-release && \
    echo IMAGE_TAG=\"${IMAGE_TAG}\" >> /etc/os-release && \
    echo IMAGE=\"${IMAGE_REPO}:${IMAGE_TAG}\" >> /etc/os-release && \
    sed -i -e "s|^NAME=.*|NAME=\"Elemental Wiit ${IMAGE_TAG}\"|g" /etc/os-release && \
    sed -i -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"Elemental Wiit ${IMAGE_TAG}\"|g" /etc/os-release

# Rebuild initrd to setup dracut with the boot configurations
# hadolint ignore=DL3059
RUN elemental init --force elemental-rootfs,elemental-sysroot,grub-config,dracut-config,cloud-config-essentials,elemental-setup,boot-assessment
