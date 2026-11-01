#!/usr/bin/env bash
# Builds tver-ka and wraps it into build/tver-ka.app (menu bar only, no Dock icon).
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
APP="build/tver-ka.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TverKa"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>TverKa</string>
  <key>CFBundleIdentifier</key><string>dev.tverka.app</string>
  <key>CFBundleName</key><string>tver-ka</string>
  <key>CFBundleDisplayName</key><string>tver-ka</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null
echo "Built $APP ($VERSION)"

if [[ " $* " == *" --install "* ]]; then
  rm -rf "/Applications/tver-ka.app"
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/tver-ka.app"
fi
