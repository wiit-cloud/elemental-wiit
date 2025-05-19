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
RUN LC_ALL=C DEBIAN_FRONTEND=noninteractive apt update
RUN LC_ALL=C DEBIAN_FRONTEND=noninteractive apt install -y libssl-dev

ARG REGISTER_TAG
ARG REGISTER_COMMIT
ARG REGISTER_COMMITDATE

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

ARG TOOLKIT_TAG
ARG TOOLKIT_COMMIT

ADD https://github.com/rancher/elemental-toolkit.git#${TOOLKIT_TAG} .

RUN go mod download
RUN go generate ./...
RUN go build \
    -ldflags "LDFLAGS:=-w -s \
    -X github.com/rancher/elemental-toolkit/v2/internal/version.version=${TOOLKIT_TAG} \
    -X github.com/rancher/elemental-toolkit/v2/internal/version.gitCommit=${TOOLKIT_COMMIT}" \
    -o /usr/bin/elemental

FROM registry.opensuse.org/opensuse/tumbleweed:latest AS os
ARG RANCHER_SYSTEM_AGENT_VERSION

# install kernel, systemd, dracut, grub2 and other required tools
RUN ARCH=$(uname -m); \
    [[ "${ARCH}" == "aarch64" ]] && ARCH="arm64"; \
    zypper --non-interactive install --no-recommends -- \
    kernel-default \
    device-mapper \
    dracut \
    grub2 \
    grub2-${ARCH}-efi \
    shim \
    haveged \
    systemd \
    NetworkManager \
    openssh-server \
    openssh-clients \
    timezone \
    parted \
    e2fsprogs \
    dosfstools \
    mtools \
    xorriso \
    findutils \
    gptfdisk \
    rsync \
    squashfs \
    lvm2 \
    tar \
    gzip \
    vim \
    which \
    less \
    sudo \
    curl \
    iproute2 \
    podman \
    sed \
    btrfsprogs \
    btrfsmaintenance \
    snapper \
    glibc-gconv-modules-extra \
    wget \
    unzip \
    nmap \
    tcpdump \
    openvswitch \
    NetworkManager-ovs \
    tmux \
    screen \
    traceroute \
    iputils \
    ipmitool \
    netcat \
    bind-utils \
    jq \
    yq \
    bash-completion \
    frr \
    patch \
    wireshark \
    lldpd \
    dhcp-client

# elemental-register dependencies
RUN ARCH=$(uname -m); \
    [[ "${ARCH}" == "aarch64" ]] && ARCH="arm64"; \
    zypper --non-interactive install --no-recommends -- \
    dmidecode
# libopenssl-1_1

# Install nm-configurator
RUN curl -o /usr/sbin/nmc -L https://github.com/suse-edge/nm-configurator/releases/latest/download/nmc-linux-$(uname -m)
RUN chmod +x /usr/sbin/nmc

# SELinux policy and tools
RUN ARCH=$(uname -m); \
    [[ "${ARCH}" == "aarch64" ]] && ARCH="arm64"; \
    zypper --non-interactive install --no-recommends -- \
    # patterns-base-selinux \
    # rke2-selinux \
    audit

# Add system files
COPY files/ /

# Enable SELinux (The security=selinux arg is default on Micro, not on Tumbleweed)
RUN sed -i "s/selinux=1/security=selinux selinux=1/g" /etc/elemental/bootargs.cfg
# Enforce SELinux
# RUN sed -i "s/enforcing=0/enforcing=1/g" /etc/elemental/bootargs.cfg

# Add elemental-register
COPY --from=register /usr/sbin/elemental-register /usr/sbin/elemental-register
COPY --from=register /usr/sbin/elemental-support /usr/sbin/elemental-support
# Add the elemental cli
COPY --from=toolkit /usr/bin/elemental /usr/bin/elemental

# Add the elemental-system-agent
ADD --chmod=0755 https://github.com/rancher/system-agent/releases/download/${RANCHER_SYSTEM_AGENT_VERSION}/rancher-system-agent-amd64 /usr/sbin/elemental-system-agent

# Enable essential services
RUN systemctl enable NetworkManager.service sshd elemental-register.timer openvswitch.service

RUN chmod +x /etc/NetworkManager/dispatcher.d/10-fabric.sh

# This is for testing purposes, do not do this in production.
RUN echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/rootlogin.conf

# Make sure trusted certificates are properly generated
RUN /usr/sbin/update-ca-certificates

# Ensure /tmp is mounted as tmpfs by default
RUN if [ -e /usr/share/systemd/tmp.mount ]; then \
    cp /usr/share/systemd/tmp.mount /etc/systemd/system; \
    fi

# Save some space
RUN zypper clean --all && \
    rm -rf /var/log/update* && \
    >/var/log/lastlog && \
    rm -rf /boot/vmlinux*

# Apply some image customizations, using patches
RUN cd /etc/frr && patch -p0 < /opt/patches/frr.patch && cd

# Update os-release file with some metadata
ARG IMAGE_REPO=norepo
ARG IMAGE_TAG=latest
RUN echo TIMESTAMP="`date +'%Y%m%d%H%M%S'`" >> /etc/os-release && \
    echo GRUB_ENTRY_NAME=\"Elemental Wiit\" >> /etc/os-release && \
    echo IMAGE_REPO=\"${IMAGE_REPO}\" >> /etc/os-release && \
    echo IMAGE_TAG=\"${IMAGE_TAG}\" >> /etc/os-release && \
    echo IMAGE=\"${IMAGE_REPO}:${IMAGE_TAG}\" >> /etc/os-release && \
    sed -i -e "s|^NAME=.*|NAME=\"Elemental Wiit ${IMAGE_TAG}\"|g" /etc/os-release && \
    sed -i -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"Elemental Wiit ${IMAGE_TAG}\"|g" /etc/os-release

# Rebuild initrd to setup dracut with the boot configurations
RUN elemental init --force elemental-rootfs,elemental-sysroot,grub-config,dracut-config,cloud-config-essentials,elemental-setup,boot-assessment
