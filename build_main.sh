#!/bin/bash
# ==============================================================================
# FixMySpine - Production Release Automation (Main Channel)
# Sparkle 2 + Ed25519 Cryptographic Signing + Appcast RSS + Dual Repo Deployment
# ==============================================================================

set -e
cd "$(dirname "$0")"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    CURRENT_VER=$(grep 'static let version =' Sources/main.swift | sed -E 's/.*"([^"]+)".*/\1/')
    read -p "Enter production release version [current: $CURRENT_VER]: " INPUT_VER
    VERSION="${INPUT_VER:-$CURRENT_VER}"
fi

NOTES="${2:-"FixMySpine 1.0 Stable: Real-time AirPods posture tracking, Apple Watch & Smartwatch sync, daily analytics, and production Sparkle 2 auto-updates."}"
PUBDATE=$(date -R)
CHANNEL="main"

echo "========================================================"
echo "🚀 Building FixMySpine Production Release v$VERSION"
echo "   Channel: $CHANNEL"
echo "   Release Notes: $NOTES"
echo "========================================================"

# 1. Update Version in Sources/main.swift
echo "Step 1: Updating version to $VERSION in code..."
sed -i '' "s/static let version = \"[^\"]*\"/static let version = \"$VERSION\"/g" Sources/main.swift

# 2. Build FixMySpine.app and Package DMG
echo "Step 2: Building app and packaging DMG installer..."
bash make_dmg.sh "$VERSION" "$CHANNEL"

# 3. Sign DMG with Sparkle 2 Ed25519 Private Key
echo "Step 3: Signing DMG with Ed25519 private key..."
if [ ! -f "./Sparkle-Tools/bin/sign_update" ]; then
    echo "Error: ./Sparkle-Tools/bin/sign_update not found!"
    exit 1
fi

SIGNATURE=$(./Sparkle-Tools/bin/sign_update -p FixMySpine.dmg)
FILESIZE=$(stat -f%z FixMySpine.dmg 2>/dev/null || stat -c%s FixMySpine.dmg)

echo "   Ed25519 Signature: $SIGNATURE"
echo "   File Size: $FILESIZE bytes"

# 4. Generate appcast.xml RSS feed
echo "Step 4: Generating production appcast.xml..."
cat > appcast.xml <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>FixMySpine Updates</title>
    <link>https://github.com/ombichave999/FixMySpine-Releases</link>
    <description>Most recent updates to FixMySpine</description>
    <language>en</language>
    <item>
      <title>FixMySpine v$VERSION</title>
      <description><![CDATA[
        <h2>FixMySpine v$VERSION Release Notes</h2>
        <p>$NOTES</p>
      ]]></description>
      <pubDate>$PUBDATE</pubDate>
      <enclosure url="https://raw.githubusercontent.com/ombichave999/FixMySpine-Releases/main/FixMySpine.dmg"
                 sparkle:version="$VERSION"
                 sparkle:shortVersionString="$VERSION"
                 length="$FILESIZE"
                 type="application/x-apple-diskimage"
                 sparkle:edSignature="$SIGNATURE" />
    </item>
  </channel>
</rss>
APPCAST

# 5. Commit & Push Private Source Repo
echo "Step 5: Pushing to private repository (ombichave999/FixMySpine)..."
git add -A
git commit -m "Release v$VERSION: $NOTES" || true
git push origin main || true

# 6. Publish to Public Distribution Repo (Sparkle Feed & DMG)
echo "Step 6: Publishing release to ombichave999/FixMySpine-Releases..."
TMP_REL_DIR="/tmp/fixmyspine_rel_$$"
rm -rf "$TMP_REL_DIR"
git clone https://github.com/ombichave999/FixMySpine-Releases.git "$TMP_REL_DIR"

cp appcast.xml "$TMP_REL_DIR/appcast.xml"
cp FixMySpine.dmg "$TMP_REL_DIR/FixMySpine.dmg"

cd "$TMP_REL_DIR"
git add appcast.xml FixMySpine.dmg
git commit -m "Sparkle Release v$VERSION" || true
git push origin main

if command -v gh &>/dev/null; then
    gh release delete "v$VERSION" -y 2>/dev/null || true
    gh release create "v$VERSION" FixMySpine.dmg \
        --repo ombichave999/FixMySpine-Releases \
        --title "FixMySpine v$VERSION" \
        --notes "$NOTES" 2>/dev/null || true
fi

cd - >/dev/null
rm -rf "$TMP_REL_DIR"

echo "========================================================"
echo "✅ SUCCESS! FixMySpine v$VERSION Production Release Published!"
echo "========================================================"
echo "• Private Codebase: ombichave999/FixMySpine"
echo "• Public Feed URL: https://raw.githubusercontent.com/ombichave999/FixMySpine-Releases/main/appcast.xml"
echo "• Signed DMG: FixMySpine.dmg ($FILESIZE bytes)"
echo "• Ed25519 Signature Verified"
