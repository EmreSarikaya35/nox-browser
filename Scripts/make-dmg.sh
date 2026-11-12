#!/bin/sh
# Universal (Intel + Apple Silicon) Release derler ve build/NOX.dmg üretir.
set -e
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -project NOX.xcodeproj -scheme NOX -configuration Release -derivedDataPath build \
  ARCHS="x86_64 arm64" ONLY_ACTIVE_ARCH=NO build
rm -rf build/dmg
mkdir -p build/dmg
cp -R build/Build/Products/Release/NOX.app build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -volname "NOX Browser" -srcfolder build/dmg -ov -format UDZO build/NOX.dmg
echo "Hazır: build/NOX.dmg"
