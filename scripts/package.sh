#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
target_arch="${1:-all}"
if [[ "$target_arch" == "all" ]]; then
  for target in arm64 x86_64; do bash scripts/package.sh "$target"; done
  exit 0
fi
case "$target_arch" in
  arm64|x86_64) ;;
  *) echo 'Usage: bash scripts/package.sh [all|arm64|x86_64]' >&2; exit 2 ;;
esac
QUICKCONVERT_ARCH="$target_arch" QUICKCONVERT_BUNDLE_ENGINES=1 bash scripts/build.sh
app="build/$target_arch/Build/Products/Release/QuickConvert.app"
mkdir -p dist
stage=$(mktemp -d "${TMPDIR:-/tmp}/quickconvert-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/QuickConvert.app"
cp README.md README.zh-TW.md CONTRIBUTING.md LICENSE "$stage/"
ditto docs "$stage/docs"
mkdir -p "$stage/distribution"
cp distribution/THIRD-PARTY-NOTICES.md "$stage/distribution/"
ln -s /Applications "$stage/Applications"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
output="dist/QuickConvert-$version-$target_arch.dmg"
rm -f "$output"
hdiutil create -volname QuickConvert -srcfolder "$stage" -ov -format UDZO "$output"
shasum -a 256 "$output" | tee "$output.sha256"
