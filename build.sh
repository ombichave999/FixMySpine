#!/bin/bash
# Builds FixMySpine.app with embedded Sparkle 2 framework and Ed25519 public key.
set -e
cd "$(dirname "$0")"

APP="FixMySpine"
VERSION="${1:-3.7}"
CHANNEL="${2:-main}"

if [ "$CHANNEL" = "beta" ]; then
    FEED_URL="https://raw.githubusercontent.com/ombichave999/FixMySpine-Releases/main/appcast-beta.xml"
else
    FEED_URL="https://raw.githubusercontent.com/ombichave999/FixMySpine-Releases/main/appcast.xml"
fi

mkdir -p build
STAGE="build/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
OUT="$STAGE/$APP.app/Contents"

mkdir -p "$OUT/MacOS" "$OUT/Resources" "$OUT/Frameworks"

# Write Info.plist with Sparkle 2 configuration
cat > "$OUT/Info.plist" <<PLIST
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
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
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
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>FixMySpine connects to your Apple Watch over Bluetooth to display live heart rate and deliver posture haptics.</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>FixMySpine connects to your Apple Watch over Bluetooth to display live heart rate and deliver posture haptics.</string>
    <key>SUFeedURL</key>
    <string>$FEED_URL</string>
    <key>SUPublicEDKey</key>
    <string>2RMO0xofZCoqUThQl+sGUs/989frROgegntI4gU8VR8=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
    <key>SUAllowsAutomaticUpdates</key>
    <true/>
</dict>
</plist>
PLIST

# Embed Sparkle.framework
if [ -d "Frameworks/Sparkle.framework" ]; then
    cp -R "Frameworks/Sparkle.framework" "$OUT/Frameworks/"
else
    echo "Error: Frameworks/Sparkle.framework not found!"
    exit 1
fi

# App icon: turn AppIcon.png into a proper .icns
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
    sips -z 18 18 AppIcon.png --out "$OUT/Resources/MenuBarIcon.png" >/dev/null
    sips -z 36 36 AppIcon.png --out "$OUT/Resources/MenuBarIcon@2x.png" >/dev/null
fi

echo "Compiling with Sparkle 2…"
swiftc -O Sources/main.swift \
    -module-cache-path ./.module-cache \
    -F ./Frameworks \
    -framework Sparkle \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Combine \
    -framework CoreMotion \
    -framework AVFoundation \
    -framework UserNotifications \
    -framework CoreBluetooth \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -o "$OUT/MacOS/$APP"

echo "Signing (ad hoc with Hardened Runtime compatibility)…"
find "$STAGE" -name '._*' -delete
xattr -cr "$STAGE/$APP.app" 2>/dev/null || true
codesign --force --sign - "$OUT/Frameworks/Sparkle.framework/Versions/B" 2>/dev/null || codesign --force --sign - "$OUT/Frameworks/Sparkle.framework"
codesign --force --deep --sign - "$STAGE/$APP.app"

echo "Moving into place…"
rm -rf "build/$APP.app"
ditto "$STAGE/$APP.app" "build/$APP.app"
rm -rf "$STAGE"

echo "Done! Finished build: build/$APP.app ($VERSION, channel: $CHANNEL)"
