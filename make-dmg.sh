#!/bin/zsh
# Fabrique dist/Mulot-<version>.dmg à envoyer à quelqu'un (Mac Apple Silicon et Intel).
set -e
cd "$(dirname "$0")"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

STAGE="build/dmg"
rm -rf "$STAGE"; mkdir -p "$STAGE/Mulot.app/Contents/MacOS" "$STAGE/Mulot.app/Contents/Resources"
touch build/.metadata_never_index
cp "$BIN/Mulot" "$STAGE/Mulot.app/Contents/MacOS/Mulot"
cp Info.plist "$STAGE/Mulot.app/Contents/Info.plist"
cp Resources/*.png Resources/*.icns "$STAGE/Mulot.app/Contents/Resources/"
IDENTITY=$(security find-identity -p codesigning -v | grep "Apple Development" | head -1 | awk '{print $2}')
codesign --force --sign "${IDENTITY:--}" --identifier app.mulot "$STAGE/Mulot.app"
ln -s /Applications "$STAGE/Applications"
cp tools/Lisez-moi.txt "$STAGE/Lisez-moi.txt"

mkdir -p dist
DMG="dist/Mulot-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Mulot" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"
echo "$DMG"
