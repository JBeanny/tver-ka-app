#!/usr/bin/env bash
# Builds a universal "Tver Ka.app" and zips it for a GitHub release.
# Usage: Scripts/release.sh   → build/Tver-Ka-<version>.zip (+ .sha256, + .sig), which the in-app updater picks up
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION)"
[[ -s Resources/update-public-key.txt ]] || { echo "Missing Resources/update-public-key.txt: run 'swift Scripts/release-key.swift keygen > Resources/update-public-key.txt' once." >&2; exit 1; }
Scripts/bundle.sh --universal

ZIP="build/Tver-Ka-$VERSION.zip"
rm -f "$ZIP"
# ditto keeps the bundle's symlinks, permissions and signature intact.
ditto -c -k --sequesterRsrc --keepParent "build/Tver Ka.app" "$ZIP"
(cd build && shasum -a 256 "$(basename "$ZIP")") | tee "$ZIP.sha256"
# The in-app updater only installs zips signed with the release key (kept in your login Keychain).
swift Scripts/release-key.swift sign "$ZIP"
echo "Release archive: $ZIP"
