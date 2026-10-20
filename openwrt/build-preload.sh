#!/bin/bash
# Stage the E5's extra pre-installed packages for the OpenWrt image build.
#
#   openwrt/build-preload.sh   -> work/openwrt/preload/
#
# What is staged, and why it is separate from the official feed:
#
#  * PassWall2 (luci-app-passwall2 + 12 dependencies + zh-cn i18n), from the
#    GitHub release Openwrt-Passwall/openwrt-passwall2 (26.10.1-2).  OpenWrt's
#    feeds do not carry it, so it is installed unsigned (--allow-untrusted).
#  * The proxy cores it needs: Xray 26.9.30 (arm64-v8a) and sing-box 1.14.2
#    (linux-arm64-musl -- OpenWrt has no glibc loader, a glibc build fails).
#    They are ELF files, not packages; they land in usr/bin/ of the image
#    (PassWall2's default @global_app[0].xray_file/sing_box_file path).
#  * ZeroTier 1.16.0-r2 (the ImmortalWrt build that implements the
#    fw_allow_* options the stock package drops) and its LuCI app + zh-cn
#    translation, from the ImmortalWrt 25.12.2 aarch64_generic repository.
#
# Everything is pinned by URL and SHA-256; a changed upstream file stops the
# build instead of silently upgrading.  No subscription URL, node list,
# password or network identity goes in here -- those stay user-configured.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TOP="$(cd "$HERE/.." && pwd)"
WORK="$TOP/work/openwrt"
OUT="$WORK/preload"
mkdir -p "$OUT"

# PassWall2 -- GitHub release 26.10.1-2
PW2_URL=https://github.com/Openwrt-Passwall/openwrt-passwall2/releases/download/26.10.1-2
# Xray / sing-box cores (raw ELF, musl static)
XRAY_URL=https://github.com/XTLS/Xray-core/releases/download/v26.9.30/Xray-linux-arm64-v8a.zip
SINGBOX_URL=https://github.com/SagerNet/sing-box/releases/download/v1.14.2/sing-box-1.14.2-linux-arm64-musl.tar.gz
# ZeroTier + LuCI from ImmortalWrt 25.12.2 (aarch64_generic)
IW_BASE=https://downloads.immortalwrt.org/releases/25.12.2/packages/aarch64_generic

fetch() { # url file sha256
    local url=$1 f=$2 want=$3 got
    if [ ! -f "$f" ]; then
        curl -fsSL -o "$f.part" "$url" || { rm -f "$f.part"; return 1; }
        mv "$f.part" "$f"
    fi
    got=$(sha256sum "$f" | cut -d' ' -f1)
    [ "$got" = "$want" ] || { echo "checksum mismatch for $f" >&2; rm -f "$f"; return 1; }
}

# --- PassWall2 main package + zh-cn ---
fetch "$PW2_URL/luci-app-passwall2-26.10.1-r2.apk" \
    "$OUT/luci-app-passwall2-26.10.1-r2.apk" \
    a2bc8c2bea2da3993691f306e5e752f03e50daf88fbc3ebd36af859cc28dd3d6
fetch "$PW2_URL/luci-i18n-passwall2-zh-cn-26.10.1.apk" \
    "$OUT/luci-i18n-passwall2-zh-cn-26.10.1.apk" \
    6a5626a028a71b11d30093bed7bd5acb04f9840777f4f3b578b33fc3fb7737e8
fetch "$PW2_URL/packages_apk_aarch64_generic.zip" \
    "$OUT/packages_apk_aarch64_generic.zip" \
    a4b54b33b13e293348e12751634ea6e044fc1d55325ab8facfd72db7ce71d9b6

# --- proxy cores (ELF into usr/bin) ---
fetch "$XRAY_URL" "$OUT/xray-26.9.30.zip" \
    9886f077f9fd8e6713b84c377c1c7db4e53b9bfa8c276a5bd12561139522b473
fetch "$SINGBOX_URL" "$OUT/sing-box-1.14.2-musl.tar.gz" \
    675297394f9430cebb72b3c48ba8bce0d6f7c750a9d68a8f7f88c515c8255cd1

# --- ZeroTier + LuCI (ImmortalWrt) ---
fetch "$IW_BASE/packages/zerotier-1.16.0-r2.apk" \
    "$OUT/zerotier-1.16.0-r2.apk" \
    ef2af90dab3cc3f21a6532b4db6b9a38f5afa2acd40b766c46748b272ee5977b
fetch "$IW_BASE/luci/luci-app-zerotier-26.236.50544~cb5d434.apk" \
    "$OUT/luci-app-zerotier-26.236.50544~cb5d434.apk" \
    efb7961c9415861e7240b58995888b3a904d336d1703e6a7190037670f2bb049
fetch "$IW_BASE/luci/luci-i18n-zerotier-zh-cn-26.236.50544~cb5d434.apk" \
    "$OUT/luci-i18n-zerotier-zh-cn-26.236.50544~cb5d434.apk" \
    14cead4bcdf342491c79df9f36ffc820253d486c6718247f1eb3efc1892e49e2

# --- unpack PassWall2 dependencies ---
rm -rf "$OUT/pw2deps"
mkdir -p "$OUT/pw2deps"
python3 - "$OUT/packages_apk_aarch64_generic.zip" "$OUT/pw2deps" <<'PY'
import sys, zipfile
src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(src) as z:
    for n in z.namelist():
        if n.endswith('.apk'):
            with z.open(n) as srcf, open(dst + '/' + n.rsplit('/', 1)[-1], 'wb') as out:
                out.write(srcf.read())
print('%d apk extracted' % len([n for n in zipfile.ZipFile(src).namelist() if n.endswith('.apk')]))
PY

# --- unpack proxy cores to usr/bin ---
rm -rf "$OUT/core" && mkdir -p "$OUT/core/usr/bin"
python3 - "$OUT/xray-26.9.30.zip" "$OUT/core/usr/bin/xray" <<'PY'
import sys, zipfile, stat
src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(src) as z:
    data = z.read('xray')
open(dst, 'wb').write(data)
import os
os.chmod(dst, 0o755)
PY
tar -xzf "$OUT/sing-box-1.14.2-musl.tar.gz" -C "$OUT/core/usr/bin" --strip-components=1 \
    --wildcards '*/sing-box'
chmod 0755 "$OUT/core/usr/bin/sing-box"

# verify the extracted cores are static arm64 ELF
for f in "$OUT/core/usr/bin/xray" "$OUT/core/usr/bin/sing-box"; do
    [ "$(od -An -t u2 -j 18 -N 2 "$f" | tr -d ' ')" = 183 ] || { echo "$f is not arm64" >&2; exit 1; }
done
# They land in the image as root; a host uid (e.g. 1001 in CI) must not leak in.
chown 0:0 "$OUT/core/usr/bin/xray" "$OUT/core/usr/bin/sing-box"

echo "preload staged: $(ls "$OUT"/*.apk | wc -l) apk + 12 pw2 deps + 2 cores"
