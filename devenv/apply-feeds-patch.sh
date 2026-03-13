#!/usr/bin/env bash
# Add the dendro feed to feeds.conf.default if not already present.
# Run this once after cloning the OpenWRT fork.
set -euo pipefail

FEEDS_FILE="/build/feeds.conf.default"
DENDRO_LINE="src-git dendro git@github.com:MaxenceCaronLasne/dendro.git"

if grep -qF "$DENDRO_LINE" "$FEEDS_FILE"; then
    echo "dendro feed already present in feeds.conf.default"
else
    echo "$DENDRO_LINE" >> "$FEEDS_FILE"
    echo "Added dendro feed to feeds.conf.default"
fi
