#!/bin/bash
# Stage the E5's extra pre-installed packages for the OpenWrt image build.
#
#   openwrt/build-preload.sh   -> work/openwrt/preload/
#
# What is staged, and why it is separate from the official feed:
#
#  * PassWall2 (luci-app-passwall2 + dependencies + zh-cn i18n), from the
#    GitHub release Openwrt-Passwall/openwrt-passwall2 (26.10.20-1).  OpenWrt's
#    feeds do not carry it, so it is installed unsigned (--allow-untrusted).
#    Since 26.10.20-1 the dependency bundle also carries the proxy cores it
#    needs (xray-core 26.10.17 and sing-box 1.14.3), so no separate ELF
#    download is needed -- their packages place them in usr/bin/ (PassWall2's
#    default @global_app[0].xray_file/sing_box_file path).
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

# PassWall2 -- GitHub release 26.10.20-1
PW2_URL=https://github.com/Openwrt-Passwall/openwrt-passwall2/releases/download/26.10.20-1
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
fetch "$PW2_URL/luci-app-passwall2-26.10.20-r1.apk" \
    "$OUT/luci-app-passwall2-26.10.20-r1.apk" \
    564f9dcd95a222dce565839e365ac89a1bbb9a4cc51aab1314086e7df509e59c
fetch "$PW2_URL/luci-i18n-passwall2-zh-cn-26.10.20.apk" \
    "$OUT/luci-i18n-passwall2-zh-cn-26.10.20.apk" \
    e041d16af6d5b00dcc8b75026e226ecdbf7a66422fe8e8584c1dde72bd14d97a
fetch "$PW2_URL/packages_apk_aarch64_generic.zip" \
    "$OUT/packages_apk_aarch64_generic.zip" \
    38180070bc3789b1a496dcd1f73524f540d248c7d8114f04d9f96e2744b7d5f3

# --- proxy cores are bundled in the PassWall2 dependency zip above ---

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

echo "preload staged: $(ls "$OUT"/*.apk | wc -l) apk + $(ls "$OUT/pw2deps"/*.apk | wc -l) pw2 deps (incl. xray-core + sing-box)"
