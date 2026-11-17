#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/generate_project.py
signing=(CODE_SIGNING_ALLOWED=NO)
if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  signing=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi
xcodebuild -project QuickConvert.xcodeproj -scheme QuickConvert \
  -configuration Release -derivedDataPath build \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO "${signing[@]}" build
if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
  # Local preview only. App Groups and Finder activation require a real signing team.
  codesign --force --sign - build/Build/Products/Release/QuickConvert.app/Contents/PlugIns/QuickConvertFinder.appex
  codesign --force --sign - build/Build/Products/Release/QuickConvert.app
fi
