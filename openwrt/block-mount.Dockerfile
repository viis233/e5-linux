FROM ubuntu:22.04
# Ubuntu rotated its archive signing key in late 2026; the stock 22.04 image
# keyring lacks it, so apt-get update fails with NO_PUBKEY. Fetch the official
# archive keyring over plain HTTP (no certificates needed) before updating.
RUN apt-get update || true \
 && python3 -c "import urllib.request; urllib.request.urlretrieve('http://archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg', '/etc/apt/trusted.gpg.d/ubuntu-archive-keyring.gpg')" \
 && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential ca-certificates curl file gawk git gettext libncurses-dev \
    libssl-dev patch python3 python3-setuptools rsync unzip wget zstd \
    && rm -rf /var/lib/apt/lists/*
