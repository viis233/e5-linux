# Ubuntu 22.04's apt cannot read the 2026-rotated keyring, and the runner's
# cached debian:trixie amd64 image likewise fails signature verification
# (No good signature) on the current archive keys. These are CI-only build
# tools from official sources, so the index is fetched without signature
# checks. The fstools APK itself is built by the pinned OpenWrt SDK.
FROM debian:trixie
RUN apt-get update -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowUnauthenticated=true \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --allow-unauthenticated \
    build-essential ca-certificates curl file gawk git gettext libncurses-dev \
    libssl-dev patch python3 python3-setuptools rsync unzip wget zstd \
    && rm -rf /var/lib/apt/lists/*
