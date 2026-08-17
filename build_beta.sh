#!/bin/bash
# ==============================================================================
# FixMySpine - Beta Channel Release Automation
# Sparkle 2 + Ed25519 Cryptographic Signing + Appcast Beta RSS
# ==============================================================================

set -e
cd "$(dirname "$0")"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    CURRENT_VER=$(grep 'static let version =' Sources/main.swift | sed -E 's/.*"([^"]+)".*/\1/')
    read -p "Enter beta release version [e.g. ${CURRENT_VER}-beta1]: " INPUT_VER
    VERSION="${INPUT_VER:-${CURRENT_VER}-beta1}"
fi

NOTES="${2:-"Beta preview release: Testing experimental features, live sensor telemetry, and performance updates."}"
PUBDATE=$(date -R)
CHANNEL="beta"

echo "========================================================"
echo "🧪 Building FixMySpine Beta Release v$VERSION"
echo "   Channel: $CHANNEL"
echo "   Release Notes: $NOTES"
echo "========================================================"

# 1. Update Version in Sources/main.swift
echo "Step 1: Updating version to $VERSION in code..."
sed -i '' "s/static let version = \"[^\"]*\"/static let version = \"$VERSION\"/g" Sources/main.swift

# 2. Build FixMySpine.app and Package DMG
echo "Step 2: Building beta app and packaging DMG installer..."
bash make_dmg.sh "$VERSION" "$CHANNEL"
mv -f FixMySpine.dmg FixMySpine-Beta.dmg

# 3. Sign DMG with Sparkle 2 Ed25519 Private Key
echo "Step 3: Signing Beta DMG with Ed25519 private key..."
if [ ! -f "./Sparkle-Tools/bin/sign_update" ]; then
    echo "Error: ./Sparkle-Tools/bin/sign_update not found!"
    exit 1
fi

SIGNATURE=$(./Sparkle-Tools/bin/sign_update -p FixMySpine-Beta.dmg)
FILESIZE=$(stat -f%z FixMySpine-Beta.dmg 2>/dev/null || stat -c%s FixMySpine-Beta.dmg)

echo "   Ed25519 Signature: $SIGNATURE"
echo "   File Size: $FILESIZE bytes"

# 4. Generate appcast-beta.xml RSS feed
echo "Step 4: Generating appcast-beta.xml..."
cat > appcast-beta.xml <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>FixMySpine Beta Updates</title>
    <link>https://github.com/ombichave999/FixMySpine-Releases</link>
    <description>Beta and early access updates to FixMySpine</description>
    <language>en</language>
    <item>
      <title>FixMySpine v$VERSION</title>
      <sparkle:channel>beta</sparkle:channel>
      <description><![CDATA[
        <h2>FixMySpine v$VERSION Beta Release Notes</h2>
        <p>$NOTES</p>
      ]]></description>
      <pubDate>$PUBDATE</pubDate>
      <enclosure url="https://raw.githubusercontent.com/ombichave999/FixMySpine-Releases/main/FixMySpine-Beta.dmg"
                 sparkle:version="$VERSION"
                 sparkle:shortVersionString="$VERSION"
                 length="$FILESIZE"
                 type="application/x-apple-diskimage"
                 sparkle:edSignature="$SIGNATURE" />
    </item>
  </channel>
</rss>
APPCAST

# 5. Publish to Public Distribution Repo
echo "Step 5: Publishing Beta release to ombichave999/FixMySpine-Releases..."
TMP_REL_DIR="/tmp/fixmyspine_rel_$$"
rm -rf "$TMP_REL_DIR"
git clone https://github.com/ombichave999/FixMySpine-Releases.git "$TMP_REL_DIR"

cp appcast-beta.xml "$TMP_REL_DIR/appcast-beta.xml"
cp FixMySpine-Beta.dmg "$TMP_REL_DIR/FixMySpine-Beta.dmg"

cd "$TMP_REL_DIR"
git add appcast-beta.xml FixMySpine-Beta.dmg
git commit -m "Sparkle Beta Release v$VERSION" || true
git push origin main

if command -v gh &>/dev/null; then
    gh release delete "v$VERSION" -y 2>/dev/null || true
    gh release create "v$VERSION" FixMySpine-Beta.dmg \
        --repo ombichave999/FixMySpine-Releases \
        --title "FixMySpine Beta v$VERSION" \
        --notes "$NOTES" \
        --prerelease 2>/dev/null || true
fi

cd - >/dev/null
rm -rf "$TMP_REL_DIR"

echo "========================================================"
echo "🧪 SUCCESS! FixMySpine Beta v$VERSION Published!"
echo "========================================================"
echo "• Beta Feed URL: https://raw.githubusercontent.com/ombichave999/FixMySpine-Releases/main/appcast-beta.xml"
echo "• Beta Signed DMG: FixMySpine-Beta.dmg ($FILESIZE bytes)"
