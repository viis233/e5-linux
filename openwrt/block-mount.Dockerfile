FROM ubuntu:22.04
# Ubuntu rotated its archive signing key in late 2026; the stock 22.04 image
# keyring lacks it, so apt-get update fails with NO_PUBKEY. The official
# archive keyring (with the current keys) is baked into the image.
COPY ubuntu-archive-keyring.gpg /etc/apt/trusted.gpg.d/ubuntu-archive-keyring.gpg
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential ca-certificates curl file gawk git gettext libncurses-dev \
    libssl-dev patch python3 python3-setuptools rsync unzip wget zstd \
    && rm -rf /var/lib/apt/lists/*
