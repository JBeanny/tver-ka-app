#!/usr/bin/env bash
# Builds Tver Ka and wraps it into "build/Tver Ka.app" (menu bar only, no Dock icon).
# Usage: Scripts/bundle.sh [--install] [--universal]
#   --install    copy the app to /Applications
#   --universal  build for Apple Silicon and Intel (used for releases)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION)"
ARCH_FLAGS=()
[[ " $* " == *" --universal "* ]] && ARCH_FLAGS=(--arch arm64 --arch x86_64)

swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/TverKa"
APP="build/Tver Ka.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TverKa"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Shortcuts/*.shortcut "$APP/Contents/Resources/"

# The update signing public key (safe to publish). Without it the app refuses to install updates.
PUBKEY_ENTRY=""
if [[ -s Resources/update-public-key.txt ]]; then
  PUBKEY_ENTRY="<key>TverKaUpdatePublicKey</key><string>$(tr -d '[:space:]' < Resources/update-public-key.txt)</string>"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>TverKa</string>
  <key>CFBundleIdentifier</key><string>dev.tverka.app</string>
  <key>CFBundleName</key><string>Tver Ka</string>
  <key>CFBundleDisplayName</key><string>Tver Ka</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  $PUBKEY_ENTRY
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null
echo "Built $APP ($VERSION)"

if [[ " $* " == *" --install "* ]]; then
  # Replace in place, including the pre-rename "tver-ka.app", so there's only ever one copy.
  rm -rf "/Applications/tver-ka.app" "/Applications/Tver Ka.app"
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/Tver Ka.app"
fi
