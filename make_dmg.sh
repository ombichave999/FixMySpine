#!/bin/bash
# Builds FixMySpine.app then packages it into a shareable FixMySpine.dmg.
# Run from the FixMySpine folder:  bash make_dmg.sh
set -e
cd "$(dirname "$0")"

bash build.sh

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
echo "Created build/FixMySpine.dmg!"

echo ""
echo "Created FixMySpine.dmg in this folder. Send it to your brother!"
echo 'First open on his Mac: RIGHT CLICK the app > Open (it is self signed, macOS asks once).'
