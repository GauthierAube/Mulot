#!/bin/zsh
# Compile Mulot et l'installe dans /Applications.
set -e
cd "$(dirname "$0")"

swift build -c release
APP="build/Mulot.app"
mkdir -p build && touch build/.metadata_never_index  # pas de doublon dans Spotlight
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Mulot "$APP/Contents/MacOS/Mulot"
cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Resources/*.png Resources/*.icns "$APP/Contents/Resources/"

# Signature stable : macOS garde les autorisations d'une compilation à l'autre.
IDENTITY=$(security find-identity -p codesigning -v | grep "Apple Development" | head -1 | awk '{print $2}')
codesign --force --sign "${IDENTITY:--}" --identifier app.mulot "$APP"

if [[ "$1" == "--install" ]]; then
  pkill -x Mulot || true
  rm -rf "/Applications/Mulot.app"
  cp -R "$APP" /Applications/
  rm -rf "$APP"  # une seule Mulot sur le Mac : celle d'Applications
  open "/Applications/Mulot.app"
  echo "Installée dans /Applications et lancée."
fi
