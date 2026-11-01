#!/usr/bin/env bash
# Builds a universal tver-ka.app and zips it for a GitHub release.
# Usage: Scripts/release.sh   → build/tver-ka-<version>.zip (+ .sha256)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION)"
Scripts/bundle.sh --universal

ZIP="build/tver-ka-$VERSION.zip"
rm -f "$ZIP"
# ditto keeps the bundle's symlinks, permissions and signature intact.
ditto -c -k --sequesterRsrc --keepParent build/tver-ka.app "$ZIP"
shasum -a 256 "$ZIP" | tee "$ZIP.sha256"
echo "Release archive: $ZIP"
