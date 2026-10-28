# Ubuntu 22.04's apt (2.4/gpgv) cannot read the keyring Ubuntu rotated in
# late 2026 (NO_PUBKEY / unsupported filetype on every trusted keyring file),
# so the base is Debian instead; the build uses the OpenWrt SDK toolchain.
FROM debian:trixie
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential ca-certificates curl file gawk git gettext libncurses-dev \
    libssl-dev patch python3 python3-setuptools rsync unzip wget zstd \
    && rm -rf /var/lib/apt/lists/*
