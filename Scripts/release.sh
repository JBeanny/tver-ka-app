#!/usr/bin/env bash
# Builds a universal "Tver Ka.app" and zips it for a GitHub release.
# Usage: Scripts/release.sh   → build/Tver-Ka-<version>.zip (+ .sha256), which the in-app updater picks up
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION)"
Scripts/bundle.sh --universal

ZIP="build/Tver-Ka-$VERSION.zip"
rm -f "$ZIP"
# ditto keeps the bundle's symlinks, permissions and signature intact.
ditto -c -k --sequesterRsrc --keepParent "build/Tver Ka.app" "$ZIP"
(cd build && shasum -a 256 "$(basename "$ZIP")") | tee "$ZIP.sha256"
echo "Release archive: $ZIP"
