#!/bin/bash
# Stage the E5's extra pre-installed packages for the OpenWrt image build.
#
#   openwrt/build-preload.sh   -> work/openwrt/preload/
#
# What is staged, and why it is separate from the official feed:
#
#  * PassWall2 (luci-app-passwall2 + dependencies + zh-cn i18n), from the
#    GitHub release Openwrt-Passwall/openwrt-passwall2 (26.10.1-2).  OpenWrt's
#    feeds do not carry it, so it is installed unsigned (--allow-untrusted).
#    The 26.10.1-2 dependency bundle does NOT carry the proxy cores (they were
#    only added from 26.10.20-1), so the exact E5-proven cores are fetched
#    separately below and staged as bare ELFs into usr/bin/ (PassWall2's
#    default @global_app[0].xray_file/sing_box_file path): xray-core 26.9.9
#    and sing-box 1.14.3.
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

# --- proxy cores: not in the 26.10.1-2 dependency zip (only from 26.10.20-1),
#     so fetch the exact E5-proven ELFs and stage them for /usr/bin ---
XRAY_URL=https://github.com/XTLS/Xray-core/releases/download/v26.9.9
SB_URL=https://github.com/SagerNet/sing-box/releases/download/v1.14.3
fetch "$XRAY_URL/Xray-linux-arm64-v8a.zip" "$OUT/xray-26.9.9.zip" \
    3e38d72dfc5eb65c91df0e5583e9b6676c32232041da47de6ae73946b526d66c
fetch "$SB_URL/sing-box-1.14.3-linux-arm64.tar.gz" "$OUT/sing-box-1.14.3.tar.gz" \
    29dae24d76bea3bc62d07dd3e60cfc12003de7debbd6b768df9be9c68360174e
unzip -o "$OUT/xray-26.9.9.zip" -d "$OUT/xray2699" >/dev/null
mv "$OUT/xray2699/xray" "$OUT/xray-26.9.9"
rm -rf "$OUT/xray2699" "$OUT/xray-26.9.9.zip"
tar -xzf "$OUT/sing-box-1.14.3.tar.gz" -C "$OUT"
mv "$OUT/sing-box-1.14.3-linux-arm64/sing-box" "$OUT/sing-box-1.14.3"
rm -rf "$OUT/sing-box-1.14.3-linux-arm64" "$OUT/sing-box-1.14.3.tar.gz"

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

echo "preload staged: $(ls "$OUT"/*.apk | wc -l) apk + $(ls "$OUT/pw2deps"/*.apk | wc -l) pw2 deps + xray-26.9.9 + sing-box-1.14.3 ELFs"
