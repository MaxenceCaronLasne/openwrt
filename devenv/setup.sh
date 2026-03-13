#!/usr/bin/env bash
set -euo pipefail

SENTINEL="/build/.dendro-setup-done"

if [ -f "$SENTINEL" ]; then
    echo "Setup already done (remove $SENTINEL to re-run)."
    exit 0
fi

cd /build

echo "==> Patching feeds.conf.default..."
/build/devenv/apply-feeds-patch.sh

echo "==> Updating feeds..."
./scripts/feeds update -a

echo "==> Installing feeds..."
./scripts/feeds install -a

echo "==> Applying diffconfig..."
cp /build/diffconfig /build/.config

echo "==> Running defconfig..."
make defconfig

touch "$SENTINEL"
echo "==> Setup complete."
