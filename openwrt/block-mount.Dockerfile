# Ubuntu 22.04's apt cannot read the 2026-rotated archive keyring
# (NO_PUBKEY / unsupported filetype). These are CI-only build tools from
# official sources, so the package index is fetched without signature checks.
# The OpenWrt SDK builds fstools on Ubuntu 22.04; Debian crashes its awk/make.
FROM ubuntu:22.04
RUN apt-get update -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowUnauthenticated=true \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --allow-unauthenticated \
    build-essential ca-certificates curl file gawk git gettext libncurses-dev \
    libssl-dev patch python3 python3-setuptools rsync unzip wget zstd \
    && rm -rf /var/lib/apt/lists/*
