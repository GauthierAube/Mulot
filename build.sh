#!/bin/zsh
# Compile Mulot et l'installe dans /Applications.
set -e
cd "$(dirname "$0")"

# Les textes viennent du catalogue Apple Localizable.xcstrings : texte source en français, traduction anglaise.
# Avec Xcode, le catalogue est mis à jour depuis le code, puis compilé dans Resources/<langue>.lproj. Ces fichiers
# compilés sont gardés dans le dépôt : sans Xcode (outils en ligne de commande seuls), on compile avec eux.
if xcrun --find xcstringstool >/dev/null 2>&1; then
  TEXTES="$PWD/.build/textes"; rm -rf "$TEXTES"; mkdir -p "$TEXTES"
  swift build -c release -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$TEXTES"
  # (Une compilation partielle ne réécrit pas tous les fichiers : on n'efface donc rien du catalogue.)
  xcrun xcstringstool sync Localizable.xcstrings --stringsdata "$TEXTES"/*.stringsdata --skip-marking-strings-stale
  xcrun xcstringstool compile Localizable.xcstrings -o Resources
  xcrun xcstringstool compile InfoPlist.xcstrings -o Resources
else
  swift build -c release
fi
APP="build/Mulot.app"
mkdir -p build && touch build/.metadata_never_index  # pas de doublon dans Spotlight
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Mulot "$APP/Contents/MacOS/Mulot"
cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Resources/*.png Resources/*.icns "$APP/Contents/Resources/"
cp -R Resources/*.lproj "$APP/Contents/Resources/"   # anglais et français

# Signature stable : macOS garde les autorisations d'une compilation à l'autre.
IDENTITY=$(security find-identity -p codesigning -v | grep "Apple Development" | head -1 | awk '{print $2}')
codesign --force --sign "${IDENTITY:--}" --identifier app.mulot "$APP"

if [[ "$1" == "--install" ]]; then
  pkill -x Mulot || true
  rm -rf "/Applications/Mulot.app"
  cp -R "$APP" /Applications/
  rm -rf "$APP"  # une seule Mulot sur le Mac : celle d'Applications
  open -g "/Applications/Mulot.app"  # en arrière-plan : ne prend pas le premier plan
  echo "Installée dans /Applications et lancée."
fi
