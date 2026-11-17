#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build.sh
app="build/Build/Products/Release/QuickConvert.app"
mkdir -p dist
stage=$(mktemp -d "${TMPDIR:-/tmp}/quickconvert-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/QuickConvert.app"
cp README.md LICENSE "$stage/"
ln -s /Applications "$stage/Applications"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
output="dist/QuickConvert-$version-universal.dmg"
rm -f "$output"
hdiutil create -volname QuickConvert -srcfolder "$stage" -ov -format UDZO "$output"
shasum -a 256 "$output"
