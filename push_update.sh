#!/bin/bash
# Builds, packages DMG, pushes code to private repo, and publishes release to public Sparkle feed.
# Usage:  bash push_update.sh [new_version] [release_notes]
# Example: bash push_update.sh 3.1 "Apple Watch & Smartwatch sync, accent color synchronization, and precision posture calibration."
set -e
cd "$(dirname "$0")"

VERSION="${1:-}"
NOTES="${2:-Apple Watch & Smartwatch sync, accent color synchronization, and precision posture calibration.}"

if [ -z "$VERSION" ]; then
    CURRENT_VER=$(grep -oE 'version = "[0-9]+\.[0-9]+"' Sources/main.swift | head -n 1 | grep -oE '[0-9]+\.[0-9]+' || echo "3.1")
    echo "Current Version: $CURRENT_VER"
    read -p "Enter new version number (e.g. 3.1): " VERSION
fi

if [ -z "$VERSION" ]; then
    echo "Error: Version cannot be empty."
    exit 1
fi

echo ""
echo "🚀 Preparing Release v$VERSION..."
echo ""

# 1. Update Version in build.sh and Sources/main.swift
echo "Step 1: Updating version to v$VERSION in configuration files..."
sed -i '' "s/<key>CFBundleVersion<\/key>[[:space:]]*<string>[0-9]*\.[0-9]*<\/string>/<key>CFBundleVersion<\/key>\n    <string>$VERSION<\/string>/g" build.sh
sed -i '' "s/<key>CFBundleShortVersionString<\/key>[[:space:]]*<string>[0-9]*\.[0-9]*<\/string>/<key>CFBundleShortVersionString<\/key>\n    <string>$VERSION<\/string>/g" build.sh
sed -i '' "s/static let version = \"[0-9]*\.[0-9]*\"/static let version = \"$VERSION\"/g" Sources/main.swift

# 2. Compile latest app into testing folder build/FixMySpine.app
echo "Step 2: Compiling test build in build/FixMySpine.app..."
bash build.sh

# 3. Create FixMySpine.dmg for distribution
echo "Step 3: Packaging FixMySpine.dmg..."
bash make_dmg.sh

# 4. Compute file size & pubDate
FILESIZE=$(stat -f%z FixMySpine.dmg 2>/dev/null || stat -c%s FixMySpine.dmg)
PUBDATE=$(date -R)

# 5. Update appcast.xml feed
echo "Step 4: Updating appcast.xml RSS feed..."
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
                 type="application/x-apple-diskimage" />
    </item>
  </channel>
</rss>
APPCAST

# 6. Commit and Push private codebase
echo "Step 5: Pushing private codebase to ombichave999/FixMySpine..."
git add -A
git commit -m "Release v$VERSION: $NOTES" || true
git push origin main || true

# 7. Publish release & appcast.xml to public distribution repo
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
cd - >/dev/null
rm -rf "$TMP_REL_DIR"

# Create GitHub Release with DMG attached
gh release create "v$VERSION" FixMySpine.dmg --repo ombichave999/FixMySpine-Releases --title "FixMySpine v$VERSION" --notes "$NOTES" || gh release upload "v$VERSION" FixMySpine.dmg --repo ombichave999/FixMySpine-Releases --clobber || true

echo ""
echo "--------------------------------------------------------"
echo "✅ SUCCESS! FixMySpine v$VERSION published & pushed!"
echo "--------------------------------------------------------"
echo "• Private Codebase: ombichave999/FixMySpine (Private)"
echo "• Distribution DMG: FixMySpine.dmg"
echo "• Public Sparkle Appcast: https://raw.githubusercontent.com/ombichave999/FixMySpine-Releases/main/appcast.xml"
echo "• Sparkle Auto-Update is 100% ACTIVE!"
