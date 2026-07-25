#!/bin/bash
# Builds FixMySpine.app. Run from the FixMySpine folder:  bash build.sh
# Builds in a temp dir (outside iCloud/Finder metadata reach), signs there,
# then moves the finished app back. Fixes the codesign "detritus" error.
set -e
cd "$(dirname "$0")"

APP="FixMySpine"
STAGE="$(mktemp -d ./.tmp-build.XXXXXX)"
OUT="$STAGE/$APP.app/Contents"

mkdir -p "$OUT/MacOS" "$OUT/Resources"

# Write Info.plist fresh (no copied Finder metadata)
cat > "$OUT/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>FixMySpine</string>
    <key>CFBundleDisplayName</key>
    <string>FixMySpine</string>
    <key>CFBundleIdentifier</key>
    <string>com.fixmyspine.app</string>
    <key>CFBundleExecutable</key>
    <string>FixMySpine</string>
    <key>CFBundleVersion</key>
    <string>3.0</string>
    <key>CFBundleShortVersionString</key>
    <string>3.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSMotionUsageDescription</key>
    <string>FixMySpine reads head motion from your AirPods to check your posture. Nothing leaves your Mac.</string>
</dict>
</plist>
PLIST

# App icon: turn AppIcon.png into a proper .icns (sips + iconutil ship with macOS)
if [ -f AppIcon.png ]; then
    echo "Building icon…"
    ICONSET="$STAGE/AppIcon.iconset"
    mkdir "$ICONSET"
    for s in 16 32 128 256 512; do
        sips -z $s $s AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
        d=$((s * 2))
        sips -z $d $d AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$OUT/Resources/AppIcon.icns"
fi

echo "Compiling…"
swiftc -O Sources/main.swift \
    -module-cache-path ./.module-cache \
    -o "$OUT/MacOS/$APP" \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Combine \
    -framework CoreMotion \
    -framework AVFoundation \
    -framework UserNotifications

echo "Signing (ad hoc)…"
find "$STAGE" -name '._*' -delete
xattr -cr "$STAGE/$APP.app" 2>/dev/null || true
codesign --force --deep --sign - "$STAGE/$APP.app"

echo "Moving into place…"
rm -rf build
mkdir -p build
ditto "$STAGE/$APP.app" "build/$APP.app"
rm -rf "$STAGE"

echo ""
echo "Done! Launch it with:  open build/$APP.app"
