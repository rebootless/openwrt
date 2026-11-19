#!/usr/bin/env bash

# OpenWrt for TP-Link TL-WR841N/ND v9 (4 MB Flash / 32 MB RAM).
# Lives in the wr841-v9 branch (based on v22.03.6), directory wr841-v9/.
# Config:   wr841-v9/wr841v9.config
# Build:    ./wr841-v9/build.sh

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."   # OpenWrt source root
CFG="$HERE/wr841v9.config"
OUT="bin/targets/ath79/tiny"

die() { echo "ERROR: $*" >&2; exit 1; }

[ -x scripts/feeds ] || die "Not an OpenWrt source root: $PWD"
[ -f "$CFG" ] || die "Configuration file not found: $CFG"

if [ ! -d feeds/packages ]; then
    ./scripts/feeds update -a
    ./scripts/feeds install -a
fi

cp "$CFG" .config
make defconfig

grep -q '^CONFIG_TARGET_ath79_tiny_DEVICE_tplink_tl-wr841-v9=y' .config \
    || die "WR841 v9 target profile is not selected in .config"

make -j"$(nproc)" download

if ! make -j"$(nproc)" V=s 2>&1 | tee build.log; then
    echo ">> Parallel build failed, retrying with a single job"
    make -j1 V=s 2>&1 | tee build.log
fi

echo
grep -i "too big" build.log && die "Firmware image is too large: remove packages" || true

fw="$(ls "$OUT"/*wr841-v9-squashfs-factory.bin 2>/dev/null || true)"
[ -n "$fw" ] || die "factory.bin was not created"

ls -lh "$OUT"/*wr841-v9*
sha256sum "$OUT"/*wr841-v9-squashfs-*.bin
echo ">> Build complete: $fw"
