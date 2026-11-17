#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/generate_project.py
bundle_engines="${QUICKCONVERT_BUNDLE_ENGINES:-0}"
if [[ "$bundle_engines" == "1" ]]; then
  python3 scripts/prepare_engines.py
fi
signing=(CODE_SIGNING_ALLOWED=NO)
if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  signing=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi
xcodebuild -project QuickConvert.xcodeproj -scheme QuickConvert \
  -configuration Release -derivedDataPath build \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO "${signing[@]}" build
app="build/Build/Products/Release/QuickConvert.app"
if [[ "$bundle_engines" == "1" ]]; then
  swift build --configuration release --product quickconvert --arch arm64 --arch x86_64
  cli_directory=$(swift build --configuration release --arch arm64 --arch x86_64 --show-bin-path)
  python3 scripts/embed_engines.py "$app"
  cp "$cli_directory/quickconvert" "$app/Contents/Helpers/quickconvert"
else
  # Remove runtimes left by an earlier full build; development builds must be unambiguous.
  rm -rf "$app/Contents/Helpers" "$app/Contents/Resources/ThirdPartyLicenses" "$app/Contents/Resources/ThirdPartySources"
  rm -f "$app/Contents/Resources/engines.lock.json"
fi
if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
  # Local preview only. App Groups and Finder activation require a real signing team.
  helper_identity="-"
  codesign --force --sign - "$app/Contents/PlugIns/QuickConvertFinder.appex"
else
  helper_identity=$(codesign --display --verbose=4 "$app" 2>&1 | sed -n 's/^Authority=//p' | head -n 1)
  if [[ -z "$helper_identity" ]]; then
    echo 'Cannot determine the containing app signing identity' >&2
    exit 1
  fi
fi
if [[ "$bundle_engines" == "1" ]]; then
  for helper in ffmpeg quickconvert; do
    codesign --force --sign "$helper_identity" --options runtime "$app/Contents/Helpers/$helper"
  done
fi
if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
  codesign --force --sign - "$app"
else
  codesign --force --sign "$helper_identity" --options runtime --preserve-metadata=entitlements,requirements,flags,runtime "$app"
fi
if [[ "$bundle_engines" == "1" ]]; then
  python3 scripts/verify_bundle.py "$app"
fi
