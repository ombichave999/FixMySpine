#!/bin/bash
# Builds FixMySpine.app then packages it into a shareable FixMySpine.dmg.
set -e
cd "$(dirname "$0")"

VERSION="${1:-3.7}"
CHANNEL="${2:-main}"

bash build.sh "$VERSION" "$CHANNEL"

echo "Packaging DMG…"
STAGE="tmp_dmg_folder"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "build/FixMySpine.app" "$STAGE/FixMySpine.app"
ln -s /Applications "$STAGE/Applications"

rm -f FixMySpine.dmg
hdiutil create -volname "FixMySpine" -srcfolder "$STAGE" -ov -format UDZO FixMySpine.dmg
rm -rf "$STAGE"

echo ""
echo "Created FixMySpine.dmg successfully!"
