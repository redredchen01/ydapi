#!/bin/bash
# Apply DexAPI UI patches to sub2api source
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCHES_DIR="$SCRIPT_DIR/patches"
SUB2API_DIR="$SCRIPT_DIR/sub2api"

for patch in "$PATCHES_DIR"/*.patch; do
  if [ -s "$patch" ]; then
    echo "Applying $(basename "$patch")..."
    cd "$SUB2API_DIR"
    patch -p0 --no-backup-if-mismatch < "$patch" || echo "WARN: $(basename "$patch") may have conflicts"
  fi
done
echo "All patches applied."
